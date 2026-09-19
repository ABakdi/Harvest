import { readdirSync, readFileSync } from 'node:fs';
import type { PullResult, PushResult, SyncRecord } from '@harvest/contracts';
import { ObjectId } from 'mongodb';
import request from 'supertest';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { bearer, expectError, harness, signUp, type Account, type Harness } from './harness.js';

let h: Harness;
beforeEach(async () => {
  h = await harness();
});
afterEach(async () => {
  await h.close();
});

async function push(account: Account, records: unknown[], deviceId = 'phone'): Promise<PushResult> {
  const res = await request(h.app).post('/v1/sync/push').set(bearer(account)).send({ deviceId, records }).expect(200);
  return res.body as PushResult;
}

async function pull(account: Account, after = 0, limit?: number): Promise<PullResult> {
  const res = await request(h.app)
    .get('/v1/sync/pull')
    .query({ after, ...(limit ? { limit } : {}) })
    .set(bearer(account))
    .expect(200);
  return res.body as PullResult;
}

/** Everything after [after], following `more` the way a client does. */
async function pullAll(account: Account, after = 0, limit = 1000): Promise<PullResult['records']> {
  const records: PullResult['records'] = [];
  let cursor = after;
  for (;;) {
    const page = await pull(account, cursor, limit);
    records.push(...page.records);
    cursor = page.cursor;
    if (!page.more) return records;
  }
}

const at = (minute: number) => `2026-09-19T10:${String(minute).padStart(2, '0')}:00.000Z`;

function note(uuid: string, minute: number, fields: { title?: string; deletedAt?: string | null } = {}): SyncRecord {
  const updatedAt = at(minute);
  const deletedAt = fields.deletedAt ?? null;
  return {
    table: 'notes',
    uuid,
    updatedAt,
    deletedAt,
    data: {
      uuid,
      title: fields.title ?? `Note ${uuid}`,
      folder: '',
      body: 'Body',
      createdAt: at(0),
      updatedAt,
      deletedAt,
    },
  };
}

const envelope = { v: 1, iv: 'AAAAAAAAAAAAAAAB', ct: 'q83vEjRWeJA=' };

/**
 * A device as the Sync API describes a client: a local table keyed by
 * (table, uuid), merged from pulls by the same rule the server uses.
 */
class Device {
  readonly rows = new Map<string, SyncRecord>();
  cursor = 0;

  constructor(
    readonly account: Account,
    readonly id: string,
  ) {}

  write(record: SyncRecord): SyncRecord {
    this.rows.set(`${record.table}/${record.uuid}`, record);
    return record;
  }

  async sync(outbox: SyncRecord[]): Promise<PushResult> {
    await this.pullAll();
    const result = await push(this.account, outbox, this.id);
    await this.pullAll();
    return result;
  }

  private async pullAll(): Promise<void> {
    for (const record of await pullAll(this.account, this.cursor)) {
      const key = `${record.table}/${record.uuid}`;
      const local = this.rows.get(key);
      if (record.purged) this.rows.delete(key);
      else if (!local || Date.parse(local.updatedAt) < Date.parse(record.updatedAt)) {
        const { seq: _seq, ...row } = record;
        this.rows.set(key, row);
      }
      this.cursor = record.seq;
    }
  }
}

