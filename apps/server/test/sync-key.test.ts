import { createHash, randomBytes } from 'node:crypto';
import {
  derivePinProof,
  fileIvHeader,
  fileKeyEpochHeader,
  filePlainBytesHeader,
  pinVerifierOf,
  syncKeySetSchema,
  syncKeyStateSchema,
  unlockResultSchema,
  wrongPinSchema,
  type KeyCheck,
  type PullResult,
  type PushResult,
  type SyncKeyState,
} from '@harvest/contracts';
import { ObjectId } from 'mongodb';
import request from 'supertest';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { KeyShares } from '../src/auth/key-shares.js';
import { bearer, expectError, harness, password, signIn, signUp, type Account, type Harness } from './harness.js';

let h: Harness;
let clock = Date.now();
beforeEach(async () => {
  clock = Date.now();
  h = await harness({ now: () => new Date(clock) });
});
afterEach(async () => {
  await h.close();
});

const check = (): KeyCheck => ({ v: 2, iv: randomBytes(12).toString('base64'), ct: randomBytes(33).toString('base64') });

type Session = Pick<Account, 'accessToken'>;
const read = (account: Session) => request(h.app).get('/v1/me/sync-key').set(bearer(account));
const unlock = (account: Session, proof: string) =>
  request(h.app).post('/v1/me/sync-key/unlock').set(bearer(account)).send({ proof });
const choose = (account: Session, body: object) => request(h.app).put('/v1/me/sync-key').set(bearer(account)).send(body);

/** The proof of [pin] for the account's salt, cheaply (the server never sees the rounds). */
async function proofOf(account: Session, pin: string): Promise<string> {
  const state = (await read(account).expect(200)).body as SyncKeyState;
  return derivePinProof(pin, state.salt, { iterations: 1000 });
}

/** Chooses [pin] as the first device would: answers the check it stored. */
async function choosePin(account: Session, pin: string): Promise<KeyCheck> {
  const stored = check();
  const verifier = await pinVerifierOf(await proofOf(account, pin));
  await choose(account, { verifier, check: stored }).expect(201);
  return stored;
}

describe('the sync key state (S6-04)', () => {
  it('hands the share out only while no PIN is set, and never the check', async () => {
    const account = await signUp(h);
    const before = syncKeyStateSchema.parse((await read(account).expect(200)).body);
    expect(before).toMatchObject({ state: 'none', epoch: 1 });
    expect(before.state === 'none' && Buffer.from(before.keyShare, 'base64')).toHaveLength(32);
    const me = await request(h.app).get('/v1/me').set(bearer(account)).expect(200);
    expect(before.salt).toBe((me.body as { syncSalt: string }).syncSalt);

    await choosePin(account, '482913');
    const after = (await read(account).expect(200)).body as Record<string, unknown>;
    expect(after).toEqual({ state: 'set', salt: before.salt, epoch: 1 });
  });

  it('makes the share once and keeps it, one per account', async () => {
    const one = await signUp(h);
    const two = await signUp(h);
    const [a, b] = await Promise.all([read(one).expect(200), read(one).expect(200)]);
    const share = (a.body as { keyShare: string }).keyShare;
    expect((b.body as { keyShare: string }).keyShare).toBe(share);
    expect(((await read(two).expect(200)).body as { keyShare: string }).keyShare).not.toBe(share);
  });

  it('keeps the share and the verifier sealed in the database, under a key that is not there', async () => {
    const account = await signUp(h);
    const share = Buffer.from(((await read(account).expect(200)).body as { keyShare: string }).keyShare, 'base64');
    const proof = await proofOf(account, '2468');
    const verifier = await pinVerifierOf(proof);
    await choose(account, { verifier, check: check() }).expect(201);
    const user = await h.db.collection('users').findOne({ _id: new ObjectId(account.userId) });
    const stored = JSON.stringify(user);
    for (const secret of [share.toString('base64'), share.toString('hex'), verifier, proof]) {
      expect(stored).not.toContain(secret);
    }
    expect(stored).not.toContain(Buffer.from(verifier, 'hex').toString('base64'));

    // Another server key opens neither, and does not quietly make a new share.
    const elsewhere = new KeyShares(h.repos.users, h.repos.windowedCounts, Buffer.alloc(32, 1));
    await expect(elsewhere.unlock(new ObjectId(account.userId), proof)).rejects.toThrow(/KEY_SHARE_KEY/);
    const after = await h.db.collection('users').findOne({ _id: new ObjectId(account.userId) });
    expect(after!.keyShare).toEqual(user!.keyShare);
  });

  it('is only for a verified account, signed in', async () => {
    const unverified = await signUp(h, { verify: false });
    expectError(await read(unverified), 403, 'forbidden');
    expectError(await request(h.app).get('/v1/me/sync-key'), 401, 'unauthorized');
  });
});

