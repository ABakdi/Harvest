import { readdirSync, readFileSync } from 'node:fs';
import { request as httpRequest } from 'node:http';
import { maxEnvelopeCtLength, maxPushBytes, maxRecordStoreBytes, retiredTables, type PullResult, type PushResult, type SyncRecord } from '@harvest/contracts';
import { ObjectId } from 'mongodb';
import request from 'supertest';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { SyncService } from '../src/sync/service.js';
import { bearer, expectError, harness, password, signUp, type Account, type Harness } from './harness.js';

let h: Harness;
beforeEach(async () => {
  h = await harness();
});
afterEach(async () => {
  await h.close();
});

async function push(account: Account, records: unknown[], deviceId = 'phone'): Promise<PushResult> {
  const res = await request(h.app).post('/v1/sync/push').set(bearer(account)).send({ deviceId, keyEpoch: 1, records }).expect(200);
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

/**
 * A row sealed the way these tests seal one: the "ciphertext" is the
 * row's JSON in base64. The server cannot tell it from the real thing,
 * which is the point, and a test can read it back with [opened].
 */
function sealed(
  table: string,
  uuid: string,
  updatedAt: string,
  deletedAt: string | null,
  row: Record<string, unknown>,
  extra: { file?: string } = {},
): SyncRecord {
  return {
    table,
    uuid,
    updatedAt,
    deletedAt,
    enc: { v: 2, iv: 'AAAAAAAAAAAAAAAB', ct: Buffer.from(JSON.stringify(row)).toString('base64') },
    ...extra,
  } as SyncRecord;
}

function opened(record: { enc?: { ct: string } }): Record<string, unknown> {
  return JSON.parse(Buffer.from(record.enc!.ct, 'base64').toString('utf8')) as Record<string, unknown>;
}

function note(
  uuid: string,
  minute: number,
  fields: { title?: string; deletedAt?: string | null; updatedAt?: string; body?: string } = {},
): SyncRecord {
  const updatedAt = fields.updatedAt ?? at(minute);
  const deletedAt = fields.deletedAt ?? null;
  return sealed('notes', uuid, updatedAt, deletedAt, {
    uuid,
    title: fields.title ?? `Note ${uuid}`,
    folder: '',
    body: fields.body ?? 'Body',
    createdAt: at(0),
    updatedAt,
    deletedAt,
  });
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
    const records = readdirSync(dir).map((file) => JSON.parse(readFileSync(new URL(file, dir), 'utf8')) as { table: string });
    const result = await push(account, records);
    // All but a table no device sends any more (M7.3).
    const retired = new Set<string>(retiredTables);
    expect(result.results.filter((r) => r.status !== 'applied').map((r) => r.table)).toEqual([...retired]);
    expect((await pullAll(account)).length).toBe(records.filter((r) => !retired.has(r.table)).length);
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
    expect(opened(records[0]!).title).toBe('Seven');
  });

  it('treats an equal stamp as the same write coming back', async () => {
    const account = await signUp(h);
    await push(account, [note('a', 5, { title: 'Mine' })]);
    const echo = await push(account, [note('a', 5, { title: 'Different body, same clock' })]);
    expect(echo.results[0]!.status).toBe('stale');
    expect(opened((await pullAll(account))[0]!).title).toBe('Mine');
    expect(echo.cursor).toBe(1);
  });

  it('compares clocks as instants, to the microsecond', async () => {
    const account = await signUp(h);
    const base = note('a', 5);
    await push(account, [base]);
    const sameMoment = note('a', 5, { updatedAt: '2026-09-19T10:05:00Z' });
    expect((await push(account, [sameMoment])).results[0]!.status).toBe('stale');
    const oneMicroLater = note('a', 5, { updatedAt: '2026-09-19T10:05:00.000001Z', title: 'Later' });
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
    expect(opened(phone.rows.get('notes/shared')!).title).toBe('Laptop edit');
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
    expect(opened(phone.rows.get('notes/n')!).title).toBe('Laptop, later');
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

  it('never skips a row when pushes race, even for a pull running beside them', async () => {
    const account = await signUp(h);
    // A device pulls in small pages all the while the pushes land: a
    // hole behind its cursor that filled in later would be a row it
    // never sees.
    const seen: number[] = [];
    let cursor = 0;
    let pushing = true;
    const pulling = (async () => {
      while (pushing) {
        const page = await pull(account, cursor, 7);
        seen.push(...page.records.map((r) => r.seq));
        cursor = page.cursor;
      }
    })();
    await Promise.all(
      Array.from({ length: 5 }, (_, batch) =>
        push(account, Array.from({ length: 20 }, (_, i) => note(`b${batch}-${i}`, i)), `device-${batch}`),
      ),
    );
    pushing = false;
    await pulling;
    seen.push(...(await pullAll(account, cursor, 7)).map((r) => r.seq));
    expect(seen).toEqual(Array.from({ length: 100 }, (_, i) => i + 1));
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
    expect(opened((await pullAll(alice))[0]!).title).toBe("Alice's");
    expect(opened((await pullAll(bob))[0]!).title).toBe("Bob's");
  });
});

