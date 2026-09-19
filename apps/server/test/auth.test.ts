import type { AuthResult, ErrorBody, Me, PullResult, SessionsResult } from '@harvest/contracts';
import { ObjectId } from 'mongodb';
import request from 'supertest';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { wrongCredentials } from '../src/auth/service.js';
import {
  bearer,
  expectError,
  freshEmail,
  harness,
  linkToken,
  password,
  refreshCookieOf,
  signIn,
  signUp,
  type Harness,
} from './harness.js';

let h: Harness;
beforeEach(async () => {
  h = await harness();
});
afterEach(async () => {
  await h.close();
});

const me = (token: { accessToken: string }) => request(h.app).get('/v1/me').set(bearer(token));
const refresh = (refreshToken: string) => request(h.app).post('/v1/auth/refresh').send({ refreshToken });

describe('sign-up', () => {
  it('creates an unverified account, signs it in and sends one verification email', async () => {
    const email = freshEmail();
    const res = await request(h.app)
      .post('/v1/auth/register')
      .send({ email: `  ${email.toUpperCase()} `, password, displayName: 'Abder' })
      .expect(201);
    const body = res.body as AuthResult;
    expect(body.user).toMatchObject({ email, displayName: 'Abder', verifiedAt: null });
    expect(body.user.syncSalt).toMatch(/^[A-Za-z0-9+/]{22}==$/);
    expect(body.expiresIn).toBe(900);
    expect(h.mailer.sent.filter((m) => m.to === email && m.purpose === 'verify')).toHaveLength(1);
    await me(body).expect(200);
  });

  it('gives the web its refresh token as a strict HttpOnly cookie, and not in the body', async () => {
    const res = await request(h.app).post('/v1/auth/register').send({ email: freshEmail(), password }).expect(201);
    expect((res.body as AuthResult).refreshToken).toBeUndefined();
    const cookie = (res.headers['set-cookie'] as unknown as string[]).find((c) => c.startsWith('harvest_refresh='));
    expect(cookie).toBeDefined();
    expect(cookie).toContain('HttpOnly');
    expect(cookie).toContain('Secure');
    expect(cookie).toContain('SameSite=Strict');
    expect(cookie).toContain('Path=/v1/auth');
  });

  it('gives the phone its refresh token in the body, and no cookie', async () => {
    const res = await request(h.app)
      .post('/v1/auth/register')
      .send({ email: freshEmail(), password, client: 'mobile' })
      .expect(201);
    expect((res.body as AuthResult).refreshToken).toMatch(/^[0-9a-f]{24}\./);
    expect(res.headers['set-cookie']).toBeUndefined();
  });

  it('refuses a taken email with 409, whatever its case', async () => {
    const account = await signUp(h);
    const res = await request(h.app)
      .post('/v1/auth/register')
      .send({ email: account.email.toUpperCase(), password: 'another long password' });
    expectError(res, 409, 'conflict');
  });

  it('refuses a short or common password, and says which field', async () => {
    const short = await request(h.app).post('/v1/auth/register').send({ email: freshEmail(), password: 'short' });
    expectError(short, 400, 'validation_failed');
    expect((short.body as ErrorBody).error.details?.[0]?.path).toEqual(['body', 'password']);

    const common = await request(h.app).post('/v1/auth/register').send({ email: freshEmail(), password: 'qwertyuiop' });
    expectError(common, 400, 'validation_failed');
  });

  it('never echoes the password in an error', async () => {
    const res = await request(h.app).post('/v1/auth/register').send({ email: 'nope', password: 'secret-value-123' });
    expect(JSON.stringify(res.body)).not.toContain('secret-value-123');
  });
});