describe('push and pull', () => {
  it('requires a verified account', async () => {
    const unverified = await signUp(h, { verify: false });
    expectError(
      await request(h.app).post('/v1/sync/push').set(bearer(unverified)).send({ deviceId: 'p', records: [] }),
      403,
      'forbidden',
    );
    expectError(await request(h.app).get('/v1/sync/pull').set(bearer(unverified)), 403, 'forbidden');
    expectError(await request(h.app).get('/v1/sync/pull'), 401, 'unauthorized');
  });

  it('stores, sequences and hands back every record unchanged', async () => {
    const account = await signUp(h);
    const records = [note('a', 1), note('b', 2)];
    const result = await push(account, records);
    expect(result.results.map((r) => r.status)).toEqual(['applied', 'applied']);
    expect(result.cursor).toBe(2);

    const pulled = await pull(account);
    expect(pulled.records.map(({ seq, ...record }) => ({ seq, record }))).toEqual([
      { seq: 1, record: records[0] },
      { seq: 2, record: records[1] },
    ]);
    expect(pulled).toMatchObject({ cursor: 2, more: false });
  });

  it('lands every contract fixture', async () => {
    const account = await signUp(h);
    const dir = new URL('../../../packages/contracts/fixtures/records/', import.meta.url);
    const records = readdirSync(dir).map((file) => JSON.parse(readFileSync(new URL(file, dir), 'utf8')) as unknown);
    const result = await push(account, records);
    expect(result.results.filter((r) => r.status !== 'applied')).toEqual([]);
    expect((await pullAll(account)).length).toBe(records.length);
  });

  it('refuses a malformed batch whole, and one of more than 500 records', async () => {
    const account = await signUp(h);
    const send = (body: unknown) => request(h.app).post('/v1/sync/push').set(bearer(account)).send(body as object);
    expectError(await send({ records: [] }), 400, 'validation_failed');
    expectError(await send({ deviceId: 'p', records: [{ uuid: 'x' }] }), 400, 'validation_failed');
    expectError(await send({ deviceId: 'p', records: Array(501).fill(note('a', 1)) }), 400, 'validation_failed');
  });

  it('validates the pull query', async () => {
    const account = await signUp(h);
    for (const query of ['limit=0', 'limit=1001', 'after=-1', 'after=abc']) {
      expectError(await request(h.app).get(`/v1/sync/pull?${query}`).set(bearer(account)), 400, 'validation_failed');
    }
  });
});

describe('conflicts', () => {
  it('lets a later write win and a stale one lose', async () => {
    const account = await signUp(h);
    await push(account, [note('a', 5, { title: 'Five' })]);

    const older = await push(account, [note('a', 3, { title: 'Three' })]);
    expect(older.results[0]!.status).toBe('stale');

    const newer = await push(account, [note('a', 7, { title: 'Seven' })]);
    expect(newer.results[0]!.status).toBe('applied');

    const records = await pullAll(account);
    expect(records).toHaveLength(1);
    expect(records[0]!.data!.title).toBe('Seven');
  });

  it('treats an equal stamp as the same write coming back', async () => {
    const account = await signUp(h);
    await push(account, [note('a', 5, { title: 'Mine' })]);
    const echo = await push(account, [note('a', 5, { title: 'Different body, same clock' })]);
    expect(echo.results[0]!.status).toBe('stale');
    expect((await pullAll(account))[0]!.data!.title).toBe('Mine');
    expect(echo.cursor).toBe(1);
  });

  it('compares clocks as instants, to the microsecond', async () => {
    const account = await signUp(h);
    const base = note('a', 5);
    await push(account, [base]);
    const sameMoment = { ...base, updatedAt: '2026-09-19T10:05:00Z', data: { ...base.data, updatedAt: '2026-09-19T10:05:00Z' } };
    expect((await push(account, [sameMoment])).results[0]!.status).toBe('stale');
    const oneMicroLater = {
      ...base,
      updatedAt: '2026-09-19T10:05:00.000001Z',
      data: { ...base.data, updatedAt: '2026-09-19T10:05:00.000001Z', title: 'Later' },
    };
    expect((await push(account, [oneMicroLater])).results[0]!.status).toBe('applied');
  });

  it('moves a replaced row to the end of the sequence', async () => {
    const account = await signUp(h);
    await push(account, [note('a', 1), note('b', 2)]);
    await push(account, [note('a', 3, { title: 'Edited' })]);
    const records = await pullAll(account, 2);
    expect(records.map((r) => [r.uuid, r.seq])).toEqual([['a', 3]]);
  });
});