describe('what the server checks', () => {
  it('stores every row as an opaque envelope, and refuses one in the clear (Phase 7)', async () => {
    const account = await signUp(h);
    const expense = { table: 'expenses', uuid: 'e1', updatedAt: at(1), deletedAt: null, enc: envelope };
    const clear = (table: string, uuid: string, data: Record<string, unknown>) => ({
      table,
      uuid,
      updatedAt: at(1),
      deletedAt: null,
      data,
    });
    const result = await push(account, [
      expense,
      clear('debts', 'd1', { uuid: 'd1', person: 'Karim' }),
      clear('notes', 'n1', { uuid: 'n1', title: 'Diary', body: 'Dear diary' }),
      clear('body_weights', 'w1', { uuid: 'w1', grams: 71_500 }),
    ]);
    expect(result.results.map((r) => r.status)).toEqual(['applied', 'invalid', 'invalid', 'invalid']);
    for (const refused of result.results.slice(1)) {
      expect(refused.issues).toContainEqual(expect.objectContaining({ path: ['data'], code: 'sealed_required' }));
    }

    const [record] = await pullAll(account);
    expect(record).toEqual({ ...expense, seq: 1 });
    // Nothing in the clear reached the database.
    const stored = JSON.stringify(await h.db.collection('records').find().toArray());
    for (const text of ['Karim', 'Dear diary', '71500']) expect(stored).not.toContain(text);
  });

  it('checks the envelope and nothing more', async () => {
    const account = await signUp(h);
    const bad = { table: 'geotags', uuid: 'g1', updatedAt: at(1), deletedAt: null, enc: { v: 3, iv: 'x', ct: '' } };
    const result = await push(account, [bad]);
    expect(result.results[0]!.status).toBe('invalid');
    expect(result.results[0]!.issues!.map((i) => i.path.join('.'))).toEqual(expect.arrayContaining(['enc.v', 'enc.iv']));
  });

  it('keeps device settings home', async () => {
    const account = await signUp(h);
    const setting = (key: string) => sealed('kv_settings', key, at(1), null, { key, valueJson: 'true', updatedAt: at(1) });
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
    const { enc: _enc, ...bare } = note('bad', 2);
    const broken = { ...bare, data: { title: 42 } };
    const result = await push(account, [note('a', 1), broken, { nonsense: true, table: 'x', uuid: 'y' }, note('b', 3)]);
    expect(result.results.map((r) => [r.table, r.uuid, r.status])).toEqual([
      ['notes', 'a', 'applied'],
      ['notes', 'bad', 'invalid'],
      ['x', 'y', 'invalid'],
      ['notes', 'b', 'applied'],
    ]);
    expect(result.results[1]!.issues).toEqual([
      expect.objectContaining({ path: ['data'], code: 'sealed_required' }),
      expect.objectContaining({ path: ['enc'] }),
    ]);
    expect((await pullAll(account)).map((r) => r.uuid)).toEqual(['a', 'b']);
  });

  it('keys a step day by its Harvest Day', async () => {
    const account = await signUp(h);
    const day = (minute: number, steps: number) =>
      sealed('step_days', '2026-09-18', at(minute), null, {
        harvestDay: '2026-09-18',
        steps,
        lastCounter: null,
        updatedAt: at(minute),
      });
    expect((await push(account, [day(1, 9000)])).results[0]!.status).toBe('applied');
    expect((await push(account, [day(2, 12000)])).results[0]!.status).toBe('applied');
    const records = await pullAll(account);
    expect(records).toHaveLength(1);
    expect(opened(records[0]!).steps).toBe(12000);
  });
});

