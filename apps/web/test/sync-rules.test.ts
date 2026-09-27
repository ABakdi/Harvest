import { sealRow, type PushBody, type PushResult } from '@harvest/contracts';
import { describe, expect, it, vi } from 'vitest';
import { getMeta, metaKeys, setMeta } from '@/app/data/db';
import { FileStore } from '@/app/data/files';
import { contractFingerprint, type SyncTransport } from '@/app/sync/engine';
import { FakeServer } from './fake-server';
import { device, testUser } from './helpers';

const expense = { amountMinor: 45_000, currency: 'DZD', category: 'food', note: 'Couscous', fromWallet: false, day: '2026-09-19' };

/** A note as the server keeps it, written by another device at [at]. */
function noteRecord(uuid: string, at: string, body: string, seq: number) {
  return {
    table: 'notes' as const,
    uuid,
    updatedAt: at,
    deletedAt: null,
    data: { uuid, title: 'Skew', folder: '', body, createdAt: '2026-09-19T12:00:00.000Z', updatedAt: at, deletedAt: null },
    seq,
  };
}

describe('the merge rules on the web', () => {
  it('a delete still waiting to go up is a tombstone, stamped when it was made (Q5-09)', async () => {
    const server = new FakeServer();
    const b = await device(server);
    const note = await b.notes.create({ title: 'Gone' });
    await b.engine.sync();
    b.clock.set('2026-09-19T12:30:00.000Z');
    await b.notes.purge(note.uuid);
    // The older copy comes down again before the purge has gone up.
    await setMeta(b.db, metaKeys.cursor, 0);
    b.clock.set('2026-09-19T15:00:00.000Z');
    await b.engine.sync();
    expect(await b.db.rows('notes').get(note.uuid)).toBeUndefined();
    const stored = server.get('notes', note.uuid)!;
    expect(stored.purged).toBe(true);
    expect(stored.updatedAt).toBe('2026-09-19T12:30:00.000Z');
  });

  it('a row with no clock of its own keeps an edit not sent yet (Q5-07)', async () => {
    const server = new FakeServer();
    const a = await device(server);
    const note = await a.notes.create({ title: 'Links' });
    await a.writer.run((tx) => tx.put('note_links', { uuid: 'link-1', fromUuid: note.uuid, toTitle: 'mine', toUuid: null }));
    const theirs = (title: string, at: string, seq: number) =>
      server.stored.set('note_links/link-1', {
        table: 'note_links',
        uuid: 'link-1',
        updatedAt: at,
        deletedAt: null,
        data: { uuid: 'link-1', fromUuid: note.uuid, toTitle: title, toUuid: null },
        seq,
      });
    theirs('theirs, older', '2026-09-19T11:00:00.000Z', 1);
    vi.spyOn(server, 'push').mockResolvedValueOnce({ results: [], cursor: 1 });
    await a.engine.sync();
    expect((await a.db.rows('note_links').get('link-1'))?.toTitle).toBe('mine');
  });

  it('an edit made after a row from a clock ahead of this one still wins (Q5-10)', async () => {
    const server = new FakeServer();
    const b = await device(server);
    const uuid = crypto.randomUUID();
    // Another device, an hour ahead of this browser, wrote the note.
    server.stored.set(`notes/${uuid}`, noteRecord(uuid, '2026-09-19T13:00:00.000Z', 'from the fast clock', 1));
    await b.engine.sync();
    b.clock.set('2026-09-19T12:10:00.000Z');
    await b.notes.update(uuid, { body: 'edited here, after' });
    await b.engine.sync();
    const stored = server.get('notes', uuid)!;
    expect((stored.data as { body: string }).body).toBe('edited here, after');
    expect(Date.parse(stored.updatedAt)).toBeGreaterThan(Date.parse('2026-09-19T13:00:00.000Z'));
  });

  it('a push the server finds stale takes the server copy (Q5-10)', async () => {
    const server = new FakeServer();
    const b = await device(server);
    const uuid = crypto.randomUUID();
    server.stored.set(`notes/${uuid}`, noteRecord(uuid, '2026-09-19T11:00:00.000Z', 'theirs', 1));
    await b.engine.sync();
    // The same clock, other words, queued here: the server keeps its own.
    await b.db.rows('notes').update(uuid, { body: 'mine' });
    await b.db.outbox.add({ table: 'notes', key: uuid, op: 'upsert', queuedAt: '2026-09-19T11:00:00.000Z' });
    await b.engine.sync();
    await b.engine.sync();
    expect((await b.db.rows('notes').get(uuid))?.body).toBe('theirs');
    expect(await b.db.outbox.count()).toBe(0);
  });

  it('a row this version cannot read is parked, and read after an update (Q5-11)', async () => {
    const server = new FakeServer();
    const uuid = crypto.randomUUID();
    const good = noteRecord(uuid, '2026-09-19T11:00:00.000Z', 'kept for later', 2);
    server.stored.set('future_table/x', { ...good, table: 'future_table' as never, uuid: 'x', seq: 1 });
    const b = await device(server);
    await b.engine.sync();
    expect(await b.db.parked.count()).toBe(1);
    expect(await getMeta(b.db, metaKeys.parkedFor)).toBe(contractFingerprint);

    // A row an older version parked, which this one can read.
    await b.db.parked.put({ table: 'notes', uuid, record: good });
    await setMeta(b.db, metaKeys.parkedFor, 'an older contract');
    await b.engine.sync();
    expect((await b.db.rows('notes').get(uuid))?.body).toBe('kept for later');
    expect(await b.db.parked.count()).toBe(1);
  });

  it('takes no setting that says where a request goes (S5-01)', async () => {
    const server = new FakeServer();
    for (const [seq, key] of ['assist.baseUrl', 'places.styleUrl'].entries()) {
      server.stored.set(`kv_settings/${key}`, {
        table: 'kv_settings',
        uuid: key,
        updatedAt: '2026-09-19T11:00:00.000Z',
        deletedAt: null,
        data: { key, valueJson: '"https://attacker.example"', updatedAt: '2026-09-19T11:00:00.000Z' },
        seq: seq + 1,
      });
    }
    const b = await device(server);
    await b.engine.sync();
    expect(await b.db.rows('kv_settings').get('assist.baseUrl')).toBeUndefined();
    expect(await b.db.rows('kv_settings').get('places.styleUrl')).toBeUndefined();
  });

  it('says why a row was refused, and sends one refused for a clock again an hour later', async () => {
    const server = new FakeServer();
    let refuse = true;
    const paced: SyncTransport = {
      pull: (after, limit) => server.pull(after, limit),
      async push(body: PushBody): Promise<PushResult> {
        const answer = await server.push(body);
        if (!refuse) return answer;
        return {
          ...answer,
          results: answer.results.map((result) => ({
            ...result,
            status: 'invalid' as const,
            issues: [{ path: ['updatedAt'], message: 'ahead', code: 'clock_ahead' }],
          })),
        };
      },
    };
    const b = await device(paced);
    await b.notes.create({ title: 'Later' });
    await b.engine.sync();
    expect(b.engine.status.invalid).toBe(1);
    expect(b.engine.status.refusedFor).toEqual(['clock_ahead']);

    refuse = false;
    await b.engine.sync();
    expect(b.engine.status.invalid).toBe(1);
    b.clock.advance(2 * 60 * 60_000);
    await b.engine.sync();
    expect(b.engine.status.invalid).toBe(0);
  });
});

