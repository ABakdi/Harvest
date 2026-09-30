import {
  heartbeatBodySchema,
  pushSubscriptionBodySchema,
  pushUnsubscribeBodySchema,
  deleteMeBodySchema,
  patchMeBodySchema,
  reauthBodySchema,
  sessionParamsSchema,
  type SessionsResult,
} from '@harvest/contracts';
import { Router } from 'express';
import { ObjectId } from 'mongodb';
import { toMe, toSession, type AuthService } from '../auth/service.js';
import type { Repositories } from '../db/index.js';
import { authOf } from '../http/authenticate.js';
import { HttpError, unauthorized } from '../http/errors.js';
import { validated } from '../http/validate.js';
import { startOfUtcDay } from '../db/admin-stats.js';
import type { Limiters } from '../http/rate-limits.js';
import { clearRefreshCookies, type CookiePolicy } from './auth.js';

/** The account and its devices. Mounted behind requireAuth. */
export function meRoutes(auth: AuthService, repos: Repositories, policy: CookiePolicy, limits: Limiters): Router {
  const router = Router();

  router.get('/', async (_req, res) => {
    const user = await auth.me(authOf(res).userId);
    res.json(toMe(user, auth.isAdmin(user)));
  });

  router.patch(
    '/',
    ...validated({ body: patchMeBodySchema }, async ({ body }, _req, res) => {
      const { userId } = authOf(res);
      const user =
        body.displayName === undefined
          ? await auth.me(userId)
          : await repos.users.setDisplayName(userId, body.displayName);
      if (!user) throw unauthorized();
      res.json(toMe(user, auth.isAdmin(user)));
    }),
  );

  // A wrong password here is a guess like any other, and an argon2 run
  // like any other: counted per account, successes let off (S5-03).
  router.delete(
    '/',
    limits.deleteAccount,
    ...validated({ body: deleteMeBodySchema }, async ({ body }, _req, res) => {
      await auth.deleteAccount(authOf(res).userId, body.password);
      clearRefreshCookies(res, policy);
      res.status(204).end();
    }),
  );

  // The password again before an export (Phase 7, M7.6): the same
  // guesses, counted against the same limit as deleting the account.
  router.post(
    '/reauth',
    limits.deleteAccount,
    ...validated({ body: reauthBodySchema }, async ({ body }, _req, res) => {
      await auth.reauth(authOf(res).userId, body.password);
      res.status(204).end();
    }),
  );

  // The daily heartbeat ([[Admin]]): the latest platform, version and
  // shared streak, and the first of a day counted once in the day's totals.
  router.post(
    '/heartbeat',
    ...validated({ body: heartbeatBodySchema }, async ({ body }, _req, res) => {
      const at = new Date();
      const { found, lastActiveAt } = await repos.users.heartbeat(authOf(res).userId, body, at);
      if (!found) throw unauthorized();
      if (!lastActiveAt || lastActiveAt < startOfUtcDay(at)) await repos.adminStats.countActive(at);
      res.status(204).end();
    }),
  );

  // A browser's Web Push subscription, kept for this account.
  router.post(
    '/push-subscription',
    ...validated({ body: pushSubscriptionBodySchema }, async ({ body }, _req, res) => {
      await repos.pushSubscriptions.save(authOf(res).userId, body.endpoint, body.keys, new Date());
      res.status(204).end();
    }),
  );

  router.delete(
    '/push-subscription',
    ...validated({ body: pushUnsubscribeBodySchema }, async ({ body }, _req, res) => {
      await repos.pushSubscriptions.remove(authOf(res).userId, body.endpoint);
      res.status(204).end();
    }),
  );

  router.get('/sessions', async (_req, res) => {
    const { userId, sessionId } = authOf(res);
    const sessions = await repos.sessions.listLive(userId, new Date());
    const body: SessionsResult = { sessions: sessions.map((s) => toSession(s, sessionId)) };
    res.json(body);
  });

  router.delete(
    '/sessions/:id',
    ...validated({ params: sessionParamsSchema }, async ({ params }, _req, res) => {
      const revoked = await repos.sessions.revoke(authOf(res).userId, new ObjectId(params.id), new Date());
      if (!revoked) throw new HttpError('not_found', 'No such session');
      res.status(204).end();
    }),
  );

  return router;
}