describe('limits (audit S5-02, S5-11)', () => {
  it('refuses a clock more than a day ahead of the server, or past 2200', async () => {
    const account = await signUp(h);
    const ahead = (ms: number) => new Date(Date.now() + ms).toISOString();
    const make = (uuid: string, updatedAt: string): SyncRecord => note(uuid, 1, { updatedAt });
    const result = await push(account, [
      make('n-soon', ahead(60 * 60_000)),
      make('n-tomorrow', ahead(2 * 24 * 60 * 60_000)),
      make('n-far', '9999-12-31T23:59:59Z'),
    ]);
    expect(result.results.map((r) => r.status)).toEqual(['applied', 'invalid', 'invalid']);
    expect(result.results[1]!.issues).toEqual([expect.objectContaining({ path: ['updatedAt'], code: 'clock_ahead' })]);
    expect(result.results[2]!.issues).toEqual([expect.objectContaining({ path: ['updatedAt'], code: 'clock_too_far' })]);
  });

  it('refuses a sealed row past its cap', async () => {
    const account = await signUp(h);
    const big = (ct: string) => ({
      table: 'notes',
      uuid: 'n-big',
      updatedAt: at(1),
      deletedAt: null,
      enc: { v: 2, iv: 'AAAAAAAAAAAAAAAB', ct },
    });
    const result = await push(account, [big('A'.repeat(maxEnvelopeCtLength + 4))]);
    expect(result.results.map((r) => r.status)).toEqual(['invalid']);
    expect(result.results[0]!.issues![0]!.path).toEqual(['enc', 'ct']);
  });

  it('pages a pull by bytes as well as by count', async () => {
    const account = await signUp(h);
    const big = (uuid: string, minute: number) => note(uuid, minute, { body: 'b'.repeat(2000) });
    await push(account, [big('a', 1), big('b', 2), big('c', 3), big('d', 4)]);

    const sync = new SyncService(h.repos);
    const userId = new ObjectId(account.userId);
    // Two rows fit under 7 kB, the third would not.
    const first = await sync.pull(userId, 0, 1000, 7000);
    expect(first.records.map((r) => r.uuid)).toEqual(['a', 'b']);
    expect(first.more).toBe(true);
    // A row bigger than the page still comes, alone.
    const alone = await sync.pull(userId, first.cursor, 1000, 10);
    expect(alone.records.map((r) => r.uuid)).toEqual(['c']);
    expect(alone.more).toBe(true);
    const rest = await sync.pull(userId, alone.cursor, 1000, 7000);
    expect(rest.records.map((r) => r.uuid)).toEqual(['d']);
    expect(rest.more).toBe(false);
  });

  it('keeps each account to its row quota, and lets it shrink when full', async () => {
    const account = await signUp(h);
    const userId = new ObjectId(account.userId);
    await push(account, [note('n1', 1)]);
    // The running total agrees with what Mongo measures of the stored rows.
    const counted = await h.db.collection('counters').findOne({ _id: userId });
    expect(counted!.recordBytes).toBe(await h.repos.records.storedBytes(userId));

    await h.db
      .collection('counters')
      .updateOne({ _id: userId }, { $set: { recordBytes: maxRecordStoreBytes - 100 } });
    const full = await push(account, [note('n2', 2)]);
    expect(full.results[0]).toMatchObject({ status: 'invalid' });
    expect(full.results[0]!.issues![0]!.code).toBe('quota_exceeded');

    // A purge makes room rather than taking it.
    const purged = await push(account, [
      { table: 'notes', uuid: 'n1', updatedAt: at(5), deletedAt: at(5), purged: true },
    ]);
    expect(purged.results[0]!.status).toBe('applied');
  });

  it('fills in the total of an account from before it was kept', async () => {
    const account = await signUp(h);
    const userId = new ObjectId(account.userId);
    await push(account, [note('n1', 1), note('n2', 2)]);
    await h.db.collection('counters').updateOne({ _id: userId }, { $unset: { recordBytes: '' } });
    await h.db.collection('records').updateMany({ userId }, { $unset: { bytes: '' } });

    await push(account, [note('n1', 3, { title: 'Longer title than before' })]);
    const counted = await h.db.collection('counters').findOne({ _id: userId });
    expect(counted!.recordBytes).toBe(await h.repos.records.storedBytes(userId));
  });

  it('gives the charge back when a write fails, wherever it fails (Q6-15)', async () => {
    const account = await signUp(h);
    const userId = new ObjectId(account.userId);
    await push(account, [note('n1', 1)]);
    const records = h.repos.records;
    for (const step of ['takeSeqs', 'putMany'] as const) {
      const real = records[step].bind(records);
      (records as unknown as Record<string, unknown>)[step] = () => Promise.reject(new Error('mongo went away'));
      const failed = await request(h.app)
        .post('/v1/sync/push')
        .set(bearer(account))
        .send({ deviceId: 'phone', keyEpoch: 1, records: [note(`big-${step}`, 2, { title: 'x'.repeat(5000) })] });
      (records as unknown as Record<string, unknown>)[step] = real;
      expect(failed.status).toBe(500);
      const total = await h.repos.totals.current(userId, 'recordBytes', () => records.storedBytes(userId));
      expect(total).toBe(await records.storedBytes(userId));
    }
  });

  it('limits sync requests per account, not per address', async () => {
    const limited = await harness({ rateLimits: { syncRequests: 2 } });
    try {
      const one = await signUp(limited);
      const two = await signUp(limited);
      const pullAs = (account: Account) => request(limited.app).get('/v1/sync/pull').set(bearer(account));
      await pullAs(one).expect(200);
      await pullAs(one).expect(200);
      expectError(await pullAs(one), 429, 'rate_limited');
      await pullAs(two).expect(200);
    } finally {
      await limited.close();
    }
  });

  it('reads no body before it knows who is asking', async () => {
    const res = await request(h.app)
      .post('/v1/sync/push')
      .set('Content-Type', 'application/json')
      .send('{"not json');
    // A 400 would mean the body was parsed first.
    expectError(res, 401, 'unauthorized');
  });
});

