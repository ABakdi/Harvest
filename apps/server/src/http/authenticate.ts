import type { RequestHandler, Response } from 'express';
import type { AccessClaims } from '../auth/tokens.js';
import type { AuthService } from '../auth/service.js';
import type { UsersRepository } from '../db/users.js';
import { HttpError, unauthorized } from './errors.js';

declare global {
  // eslint-disable-next-line @typescript-eslint/no-namespace
  namespace Express {
    interface Locals {
      auth?: AccessClaims;
      input?: unknown;
    }
  }
}

/**
 * Requires a valid access token (ADR-011 rule 1). The user id comes from
 * the token, never from the body.
 */
export function requireAuth(auth: AuthService): RequestHandler {
  return async (req, res, next) => {
    const header = req.get('authorization') ?? '';
    const match = /^Bearer\s+(\S+)$/i.exec(header);
    if (!match?.[1]) throw unauthorized('Missing access token');
    const claims = await auth.authenticate(match[1]);
    if (!claims) throw unauthorized('Invalid or expired access token');
    res.locals.auth = claims;
    next();
  };
}

/**
 * Sync is for verified accounts only: a mistyped address must not
 * quietly own my data ([[Accounts]]).
 */
export function requireVerified(users: UsersRepository): RequestHandler {
  return async (_req, res, next) => {
    const user = await users.findById(authOf(res).userId);
    if (!user) throw unauthorized();
    if (user.verifiedAt === null) throw new HttpError('forbidden', 'Confirm your email before syncing');
    next();
  };
}

/** The caller, on a route behind [requireAuth]. */
export function authOf(res: Response): AccessClaims {
  const auth = res.locals.auth;
  if (!auth) throw new Error('authOf used on a route without requireAuth');
  return auth;
}
