import { deleteMeBodySchema, patchMeBodySchema, sessionParamsSchema, type SessionsResult } from '@harvest/contracts';
import { Router } from 'express';
import { ObjectId } from 'mongodb';
import { toMe, toSession, type AuthService } from '../auth/service.js';
import type { Repositories } from '../db/index.js';
import { authOf } from '../http/authenticate.js';
import { HttpError, unauthorized } from '../http/errors.js';
import { validated } from '../http/validate.js';
import { cookieOptions, refreshCookie, type CookiePolicy } from './auth.js';

/** The account and its devices. Mounted behind requireAuth. */
export function meRoutes(auth: AuthService, repos: Repositories, policy: CookiePolicy): Router {
  const router = Router();

  router.get('/', async (_req, res) => {
    res.json(toMe(await auth.me(authOf(res).userId)));
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
      res.json(toMe(user));
    }),
  );

  router.delete(
    '/',
    ...validated({ body: deleteMeBodySchema }, async ({ body }, _req, res) => {
      await auth.deleteAccount(authOf(res).userId, body.password);
      res.clearCookie(refreshCookie, cookieOptions(policy));
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