describe('a push in one go (P6-02)', () => {
  it('judges a row sent twice in one batch against its own earlier copy', async () => {
    const account = await signUp(h);
    const result = await push(account, [note('n1', 2, { title: 'second' }), note('n1', 1), note('n1', 3, { title: 'third' })]);
    expect(result.results.map((r) => r.status)).toEqual(['applied', 'stale', 'applied']);
    const rows = await pullAll(account);
    expect(rows).toHaveLength(1);
    expect(opened(rows[0]!)).toMatchObject({ title: 'third' });
    const userId = new ObjectId(account.userId);
    expect((await h.db.collection('counters').findOne({ _id: userId }))!.recordBytes).toBe(
      await h.repos.records.storedBytes(userId),
    );
  });

  it('keeps the batch order in the sequence', async () => {
    const account = await signUp(h);
    await push(account, [note('a', 1), note('b', 1), note('c', 1)]);
    const again = await push(account, [note('c', 2), note('a', 2)]);
    expect(again.cursor).toBe(5);
    const rows = await pullAll(account);
    expect(rows.map((r) => `${r.uuid}@${r.seq}`)).toEqual(['b@2', 'c@4', 'a@5']);
  });
});

describe('what a device gets back (P6-08, S6-16, Q6-03)', () => {
  it('leaves out a device\'s own writes when it says who it is, and still moves the cursor', async () => {
    const account = await signUp(h);
    await push(account, [note('mine', 1)], 'phone');
    await push(account, [note('theirs', 1)], 'laptop');
    await push(account, [note('mine2', 1)], 'phone');
    const page = (
      await request(h.app).get('/v1/sync/pull').query({ after: 0, deviceId: 'phone' }).set(bearer(account)).expect(200)
    ).body as PullResult;
    expect(page.records.map((r) => r.uuid)).toEqual(['theirs']);
    expect(page.cursor).toBe(3);
    expect(page.more).toBe(false);
    // Without it, a device rebuilding its store gets everything back.
    expect((await pullAll(account)).map((r) => r.uuid)).toEqual(['mine', 'theirs', 'mine2']);
  });

  it('counts the device\'s own writes against the page size, so a page never runs long', async () => {
    const account = await signUp(h);
    await push(account, [note('a', 1), note('b', 1), note('c', 1)], 'phone');
    const page = (
      await request(h.app).get('/v1/sync/pull').query({ after: 0, limit: 2, deviceId: 'phone' }).set(bearer(account)).expect(200)
    ).body as PullResult;
    expect(page).toEqual({ records: [], cursor: 2, more: true });
  });

  it('takes the endpoint settings a 3.0.0 phone sends, and keeps none of them', async () => {
    const account = await signUp(h);
    const setting = (key: string, value: string) =>
      sealed('kv_settings', key, at(1), null, { key, valueJson: JSON.stringify(value), updatedAt: at(1) });
    const result = await push(account, [setting('assist.baseUrl', 'https://evil.example'), setting('places.styleUrl', 'https://evil.example')]);
    expect(result.results.map((r) => r.status)).toEqual(['applied', 'applied']);
    expect(await h.db.collection('records').countDocuments({})).toBe(0);
  });

  it('answers a push over the body limit with payload_too_large', async () => {
    const account = await signUp(h);
    const big = Array.from({ length: 6 }, (_, i) => ({
      table: 'geotags',
      uuid: `g${i}`,
      updatedAt: at(1),
      deletedAt: null,
      enc: { v: 2, iv: 'AAAAAAAAAAAAAAAB', ct: 'A'.repeat(999_996) },
    }));
    const res = await request(h.app).post('/v1/sync/push').set(bearer(account)).send({ deviceId: 'p', keyEpoch: 1, records: big });
    expectError(res, 413, 'payload_too_large');
    // A batch built to maxPushBytes fits.
    const fits = big.slice(0, Math.floor(maxPushBytes / 1_000_200));
    expect(JSON.stringify({ deviceId: 'p', keyEpoch: 1, records: fits }).length).toBeLessThan(maxPushBytes);
    await request(h.app).post('/v1/sync/push').set(bearer(account)).send({ deviceId: 'p', keyEpoch: 1, records: fits }).expect(200);
  });
});