describe('two devices', () => {
  it('converge, whichever order they sync in', async () => {
    const account = await signUp(h);
    const phone = new Device(account, 'phone');
    const laptop = new Device(account, 'laptop');

    const phoneNotes = [phone.write(note('p1', 1)), phone.write(note('shared', 2, { title: 'Phone draft' }))];
    const laptopNotes = [laptop.write(note('l1', 3)), laptop.write(note('shared', 4, { title: 'Laptop edit' }))];

    await phone.sync(phoneNotes);
    await laptop.sync(laptopNotes);
    await phone.sync([]);

    expect([...phone.rows.keys()].sort()).toEqual(['notes/l1', 'notes/p1', 'notes/shared']);
    expect(Object.fromEntries(phone.rows)).toEqual(Object.fromEntries(laptop.rows));
    expect(phone.rows.get('notes/shared')!.data!.title).toBe('Laptop edit');
  });

  it('lose a stale offline edit to a newer remote one', async () => {
    const account = await signUp(h);
    const phone = new Device(account, 'phone');
    const laptop = new Device(account, 'laptop');
    await phone.sync([phone.write(note('n', 1, { title: 'Original' }))]);
    await laptop.sync([]);

    // Offline, the phone edits at minute 2; the laptop edits at minute 5 and syncs first.
    const offline = phone.write(note('n', 2, { title: 'Phone, offline' }));
    await laptop.sync([laptop.write(note('n', 5, { title: 'Laptop, later' }))]);

    const result = await phone.sync([offline]);
    expect(result.results[0]!.status).toBe('stale');
    expect(phone.rows.get('notes/n')!.data!.title).toBe('Laptop, later');
  });

  it('propagate a soft delete and a purge', async () => {
    const account = await signUp(h);
    const phone = new Device(account, 'phone');
    const laptop = new Device(account, 'laptop');
    await phone.sync([phone.write(note('soft', 1)), phone.write(note('hard', 1))]);
    await laptop.sync([]);
    expect(laptop.rows.size).toBe(2);

    const trashed = phone.write(note('soft', 2, { deletedAt: at(2) }));
    const purged: SyncRecord = { table: 'notes', uuid: 'hard', updatedAt: at(3), deletedAt: at(3), purged: true };
    phone.rows.delete('notes/hard');
    const result = await phone.sync([trashed, purged]);
    expect(result.results.map((r) => r.status)).toEqual(['applied', 'applied']);

    await laptop.sync([]);
    expect(laptop.rows.get('notes/soft')!.deletedAt).toBe(at(2));
    expect(laptop.rows.has('notes/hard')).toBe(false);

    // The tombstone keeps nothing of what the row held.
    const stored = await h.db.collection('records').findOne({ userId: new ObjectId(account.userId), uuid: 'hard' });
    expect(stored).toMatchObject({ purged: true });
    expect(stored!.data).toBeUndefined();
    expect(stored!.enc).toBeUndefined();

    // And an older write of the purged row cannot bring it back.
    expect((await push(account, [note('hard', 2)])).results[0]!.status).toBe('stale');
  });
});

