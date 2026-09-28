import { Blob as NodeBlob } from 'node:buffer';
import { openFileAny, sealFile, sealRowV2, trailKeyOf, type PulledRecord } from '@harvest/contracts';
import { HarvestDay } from '@harvest/core';
import { afterEach, beforeAll, describe, expect, it, vi } from 'vitest';
import { getMeta, metaKeys } from '@/app/data/db';
import { sha256Of } from '@/app/data/files';
import { LocationHistoryRepository } from '@/app/data/places';
import { Keyring } from '@/app/sync/keyring';
import { ApiError, api } from '@/lib/api';
import { FakeServer } from './fake-server';
import { device, openStored, syncing, testClock, testFileName, testKey, testNameKey, testPin, testUser } from './helpers';

/** Every table sealed, and the server told once (Phase 7, M7.1 and M7.2). */

beforeAll(() => {
  // jsdom's Blob does not survive IndexedDB's structured clone; Node's does.
  vi.stubGlobal('Blob', NodeBlob);
});

afterEach(() => {
  vi.restoreAllMocks();
});

const at = '2026-09-18T09:00:00.000Z';

function plainNote(uuid: string, title: string, createdAt = at) {
  return {
    table: 'notes' as const,
    uuid,
    updatedAt: at,
    deletedAt: null,
    data: { uuid, title, folder: '', body: `${title}, in the clear`, createdAt, updatedAt: at, deletedAt: null },
  };
}

function memoryRow(uuid: string, fileHash: string | null) {
  return {
    uuid,
    albumUuid: 'a1',
    harvestDay: '2026-09-19',
    path: `a1/${uuid}.jpg`,
    kind: 'photo' as const,
    note: null,
    fileHash,
    capturedAt: '2026-09-19T10:00:00.000Z',
    updatedAt: '2026-09-19T10:00:00.000Z',
    deletedAt: null,
  };
}

const inTheClear = (server: FakeServer) => [...server.stored.values()].filter((record) => record.data !== undefined);

describe('rows kept in the clear before Phase 7', () => {
  it('are taken, checked as an opened row is, and one that fails is parked', async () => {
    const server = new FakeServer();
    server.storePlain(plainNote('n1', 'Kept'));
    server.storePlain(plainNote('n2', 'Broken', 'yesterday'));
    const b = await device(server);
    await b.engine.sync();
    expect((await b.db.rows('notes').get('n1'))?.title).toBe('Kept');
    expect(await b.db.rows('notes').get('n2')).toBeUndefined();
    expect(await b.db.parked.count()).toBe(1);
  });

  it('go up sealed once, at their own clock, and then the server lets go of them', async () => {
    const server = new FakeServer();
    server.storePlain(plainNote('n1', 'First'));
    server.storePlain(plainNote('n2', 'Second'));
    const a = await syncing(server);
    await a.engine.sync();

    expect(a.engine.status.phase).toBe('idle');
    expect(server.sealedCalls).toEqual([{ deviceId: expect.any(String) as string, keyEpoch: 1 }]);
    expect(inTheClear(server)).toEqual([]);
    const n1 = server.get('notes', 'n1');
    expect(n1?.enc).toBeDefined();
    expect(n1?.updatedAt).toBe(at);
    expect(await openStored(n1)).toMatchObject({ title: 'First', body: 'First, in the clear' });
    expect(await getMeta(a.db, metaKeys.sealedFor)).toBe(1);
    // A row sent again unchanged is not behind: the history is not pulled again.
    expect(await getMeta(a.db, metaKeys.rebuild)).toBeUndefined();

    const pushes = server.pushes;
    await a.engine.sync();
    expect(server.sealedCalls).toHaveLength(1);
    expect(server.pushes).toBe(pushes);
  });

  it('are sealed by a browser that had them from before, not only by one that pulls them now', async () => {
    const server = new FakeServer();
    server.storePlain(plainNote('n1', 'Old'));
    // Pulled while this browser had no key: here, and the cursor past it.
    const a = await device(server);
    await a.engine.sync();
    expect(await a.db.rows('notes').get('n1')).toBeDefined();
    await a.keyring.unlock(testPin, testUser.syncSalt, 1);
    await a.engine.sync();
    expect(inTheClear(server)).toEqual([]);
    expect(await openStored(server.get('notes', 'n1'))).toMatchObject({ title: 'Old' });
  });

  it('are not let go of while a row here is refused, unread, or no key is here', async () => {
    const server = new FakeServer();
    server.storePlain(plainNote('n1', 'Kept'));
    server.storePlain(plainNote('n2', 'Broken', 'yesterday'));
    const locked = await device(server);
    await locked.engine.sync();
    expect(server.sealedCalls).toEqual([]);

    // The broken row is parked here: the server keeps its copy.
    const a = await syncing(server);
    await a.engine.sync();
    expect(server.sealedCalls).toEqual([]);
    expect(inTheClear(server).map((record) => record.uuid)).toEqual(['n2']);
    expect(server.get('notes', 'n1')?.enc).toBeDefined();
  });
});