describe('an account deleted while a push is on its way (Q6-02)', () => {
  it('writes nothing back for it', async () => {
    const account = await signUp(h);
    const server = h.app.listen(0);
    try {
      const port = (server.address() as { port: number }).port;
      const body = JSON.stringify({ deviceId: 'phone', keyEpoch: 1, records: [note('late', 1)] });
      // The headers go now; the body only after the account is gone.
      const answer = new Promise<{ status: number }>((resolve, reject) => {
        const req = httpRequest(
          {
            port,
            method: 'POST',
            path: '/v1/sync/push',
            headers: { authorization: `Bearer ${account.accessToken}`, 'content-type': 'application/json', 'content-length': Buffer.byteLength(body) },
          },
          (res) => {
            res.resume();
            res.on('end', () => resolve({ status: res.statusCode ?? 0 }));
          },
        );
        req.on('error', reject);
        req.write(body.slice(0, 10));
        setTimeout(() => {
          void request(h.app)
            .delete('/v1/me')
            .set(bearer(account))
            .send({ password })
            .then(() => req.end(body.slice(10)));
        }, 100);
      });
      const { status } = await answer;
      expect(status).toBe(401);
      const userId = new ObjectId(account.userId);
      expect(await h.db.collection('records').countDocuments({ userId })).toBe(0);
      expect(await h.db.collection('counters').countDocuments({ _id: userId })).toBe(0);
    } finally {
      server.close();
    }
  });
});

