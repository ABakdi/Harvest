import { zipSync } from 'fflate';
import { describe, expect, it } from 'vitest';
import { buildWorkbook, ExportSheet, type CellValue } from '@/app/data/archive-xlsx';
import { Geotagger, geotagUuid, type Locator } from '@/app/data/geotags';
import { applyImport, openArchive } from '@/app/data/import';
import { FakeServer } from './fake-server';
import { device } from './helpers';

/**
 * Only something done here and now gets this device's position
 * ([[Places]] PL2): rows an archive brings keep the places they came
 * with, and no geotag leaves the browser before its place is known.
 */

type Device = Awaited<ReturnType<typeof device>>;

/** A locator standing somewhere else entirely: today's position. */
function today(): { locator: Locator; asked: () => number } {
  let asked = 0;
  return {
    locator: {
      current: () => {
        asked++;
        return Promise.resolve({ latitude: 51.5, longitude: -0.12, accuracyM: 5, at: new Date('2026-09-19T12:00:00.000Z') });
      },
      lastKnown: () => Promise.resolve(null),
    },
    asked: () => asked,
  };
}

async function geotaggingOn(h: Device) {
  await h.settings.setBool('features.places', true);
  await h.settings.setBool('web.geotagging', true);
}

function archive(sheets: Record<string, CellValue[][]>): Uint8Array {
  const workbook = buildWorkbook(
    Object.entries(sheets).map(([name, [headers, ...rows]]) => new ExportSheet({ name, headers: headers as string[], rows })),
  );
  return zipSync({ 'harvest.xlsx': workbook }, { level: 0 });
}

describe('importing with geotagging on', () => {
  it('keeps the archive’s geotag and adds none of today’s', async () => {
    const h = await device(new FakeServer());
    const { locator, asked } = today();
    const tagger = new Geotagger(h.db, h.writer, h.clock, locator);
    await geotaggingOn(h);

    const tagged = geotagUuid('notes', 'n1');
    const bundle = openArchive(
      archive({
        Notes: [
          ['Uuid', 'Title', 'Body', 'UpdatedAt'],
          ['n1', 'Market', 'bread', '2026-08-01T09:00:00Z'],
          ['n2', 'Untagged', 'milk', '2026-08-01T09:00:00Z'],
        ],
        Geotags: [
          ['Uuid', 'TargetTable', 'TargetUuid', 'HarvestDay', 'At', 'Latitude', 'Longitude', 'AccuracyM', 'State', 'UpdatedAt'],
          [tagged, 'notes', 'n1', '2026-08-01', '2026-08-01T09:00:00Z', 36.75, 3.06, 12, 'fixed', '2026-08-01T09:00:05Z'],
        ],
      }),
    );
    await applyImport(h.writer, bundle);
    await tagger.settled;

    const tags = await h.db.rows('geotags').toArray();
    expect(tags).toHaveLength(1);
    expect(tags[0]).toMatchObject({ uuid: tagged, latitude: 36.75, longitude: 3.06, state: 'fixed', at: '2026-08-01T09:00:00.000Z' });
    expect(await h.db.rows('geotags').get(geotagUuid('notes', 'n2'))).toBeUndefined();
    expect(asked()).toBe(0);
  });

  it('still tags what I write myself', async () => {
    const h = await device(new FakeServer());
    const { locator } = today();
    const tagger = new Geotagger(h.db, h.writer, h.clock, locator);
    await geotaggingOn(h);
    await h.writer.run((tx) =>
      tx.put('notes', { uuid: 'mine', title: 'Here', folder: '', body: '', createdAt: tx.now(), updatedAt: tx.now(), deletedAt: null }),
    );
    await tagger.settled;
    expect(await h.db.rows('geotags').get(geotagUuid('notes', 'mine'))).toMatchObject({ state: 'fixed', latitude: 51.5 });
  });
});

describe('a geotag waiting for its place', () => {
  it('is never stored, nor queued for sync, while pending', async () => {
    const h = await device(new FakeServer());
    let release!: () => void;
    const held = new Promise<void>((resolve) => (release = resolve));
    const locator: Locator = {
      current: async () => {
        await held;
        return null;
      },
      lastKnown: () => Promise.resolve(null),
    };
    const tagger = new Geotagger(h.db, h.writer, h.clock, locator);
    await geotaggingOn(h);
    await h.writer.run((tx) =>
      tx.put('notes', { uuid: 'n1', title: 'Idea', folder: '', body: '', createdAt: tx.now(), updatedAt: tx.now(), deletedAt: null }),
    );

    // The fix is still out: as a closed tab would leave it, nothing pending exists.
    expect(await h.db.rows('geotags').count()).toBe(0);
    expect((await h.db.outbox.toArray()).filter((row) => row.table === 'geotags')).toHaveLength(0);

    release();
    await tagger.settled;
    const tag = await h.db.rows('geotags').get(geotagUuid('notes', 'n1'));
    expect(tag).toMatchObject({ state: 'unavailable', latitude: null, at: '2026-09-19T12:00:00.000Z' });
  });
});
