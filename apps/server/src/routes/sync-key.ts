import {
  deleteSyncKeyBodySchema,
  setSyncKeyBodySchema,
  unlockBodySchema,
  type SyncKeySet,
} from '@harvest/contracts';
import { Router, type RequestHandler } from 'express';
import type { KeyShares } from '../auth/key-shares.js';
import type { AuthService } from '../auth/service.js';
import { authOf } from '../http/authenticate.js';
import { validated } from '../http/validate.js';

/**
 * The account's key share, its PIN check and its epoch ([[Sync-API]],
 * sync key). Mounted behind requireAuth, a per-account limit,
 * requireVerified and a 16 kB body parser.
 */
export function syncKeyRoutes(keys: KeyShares, auth: AuthService, passwordLimit: RequestHandler): Router {
  const router = Router();

  router.get('/', async (_req, res) => {
    res.json(await keys.state(authOf(res).userId));
  });

  router.post(
    '/unlock',
    ...validated({ body: unlockBodySchema }, async ({ body }, _req, res) => {
      res.json(await keys.unlock(authOf(res).userId, body.proof));
    }),
  );

  router.put(
    '/',
    ...validated({ body: setSyncKeyBodySchema }, async ({ body }, _req, res) => {
      const answer: SyncKeySet = await keys.setPin(authOf(res).userId, body.verifier, body.check);
      res.status(201).json(answer);
    }),
  );

  // Start over: the password, counted like deleting the account (the
  // same limiter, so the two share one allowance).
  router.delete(
    '/',
    passwordLimit,
    ...validated({ body: deleteSyncKeyBodySchema }, async ({ body }, _req, res) => {
      await auth.resetSyncKey(authOf(res).userId, body.password);
      await keys.forgetTries(authOf(res).userId);
      res.status(204).end();
    }),
  );

  return router;
}