describe('paging', () => {
  it('pages in sequence order and says when there is more', async () => {
    const account = await signUp(h);
    await push(account, Array.from({ length: 25 }, (_, i) => note(`n${i}`, i % 60)));

    const first = await pull(account, 0, 10);
    expect(first.records.map((r) => r.seq)).toEqual([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
    expect(first).toMatchObject({ cursor: 10, more: true });

    const second = await pull(account, first.cursor, 10);
    expect(second).toMatchObject({ cursor: 20, more: true });

    const third = await pull(account, second.cursor, 10);
    expect(third.records).toHaveLength(5);
    expect(third).toMatchObject({ cursor: 25, more: false });

    const empty = await pull(account, 25, 10);
    expect(empty).toEqual({ records: [], cursor: 25, more: false });
  });

  it('never skips a row when pushes race', async () => {
    const account = await signUp(h);
    await Promise.all(
      Array.from({ length: 5 }, (_, batch) =>
        push(account, Array.from({ length: 20 }, (_, i) => note(`b${batch}-${i}`, i)), `device-${batch}`),
      ),
    );
    const records = await pullAll(account, 0, 7);
    expect(records.map((r) => r.seq)).toEqual(Array.from({ length: 100 }, (_, i) => i + 1));
  });
});

describe('isolation', () => {
  it('never shows one account the rows of another', async () => {
    const alice = await signUp(h);
    const bob = await signUp(h);
    await push(alice, [note('same-uuid', 5, { title: "Alice's" })]);
    expect(await pullAll(bob)).toEqual([]);

    // Bob's row with the same key is his own, with his own sequence.
    const result = await push(bob, [note('same-uuid', 1, { title: "Bob's" })]);
    expect(result.results[0]!.status).toBe('applied');
    expect(result.cursor).toBe(1);
    expect((await pullAll(alice))[0]!.data!.title).toBe("Alice's");
    expect((await pullAll(bob))[0]!.data!.title).toBe("Bob's");
  });
});

describe('what the server checks', () => {
  it('stores the private tier as an opaque envelope, and refuses it in the clear', async () => {
    const account = await signUp(h);
    const sealed = { table: 'expenses', uuid: 'e1', updatedAt: at(1), deletedAt: null, enc: envelope };
    const clear = {
      table: 'debts',
      uuid: 'd1',
      updatedAt: at(1),
      deletedAt: null,
      data: { uuid: 'd1', person: 'Karim' },
    };
    const result = await push(account, [sealed, clear]);
    expect(result.results.map((r) => r.status)).toEqual(['applied', 'invalid']);

    const [record] = await pullAll(account);
    expect(record).toEqual({ ...sealed, seq: 1 });
    // The name never reached the database.
    expect(JSON.stringify(await h.db.collection('records').find().toArray())).not.toContain('Karim');
  });

  it('checks the envelope and nothing more', async () => {
    const account = await signUp(h);
    const bad = { table: 'geotags', uuid: 'g1', updatedAt: at(1), deletedAt: null, enc: { v: 2, iv: 'x', ct: '' } };
    const result = await push(account, [bad]);
    expect(result.results[0]!.status).toBe('invalid');
    expect(result.results[0]!.issues!.map((i) => i.path.join('.'))).toEqual(expect.arrayContaining(['enc.v', 'enc.iv']));
  });

  it('keeps device settings home', async () => {
    const account = await signUp(h);
    const setting = (key: string) => ({
      table: 'kv_settings',
      uuid: key,
      updatedAt: at(1),
      deletedAt: null,
      data: { key, valueJson: 'true', updatedAt: at(1) },
    });
    const result = await push(account, [setting('features.places'), setting('lock.armed'), setting('streak.lastJudgedDay')]);
    expect(result.results.map((r) => [r.uuid, r.status])).toEqual([
      ['features.places', 'applied'],
      ['lock.armed', 'invalid'],
      ['streak.lastJudgedDay', 'invalid'],
    ]);
    expect((await pullAll(account)).map((r) => r.uuid)).toEqual(['features.places']);
  });

  it('isolates an invalid record: the rest of the batch lands', async () => {
    const account = await signUp(h);
    const broken = { ...note('bad', 2), data: { ...note('bad', 2).data, title: 42 } };
    const result = await push(account, [note('a', 1), broken, { nonsense: true, table: 'x', uuid: 'y' }, note('b', 3)]);
    expect(result.results.map((r) => [r.table, r.uuid, r.status])).toEqual([
      ['notes', 'a', 'applied'],
      ['notes', 'bad', 'invalid'],
      ['x', 'y', 'invalid'],
      ['notes', 'b', 'applied'],
    ]);
    expect(result.results[1]!.issues).toEqual([
      expect.objectContaining({ path: ['data', 'title'] }),
    ]);
    expect((await pullAll(account)).map((r) => r.uuid)).toEqual(['a', 'b']);
  });

  it('keys a step day by its Harvest Day', async () => {
    const account = await signUp(h);
    const day = {
      table: 'step_days',
      uuid: '2026-09-18',
      updatedAt: at(1),
      deletedAt: null,
      data: { harvestDay: '2026-09-18', steps: 9000, lastCounter: null, updatedAt: at(1) },
    };
    expect((await push(account, [day])).results[0]!.status).toBe('applied');
    const later = { ...day, updatedAt: at(2), data: { ...day.data, steps: 12000, updatedAt: at(2) } };
    expect((await push(account, [later])).results[0]!.status).toBe('applied');
    const records = await pullAll(account);
    expect(records).toHaveLength(1);
    expect(records[0]!.data!.steps).toBe(12000);
  });
});