describe('the sealed rows on the web', () => {
  it('a row sealed by 3.0.0 stays sealed and is counted, never fatal', async () => {
    const server = new FakeServer();
    const old = await crypto.subtle.importKey('raw', new Uint8Array(32), 'AES-GCM', false, ['encrypt']);
    const uuid = crypto.randomUUID();
    server.stored.set(`expenses/${uuid}`, {
      table: 'expenses',
      uuid,
      updatedAt: '2026-09-19T11:00:00.000Z',
      deletedAt: null,
      enc: await sealRow(old, 'expenses', uuid, { uuid }),
      seq: 1,
    });
    const b = await device(server);
    await b.keyring.unlock('2468', testUser.syncSalt, 1);
    await b.notes.create({ title: 'Plain' });
    await b.engine.sync();
    expect(b.engine.status.phase).toBe('idle');
    expect(b.engine.status.unreadable).toBe(1);
    expect(await b.keyring.key(testUser.syncSalt)).not.toBeNull();
  });

  it('forgets a sealed entry once it is opened, even when the row here is newer (Q5-12)', async () => {
    const server = new FakeServer();
    const a = await device(server);
    await a.keyring.unlock('2468', testUser.syncSalt, 1);
    const uuid = await a.money.log(expense);
    await a.engine.sync();

    const b = await device(server);
    await b.engine.sync();
    expect(b.engine.status.sealed).toBe(1);
    // A newer copy of the row is already here.
    const row = (await a.db.rows('expenses').get(uuid))!;
    await b.db.rows('expenses').put({ ...row, note: 'newer here', updatedAt: '2026-09-20T12:00:00.000Z' });
    await b.keyring.unlock('2468', testUser.syncSalt, 1);
    await b.engine.openSealed();
    expect(b.engine.status.sealed).toBe(0);
    expect((await b.db.rows('expenses').get(uuid))?.note).toBe('newer here');
  });

  it('a PIN started over on another device is asked for again here, and what is here goes up under the new one', async () => {
    const server = new FakeServer();
    const a = await device(server);
    const b = await device(server);
    await a.keyring.unlock('2468', testUser.syncSalt, 1);
    await b.keyring.unlock('2468', testUser.syncSalt, 1);
    const mine = await b.money.log(expense);
    await b.engine.sync();
    expect(server.get('expenses', mine)).toBeDefined();

    await a.keyring.startOver('the password');
    expect(server.get('expenses', mine)).toBeUndefined();
    await a.keyring.unlock('9731', testUser.syncSalt, 1);

    // B, a few minutes on, has money of its own to send: before anything
    // goes up sealed, its key is held against the account's check.
    b.clock.advance(3 * 60_000);
    const later = await b.money.log({ ...expense, note: 'Tea' });
    await b.engine.sync();
    expect(b.engine.status.pinChanged).toBe(true);
    expect(await b.keyring.key(testUser.syncSalt)).toBeNull();
    expect(server.get('expenses', later)).toBeUndefined();

    await b.keyring.unlock('9731', testUser.syncSalt, 1);
    expect(b.engine.status.pinChanged).toBe(false);
    await b.engine.sync();
    expect(server.get('expenses', mine)?.enc).toMatchObject({ v: 2 });
    expect(server.get('expenses', later)?.enc).toMatchObject({ v: 2 });
    await a.engine.sync();
    expect((await a.db.rows('expenses').get(mine))?.amountMinor).toBe(45_000);
  });

  it('a wrong key never seals: a second browser choosing at once is checked against the first', async () => {
    const server = new FakeServer();
    const a = await device(server);
    const b = await device(server);
    // B opened its prompt before A chose; A's check is there first.
    await a.keyring.unlock('2468', testUser.syncSalt, 1);
    const stored = server.check;
    server.check = null;
    const put = vi.spyOn(server, 'putKeyCheck').mockResolvedValueOnce(stored);
    await expect(b.keyring.unlock('9731', testUser.syncSalt, 1)).rejects.toMatchObject({ chosenElsewhere: true });
    expect(put).toHaveBeenCalled();
    expect(await b.keyring.key(testUser.syncSalt)).toBeNull();
  });
});

