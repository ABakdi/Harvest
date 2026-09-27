import { createHash, randomBytes } from 'node:crypto';
import {
  fileIvHeader,
  filePlainBytesHeader,
  keyCheckConflictSchema,
  keyCheckStoredSchema,
  syncKeyResultSchema,
  type KeyCheck,
  type PullResult,
  type SyncKeyResult,
} from '@harvest/contracts';
import { ObjectId } from 'mongodb';
import request from 'supertest';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { KeyShares } from '../src/auth/key-shares.js';
import { bearer, expectError, harness, password, signIn, signUp, type Account, type Harness } from './harness.js';

let h: Harness;
beforeEach(async () => {
  h = await harness();
});
afterEach(async () => {
  await h.close();
});

const check = (): KeyCheck => ({ v: 2, iv: randomBytes(12).toString('base64'), ct: randomBytes(33).toString('base64') });

const read = (account: Pick<Account, 'accessToken'>) => request(h.app).get('/v1/me/sync-key').set(bearer(account));
const store = (account: Account, body: object) =>
  request(h.app).put('/v1/me/sync-key/check').set(bearer(account)).send(body);

describe('the key share (S5-04)', () => {
  it('hands a verified account its salt, a 32-byte share and no check yet', async () => {
    const account = await signUp(h);
    const res = await read(account).expect(200);
    const body = syncKeyResultSchema.parse(res.body);
    expect(Buffer.from(body.keyShare, 'base64')).toHaveLength(32);
    expect(body.check).toBeNull();
    const me = await request(h.app).get('/v1/me').set(bearer(account)).expect(200);
    expect(body.salt).toBe((me.body as { syncSalt: string }).syncSalt);
    expect(res.headers['cache-control']).toBe('no-store');
  });

  it('makes the share once and keeps it, one per account', async () => {
    const one = await signUp(h);
    const two = await signUp(h);
    const [a, b] = await Promise.all([read(one).expect(200), read(one).expect(200)]);
    const share = (a.body as SyncKeyResult).keyShare;
    expect((b.body as SyncKeyResult).keyShare).toBe(share);
    expect(((await read(one).expect(200)).body as SyncKeyResult).keyShare).toBe(share);
    expect(((await read(two).expect(200)).body as SyncKeyResult).keyShare).not.toBe(share);
  });

  it('keeps the share sealed in the database, under a key that is not there', async () => {
    const account = await signUp(h);
    const share = Buffer.from(((await read(account).expect(200)).body as SyncKeyResult).keyShare, 'base64');
    const user = await h.db.collection('users').findOne({ _id: new ObjectId(account.userId) });
    const stored = JSON.stringify(user);
    expect(stored).not.toContain(share.toString('base64'));
    expect(stored).not.toContain(share.toString('hex'));
    const sealed = user!.keyShare as { iv: unknown; ct: unknown };
    expect(typeof sealed.iv).toBe('string');
    expect(typeof sealed.ct).toBe('string');

    // Another server key does not open it, and does not quietly make a new one.
    const elsewhere = new KeyShares(h.repos.users, Buffer.alloc(32, 1));
    await expect(elsewhere.read(new ObjectId(account.userId))).rejects.toThrow(/KEY_SHARE_KEY/);
    const after = await h.db.collection('users').findOne({ _id: new ObjectId(account.userId) });
    expect(after!.keyShare).toEqual(user!.keyShare);
  });

  it('is only for a verified account, signed in', async () => {
    const unverified = await signUp(h, { verify: false });
    expectError(await read(unverified), 403, 'forbidden');
    expectError(await request(h.app).get('/v1/me/sync-key'), 401, 'unauthorized');
  });

  it('is limited per account', async () => {
    await h.close();
    h = await harness({ rateLimits: { syncKeyRequests: 2 } });
    const account = await signUp(h);
    await read(account).expect(200);
    await store(account, { check: check() }).expect(201);
    expectError(await read(account), 429, 'rate_limited');
    // The same account from another device is the same allowance.
    const laptop = (await signIn(h, account.email).expect(200)).body as { accessToken: string };
    expectError(await read(laptop), 429, 'rate_limited');
    await read(await signUp(h)).expect(200);
  });

  it('goes with the account', async () => {
    const account = await signUp(h);
    await read(account).expect(200);
    await store(account, { check: check() }).expect(201);
    await request(h.app).delete('/v1/me').set(bearer(account)).send({ password }).expect(204);
    expect(await h.db.collection('users').countDocuments({ _id: new ObjectId(account.userId) })).toBe(0);
  });
});

