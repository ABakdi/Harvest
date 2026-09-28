import { Writable } from 'node:stream';
import type { AuthResult } from '@harvest/contracts';
import { ObjectId } from 'mongodb';
import { pino } from 'pino';
import request from 'supertest';
import { afterEach, describe, expect, it } from 'vitest';
import { hashing, maxConcurrentHashes, maxWaitingHashes, verifyPassword } from '../src/auth/passwords.js';
import { AuthService } from '../src/auth/service.js';
import { loadConfig } from '../src/config.js';
import { transportOptions } from '../src/mail/smtp.js';
import { KeyedMutex } from '../src/sync/mutex.js';
import {
  bearer,
  expectError,
  freshEmail,
  harness,
  password,
  signIn,
  signUp,
  type Harness,
} from './harness.js';

let h: Harness | undefined;
afterEach(async () => {
  await h?.close();
  h = undefined;
});

const register = (app: Harness['app'], email: string, pass = password) =>
  request(app).post('/v1/auth/register').send({ email, password: pass, client: 'mobile' });

describe('sign-up (audit S5-05)', () => {
  it('allows a few sign-ups an hour from one address, taken or not', async () => {
    h = await harness({ rateLimits: { registrations: 2 } });
    const email = freshEmail();
    await register(h.app, email).expect(201);
    expectError(await register(h.app, email), 409, 'conflict');
    const blocked = await register(h.app, freshEmail());
    expectError(blocked, 429, 'rate_limited');
    expect(Number(blocked.headers['retry-after'])).toBeGreaterThan(0);
  });

  it('does not count a body that did not parse', async () => {
    h = await harness({ rateLimits: { registrations: 1 } });
    for (let i = 0; i < 3; i += 1) {
      expectError(await register(h.app, freshEmail(), 'password'), 400, 'validation_failed');
    }
    await register(h.app, freshEmail()).expect(201);
  });
});

describe('sign-in per email (audit S5-06)', () => {
  it('slows many addresses guessing at one account, and keeps no address', async () => {
    h = await harness({ rateLimits: { emailLoginFailures: 3, loginFailures: 1000 } });
    const account = await signUp(h);
    const wrong = () => request(h!.app).post('/v1/auth/login').send({ email: account.email, password: 'wrong wrong' });
    for (let i = 0; i < 3; i += 1) expectError(await wrong(), 401, 'unauthorized');

    // Even the right password waits: the hash is not run at all.
    const blocked = await signIn(h, account.email);
    expectError(blocked, 429, 'rate_limited');
    expect(Number(blocked.headers['retry-after'])).toBeGreaterThan(3000);

    // Another account is not held up, and an unknown address counts alike.
    const other = await signUp(h);
    await signIn(h, other.email).expect(200);
    const nobody = freshEmail();
    for (let i = 0; i < 3; i += 1) {
      expectError(await request(h.app).post('/v1/auth/login').send({ email: nobody, password }), 401, 'unauthorized');
    }
    expectError(await request(h.app).post('/v1/auth/login').send({ email: nobody, password }), 429, 'rate_limited');

    const kept = JSON.stringify(await h.db.collection('login_failures').find().toArray());
    expect(kept).not.toContain(account.email);
    expect(kept).not.toContain(nobody);
  });

  it('forgets the failures once the right password comes', async () => {
    h = await harness({ rateLimits: { emailLoginFailures: 3, loginFailures: 1000 } });
    const account = await signUp(h);
    const wrong = () => request(h!.app).post('/v1/auth/login').send({ email: account.email, password: 'wrong wrong' });
    await wrong().expect(401);
    await wrong().expect(401);
    await signIn(h, account.email).expect(200);
    await wrong().expect(401);
    await wrong().expect(401);
    await signIn(h, account.email).expect(200);
  });
});