describe('sealing what was stored in the clear (Phase 7)', () => {
  /** A row as the server kept it before Phase 7: in the clear, in `data`. */
  async function storePlain(account: Account, uuid: string, minute: number, fields: Record<string, unknown> = {}) {
    const userId = new ObjectId(account.userId);
    const seq = await h.repos.records.takeSeqs(userId, 1);
    const row = { uuid, title: `Note ${uuid}`, folder: '', body: 'In the clear', createdAt: at(0), updatedAt: at(minute), deletedAt: null, ...fields };
    await h.db.collection('records').insertOne({
      userId,
      table: 'notes',
      uuid,
      updatedAt: at(minute),
      deletedAt: null,
      stamp: Date.parse(at(minute)) * 1000,
      data: row,
      seq,
      deviceId: 'old-phone',
    });
  }

  const choosePin = (account: Account) =>
    request(h.app)
      .put('/v1/me/sync-key')
      .set(bearer(account))
      .send({ verifier: 'ab'.repeat(32), check: { v: 2, iv: 'AAAAAAAAAAAAAAAB', ct: 'c2VhbGVkIGNoZWNrIGJ5dGVz' } })
      .expect(201);
  const sealedCall = (account: Account, keyEpoch: number) =>
    request(h.app).post('/v1/sync/sealed').set(bearer(account)).send({ deviceId: 'phone', keyEpoch });

  it('hands a row kept in the clear out as it is, until a device seals it', async () => {
    const account = await signUp(h);
    await storePlain(account, 'old', 1);
    const [record] = await pullAll(account);
    expect(record).toMatchObject({ table: 'notes', uuid: 'old', data: { body: 'In the clear' } });
    expect(record!.enc).toBeUndefined();
  });

  it('lets a row’s sealed copy replace its copy in the clear at the same clock, and only then', async () => {
    const account = await signUp(h);
    await storePlain(account, 'same', 5);
    await storePlain(account, 'newer', 5);
    const result = await push(account, [note('same', 5, { title: 'Sealed' }), note('newer', 4)]);
    expect(result.results.map((r) => r.status)).toEqual(['applied', 'stale']);

    const stored = await h.db.collection('records').findOne({ userId: new ObjectId(account.userId), uuid: 'same' });
    expect(stored!.data).toBeUndefined();
    expect(opened(stored as unknown as { enc: { ct: string } }).title).toBe('Sealed');
    // Sealed once, the same clock is the same write again.
    expect((await push(account, [note('same', 5, { title: 'Again' })])).results[0]!.status).toBe('stale');
    const userId = new ObjectId(account.userId);
    expect((await h.db.collection('counters').findOne({ _id: userId }))!.recordBytes).toBe(
      await h.repos.records.storedBytes(userId),
    );
  });

  it('deletes what is left in the clear once a device says all of it is sealed', async () => {
    const account = await signUp(h);
    const userId = new ObjectId(account.userId);
    await storePlain(account, 'left', 1);
    await storePlain(account, 'sealed', 1);
    await push(account, [
      note('sealed', 1),
      note('mine', 2),
      { table: 'notes', uuid: 'gone', updatedAt: at(3), deletedAt: at(3), purged: true },
    ]);

    // Nothing can have been sealed without a secret.
    expectError(await sealedCall(account, 1), 409, 'conflict');
    await choosePin(account);
    // Nor under a key the account no longer has.
    expectError(await sealedCall(account, 2), 409, 'key_changed');

    const res = await sealedCall(account, 1).expect(200);
    expect(res.body).toEqual({ dropped: 1 });
    const left = await h.db.collection('records').find({ userId }).toArray();
    expect(left.map((doc) => String(doc.uuid)).sort()).toEqual(['gone', 'mine', 'sealed']);
    expect(left.every((doc) => doc.data === undefined)).toBe(true);
    expect(JSON.stringify(left)).not.toContain('In the clear');
    // The room is counted again from what is left.
    await push(account, [note('after', 4)]);
    expect((await h.db.collection('counters').findOne({ _id: userId }))!.recordBytes).toBe(
      await h.repos.records.storedBytes(userId),
    );
    // Asked again, there is nothing more to drop.
    expect((await sealedCall(account, 1).expect(200)).body).toEqual({ dropped: 0 });
  });

  it('refuses a trail point of 3.1’s, and drops the ones it holds once all is sealed (M7.3)', async () => {
    const account = await signUp(h);
    const userId = new ObjectId(account.userId);
    const point = sealed('location_points', 'p1', at(1), null, { uuid: 'p1' });
    const refused = await push(account, [point]);
    expect(refused.results[0]).toMatchObject({ status: 'invalid' });
    expect(refused.results[0]!.issues![0]!.code).toBe('retired_table');
    // As 3.1 stored them, sealed, one a point.
    const seq = await h.repos.records.takeSeqs(userId, 1);
    await h.db.collection('records').insertOne({ ...point, userId, stamp: Date.parse(at(1)) * 1000, seq, deviceId: 'old-phone' });
    // A purge of one still goes through, like any tombstone.
    const purge = { table: 'location_points', uuid: 'p2', updatedAt: at(2), deletedAt: at(2), purged: true };
    expect((await push(account, [purge])).results[0]!.status).toBe('applied');
    await push(account, [sealed('trail_days', 'k1', at(3), null, { key: 'k1' })]);

    await choosePin(account);
    expect((await sealedCall(account, 1).expect(200)).body).toEqual({ dropped: 2 });
    expect((await pullAll(account)).map((r) => r.table)).toEqual(['trail_days']);
  });

  it('takes only a device and an epoch', async () => {
    const account = await signUp(h);
    expectError(await request(h.app).post('/v1/sync/sealed').set(bearer(account)).send({ deviceId: 'p' }), 400, 'validation_failed');
    expectError(
      await request(h.app).post('/v1/sync/sealed').set(bearer(account)).send({ deviceId: 'p', keyEpoch: 1, all: true }),
      400,
      'validation_failed',
    );
    expectError(await request(h.app).post('/v1/sync/sealed').send({ deviceId: 'p', keyEpoch: 1 }), 401, 'unauthorized');
  });

  it('knows the files a sealed row names by its clear name, and a row from before by its data', async () => {
    const account = await signUp(h);
    const userId = new ObjectId(account.userId);
    const sealedName = 'c'.repeat(64);
    const oldName = 'd'.repeat(64);
    await storePlain(account, 'old-memory', 1);
    await h.db
      .collection('records')
      .updateOne({ userId, uuid: 'old-memory' }, { $set: { table: 'memories', 'data.fileHash': oldName } });
    await push(account, [sealed('memories', 'm1', at(2), null, { path: 'a.jpg' }, { file: sealedName })]);
    expect([...(await h.repos.records.namedFiles(userId))].sort()).toEqual([sealedName, oldName]);
    expect(await h.repos.records.namesFile(userId, sealedName)).toBe(true);
    expect(await h.repos.records.namesFile(userId, oldName)).toBe(true);
    expect(await h.repos.records.namesFile(userId, 'e'.repeat(64))).toBe(false);
  });
});