describe('verification', () => {
  it('verifies with the emailed link, once', async () => {
    const account = await signUp(h, { verify: false });
    const token = linkToken(h, account.email, 'verify');
    await request(h.app).post('/v1/auth/verify-email').send({ token }).expect(204);
    expect(((await me(account)).body as Me).verifiedAt).not.toBeNull();

    const again = await request(h.app).post('/v1/auth/verify-email').send({ token });
    expectError(again, 400, 'validation_failed');
  });

  it('refuses a forged or expired link', async () => {
    const account = await signUp(h, { verify: false });
    const forged = `${account.userId}.${'A'.repeat(43)}`;
    expectError(await request(h.app).post('/v1/auth/verify-email').send({ token: forged }), 400, 'validation_failed');

    await h.db.collection('one_time_tokens').updateMany({}, { $set: { expiresAt: new Date(Date.now() - 1000) } });
    const token = linkToken(h, account.email, 'verify');
    expectError(await request(h.app).post('/v1/auth/verify-email').send({ token }), 400, 'validation_failed');
  });

  it('re-sends a link that replaces the old one, and answers the same for unknown addresses', async () => {
    const account = await signUp(h, { verify: false });
    const first = linkToken(h, account.email, 'verify');

    await request(h.app).post('/v1/auth/resend-verification').send({ email: account.email }).expect(202);
    const second = linkToken(h, account.email, 'verify');
    expect(second).not.toBe(first);
    expectError(await request(h.app).post('/v1/auth/verify-email').send({ token: first }), 400, 'validation_failed');
    await request(h.app).post('/v1/auth/verify-email').send({ token: second }).expect(204);

    const sent = h.mailer.sent.length;
    await request(h.app).post('/v1/auth/resend-verification').send({ email: freshEmail() }).expect(202);
    expect(h.mailer.sent).toHaveLength(sent);
  });
});

describe('sign-in', () => {
  it('signs in with the right password', async () => {
    const account = await signUp(h);
    const res = await signIn(h, account.email.toUpperCase()).expect(200);
    await me(res.body as AuthResult).expect(200);
  });

  it('answers a wrong password and an unknown email with the same 401', async () => {
    const account = await signUp(h);
    const wrong = await request(h.app).post('/v1/auth/login').send({ email: account.email, password: 'not the password' });
    const unknown = await request(h.app).post('/v1/auth/login').send({ email: freshEmail(), password });
    expectError(wrong, 401, 'unauthorized');
    expectError(unknown, 401, 'unauthorized');
    expect((wrong.body as ErrorBody).error.message).toBe(wrongCredentials);
    expect(unknown.body).toEqual(wrong.body);
  });

  it('rate-limits an address after five failures in fifteen minutes', async () => {
    const account = await signUp(h);
    for (let i = 0; i < 5; i += 1) {
      await request(h.app).post('/v1/auth/login').send({ email: account.email, password: 'wrong wrong' }).expect(401);
    }
    const blocked = await signIn(h, account.email);
    expectError(blocked, 429, 'rate_limited');
    expect(Number(blocked.headers['retry-after'])).toBeGreaterThan(0);
  });

  it('does not count successful sign-ins against the limit', async () => {
    const account = await signUp(h);
    for (let i = 0; i < 7; i += 1) await signIn(h, account.email).expect(200);
  });

  it('refuses requests without a valid access token', async () => {
    expectError(await request(h.app).get('/v1/me'), 401, 'unauthorized');
    expectError(await request(h.app).get('/v1/me').set('Authorization', 'Bearer nonsense'), 401, 'unauthorized');
    expectError(await request(h.app).get('/v1/me').set('Authorization', 'Basic abc'), 401, 'unauthorized');
  });
});

describe('refresh tokens', () => {
  it('rotate on every use', async () => {
    const account = await signUp(h);
    const first = await refresh(account.refreshToken).expect(200);
    const rotated = (first.body as AuthResult).refreshToken!;
    expect(rotated).not.toBe(account.refreshToken);
    await me(first.body as AuthResult).expect(200);

    const second = await refresh(rotated).expect(200);
    expect((second.body as AuthResult).refreshToken).not.toBe(rotated);
  });

  it('revoke the whole family when one is used twice (AC4)', async () => {
    const account = await signUp(h);
    const rotated = ((await refresh(account.refreshToken).expect(200)).body as AuthResult);

    // The old token comes back: someone else has a copy.
    expectError(await refresh(account.refreshToken), 401, 'unauthorized');

    // Every token and access token of that session is now dead.
    expectError(await refresh(rotated.refreshToken!), 401, 'unauthorized');
    expectError(await me(rotated), 401, 'unauthorized');
    expectError(await me(account), 401, 'unauthorized');
  });

  it('leave other sessions alone when one family is revoked', async () => {
    const account = await signUp(h);
    const laptop = (await signIn(h, account.email).expect(200)).body as AuthResult;
    await refresh(account.refreshToken).expect(200);
    await refresh(account.refreshToken).expect(401);
    await me(laptop).expect(200);
    await refresh(laptop.refreshToken!).expect(200);
  });

  it('refuse garbage and expired tokens', async () => {
    expectError(await refresh('garbage'), 401, 'unauthorized');
    expectError(await request(h.app).post('/v1/auth/refresh').send({}), 401, 'unauthorized');

    const account = await signUp(h);
    await h.db.collection('refresh_tokens').updateMany({}, { $set: { expiresAt: new Date(Date.now() - 1000) } });
    expectError(await refresh(account.refreshToken), 401, 'unauthorized');
  });

  it('work from the cookie on the web, and rotate the cookie', async () => {
    const email = (await signUp(h)).email;
    const login = await signIn(h, email, 'web').expect(200);
    const cookie = refreshCookieOf(login)!;
    expect(cookie).toBeDefined();

    const res = await request(h.app).post('/v1/auth/refresh').set('Cookie', `harvest_refresh=${cookie}`).expect(200);
    expect((res.body as AuthResult).refreshToken).toBeUndefined();
    const next = refreshCookieOf(res);
    expect(next).toBeDefined();
    expect(next).not.toBe(cookie);
  });
});