describe('choosing the PIN', () => {
  it('stores the verifier and the check once; the next device enters', async () => {
    const account = await signUp(h);
    const answer = await choose(account, { verifier: await pinVerifierOf(await proofOf(account, '1357')), check: check() });
    expect(answer.status).toBe(201);
    expect(syncKeySetSchema.parse(answer.body)).toEqual({ epoch: 1 });

    const late = await choose(account, { verifier: await pinVerifierOf(await proofOf(account, '9753')), check: check() });
    expectError(late, 409, 'conflict');
  });

  it('takes the same choice again, a retry whose answer was lost', async () => {
    const account = await signUp(h);
    const body = { verifier: await pinVerifierOf(await proofOf(account, '1357')), check: check() };
    await choose(account, body).expect(201);
    await choose(account, body).expect(201);
  });

  it('lets exactly one of two devices choosing at once win', async () => {
    const account = await signUp(h);
    const one = { verifier: await pinVerifierOf(await proofOf(account, '1111')), check: check() };
    const two = { verifier: await pinVerifierOf(await proofOf(account, '2222')), check: check() };
    const answers = await Promise.all([choose(account, one), choose(account, two)]);
    expect(answers.map((res) => res.status).sort()).toEqual([201, 409]);
  });

  it('takes only a well-formed verifier and version 2 check', async () => {
    const account = await signUp(h);
    const verifier = randomBytes(32).toString('hex');
    expectError(await choose(account, { verifier, check: { ...check(), v: 1 } }), 400, 'validation_failed');
    expectError(await choose(account, { verifier: 'abc', check: check() }), 400, 'validation_failed');
    expectError(await choose(account, { verifier, check: check(), extra: 1 }), 400, 'validation_failed');
  });
});

