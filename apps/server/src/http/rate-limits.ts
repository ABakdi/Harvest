import type { Request, Response } from 'express';
import { rateLimit, type Options, type RateLimitInfo } from 'express-rate-limit';
import { HttpError } from './errors.js';

export interface RateLimitSettings {
  /** Failed sign-ins per address per window ([[Accounts]]: five in fifteen minutes). */
  loginFailures: number;
  /** Everything else under /v1/auth that costs a hash or sends an email. */
  authRequests: number;
  /** Token refreshes; generous, because every tab of the web app refreshes. */
  refreshes: number;
  windowMs: number;
  /**
   * Sign-ups per address per hour. Sign-up is the one route that says an
   * address is taken ([[Accounts]] AC3), so it is the one kept tightest.
   */
  registrations: number;
  registrationWindowMs: number;
  /** Wrong passwords per account per window when deleting it. */
  deleteFailures: number;
  /** Sync requests (push and pull) per account per minute. */
  syncRequests: number;
  /** File requests per account per minute: a year of pictures comes down in batches. */
  fileRequests: number;
  /** Key-share and key-check requests per account per window. */
  syncKeyRequests: number;
  /**
   * Failed sign-ins per email per hour from one network (/24, /48): the
   * soft limit behind the per-address one. It is keyed by the network as
   * well as the email, so nobody can lock someone else out from one
   * machine (S6-03). Kept in Mongo, so a restart does not reset it.
   */
  emailLoginFailures: number;
  /** Failed sign-ins per email per hour from anywhere: the ceiling many networks share. */
  emailGlobalLoginFailures: number;
  emailWindowMs: number;
  /** Admin requests per account per window ([[Admin]]). */
  adminRequests: number;
  /** News fetches per address per window: a phone asks every few hours. */
  newsRequests: number;
  /** Reports of problems per network per hour, counted in memory only ([[Admin]]). */
  reports: number;
}

export const defaultRateLimits: RateLimitSettings = {
  loginFailures: 5,
  authRequests: 30,
  refreshes: 120,
  windowMs: 15 * 60_000,
  registrations: 5,
  registrationWindowMs: 60 * 60_000,
  deleteFailures: 5,
  syncRequests: 120,
  fileRequests: 300,
  syncKeyRequests: 60,
  emailLoginFailures: 20,
  emailGlobalLoginFailures: 200,
  emailWindowMs: 60 * 60_000,
  adminRequests: 300,
  newsRequests: 60,
  reports: 5,
};

function limiter(limit: number, windowMs: number, extra: Partial<Options> = {}) {
  return rateLimit({
    windowMs,
    limit,
    standardHeaders: 'draft-7',
    legacyHeaders: false,
    handler: (req, _res, next) => {
      const reset = (req as Request & { rateLimit?: RateLimitInfo }).rateLimit?.resetTime;
      const seconds = reset ? Math.max(1, Math.ceil((reset.getTime() - Date.now()) / 1000)) : Math.ceil(windowMs / 1000);
      next(new HttpError('rate_limited', 'Too many attempts; try again later', undefined, { 'Retry-After': String(seconds) }));
    },
    ...extra,
  });
}

/**
 * Keyed by the signed-in account rather than the address: behind
 * requireAuth, the account is who is asking, and one phone on a
 * carrier's shared address must not spend another's allowance.
 */
function byAccount(limit: number, windowMs: number, extra: Partial<Options> = {}) {
  return limiter(limit, windowMs, {
    keyGenerator: (_req: Request, res: Response) => {
      const auth = res.locals.auth;
      if (!auth) throw new Error('an account limiter used on a route without requireAuth');
      return auth.userId.toHexString();
    },
    ...extra,
  });
}

/**
 * The limiters, made per app, so each app (and each test) starts with a
 * clean count.
 *
 * Sign-in counts failures only: a person who types the right password
 * five times an hour is not an attack. It is keyed by address rather
 * than by email, so nobody can lock someone else out by guessing at
 * their account; the softer per-email count lives in Mongo
 * (`LoginFailuresRepository`).
 */
export function authLimiters(settings: RateLimitSettings) {
  return {
    login: limiter(settings.loginFailures, settings.windowMs, { skipSuccessfulRequests: true }),
    auth: limiter(settings.authRequests, settings.windowMs),
    // Every answer that could say whether an address is taken counts (201
    // and 409); a body that did not parse (400, a weak password retyped)
    // says nothing, and is let off.
    register: limiter(settings.registrations, settings.registrationWindowMs, {
      skipSuccessfulRequests: true,
      requestWasSuccessful: (_req, res) => res.statusCode === 400,
    }),
    refresh: limiter(settings.refreshes, settings.windowMs),
    deleteAccount: byAccount(settings.deleteFailures, settings.windowMs, { skipSuccessfulRequests: true }),
    sync: byAccount(settings.syncRequests, 60_000),
    files: byAccount(settings.fileRequests, 60_000),
    syncKey: byAccount(settings.syncKeyRequests, settings.windowMs),
    admin: byAccount(settings.adminRequests, settings.windowMs),
    news: limiter(settings.newsRequests, settings.windowMs),
    reports: limiter(settings.reports, 60 * 60_000),
  };
}

export type Limiters = ReturnType<typeof authLimiters>;