describe('sign-out', () => {
  it('kills the refresh token and the access token of that device only', async () => {
    const account = await signUp(h);
    const laptop = (await signIn(h, account.email).expect(200)).body as AuthResult;

    await request(h.app).post('/v1/auth/logout').send({ refreshToken: account.refreshToken }).expect(204);
    expectError(await refresh(account.refreshToken), 401, 'unauthorized');
    expectError(await me(account), 401, 'unauthorized');
    await me(laptop).expect(200);
  });

  it('clears the web cookie, and is quiet about unknown tokens', async () => {
    const res = await request(h.app).post('/v1/auth/logout').send({ refreshToken: 'whatever' }).expect(204);
    expect(String(res.headers['set-cookie'])).toContain('harvest_refresh=;');
  });
});

describe('forgot and reset', () => {
  it('answers 202 for an unknown address and sends nothing', async () => {
    await request(h.app).post('/v1/auth/forgot-password').send({ email: freshEmail() }).expect(202);
    expect(h.mailer.sent.filter((m) => m.purpose === 'reset')).toHaveLength(0);
  });

  it('resets the password with a single-use link and signs out every device (AC5)', async () => {
    const account = await signUp(h);
    const laptop = (await signIn(h, account.email).expect(200)).body as AuthResult;

    await request(h.app).post('/v1/auth/forgot-password').send({ email: account.email }).expect(202);
    const token = linkToken(h, account.email, 'reset');
    const newPassword = 'a brand new passphrase';
    await request(h.app).post('/v1/auth/reset-password').send({ token, password: newPassword }).expect(204);

    for (const session of [account, laptop]) {
      expectError(await me(session), 401, 'unauthorized');
      expectError(await refresh(session.refreshToken!), 401, 'unauthorized');
    }
    expectError(await signIn(h, account.email), 401, 'unauthorized');
    await request(h.app).post('/v1/auth/login').send({ email: account.email, password: newPassword }).expect(200);

    const reused = await request(h.app).post('/v1/auth/reset-password').send({ token, password: 'yet another passphrase' });
    expectError(reused, 400, 'validation_failed');
  });

  it('only honours the newest link, and not after an hour', async () => {
    const account = await signUp(h);
    await request(h.app).post('/v1/auth/forgot-password').send({ email: account.email }).expect(202);
    const old = linkToken(h, account.email, 'reset');
    await request(h.app).post('/v1/auth/forgot-password').send({ email: account.email }).expect(202);
    const newest = linkToken(h, account.email, 'reset');
    expectError(
      await request(h.app).post('/v1/auth/reset-password').send({ token: old, password: 'a brand new passphrase' }),
      400,
      'validation_failed',
    );

    await h.db.collection('one_time_tokens').updateMany({ purpose: 'reset' }, { $set: { expiresAt: new Date(Date.now() - 1) } });
    expectError(
      await request(h.app).post('/v1/auth/reset-password').send({ token: newest, password: 'a brand new passphrase' }),
      400,
      'validation_failed',
    );
  });

  it('applies the password policy to the new password', async () => {
    const account = await signUp(h);
    await request(h.app).post('/v1/auth/forgot-password').send({ email: account.email }).expect(202);
    const token = linkToken(h, account.email, 'reset');
    expectError(await request(h.app).post('/v1/auth/reset-password').send({ token, password: '1234567890' }), 400, 'validation_failed');
  });
});

