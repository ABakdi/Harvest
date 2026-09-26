import { randomUUID } from 'node:crypto';
import type { AuthResult } from '@harvest/contracts';
import type { Express } from 'express';
import type { Db } from 'mongodb';
import request, { type Response } from 'supertest';
import { expect, inject } from 'vitest';
import { createApp } from '../src/app.js';
import { loadConfig } from '../src/config.js';
import { createRepositories, type Repositories } from '../src/db/index.js';
import { connectMongo } from '../src/db/mongo.js';
import type { RateLimitSettings } from '../src/http/rate-limits.js';
import { createLogger } from '../src/logger.js';
import { MemoryMailer } from '../src/mail/mailer.js';
import { ReleaseSource, type Fetch } from '../src/releases/github.js';

export const appOrigin = 'https://harvest.example';

export interface Harness {
  app: Express;
  db: Db;
  repos: Repositories;
  mailer: MemoryMailer;
  close(): Promise<void>;
}

export interface HarnessOptions {
  env?: Record<string, string>;
  rateLimits?: Partial<RateLimitSettings>;
  fetch?: Fetch;
  /** The assist's model, which is otherwise over the network. */
  assistFetch?: typeof fetch;
}

/**
 * A whole app on a fresh database of the shared mongod. Nothing is
 * mocked but the outside world: mail is kept in memory and GitHub is a
 * fetch the test hands in.
 */
export async function harness(options: HarnessOptions = {}): Promise<Harness> {
  const mongo = await connectMongo(inject('mongoUrl'), `harvest_test_${randomUUID().slice(0, 8)}`);
  const repos = await createRepositories(mongo.db);
  const config = await loadConfig({
    NODE_ENV: 'test',
    CORS_ORIGINS: appOrigin,
    APP_URL: appOrigin,
    ...options.env,
  });
  const mailer = new MemoryMailer();
  const app = createApp({
    config,
    db: mongo.db,
    repos,
    mailer,
    releases: new ReleaseSource({
      repo: config.githubRepo,
      fetch: options.fetch ?? (() => Promise.reject(new Error('no network in tests'))),
    }),
    logger: createLogger('silent'),
    ...(options.rateLimits ? { rateLimits: options.rateLimits } : {}),
    ...(options.assistFetch ? { assistFetch: options.assistFetch } : {}),
  });
  return {
    app,
    db: mongo.db,
    repos,
    mailer,
    close: async () => {
      await mongo.db.dropDatabase();
      await mongo.close();
    },
  };
}

export const password = 'correct horse battery';

export interface Account {
  email: string;
  accessToken: string;
  refreshToken: string;
  userId: string;
}

let counter = 0;
export function freshEmail(): string {
  counter += 1;
  return `farmer${counter}.${randomUUID().slice(0, 6)}@example.com`;
}

/** A signed-up account on the phone (tokens in the body), verified unless told otherwise. */
export async function signUp(h: Harness, options: { verify?: boolean; email?: string } = {}): Promise<Account> {
  const email = options.email ?? freshEmail();
  const res = await request(h.app)
    .post('/v1/auth/register')
    .send({ email, password, client: 'mobile', deviceName: 'Pixel' })
    .expect(201);
  const body = res.body as AuthResult;
  if (options.verify !== false) {
    await request(h.app)
      .post('/v1/auth/verify-email')
      .send({ token: linkToken(h, email, 'verify') })
      .expect(204);
  }
  return { email, accessToken: body.accessToken, refreshToken: body.refreshToken!, userId: body.user.id };
}

export function signIn(h: Harness, email: string, client: 'web' | 'mobile' = 'mobile', deviceName = 'Laptop') {
  return request(h.app).post('/v1/auth/login').send({ email, password, client, deviceName });
}

/** The token at the end of the newest emailed link of [purpose]. */
export function linkToken(h: Harness, email: string, purpose: 'verify' | 'reset'): string {
  const mail = h.mailer.last(email, purpose);
  expect(mail, `a ${purpose} email to ${email}`).toBeDefined();
  return decodeURIComponent(mail!.link.split('/').at(-1)!);
}

export const bearer = (account: { accessToken: string }) => ({ Authorization: `Bearer ${account.accessToken}` });

/** The refresh cookie's value from a response, if it set one. */
export function refreshCookieOf(res: Response): string | undefined {
  const header = res.headers['set-cookie'] as unknown as string[] | undefined;
  const cookie = header?.find((c) => c.startsWith('harvest_refresh='));
  const value = cookie?.split(';')[0]?.slice('harvest_refresh='.length);
  return value && value.length > 0 ? value : undefined;
}

export function expectError(res: Response, status: number, code: string): void {
  expect(res.status).toBe(status);
  expect(res.body).toMatchObject({ error: { code } });
  expect(typeof (res.body as { error: { message: unknown } }).error.message).toBe('string');
}
