import { Blob as NodeBlob } from 'node:buffer';
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { DataCard } from '@/app/components/data-card';
import { HarvestContext } from '@/app/context';
import { buildArchive } from '@/app/data/export';
import { FakeServer } from './fake-server';
import { device } from './helpers';

// Node's Blob survives IndexedDB's structured clone and has arrayBuffer().
globalThis.Blob = NodeBlob as unknown as typeof Blob;

afterEach(() => {
  vi.restoreAllMocks();
});

const at = '2026-09-18T08:00:00.000Z';

async function withSeed() {
  const h = await device(new FakeServer());
  await h.writer.run(async (tx) => {
    await tx.put('commitments', {
      uuid: 'seed-1',
      type: 'habit',
      title: 'Read 20 pages',
      scheduleJson: '{"type":"daily"}',
      totalTarget: null,
      dailyCommitment: null,
      dueDay: null,
      pausedAt: null,
      note: null,
      remindAt: null,
      deadline: null,
      goalUuid: null,
      archivedAt: null,
      archiveNote: null,
      deletedAt: null,
      createdAt: at,
      updatedAt: at,
    });
    await tx.put('check_ins', {
      uuid: 'check-1',
      commitmentUuid: 'seed-1',
      harvestDay: '2026-09-18',
      quantity: 1,
      loggedAt: at,
      deletedAt: null,
      updatedAt: at,
    });
  });
  return h;
}

function renderCard(h: Awaited<ReturnType<typeof device>>) {
  render(
    <HarvestContext.Provider value={h}>
      <DataCard />
    </HarvestContext.Provider>,
  );
}

describe('My data on the web', () => {
  it('downloads the archive, named the way the phone names it', async () => {
    const h = await withSeed();
    const made = vi.fn((_: Blob) => 'blob:archive');
    Object.assign(URL, { createObjectURL: made, revokeObjectURL: vi.fn() });
    const clicked = vi.spyOn(HTMLAnchorElement.prototype, 'click').mockImplementation(() => {});
    renderCard(h);

    await userEvent.click(screen.getByRole('button', { name: 'Download the archive' }));
    expect(await screen.findByText(/^Saved as harvest-2026-09-19-\d{4}\.zip$/)).toBeInTheDocument();
    expect(clicked).toHaveBeenCalledTimes(1);
    const blob = made.mock.calls[0]![0];
    expect(blob.size).toBeGreaterThan(1000);
  });

  it('offers the location switch only when places are on, and remembers it here', async () => {
    const h = await withSeed();
    renderCard(h);
    expect(screen.queryByRole('switch', { name: 'Include my location history' })).not.toBeInTheDocument();
    await h.writer.run((tx) => tx.put('kv_settings', { key: 'features.places', valueJson: 'true', updatedAt: at }));
    const toggle = await screen.findByRole('switch', { name: 'Include my location history' });
    expect(toggle).toBeChecked();
    await userEvent.click(toggle);
    await waitFor(async () => expect((await h.db.rows('kv_settings').get('export.includePlaces'))?.valueJson).toBe('false'));
    // A choice about this browser's exports: never queued for sync.
    expect((await h.db.outbox.toArray()).some((entry) => entry.key === 'export.includePlaces')).toBe(false);
  });

  it('shows what an archive would do, and only merges when asked', async () => {
    const source = await withSeed();
    const { bytes, fileName } = await buildArchive(source.db, () => Promise.resolve(null), { now: new Date(at) });
    const target = await device(new FakeServer());
    renderCard(target);

    const file = new File([bytes.slice()], fileName, { type: 'application/zip' });
    await userEvent.upload(screen.getByLabelText('Bring an archive back'), file);
    expect(await screen.findByText(fileName)).toBeInTheDocument();
    expect(screen.getByText('2 new, 0 to update')).toBeInTheDocument();
    expect(screen.getByText('Seeds')).toBeInTheDocument();
    expect(screen.getByText('Check-ins')).toBeInTheDocument();
    // Nothing has been written yet.
    expect(await target.db.rows('commitments').count()).toBe(0);

    await userEvent.click(screen.getByRole('button', { name: 'Merge it in' }));
    expect(await screen.findByText('Done — 2 added, 0 updated.')).toBeInTheDocument();
    expect((await target.db.rows('commitments').get('seed-1'))?.title).toBe('Read 20 pages');
  });

  it('says so when the file is not a Harvest archive', async () => {
    const h = await device(new FakeServer());
    renderCard(h);
    await userEvent.upload(screen.getByLabelText('Bring an archive back'), new File(['hello'], 'notes.zip', { type: 'application/zip' }));
    expect(await screen.findByText('That file could not be opened.')).toBeInTheDocument();
  });
});