describe('unlocking (S6-04)', () => {
  it('hands the share, the check and the epoch for the right PIN only', async () => {
    const account = await signUp(h);
    const share = ((await read(account).expect(200)).body as { keyShare: string }).keyShare;
    const stored = await choosePin(account, '482913');

    const right = unlockResultSchema.parse((await unlock(account, await proofOf(account, '482913')).expect(200)).body);
    expect(right).toEqual({ keyShare: share, check: stored, epoch: 1 });

    const wrong = await unlock(account, await proofOf(account, '482914'));
    expectError(wrong, 403, 'wrong_pin');
    expect(wrongPinSchema.parse(wrong.body).triesLeft).toBe(4);
  });

  it('refuses before a PIN is chosen: choose instead', async () => {
    const account = await signUp(h);
    expectError(await unlock(account, randomBytes(32).toString('base64')), 409, 'conflict');
  });

  it('allows five wrong PINs in a quarter of an hour, and a right one starts it again', async () => {
    const account = await signUp(h);
    await choosePin(account, '482913');
    const wrong = await proofOf(account, '000001');
    for (let left = 4; left >= 0; left -= 1) {
      expect(wrongPinSchema.parse((await unlock(account, wrong)).body).triesLeft).toBe(left);
    }
    // Past the limit even the right PIN waits: a stolen session gets five guesses, not a million.
    const blocked = await unlock(account, await proofOf(account, '482913'));
    expectError(blocked, 429, 'rate_limited');
    expect(Number(blocked.headers['retry-after'])).toBeGreaterThan(800);

    clock += 15 * 60_000 + 1000;
    await unlock(account, await proofOf(account, '482913')).expect(200);
    // The right PIN started the short window again: five more tries.
    for (let i = 0; i < 4; i += 1) expectError(await unlock(account, wrong), 403, 'wrong_pin');
  });

  it('allows twenty wrong PINs in a day, whatever the quarter hours, kept in the database', async () => {
    const account = await signUp(h);
    await choosePin(account, '482913');
    const wrong = await proofOf(account, '000001');
    for (let round = 0; round < 4; round += 1) {
      for (let i = 0; i < 5; i += 1) expectError(await unlock(account, wrong), 403, 'wrong_pin');
      clock += 16 * 60_000;
    }
    const blocked = await unlock(account, await proofOf(account, '482913'));
    expectError(blocked, 429, 'rate_limited');
    expect(Number(blocked.headers['retry-after'])).toBeGreaterThan(20 * 60 * 60);
    expect(await h.db.collection('windowed_counts').countDocuments({ _id: `unlock/${account.userId}` as never })).toBe(1);
  });

  it('counts tries sent at once, one by one', async () => {
    const account = await signUp(h);
    await choosePin(account, '482913');
    const wrong = await proofOf(account, '000001');
    const answers = await Promise.all(Array.from({ length: 12 }, () => unlock(account, wrong)));
    expect(answers.filter((res) => res.status === 403)).toHaveLength(5);
    expect(answers.filter((res) => res.status === 429)).toHaveLength(7);
  });

  it('takes nothing but a 32-byte proof', async () => {
    const account = await signUp(h);
    await choosePin(account, '482913');
    expectError(await unlock(account, randomBytes(16).toString('base64')), 400, 'validation_failed');
    expectError(
      await request(h.app).post('/v1/me/sync-key/unlock').set(bearer(account)).send({ proof: randomBytes(32).toString('base64'), pin: '1' }),
      400,
      'validation_failed',
    );
  });

  it('keeps one account\'s tries its own, and the same account\'s devices share them', async () => {
    await h.close();
    h = await harness({ now: () => new Date(clock), rateLimits: { syncKeyRequests: 1000 } });
    const account = await signUp(h);
    const other = await signUp(h);
    await choosePin(account, '482913');
    await choosePin(other, '482913');
    const laptop = (await signIn(h, account.email).expect(200)).body as Session;
    const wrong = await proofOf(account, '000001');
    for (let i = 0; i < 5; i += 1) await unlock(i % 2 === 0 ? account : laptop, wrong);
    expectError(await unlock(laptop, wrong), 429, 'rate_limited');
    await unlock(other, await proofOf(other, '482913')).expect(200);
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
  const reset = (account: Session, pass: string, extra: object = {}) =>
    request(h.app).delete('/v1/me/sync-key').set(bearer(account)).send({ password: pass, ...extra });
  const push = (account: Session, records: object[], keyEpoch?: number) =>
    request(h.app)
      .post('/v1/sync/push')
      .set(bearer(account))
      .send({ deviceId: 'phone', records, ...(keyEpoch === undefined ? {} : { keyEpoch }) });
  const upload = (account: Session, bytes: Buffer, epoch: string | null) => {
    const req = request(h.app)
      .put(`/v1/files/${createHash('sha256').update(bytes).digest('hex')}`)
      .set(bearer(account))
      .set('Content-Type', 'application/octet-stream')
      .set(fileIvHeader, randomBytes(12).toString('base64'))
      .set(filePlainBytesHeader, String(bytes.length - 16));
    return epoch === null ? req.send(bytes) : req.set(fileKeyEpochHeader, epoch).send(bytes);
  };

  async function filled(account: Account) {
    await choosePin(account, '482913');
    await push(account, [sealedRow, plainRow], 1).expect(200);
    await upload(account, randomBytes(500), '1').expect(201);
  }

  it('drops the verifier, the check, the share, the private rows and the files, moves the epoch, keeps the plain tier', async () => {
    const account = await signUp(h);
    const share = ((await read(account).expect(200)).body as { keyShare: string }).keyShare;
    await filled(account);

    await reset(account, password).expect(204);

    const after = syncKeyStateSchema.parse((await read(account).expect(200)).body);
    expect(after.state).toBe('none');
    expect(after.epoch).toBe(2);
    expect(after.state === 'none' && after.keyShare).not.toBe(share);

    // A device whose cursor is behind never sees the private rows again.
    const pulled = await request(h.app).get('/v1/sync/pull').set(bearer(account)).expect(200);
    expect((pulled.body as PullResult).records.map((r) => r.uuid)).toEqual(['n1']);
    const userId = new ObjectId(account.userId);
    expect(await h.db.collection('files').countDocuments({ userId })).toBe(0);
    expect(await h.db.collection('file_blobs.files').countDocuments({ 'metadata.userId': userId })).toBe(0);

    // The totals start again from what is left.
    const missing = await request(h.app).post('/v1/files/missing').set(bearer(account)).send({ hashes: [] }).expect(200);
    expect(missing.body).toMatchObject({ usedBytes: 0 });
    await push(account, [{ ...sealedRow, uuid: 'g2' }], 2).expect(200);
    const counter = await h.db.collection('counters').findOne({ _id: userId });
    expect(counter!.recordBytes).toBe(await h.repos.records.storedBytes(userId));

    // And a new PIN can be chosen, under the new epoch.
    const set = await choose(account, { verifier: await pinVerifierOf(await proofOf(account, '1234')), check: check() });
    expect(set.body).toEqual({ epoch: 2 });
  });

  it('refuses sealed writes from a device still on the old key (S6-07)', async () => {
    const account = await signUp(h);
    await filled(account);
    await reset(account, password).expect(204);

    // A sealed push under epoch 1: every sealed record refused, the plain one still lands.
    const res = (await push(account, [{ ...sealedRow, uuid: 'g-late' }, { ...plainRow, uuid: 'n2', data: { ...plainRow.data, uuid: 'n2' } }], 1).expect(200))
      .body as PushResult;
    expect(res.results.map((r) => r.status)).toEqual(['invalid', 'applied']);
    expect(res.results[0]!.issues![0]!.code).toBe('key_changed');
    // No epoch at all is no better.
    const bare = (await push(account, [{ ...sealedRow, uuid: 'g-bare' }]).expect(200)).body as PushResult;
    expect(bare.results[0]!.issues![0]!.code).toBe('key_changed');

    // A file sealed under the old key is refused, and nothing is kept, not even as "held".
    const bytes = randomBytes(300);
    expectError(await upload(account, bytes, '1'), 409, 'key_changed');
    expectError(await upload(account, bytes, null), 409, 'key_changed');
    const name = createHash('sha256').update(bytes).digest('hex');
    const asked = await request(h.app).post('/v1/files/missing').set(bearer(account)).send({ hashes: [name] }).expect(200);
    expect(asked.body).toMatchObject({ missing: [name] });
    // Under the new epoch it goes.
    await upload(account, bytes, '2').expect(201);
  });

  it('forgets the wrong tries with the old PIN', async () => {
    const account = await signUp(h);
    await choosePin(account, '482913');
    const wrong = await proofOf(account, '000001');
    for (let i = 0; i < 5; i += 1) await unlock(account, wrong);
    await reset(account, password).expect(204);
    await choosePin(account, '1234');
    await unlock(account, await proofOf(account, '1234')).expect(200);
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
    expect(((await read(account).expect(200)).body as SyncKeyState).state).toBe('set');
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
    expect(((await read(two).expect(200)).body as SyncKeyState).epoch).toBe(1);
    await unlock(two, await proofOf(two, '482913')).expect(200);
    const pulled = await request(h.app).get('/v1/sync/pull').set(bearer(two)).expect(200);
    expect((pulled.body as PullResult).records).toHaveLength(2);
  });

  it('goes with the account', async () => {
    const account = await signUp(h);
    await filled(account);
    await request(h.app).delete('/v1/me').set(bearer(account)).send({ password }).expect(204);
    expect(await h.db.collection('users').countDocuments({ _id: new ObjectId(account.userId) })).toBe(0);
    expect(await h.db.collection('file_blobs.files').countDocuments({})).toBe(0);
    expect(await h.db.collection('file_blobs.chunks').countDocuments({})).toBe(0);
  });
});