describe('files a purge leaves behind (Q5-23)', () => {
  it('an incoming purge releases the bytes here, and tells the server when nothing names them', async () => {
    const server = new FakeServer();
    const h = await device(server);
    const forgotten: string[] = [];
    const store = new FileStore(h.db, h.keyring, () => testUser.syncSalt, h.writer, {
      file: vi.fn(),
      filesMissing: vi.fn(),
      putFile: vi.fn(),
      forgetFile: (sha256: string) => {
        forgotten.push(sha256);
        return Promise.resolve();
      },
    });
    const { sha256 } = await store.keep(new Blob([new Uint8Array([1, 2, 3])]));
    await store.releasePurged('memories', { uuid: 'gone', fileHash: sha256 });
    expect(await h.db.files.get(sha256)).toBeUndefined();
    expect(forgotten).toEqual([sha256]);
  });

  it('sweeps bytes no row names once they have been here an hour', async () => {
    const h = await device(new FakeServer());
    await h.db.files.put({ sha256: 'old', blob: new Blob(['x']), fetchedAt: '2026-01-01T00:00:00.000Z' });
    await h.db.files.put({ sha256: 'new', blob: new Blob(['y']), fetchedAt: new Date().toISOString() });
    expect(await h.files.sweepOrphans()).toBe(1);
    expect(await h.db.files.get('new')).toBeDefined();
  });

  it('the sync hands every purged row to the file store', async () => {
    const server = new FakeServer();
    const a = await device(server);
    const b = await device(server);
    const note = await a.notes.create({ title: 'Gone' });
    await a.engine.sync();
    await b.engine.sync();
    const released = vi.spyOn(b.files, 'releasePurged').mockResolvedValue();
    a.clock.advance(60_000);
    await a.notes.purge(note.uuid);
    await a.engine.sync();
    await b.engine.sync();
    expect(released).toHaveBeenCalledWith('notes', expect.objectContaining({ uuid: note.uuid }));
  });
});