describe('deleting the account (audit S5-03, Q5-56)', () => {
  it('counts wrong passwords per account', async () => {
    h = await harness({ rateLimits: { deleteFailures: 2 } });
    const account = await signUp(h);
    const del = (pass: string) => request(h!.app).delete('/v1/me').set(bearer(account)).send({ password: pass });
    expectError(await del('not my password'), 403, 'forbidden');
    expectError(await del('not my password'), 403, 'forbidden');
    expectError(await del(password), 429, 'rate_limited');

    // Another device of the same account is the same account.
    const laptop = (await signIn(h, account.email).expect(200)).body as AuthResult;
    expectError(
      await request(h.app).delete('/v1/me').set(bearer(laptop)).send({ password }),
      429,
      'rate_limited',
    );
  });

  it('waits for a push already running before it deletes', async () => {
    h = await harness();
    const account = await signUp(h);
    const userId = new ObjectId(account.userId);
    // The lock, watched: the delete is known to be queued, not guessed
    // to be after a pause.
    let queued!: () => void;
    const deleteQueued = new Promise<void>((resolve) => (queued = resolve));
    const lock = new (class extends KeyedMutex {
      override run<T>(key: string, task: () => Promise<T>): Promise<T> {
        const running = super.run(key, task);
        queued();
        return running;
      }
    })();
    const auth = new AuthService({
      repos: h.repos,
      mailer: h.mailer,
      logger: pino({ level: 'silent' }),
      keys: (await loadConfig({ NODE_ENV: 'test' })).jwt,
      appUrl: 'https://harvest.example',
      accountLock: lock,
    });

    let finish!: () => void;
    const holding = new Promise<void>((resolve) => (finish = resolve));
    const pushing = KeyedMutex.prototype.run.call(lock, userId.toHexString(), () => holding);
    const deleting = auth.deleteAccount(userId, password);
    await deleteQueued;
    // The push holds the account; nothing is gone yet.
    expect(await h.repos.users.findById(userId)).not.toBeNull();
    finish();
    await pushing;
    await deleting;
    expect(await h.repos.users.findById(userId)).toBeNull();
  });
});

describe('the account lock (Q6-17)', () => {
  it('tells a waiter to come back rather than hang behind a stuck task', async () => {
    const lock = new KeyedMutex(30);
    let finish!: () => void;
    const stuck = lock.run('a', () => new Promise<void>((resolve) => (finish = resolve)));
    await expect(lock.run('a', () => Promise.resolve('never'))).rejects.toMatchObject({
      code: 'rate_limited',
      headers: { 'Retry-After': '5' },
    });
    // Another account is not held up by it.
    expect(await lock.run('b', () => Promise.resolve('b'))).toBe('b');

    finish();
    await stuck;
    expect(await lock.run('a', () => Promise.resolve('free'))).toBe('free');
  });

  it('keeps later waiters behind a stuck task after one gave up', async () => {
    const lock = new KeyedMutex(30);
    let finish!: () => void;
    let stuckDone = false;
    const stuck = lock.run('a', () =>
      new Promise<void>((resolve) => (finish = resolve)).then(() => {
        stuckDone = true;
      }),
    );
    const gaveUp = lock.run('a', () => Promise.resolve());
    await expect(gaveUp).rejects.toMatchObject({ code: 'rate_limited' });
    let ranEarly = false;
    const late = lock.run('a', () => {
      ranEarly = !stuckDone;
      return Promise.resolve();
    });
    finish();
    await stuck;
    await late.catch(() => undefined);
    expect(ranEarly).toBe(false);
  });
});

describe('argon2 at once (audit S5-03)', () => {
  it('runs a few hashes at a time and turns away a crowd', async () => {
    const hash = await (await import('argon2')).default.hash('x'.repeat(12));
    let peak = 0;
    const watch = setInterval(() => (peak = Math.max(peak, hashing.load.running)), 1);
    const results = await Promise.allSettled(
      Array.from({ length: maxConcurrentHashes + maxWaitingHashes + 8 }, () => verifyPassword(hash, 'wrong')),
    );
    clearInterval(watch);
    expect(peak).toBeLessThanOrEqual(maxConcurrentHashes);
    const refused = results.filter((r) => r.status === 'rejected');
    expect(refused.length).toBeGreaterThanOrEqual(8);
    expect((refused[0] as PromiseRejectedResult).reason).toMatchObject({ code: 'rate_limited' });
    expect(hashing.load).toEqual({ running: 0, waiting: 0 });
  });
});

