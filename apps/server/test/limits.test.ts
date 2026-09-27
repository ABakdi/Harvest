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
    const lock = new KeyedMutex();
    const auth = new AuthService({
      repos: h.repos,
      mailer: h.mailer,
      logger: pino({ level: 'silent' }),
      keys: (await loadConfig({ NODE_ENV: 'test' })).jwt,
      appUrl: 'https://harvest.example',
      accountLock: lock,
    });

    let finish!: () => void;
    const pushing = lock.run(userId.toHexString(), () => new Promise<void>((resolve) => (finish = resolve)));
    const deleting = auth.deleteAccount(userId, password);
    await new Promise((resolve) => setTimeout(resolve, 300));
    // The push holds the account; nothing is gone yet.
    expect(await h.repos.users.findById(userId)).not.toBeNull();
    finish();
    await pushing;
    await deleting;
    expect(await h.repos.users.findById(userId)).toBeNull();
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
    await new Promise((resolve) => setTimeout(resolve, 50));
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