describe('the account', () => {
  it('reads and renames', async () => {
    const account = await signUp(h);
    const renamed = await request(h.app).patch('/v1/me').set(bearer(account)).send({ displayName: '  Abder  ' }).expect(200);
    expect((renamed.body as Me).displayName).toBe('Abder');
    const cleared = await request(h.app).patch('/v1/me').set(bearer(account)).send({ displayName: null }).expect(200);
    expect((cleared.body as Me).displayName).toBeNull();
    expectError(await request(h.app).patch('/v1/me').set(bearer(account)).send({ email: 'x@y.z' }), 400, 'validation_failed');
  });

  it('lists devices, marks the current one, and signs one out', async () => {
    const account = await signUp(h);
    const laptop = (await signIn(h, account.email, 'mobile', 'Laptop').expect(200)).body as AuthResult;

    const list = (await request(h.app).get('/v1/me/sessions').set(bearer(account)).expect(200)).body as SessionsResult;
    expect(list.sessions).toHaveLength(2);
    expect(list.sessions.filter((s) => s.current).map((s) => s.deviceName)).toEqual(['Pixel']);
    const other = list.sessions.find((s) => !s.current)!;
    expect(other.deviceName).toBe('Laptop');

    await request(h.app).delete(`/v1/me/sessions/${other.id}`).set(bearer(account)).expect(204);
    expectError(await me(laptop), 401, 'unauthorized');
    expectError(await refresh(laptop.refreshToken!), 401, 'unauthorized');

    expectError(await request(h.app).delete(`/v1/me/sessions/${other.id}`).set(bearer(account)), 404, 'not_found');
    expectError(await request(h.app).delete('/v1/me/sessions/not-an-id').set(bearer(account)), 400, 'validation_failed');
  });

  it("cannot see or sign out another account's devices", async () => {
    const alice = await signUp(h);
    const bob = await signUp(h);
    const aliceSessions = (await request(h.app).get('/v1/me/sessions').set(bearer(alice)).expect(200)).body as SessionsResult;
    const bobSessions = (await request(h.app).get('/v1/me/sessions').set(bearer(bob)).expect(200)).body as SessionsResult;
    expect(bobSessions.sessions.map((s) => s.id)).not.toContain(aliceSessions.sessions[0]!.id);

    expectError(
      await request(h.app).delete(`/v1/me/sessions/${aliceSessions.sessions[0]!.id}`).set(bearer(bob)),
      404,
      'not_found',
    );
    await me(alice).expect(200);
  });

  it('is deleted whole with the password, and nothing of another account goes with it (AC6)', async () => {
    const alice = await signUp(h);
    const bob = await signUp(h);
    const record = (uuid: string) => ({
      table: 'kv_settings',
      uuid,
      updatedAt: '2026-09-19T10:00:00.000Z',
      deletedAt: null,
      data: { key: uuid, valueJson: '"dark"', updatedAt: '2026-09-19T10:00:00.000Z' },
    });
    for (const account of [alice, bob]) {
      await request(h.app)
        .post('/v1/sync/push')
        .set(bearer(account))
        .send({ deviceId: 'phone', records: [record('themeMode')] })
        .expect(200);
    }

    expectError(
      await request(h.app).delete('/v1/me').set(bearer(alice)).send({ password: 'not my password' }),
      403,
      'forbidden',
    );
    await request(h.app).delete('/v1/me').set(bearer(alice)).send({ password }).expect(204);

    const aliceId = new ObjectId(alice.userId);
    for (const name of ['sessions', 'refresh_tokens', 'one_time_tokens', 'records']) {
      expect(await h.db.collection(name).countDocuments({ userId: aliceId }), name).toBe(0);
    }
    expect(await h.db.collection('users').countDocuments({ _id: aliceId })).toBe(0);
    expect(await h.db.collection('counters').countDocuments({ _id: aliceId })).toBe(0);

    expectError(await me(alice), 401, 'unauthorized');
    expectError(await refresh(alice.refreshToken), 401, 'unauthorized');
    expectError(await signIn(h, alice.email), 401, 'unauthorized');

    const bobPull = await request(h.app).get('/v1/sync/pull').set(bearer(bob)).expect(200);
    expect((bobPull.body as PullResult).records).toHaveLength(1);
    await me(bob).expect(200);

    // The address is free again.
    await request(h.app).post('/v1/auth/register').send({ email: alice.email, password }).expect(201);
  });
});
