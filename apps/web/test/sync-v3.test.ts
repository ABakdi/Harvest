import { describe, expect, it, vi } from 'vitest';
import { HarvestDB } from '@/app/data/db';
import { Keyring, PinLimitedError, WrongPassphraseError } from '@/app/sync/keyring';
import { FakeServer } from './fake-server';
import { device, openStored, syncing, testUser } from './helpers';

const expense = { amountMinor: 45_000, currency: 'DZD', category: 'food', note: 'Couscous', fromWallet: false, day: '2026-09-19' };

describe('the PIN, checked by the server (S6-04)', () => {
  it('hands the key share out only for the right PIN, with a limit on tries', async () => {
    const server = new FakeServer();
    const a = await device(server);
    await a.keyring.unlock('2468', testUser.syncSalt, 1);
    // Nothing a session is given before a right proof opens anything.
    expect(await server.syncKey()).not.toHaveProperty('keyShare');

    const b = await device(server);
    for (let left = 4; left >= 0; left--) {
      await expect(b.keyring.unlock('1357', testUser.syncSalt, 1)).rejects.toSatisfy(
        (error: unknown) => error instanceof WrongPassphraseError && error.triesLeft === left,
      );
    }
    await expect(b.keyring.unlock('2468', testUser.syncSalt, 1)).rejects.toBeInstanceOf(PinLimitedError);
    expect(await b.keyring.key(testUser.syncSalt)).toBeNull();
    server.wrong = 0;
    await b.keyring.unlock('2468', testUser.syncSalt, 1);
    expect(await b.keyring.epoch()).toBe(1);
  });
});

describe('the key epoch on every sealed write (S6-07)', () => {
  it('a sealed push refused for a stale epoch forgets the key, says so, and keeps the change', async () => {
    const server = new FakeServer();
    const b = await device(server);
    await b.keyring.unlock('2468', testUser.syncSalt, 1);
    await b.engine.sync();
    // Started over elsewhere between this browser's check and its push.
    const uuid = await b.money.log(expense);
    const check = vi.spyOn(b.keyring, 'stillTheAccounts').mockResolvedValue(true);
    server.epoch = 2;
    await b.engine.sync();
    check.mockRestore();
    expect(b.engine.status.pinChanged).toBe(true);
    expect(await b.keyring.key(testUser.syncSalt)).toBeNull();
    expect(server.get('expenses', uuid)).toBeUndefined();
    expect(await b.db.outbox.where('table').equals('expenses').count()).toBeGreaterThan(0);
  });

  it('sends nothing before the PIN, and names the epoch with every batch after (Phase 7)', async () => {
    const server = new FakeServer();
    const b = await device(server);
    const push = vi.spyOn(server, 'push');
    await b.notes.create({ title: 'Plain' });
    await b.engine.sync();
    expect(push).not.toHaveBeenCalled();
    await b.keyring.unlock('2468', testUser.syncSalt, 1);
    await b.money.log(expense);
    await b.engine.sync();
    expect(push).toHaveBeenCalled();
    for (const [body] of push.mock.calls) expect(body).toMatchObject({ keyEpoch: 1 });
  });
});

