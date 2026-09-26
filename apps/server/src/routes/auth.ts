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
import { unauthorized } from '../http/errors.js';
import type { authLimiters } from '../http/rate-limits.js';
import { validated } from '../http/validate.js';

export const refreshCookie = 'harvest_refresh';

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

function answer(res: Response, signedIn: SignedIn, policy: CookiePolicy, status = 200): void {
  const body: AuthResult = {
    accessToken: signedIn.accessToken,
    expiresIn: signedIn.expiresIn,
    user: signedIn.user,
  };
  if (signedIn.client === 'mobile') {
    body.refreshToken = signedIn.refreshToken;
  } else {
    res.cookie(refreshCookie, signedIn.refreshToken, { ...cookieOptions(policy), maxAge: refreshTokenMs });
  }
  res.status(status).json(body);
}

/** The phone sends its token in the body; the web's comes in the cookie. */
function presentedToken(req: Request, fromBody: string | undefined): string | undefined {
  if (fromBody) return fromBody;
  const cookies = req.cookies as Record<string, unknown> | undefined;
  const cookie = cookies?.[refreshCookie];
  return typeof cookie === 'string' && cookie.length > 0 ? cookie : undefined;
}

export function authRoutes(
  auth: AuthService,
  limits: ReturnType<typeof authLimiters>,
  policy: CookiePolicy,
): Router {
  const router = Router();

  router.post(
    '/register',
    limits.auth,
    ...validated({ body: registerBodySchema }, async ({ body }, _req, res) => {
      answer(res, await auth.register(body), policy, 201);
    }),
  );

  router.post(
    '/login',
    limits.login,
    ...validated({ body: loginBodySchema }, async ({ body }, _req, res) => {
      answer(res, await auth.login(body), policy);
    }),
  );

  router.post(
    '/refresh',
    limits.refresh,
    ...validated({ body: refreshBodySchema }, async ({ body }, req, res) => {
      const token = presentedToken(req, body.refreshToken);
      if (!token) throw unauthorized('Missing refresh token');
      try {
        answer(res, await auth.refresh(token), policy);
      } catch (error) {
        // A refresh that fails leaves a dead cookie behind otherwise.
        res.clearCookie(refreshCookie, cookieOptions(policy));
        throw error;
      }
    }),
  );

  router.post(
    '/logout',
    ...validated({ body: logoutBodySchema }, async ({ body }, req, res) => {
      const token = presentedToken(req, body.refreshToken);
      if (token) await auth.logout(token);
      res.clearCookie(refreshCookie, cookieOptions(policy));
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
      res.clearCookie(refreshCookie, cookieOptions(policy));
      res.status(204).end();
    }),
  );

  return router;
}

export { cookieOptions };
