import type { Request } from 'express';
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
}

export const defaultRateLimits: RateLimitSettings = {
  loginFailures: 5,
  authRequests: 30,
  refreshes: 120,
  windowMs: 15 * 60_000,
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
 * The auth limiters, keyed by the client's address. Made per app, so
 * each app (and each test) starts with a clean count.
 *
 * Sign-in counts failures only: a person who types the right password
 * five times an hour is not an attack. It is keyed by address rather
 * than by email, so nobody can lock someone else out by guessing at
 * their account.
 */
export function authLimiters(settings: RateLimitSettings) {
  return {
    login: limiter(settings.loginFailures, settings.windowMs, { skipSuccessfulRequests: true }),
    auth: limiter(settings.authRequests, settings.windowMs),
    refresh: limiter(settings.refreshes, settings.windowMs),
  };
}