describe('files named by a keyed hash', () => {
  it('a row that names a file says which beside its envelope, by the name, never the hash', async () => {
    const server = new FakeServer();
    const a = await syncing(server);
    vi.spyOn(api, 'filesMissing').mockResolvedValue({ missing: [], usedBytes: 0, quotaBytes: 1 });
    const hash = 'f'.repeat(64);
    await a.db.rows('memories').put(memoryRow('m1', hash));
    await a.db.outbox.add({ table: 'memories', key: 'm1', op: 'upsert', queuedAt: '2026-09-19T10:00:00.000Z' });
    await a.engine.sync();

    const stored = server.get('memories', 'm1')!;
    expect(stored.file).toBe(await testFileName(hash));
    expect(JSON.stringify(stored)).not.toContain(hash);
    // For the server alone: a pull does not hand it back.
    const { records } = await server.pull(0, 100);
    expect(records.find((record: PulledRecord) => record.uuid === 'm1')).not.toHaveProperty('file');
  });

  it('a file stored under its plain hash is fetched, sealed again and sent under its name', async () => {
    const server = new FakeServer();
    const h = await syncing(server);
    const bytes = new Uint8Array(300).map((_, i) => (i * 7) % 256);
    const sha256 = await sha256Of(bytes.slice().buffer);
    const name = await testFileName(sha256);
    const old = await sealFile(await testKey(), sha256, bytes);
    await h.db.rows('memories').put(memoryRow('m1', sha256));

    const held = new Set([sha256]);
    vi.spyOn(api, 'filesMissing').mockImplementation((names) =>
      Promise.resolve({ missing: names.filter((asked) => !held.has(asked)), usedBytes: 0, quotaBytes: 1 }),
    );
    vi.spyOn(api, 'file').mockImplementation((asked) =>
      asked === sha256 ? Promise.resolve({ sealed: old.sealed, iv: old.iv }) : Promise.reject(new ApiError(404, 'not_found', 'None')),
    );
    const sent: { name: string; sealed: ArrayBuffer; iv: string }[] = [];
    vi.spyOn(api, 'putFile').mockImplementation((asked, sealed, iv) => {
      held.add(asked);
      sent.push({ name: asked, sealed, iv });
      return Promise.resolve({ sha256: asked, bytes: sealed.byteLength, had: false });
    });

    expect(await h.files.settle()).toBe(true);
    expect(sent.map((file) => file.name)).toEqual([name]);
    const opened = await openFileAny(await testKey(), name, { iv: sent[0]!.iv, ct: sent[0]!.sealed });
    expect(opened).toEqual(bytes);
    // Named already: the row is left as it is.
    expect((await h.db.rows('memories').get('m1'))?.updatedAt).toBe('2026-09-19T10:00:00.000Z');
  });

  it('a file on the server under neither name does not hold the sealing up', async () => {
    const server = new FakeServer();
    const h = await syncing(server);
    await h.db.rows('memories').put(memoryRow('m1', 'e'.repeat(64)));
    vi.spyOn(api, 'filesMissing').mockImplementation((names) => Promise.resolve({ missing: names, usedBytes: 0, quotaBytes: 1 }));
    vi.spyOn(api, 'file').mockRejectedValue(new ApiError(404, 'not_found', 'None'));
    expect(await h.files.settle()).toBe(true);
  });
});

describe('the key kept here', () => {
  it('a key kept by 3.1, with no name key, is not used: the PIN is asked once more', async () => {
    const server = new FakeServer();
    const h = await device(server);
    await h.db.meta.put({
      key: metaKeys.privateKeyV3,
      value: { key: await testKey(), salt: testUser.syncSalt, epoch: 1, id: 'old', v: 3 },
    });
    const keyring = new Keyring(h.db, server);
    expect(await keyring.key(testUser.syncSalt)).toBeNull();
    expect(await keyring.nameKey(testUser.syncSalt)).toBeNull();

    await keyring.unlock(testPin, testUser.syncSalt, 1);
    expect(await h.db.meta.get(metaKeys.privateKeyV3)).toBeUndefined();
    const nameKey = await keyring.nameKey(testUser.syncSalt);
    expect(nameKey?.extractable).toBe(false);
    expect(nameKey?.usages).toEqual(['sign']);
    expect((await keyring.key(testUser.syncSalt))?.extractable).toBe(false);
  });
});