describe('bodies (audit S5-07)', () => {
  it('refuses a key the contract does not name', async () => {
    h = await harness();
    const account = await signUp(h);
    expectError(
      await request(h.app).post('/v1/auth/login').send({ email: account.email, password, admin: true }),
      400,
      'validation_failed',
    );
  });

  it('reads at most 16 kB before sign-in, and nothing of the assist before the token', async () => {
    h = await harness();
    expectError(
      await request(h.app).post('/v1/auth/logout').send({ refreshToken: 'x', pad: 'y'.repeat(20_000) }),
      413,
      'payload_too_large',
    );
    const res = await request(h.app)
      .post('/v1/assist')
      .set('Content-Type', 'application/json')
      .send(`{"text":"${'z'.repeat(2_000_000)}`);
    expectError(res, 401, 'unauthorized');
  });
});

describe('mail (audit S5-13, S5-20)', () => {
  const smtp = { host: 'smtp.example', port: 587, secure: false, allowPlaintext: false, user: undefined, pass: undefined };

  it('requires STARTTLS on a plain port unless told a relay is local', () => {
    expect(transportOptions(smtp)).toMatchObject({ requireTLS: true, tls: { minVersion: 'TLSv1.2' } });
    expect(transportOptions({ ...smtp, port: 465, secure: true })).toMatchObject({ requireTLS: false });
    expect(transportOptions({ ...smtp, allowPlaintext: true })).toMatchObject({ requireTLS: false });
  });

  it('logs a failed mail by its codes, never its address', async () => {
    h = await harness();
    const account = await signUp(h);
    const lines: string[] = [];
    const logger = pino(
      { level: 'error' },
      new Writable({
        write(chunk: Buffer, _encoding, done) {
          lines.push(chunk.toString());
          done();
        },
      }),
    );
    const failure = Object.assign(new Error(`Recipient rejected: ${account.email}`), {
      code: 'EENVELOPE',
      responseCode: 550,
      rejected: [account.email],
    });
    const auth = new AuthService({
      repos: h.repos,
      mailer: { send: () => Promise.reject(failure) },
      logger,
      keys: (await loadConfig({ NODE_ENV: 'test' })).jwt,
      appUrl: 'https://harvest.example',
    });
    await auth.forgotPassword(account.email);
    await auth.settled();
    expect(lines).toHaveLength(1);
    expect(lines[0]).toContain('EENVELOPE');
    expect(lines[0]).toContain('550');
    expect(lines[0]).not.toContain(account.email);
  });
});

describe('config', () => {
  it('refuses production without a key-share key, or with one of the wrong size', async () => {
    const { generateKeyPairSync } = await import('node:crypto');
    const { privateKey, publicKey } = generateKeyPairSync('ed25519');
    const production = {
      NODE_ENV: 'production',
      MONGO_URL: 'mongodb://db/harvest',
      JWT_PRIVATE_KEY: privateKey.export({ type: 'pkcs8', format: 'pem' }).toString(),
      JWT_PUBLIC_KEY: publicKey.export({ type: 'spki', format: 'pem' }).toString(),
      SMTP_HOST: 'smtp.example',
    };
    await expect(loadConfig(production)).rejects.toThrow(/KEY_SHARE_KEY/);
    await expect(loadConfig({ ...production, KEY_SHARE_KEY: Buffer.alloc(16).toString('base64') })).rejects.toThrow(
      /KEY_SHARE_KEY/,
    );
    const key = Buffer.alloc(32, 9);
    const config = await loadConfig({
      ...production,
      KEY_SHARE_KEY: key.toString('base64'),
      SMTP_ALLOW_PLAINTEXT: 'true',
      ASSIST_GLOBAL_DAILY_LIMIT: '7',
    });
    expect(config.keyShareKey.equals(key)).toBe(true);
    expect(config.smtp).toMatchObject({ allowPlaintext: true });
    expect(config.assist.globalDailyLimit).toBe(7);
  });

  it('seals with a fixed key outside production, so a laptop survives a restart', async () => {
    const one = await loadConfig({ NODE_ENV: 'development' });
    const two = await loadConfig({ NODE_ENV: 'test' });
    expect(one.keyShareKey.equals(two.keyShareKey)).toBe(true);
    expect(one.keyShareKey).toHaveLength(32);
  });
});