describe('batches filled by bytes (Q6-03)', () => {
  async function longNotes(h: Awaited<ReturnType<typeof device>>, count: number, length: number) {
    for (let i = 0; i < count; i++) {
      await h.writer.run((tx) =>
        tx.put('notes', {
          uuid: `long-${i}`,
          title: `Long ${i}`,
          folder: '',
          body: 'x'.repeat(length),
          createdAt: tx.now(),
          updatedAt: tx.now(),
          deletedAt: null,
        }),
      );
    }
  }

  it('stops a batch before the body limit, and every row goes', async () => {
    const server = new FakeServer();
    const h = await syncing(server);
    // Straight to the store, near the longest a note may be.
    for (let i = 0; i < 8; i++) {
      const now = h.clock().toISOString();
      await h.db.rows('notes').put({ uuid: `long-${i}`, title: `Long ${i}`, folder: '', body: 'x'.repeat(480 * 1024), createdAt: now, updatedAt: now, deletedAt: null });
      await h.db.outbox.add({ table: 'notes', key: `long-${i}`, op: 'upsert', queuedAt: now });
    }
    await h.engine.sync();
    // The four built-in lists the PIN sent again and six sealed notes
    // fill a push; the last two go in the next.
    expect(server.batches.slice(0, 2)).toEqual([10, 2]);
    expect(await h.db.outbox.count()).toBe(0);
  });

  it('halves a batch the server finds too large (413)', async () => {
    const server = new FakeServer();
    const h = await syncing(server);
    await longNotes(h, 5, 10);
    server.tooLargeOver = 2;
    await h.engine.sync();
    expect(h.engine.status.phase).toBe('idle');
    expect(await h.db.outbox.count()).toBe(0);
    for (let i = 0; i < 5; i++) expect(server.get('notes', `long-${i}`)).toBeDefined();
  });

  it('refuses here, with a reason, one change too large for any push, and sends the rest', async () => {
    const server = new FakeServer();
    const h = await syncing(server);
    const now = h.clock().toISOString();
    // Within every column's length, and still past a push once sealed:
    // three bytes a character, in two columns.
    const wide = '€'.repeat(499_000);
    await h.db.rows('notes').put({ uuid: 'huge', title: wide, folder: '', body: wide, createdAt: now, updatedAt: now, deletedAt: null });
    await h.db.outbox.add({ table: 'notes', key: 'huge', op: 'upsert', queuedAt: now });
    await h.notes.create({ title: 'Small' });
    await h.engine.sync();
    expect(h.engine.status.invalid).toBe(1);
    expect(h.engine.status.refusedFor).toContain('too_large');
    expect(server.get('notes', 'huge')).toBeUndefined();
    const titles = await Promise.all(
      [...server.stored.values()].filter((record) => record.table === 'notes').map(async (record) => (await openStored(record))?.title),
    );
    expect(titles).toContain('Small');
  });
});

describe("a pull leaves out this browser's own writes", () => {
  it('except when the history is pulled again from nothing', async () => {
    const server = new FakeServer();
    const h = await device(server);
    await h.notes.create({ title: 'Mine' });
    await h.engine.sync();
    const deviceId = server.pulledAs.at(-1);
    expect(deviceId).toBeTruthy();
    expect(server.pulledAs.every((id) => id === deviceId)).toBe(true);
    await h.keyring.unlock('2468', testUser.syncSalt, 1);
    server.pulledAs.length = 0;
    await h.engine.sync();
    expect(server.pulledAs.at(-1)).toBe(deviceId);
  });
});

describe('tabs share the key (Q6-05)', () => {
  it('a key kept or forgotten in one tab reaches the others, and none wipes a newer key', async () => {
    const db = new HarvestDB(`tabs-${Date.now()}`);
    await db.open();
    const server = new FakeServer();
    const a = new Keyring(db, server);
    const b = new Keyring(db, server);
    expect(await b.key(null)).toBeNull();
    await a.unlock('2468', undefined, 1);
    await vi.waitFor(async () => expect(await b.key(null)).not.toBeNull());

    // Started over, and a new PIN kept in tab A; tab B still thinks the old one.
    const oldId = await b.keyId();
    await server.startOverSyncKey('the password');
    await a.unlock('9731', undefined, 1);
    expect(await b.forgetIfStill(oldId ?? undefined)).toBe(false);
    expect(await a.key(null)).not.toBeNull();
    expect(await a.epoch()).toBe(2);

    await a.clear();
    await vi.waitFor(async () => expect(await b.key(null)).toBeNull());
    db.close();
  });
});

describe('one sync at a time across tabs (Q6-06)', () => {
  it('runs each sync under the browser-wide lock', async () => {
    const requested: string[] = [];
    const locks = {
      request: (name: string, run: () => Promise<unknown>) => {
        requested.push(name);
        return run();
      },
    };
    vi.stubGlobal('navigator', { ...navigator, locks });
    try {
      const h = await device(new FakeServer());
      await h.engine.sync();
      expect(requested).toContain('harvest-sync');
    } finally {
      vi.unstubAllGlobals();
    }
  });
});
