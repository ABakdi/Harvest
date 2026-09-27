import {
  forgotPasswordBodySchema,
  loginBodySchema,
  logoutBodySchema,
  refreshBodySchema,
  registerBodySchema,
  resendVerificationBodySchema,
  resetPasswordBodySchema,
  verifyEmailBodySchema,
  type AuthResult,
} from '@harvest/contracts';
import { Router, type CookieOptions, type Request, type Response } from 'express';
import { refreshTokenMs, type AuthService, type SignedIn } from '../auth/service.js';
import { HttpError, unauthorized } from '../http/errors.js';
import type { Limiters } from '../http/rate-limits.js';
import { validated } from '../http/validate.js';

/**
 * The refresh cookie's name. Where it is Secure it carries the
 * `__Secure-` prefix, which a browser only accepts from https with the
 * Secure flag, so no page on plain http can plant one (audit S5-20).
 * The web never reads it (it is HttpOnly), so the name is the server's
 * alone; the old one is still read, and cleared, so nobody is signed
 * out by the change.
 */
export const legacyRefreshCookie = 'harvest_refresh';
export const secureRefreshCookie = '__Secure-harvest_refresh';

export function refreshCookieName(policy: CookiePolicy): string {
  return policy.secure ? secureRefreshCookie : legacyRefreshCookie;
}

export interface CookiePolicy {
  secure: boolean;
}

/**
 * The web's refresh token lives in a cookie no script can read, sent
 * only to the auth routes and only from Harvest's own pages. The access
 * token lives in memory, so nothing that survives a reload is readable.
 */
function cookieOptions(policy: CookiePolicy): CookieOptions {
  return { httpOnly: true, secure: policy.secure, sameSite: 'strict', path: '/v1/auth' };
}

/** Clears the refresh cookie under both its names. */
export function clearRefreshCookies(res: Response, policy: CookiePolicy): void {
  res.clearCookie(refreshCookieName(policy), cookieOptions(policy));
  if (refreshCookieName(policy) !== legacyRefreshCookie) {
    res.clearCookie(legacyRefreshCookie, cookieOptions(policy));
  }
}

function answer(res: Response, signedIn: SignedIn, policy: CookiePolicy, status = 200, req?: Request): void {
  const body: AuthResult = {
    accessToken: signedIn.accessToken,
    expiresIn: signedIn.expiresIn,
    user: signedIn.user,
  };
  if (signedIn.client === 'mobile') {
    body.refreshToken = signedIn.refreshToken;
  } else {
    res.cookie(refreshCookieName(policy), signedIn.refreshToken, { ...cookieOptions(policy), maxAge: refreshTokenMs });
    // Moved to the new name: the old cookie goes.
    const cookies = req?.cookies as Record<string, unknown> | undefined;
    if (refreshCookieName(policy) !== legacyRefreshCookie && cookies?.[legacyRefreshCookie] !== undefined) {
      res.clearCookie(legacyRefreshCookie, cookieOptions(policy));
    }
  }
  res.status(status).json(body);
}

/** The phone sends its token in the body; the web's comes in the cookie. */
function presentedToken(req: Request, fromBody: string | undefined): string | undefined {
  if (fromBody) return fromBody;
  const cookies = req.cookies as Record<string, unknown> | undefined;
  for (const name of [secureRefreshCookie, legacyRefreshCookie]) {
    const cookie = cookies?.[name];
    if (typeof cookie === 'string' && cookie.length > 0) return cookie;
  }
  return undefined;
}

export function authRoutes(auth: AuthService, limits: Limiters, policy: CookiePolicy): Router {
  const router = Router();

  // Sign-up says whether an address is taken (409), the one route that
  // does ([[Accounts]] AC3): it has a limit of its own, much tighter than
  // the rest.
  router.post(
    '/register',
    limits.register,
    limits.auth,
    ...validated({ body: registerBodySchema }, async ({ body }, req, res) => {
      answer(res, await auth.register(body), policy, 201, req);
    }),
  );

  router.post(
    '/login',
    limits.login,
    ...validated({ body: loginBodySchema }, async ({ body }, req, res) => {
      answer(res, await auth.login(body), policy, 200, req);
    }),
  );

  router.post(
    '/refresh',
    limits.refresh,
    ...validated({ body: refreshBodySchema }, async ({ body }, req, res) => {
      const token = presentedToken(req, body.refreshToken);
      if (!token) throw unauthorized('Missing refresh token');
      try {
        answer(res, await auth.refresh(token), policy, 200, req);
      } catch (error) {
        // A refresh the session refused leaves a dead cookie behind
        // otherwise. Anything else (the database away for a moment) is
        // not the session's end, and the cookie stays for the next try
        // (Q5-15).
        if (error instanceof HttpError && error.code === 'unauthorized') clearRefreshCookies(res, policy);
        throw error;
      }
    }),
  );

  router.post(
    '/logout',
    ...validated({ body: logoutBodySchema }, async ({ body }, req, res) => {
      const token = presentedToken(req, body.refreshToken);
      if (token) await auth.logout(token);
      clearRefreshCookies(res, policy);
      res.status(204).end();
    }),
  );

  router.post(
    '/verify-email',
    limits.auth,
    ...validated({ body: verifyEmailBodySchema }, async ({ body }, _req, res) => {
      await auth.verifyEmail(body.token);
      res.status(204).end();
    }),
  );

  // Both answer 202 whether or not the address has an account (AC3).
  router.post(
    '/resend-verification',
    limits.auth,
    ...validated({ body: resendVerificationBodySchema }, async ({ body }, _req, res) => {
      await auth.resendVerification(body.email);
      res.status(202).end();
    }),
  );

  router.post(
    '/forgot-password',
    limits.auth,
    ...validated({ body: forgotPasswordBodySchema }, async ({ body }, _req, res) => {
      await auth.forgotPassword(body.email);
      res.status(202).end();
    }),
  );

  router.post(
    '/reset-password',
    limits.auth,
    ...validated({ body: resetPasswordBodySchema }, async ({ body }, _req, res) => {
      await auth.resetPassword(body.token, body.password);
      clearRefreshCookies(res, policy);
      res.status(204).end();
    }),
  );

  return router;
}

export { cookieOptions };