describe('the trail, a day a row (M7.3)', () => {
  const day = '2026-09-19';

  function point(uuid: string, updatedAt: string, latitude = 36.75, deletedAt: string | null = null) {
    return {
      uuid,
      recordedAt: '2026-09-19T08:00:00.000Z',
      latitude,
      longitude: 3.05,
      accuracyM: 10,
      speedMps: null,
      altitudeM: null,
      updatedAt,
      deletedAt,
    };
  }

  async function storeDay(server: FakeServer, points: ReturnType<typeof point>[], updatedAt: string, seq: number) {
    const key = await trailKeyOf(await testNameKey(), day);
    const data = { key, harvestDay: day, points, updatedAt };
    const clocks = { updatedAt, deletedAt: null };
    server.stored.set(`trail_days/${key}`, {
      table: 'trail_days',
      uuid: key,
      ...clocks,
      enc: await sealRowV2(await testKey(), 'trail_days', key, clocks, data),
      seq,
    });
    return key;
  }

  it('opens a day into its points, each merged on its own clock, and never drops one a newer copy lacks', async () => {
    const server = new FakeServer();
    await storeDay(server, [point('p1', '2026-09-19T08:00:00.000Z'), point('p2', '2026-09-19T08:00:00.000Z')], '2026-09-19T08:00:00.000Z', 1);
    // Early in the day: the one-time sealing sends the day back stamped
    // 07:00, older than the server's, so the server keeps its own.
    const b = await syncing(server, testClock('2026-09-19T07:30:00.000Z'));
    await b.engine.sync();
    expect((await b.db.rows('location_points').toArray()).map((row) => row.uuid).sort()).toEqual(['p1', 'p2']);
    expect((await b.db.rows('location_points').get('p1'))?.harvestDay).toBe(day);
    expect(b.engine.status.sealed).toBe(0);

    // A later copy: p1 moved on, p2 left out, p3 new and deleted at once.
    await storeDay(
      server,
      [point('p1', '2026-09-19T09:00:00.000Z', 36.8), point('p3', '2026-09-19T09:00:00.000Z', 36.7, '2026-09-19T09:00:00.000Z')],
      '2026-09-19T09:00:00.000Z',
      1000,
    );
    await b.engine.sync();
    expect((await b.db.rows('location_points').get('p1'))?.latitude).toBe(36.8);
    expect(await b.db.rows('location_points').get('p2')).toBeDefined();
    expect((await b.db.rows('location_points').get('p3'))?.deletedAt).toBe('2026-09-19T09:00:00.000Z');
  });

  it('waits sealed without the key, and opens into points once it is entered', async () => {
    const server = new FakeServer();
    const b = await device(server);
    await b.keyring.unlock(testPin, testUser.syncSalt, 1);
    await b.keyring.clear();
    const key = await storeDay(server, [point('p1', '2026-09-19T08:00:00.000Z')], '2026-09-19T08:00:00.000Z', 1);
    await b.engine.sync();
    expect(await b.db.sealed.get(['trail_days', key])).toBeDefined();
    await b.keyring.unlock(testPin, testUser.syncSalt, 1);
    await b.engine.openSealed();
    expect(await b.db.rows('location_points').get('p1')).toBeDefined();
    expect(await b.db.sealed.get(['trail_days', key])).toBeUndefined();
  });

  it('sends a changed point as its whole day, under the keyed day, on the hour and always later', async () => {
    const server = new FakeServer();
    const a = await syncing(server);
    // The one-time sealing done, with nothing to seal yet.
    await a.engine.sync();
    await a.db.rows('location_points').bulkPut([
      { ...point('p1', '2026-09-19T08:00:00.000Z'), harvestDay: day },
      { ...point('p2', '2026-09-19T08:00:00.000Z'), harvestDay: day },
    ]);
    a.clock.set('2026-09-19T12:34:56.000Z');
    const history = new LocationHistoryRepository(a.writer);
    const deletedAt = await history.deleteDay(HarvestDay.parse(day));
    await a.engine.sync();

    const key = await trailKeyOf(await testNameKey(), day);
    expect([...server.stored.values()].some((record) => record.table === 'location_points')).toBe(false);
    const stored = server.get('trail_days', key)!;
    expect(stored.updatedAt).toBe('2026-09-19T12:00:00.000Z');
    const opened = (await openStored(stored)) as { harvestDay: string; points: { uuid: string; deletedAt: string | null }[] };
    expect(opened.harvestDay).toBe(day);
    expect(opened.points.map((p) => [p.uuid, p.deletedAt]).sort()).toEqual([
      ['p1', deletedAt],
      ['p2', deletedAt],
    ]);
    // Not even the day is in the clear: the key is a keyed hash of it.
    expect(stored.uuid).toMatch(/^[0-9a-f]{32}$/);

    // Brought back within the same hour: the day goes again, a second on.
    a.clock.set('2026-09-19T12:40:00.000Z');
    await history.restoreDay(HarvestDay.parse(day), deletedAt);
    await a.engine.sync();
    expect(server.get('trail_days', key)!.updatedAt).toBe('2026-09-19T12:00:01.000Z');
    expect(await a.db.outbox.count()).toBe(0);
  });

  it('sends a point gone for good as its own tombstone, which the server takes', async () => {
    const server = new FakeServer();
    const a = await syncing(server);
    await a.db.rows('location_points').put({ ...point('p1', '2026-09-19T08:00:00.000Z'), harvestDay: day });
    await new LocationHistoryRepository(a.writer).deleteAll();
    await a.engine.sync();
    expect(server.get('location_points', 'p1')).toMatchObject({ purged: true });
    expect(a.engine.status.invalid).toBe(0);
  });

  it('never holds the sealing up for a point the server refused as retired', async () => {
    const server = new FakeServer();
    const a = await syncing(server);
    await a.db.outbox.add({
      table: 'location_points',
      key: 'p-old',
      op: 'upsert',
      queuedAt: '2026-09-19T08:00:00.000Z',
      invalid: [{ path: ['table'], message: 'retired', code: 'retired_table' }],
    });
    await a.engine.sync();
    expect(server.sealedCalls).toHaveLength(1);
  });
});

