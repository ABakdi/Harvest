import { createHash } from 'node:crypto';
import { ObjectId } from 'mongodb';
import request from 'supertest';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { loadConfig } from '../src/config.js';
import { createRepositories } from '../src/db/index.js';
import { bearer, expectError, harness, password, signIn, signUp, type Harness } from './harness.js';

let h: Harness;
beforeEach(async () => {
  h = await harness();
});
afterEach(async () => {
  await h.close();
});

const secret = async () => (await loadConfig({ NODE_ENV: 'test', CORS_ORIGINS: 'https://x', APP_URL: 'https://x' })).keyShareKey;

describe('what the server keeps of a person (Phase 7, M7.7)', () => {
  it('holds no address and no name as themselves, and still signs in and answers who I am', async () => {
    const account = await signUp(h);
    await request(h.app).patch('/v1/me').set(bearer(account)).send({ displayName: 'Warda Belkacem' }).expect(200);
    await signIn(h, account.email).expect(200);
    await signIn(h, account.email.toUpperCase()).expect(200);
    const me = await request(h.app).get('/v1/me').set(bearer(account)).expect(200);
    expect(me.body).toMatchObject({ email: account.email, displayName: 'Warda Belkacem' });

    const everything = JSON.stringify(
      await Promise.all(
        (await h.db.listCollections().toArray()).map(async ({ name }) => h.db.collection(name).find().toArray()),
      ),
    );
    const local = account.email.split('@')[0]!;
    expect(everything).not.toContain(local);
    expect(everything).not.toContain('Warda');
    // Nor any plain hash of it a guess could be checked against.
    for (const prefix of ['', 'login/', 'mail/']) {
      expect(everything).not.toContain(createHash('sha256').update(`${prefix}${account.email}`).digest('hex'));
    }
  });

  it('keeps an address unique by its keyed hash', async () => {
    const account = await signUp(h);
    const again = await request(h.app)
      .post('/v1/auth/register')
      .send({ email: account.email, password, client: 'mobile' });
    expect(again.status).toBe(409);
    expect(await h.db.collection('users').countDocuments({})).toBe(1);
  });

  it('seals an account stored before Phase 7 at the next start, and it still signs in', async () => {
    const account = await signUp(h);
    const userId = new ObjectId(account.userId);
    // As 3.1 kept it: the address and the name as themselves, unique as themselves.
    await h.db.collection('users').updateOne(
      { _id: userId },
      { $set: { email: account.email, displayName: 'Old name' }, $unset: { emailLookup: '', emailSealed: '', nameSealed: '' } },
    );
    await h.db.collection('users').dropIndex('email_lookup_unique');
    await h.db.collection('users').createIndex({ email: 1 }, { unique: true, name: 'email_unique' });

    const repos = await createRepositories(h.db, await secret());
    const stored = await h.db.collection('users').findOne({ _id: userId });
    expect(stored!.email).toBeUndefined();
    expect(stored!.displayName).toBeUndefined();
    expect(stored!.emailLookup).toMatch(/^[0-9a-f]{64}$/);
    expect(await h.db.collection('users').indexExists('email_unique')).toBe(false);
    expect((await repos.users.findByEmail(account.email))?.displayName).toBe('Old name');
    await signIn(h, account.email).expect(200);
    // A second start finds nothing to do.
    expect(await repos.users.sealLegacy()).toBe(0);
  });

  it('opens nothing under another KEY_SHARE_KEY', async () => {
    const account = await signUp(h);
    const other = await createRepositories(h.db, Buffer.alloc(32, 9));
    expect(await other.users.findByEmail(account.email)).toBeNull();
    await expect(other.users.findById(new ObjectId(account.userId))).rejects.toThrow(/KEY_SHARE_KEY/);
  });
});

describe('the password again before an export (Phase 7, M7.6)', () => {
  const reauth = (h: Harness, account: { accessToken: string }, body: object) =>
    request(h.app).post('/v1/me/reauth').set(bearer(account)).send(body);

  it('takes the right password, refuses a wrong one, and nothing else', async () => {
    const account = await signUp(h);
    await reauth(h, account, { password }).expect(204);
    expectError(await reauth(h, account, { password: 'not my password' }), 403, 'forbidden');
    expectError(await reauth(h, account, { password, keep: true }), 400, 'validation_failed');
    expectError(await request(h.app).post('/v1/me/reauth').send({ password }), 401, 'unauthorized');
  });

  it('counts wrong ones with deleting the account', async () => {
    const limited = await harness({ rateLimits: { deleteFailures: 2 } });
    try {
      const account = await signUp(limited);
      expectError(await reauth(limited, account, { password: 'wrong once' }), 403, 'forbidden');
      expectError(
        await request(limited.app).delete('/v1/me').set(bearer(account)).send({ password: 'wrong twice' }),
        403,
        'forbidden',
      );
      expectError(await reauth(limited, account, { password }), 429, 'rate_limited');
    } finally {
      await limited.close();
    }
  });
});