describe('sign-in per email and network (S6-03)', () => {
  const from = (network: string) => ({ 'X-Forwarded-For': network });

  it('lets one network lock the email out only for itself, under a higher ceiling for all', async () => {
    h = await harness({
      env: { TRUST_PROXY: '1' },
      rateLimits: { emailLoginFailures: 3, emailGlobalLoginFailures: 7, loginFailures: 1000 },
    });
    const account = await signUp(h);
    const attempt = (ip: string, pass = 'wrong wrong') =>
      request(h!.app).post('/v1/auth/login').set(from(ip)).send({ email: account.email, password: pass, client: 'mobile' });

    // Three wrong from one /24 (any address in it) block that /24...
    for (const ip of ['203.0.113.5', '203.0.113.77', '203.0.113.200']) expectError(await attempt(ip), 401, 'unauthorized');
    expectError(await attempt('203.0.113.9', password), 429, 'rate_limited');
    // ...and nobody else: the owner signs in from home.
    await attempt('198.51.100.20', password).expect(200);

    // Many networks together reach the ceiling for the email everywhere.
    for (const ip of ['192.0.2.1', '192.0.2.2', '192.0.2.3', '100.64.1.1', '100.64.1.2', '100.64.1.3', '100.65.1.1']) {
      await attempt(ip);
    }
    expectError(await attempt('198.51.100.20', password), 429, 'rate_limited');
    // IPv6: one /48 is one network.
    expect((await attempt('2001:db8:1:1::1')).status).toBe(429);
  });

  it('clears every count of the email with a password reset', async () => {
    h = await harness({ env: { TRUST_PROXY: '1' }, rateLimits: { emailLoginFailures: 2, loginFailures: 1000 } });
    const account = await signUp(h);
    const attempt = (pass: string) =>
      request(h!.app).post('/v1/auth/login').set(from('203.0.113.5')).send({ email: account.email, password: pass });
    await attempt('wrong wrong').expect(401);
    await attempt('wrong wrong').expect(401);
    expectError(await attempt(password), 429, 'rate_limited');

    await request(h.app).post('/v1/auth/forgot-password').send({ email: account.email }).expect(202);
    await h.settled();
    const token = decodeURIComponent(h.mailer.last(account.email, 'reset')!.link.split('/').at(-1)!);
    await request(h.app).post('/v1/auth/reset-password').send({ token, password: 'a brand new passphrase' }).expect(204);
    await attempt('a brand new passphrase').expect(200);
  });

  it('reads networks the way a limit should', async () => {
    const { networkOf } = await import('../src/http/ip.js');
    expect(networkOf('203.0.113.77')).toBe('203.0.113.0/24');
    expect(networkOf('::ffff:203.0.113.77')).toBe('203.0.113.0/24');
    expect(networkOf('2001:db8:1:ff::1')).toBe('2001:db8:1::/48');
    expect(networkOf('2001:0db8:0001::')).toBe('2001:db8:1::/48');
    expect(networkOf('::1')).toBe('0:0:0::/48');
    expect(networkOf(undefined)).toBe('unknown');
  });
});