describe('the trail in the one-time sealing', () => {
  it('sends every point held here again as its day, before the server lets go of the points', async () => {
    const server = new FakeServer();
    // Points a 3.1 phone sealed one by one, pulled here before the key.
    const key = await testKey();
    const points = [
      { uuid: 'p1', harvestDay: '2026-09-18', updatedAt: '2026-09-18T08:00:00.000Z', deletedAt: null },
      { uuid: 'p2', harvestDay: '2026-09-18', updatedAt: '2026-09-18T09:00:00.000Z', deletedAt: '2026-09-18T10:00:00.000Z' },
      { uuid: 'p3', harvestDay: '2026-09-19', updatedAt: '2026-09-19T08:00:00.000Z', deletedAt: null },
    ];
    for (const [index, p] of points.entries()) {
      const data = {
        uuid: p.uuid,
        harvestDay: p.harvestDay,
        recordedAt: p.updatedAt,
        latitude: 36.75,
        longitude: 3.05,
        accuracyM: null,
        speedMps: null,
        altitudeM: null,
        updatedAt: p.updatedAt,
        deletedAt: p.deletedAt,
      };
      const clocks = { updatedAt: p.updatedAt, deletedAt: p.deletedAt };
      server.stored.set(`location_points/${p.uuid}`, {
        table: 'location_points',
        uuid: p.uuid,
        ...clocks,
        enc: await sealRowV2(key, 'location_points', p.uuid, clocks, data),
        seq: index + 1,
      });
    }
    const sealedAt: number[] = [];
    const sealed = server.sealed.bind(server);
    vi.spyOn(server, 'sealed').mockImplementation((body) => {
      sealedAt.push([...server.stored.values()].filter((record) => record.table === 'trail_days').length);
      return sealed(body);
    });

    const a = await syncing(server);
    await a.engine.sync();
    expect(await a.db.rows('location_points').count()).toBe(3);

    // Both days were on the server before it was told, and hold every point.
    expect(sealedAt).toEqual([2]);
    const nameKey = await testNameKey();
    const first = (await openStored(server.get('trail_days', await trailKeyOf(nameKey, '2026-09-18')))) as {
      points: { uuid: string; deletedAt: string | null }[];
    };
    expect(first.points.map((p) => [p.uuid, p.deletedAt]).sort()).toEqual([
      ['p1', null],
      ['p2', '2026-09-18T10:00:00.000Z'],
    ]);
    const second = (await openStored(server.get('trail_days', await trailKeyOf(nameKey, '2026-09-19')))) as {
      points: { uuid: string }[];
    };
    expect(second.points.map((p) => p.uuid)).toEqual(['p3']);
    expect(await a.db.outbox.count()).toBe(0);
  });
});