describe('the key check (S5-09, Q5-01, Q5-55)', () => {
  it('stores the first check and hands it to every device after', async () => {
    const account = await signUp(h);
    const first = check();
    const stored = await store(account, { check: first }).expect(201);
    expect(keyCheckStoredSchema.parse(stored.body)).toEqual({ check: first });
    expect(((await read(account).expect(200)).body as SyncKeyResult).check).toEqual(first);
  });

  it('answers a second device choosing with the check already stored', async () => {
    const account = await signUp(h);
    const first = check();
    await store(account, { check: first }).expect(201);
    const late = await store(account, { check: check() });
    expectError(late, 409, 'conflict');
    expect(keyCheckConflictSchema.parse(late.body).check).toEqual(first);
    expect(((await read(account).expect(200)).body as SyncKeyResult).check).toEqual(first);
  });

  it('takes the same check again, a retry whose answer was lost', async () => {
    const account = await signUp(h);
    const first = check();
    await store(account, { check: first }).expect(201);
    await store(account, { check: first }).expect(201);
  });

  it('lets exactly one of two devices choosing at once win', async () => {
    const account = await signUp(h);
    const answers = await Promise.all([store(account, { check: check() }), store(account, { check: check() })]);
    expect(answers.map((res) => res.status).sort()).toEqual([201, 409]);
  });

  it('takes only a well-formed version 2 check, and nothing else in the body', async () => {
    const account = await signUp(h);
    expectError(await store(account, { check: { ...check(), v: 1 } }), 400, 'validation_failed');
    expectError(await store(account, { check: { ...check(), iv: 'AAAA' } }), 400, 'validation_failed');
    expectError(await store(account, { check: { ...check(), ct: 'A'.repeat(400) } }), 400, 'validation_failed');
    expectError(await store(account, { check: check(), extra: 1 }), 400, 'validation_failed');
  });

  it('keeps each account to its own check', async () => {
    const one = await signUp(h);
    const two = await signUp(h);
    await store(one, { check: check() }).expect(201);
    expect(((await read(two).expect(200)).body as SyncKeyResult).check).toBeNull();
    await store(two, { check: check() }).expect(201);
  });
});

describe('starting over (a forgotten PIN)', () => {
  const at = '2026-09-19T10:00:00.000Z';
  const sealedRow = { table: 'geotags', uuid: 'g1', updatedAt: at, deletedAt: null, enc: { v: 2, iv: 'AAAAAAAAAAAAAAAB', ct: 'q83vEjRWeJA=' } };
  const plainRow = {
    table: 'notes',
    uuid: 'n1',
    updatedAt: at,
    deletedAt: null,
    data: { uuid: 'n1', title: 'Kept', folder: '', body: 'b', createdAt: at, updatedAt: at, deletedAt: null },
  };
  const reset = (account: Pick<Account, 'accessToken'>, pass: string, extra: object = {}) =>
    request(h.app).delete('/v1/me/sync-key').set(bearer(account)).send({ password: pass, ...extra });

  async function filled(account: Account) {
    await read(account).expect(200);
    await store(account, { check: check() }).expect(201);
    await request(h.app)
      .post('/v1/sync/push')
      .set(bearer(account))
      .send({ deviceId: 'phone', records: [sealedRow, plainRow] })
      .expect(200);
    const bytes = randomBytes(500);
    await request(h.app)
      .put(`/v1/files/${createHash('sha256').update(bytes).digest('hex')}`)
      .set(bearer(account))
      .set('Content-Type', 'application/octet-stream')
      .set(fileIvHeader, randomBytes(12).toString('base64'))
      .set(filePlainBytesHeader, '484')
      .send(bytes)
      .expect(201);
  }

  it('drops the check, the share, the private rows and the files, and keeps the plain tier', async () => {
    const account = await signUp(h);
    await filled(account);
    const before = (await read(account).expect(200)).body as SyncKeyResult;

    await reset(account, password).expect(204);

    const after = (await read(account).expect(200)).body as SyncKeyResult;
    expect(after.check).toBeNull();
    expect(after.keyShare).not.toBe(before.keyShare);
    expect(after.salt).toBe(before.salt);

    // A device whose cursor is behind never sees the private rows again.
    const pulled = await request(h.app).get('/v1/sync/pull').set(bearer(account)).expect(200);
    expect((pulled.body as PullResult).records.map((r) => r.uuid)).toEqual(['n1']);
    const userId = new ObjectId(account.userId);
    expect(await h.db.collection('files').countDocuments({ userId })).toBe(0);

    // The totals start again from what is left.
    const missing = await request(h.app).post('/v1/files/missing').set(bearer(account)).send({ hashes: [] }).expect(200);
    expect(missing.body).toMatchObject({ usedBytes: 0 });
    await request(h.app)
      .post('/v1/sync/push')
      .set(bearer(account))
      .send({ deviceId: 'phone', records: [{ ...sealedRow, uuid: 'g2' }] })
      .expect(200);
    const counter = await h.db.collection('counters').findOne({ _id: userId });
    expect(counter!.recordBytes).toBe(await h.repos.records.storedBytes(userId));

    // And a new PIN can be chosen.
    await store(account, { check: check() }).expect(201);
  });

  it('asks for the password, counted like deleting the account', async () => {
    await h.close();
    h = await harness({ rateLimits: { deleteFailures: 2 } });
    const account = await signUp(h);
    await filled(account);
    expectError(await reset(account, 'not my password'), 403, 'forbidden');
    expectError(await request(h.app).delete('/v1/me').set(bearer(account)).send({ password: 'nope nope' }), 403, 'forbidden');
    expectError(await reset(account, password), 429, 'rate_limited');
    // Nothing went.
    expect(((await read(account).expect(200)).body as SyncKeyResult).check).not.toBeNull();
  });

  it('takes nothing but the password, and only from a verified account', async () => {
    const account = await signUp(h);
    expectError(await reset(account, password, { pin: '1234' }), 400, 'validation_failed');
    const unverified = await signUp(h, { verify: false });
    expectError(await reset(unverified, password), 403, 'forbidden');
    expectError(await request(h.app).delete('/v1/me/sync-key').send({ password }), 401, 'unauthorized');
  });

  it('leaves other accounts alone', async () => {
    const one = await signUp(h);
    const two = await signUp(h);
    await filled(one);
    await filled(two);
    await reset(one, password).expect(204);
    expect(((await read(two).expect(200)).body as SyncKeyResult).check).not.toBeNull();
    const pulled = await request(h.app).get('/v1/sync/pull').set(bearer(two)).expect(200);
    expect((pulled.body as PullResult).records).toHaveLength(2);
  });
});