describe('the emailed flows (S6-10, S6-14)', () => {
  it('answers before looking anything up, and mails after', async () => {
    h = await harness();
    const account = await signUp(h);
    const before = h.mailer.sent.length;
    await request(h.app).post('/v1/auth/forgot-password').send({ email: account.email }).expect(202);
    // The answer is out; the lookup and the mail come after it.
    expect(h.mailer.sent.length).toBe(before);
    await h.settled();
    expect(h.mailer.sent.length).toBe(before + 1);
  });

  it('sends at most three mails an hour to one address, silently', async () => {
    let clock = Date.now();
    h = await harness({ now: () => new Date(clock) });
    // Sign-up's own verification mail is the first of the three.
    const account = await signUp(h, { verify: false });
    await h.settled();
    // Each one's mail work done before the next is asked: the work runs
    // after the answer, and eight at once would race for the two mails
    // left, so which kind got them (a reset or not) would be chance.
    for (let i = 0; i < 4; i += 1) {
      await request(h.app).post('/v1/auth/forgot-password').send({ email: account.email }).expect(202);
      await h.settled();
      await request(h.app).post('/v1/auth/resend-verification').send({ email: account.email }).expect(202);
      await h.settled();
    }
    expect(h.mailer.sent.filter((m) => m.to === account.email)).toHaveLength(3);
    // The first reset link still works: the refused ones changed nothing.
    const reset = h.mailer.last(account.email, 'reset')!;
    const token = decodeURIComponent(reset.link.split('/').at(-1)!);
    clock += 61 * 60_000;
    await request(h.app).post('/v1/auth/forgot-password').send({ email: account.email }).expect(202);
    await h.settled();
    expect(h.mailer.sent.filter((m) => m.to === account.email)).toHaveLength(4);
    // A newer link replaced it, as always.
    expectError(await request(h.app).post('/v1/auth/reset-password').send({ token, password: 'a brand new passphrase' }), 400, 'validation_failed');
  });
});

describe('windowed counts under load (S6-14)', () => {
  it('lets exactly the maximum through when many take at once, in a fresh window and a rolled one', async () => {
    h = await harness();
    const windows = [
      { max: 3, ms: 60 * 60_000 },
      { max: 10, ms: 24 * 60 * 60_000 },
    ];
    const at = new Date();
    const burst = (now: Date) =>
      Promise.all(Array.from({ length: 40 }, () => h!.repos.windowedCounts.take('burst', windows, now)));
    expect((await burst(at)).filter((r) => r.ok)).toHaveLength(3);
    // The hour is over: the first window starts again, the day's goes on.
    const later = new Date(at.getTime() + 61 * 60_000);
    expect((await burst(later)).filter((r) => r.ok)).toHaveLength(3);
    const doc = await h.db.collection('windowed_counts').findOne({ _id: 'burst' as never });
    expect((doc!.windows as { count: number }[]).map((w) => w.count)).toEqual([3, 6]);
  });
});

describe('sign-out with an old token (S6-15)', () => {
  it('ends the session only for the current token, or one exchanged moments ago', async () => {
    let clock = Date.now();
    h = await harness({ now: () => new Date(clock) });
    const account = await signUp(h);
    const refresh = (token: string) => request(h!.app).post('/v1/auth/refresh').send({ refreshToken: token });
    const rotated = (await refresh(account.refreshToken).expect(200)).body as AuthResult;
    clock += 60_000;
    // An old token from a log: nothing happens.
    await request(h.app).post('/v1/auth/logout').send({ refreshToken: account.refreshToken }).expect(204);
    await request(h.app).get('/v1/me').set(bearer(rotated)).expect(200);
    // The current one signs the device out.
    await request(h.app).post('/v1/auth/logout').send({ refreshToken: rotated.refreshToken }).expect(204);
    expectError(await request(h.app).get('/v1/me').set(bearer(rotated)), 401, 'unauthorized');
  });
});

describe('caching (S6-01)', () => {
  it('lets no API answer be cached, and clears the cache at sign-out', async () => {
    h = await harness({ fetch: () => Promise.reject(new Error('offline')) });
    const account = await signUp(h);
    for (const path of ['/v1/me', '/v1/me/sessions', '/v1/sync/pull', '/v1/health', '/v1/nowhere']) {
      const res = await request(h.app).get(path).set(bearer(account));
      expect(res.headers['cache-control'], path).toBe('no-store');
    }
    expect((await request(h.app).get('/v1/me')).headers['cache-control']).toBe('no-store');
    const out = await request(h.app).post('/v1/auth/logout').send({}).expect(204);
    expect(out.headers['clear-site-data']).toBe('"cache"');
  });
});
