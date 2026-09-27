import { deleteSyncKeyBodySchema, putKeyCheckBodySchema, type KeyCheckStored } from '@harvest/contracts';
import { Router, type RequestHandler } from 'express';
import type { KeyShares } from '../auth/key-shares.js';
import type { AuthService } from '../auth/service.js';
import { authOf } from '../http/authenticate.js';
import { validated } from '../http/validate.js';

/**
 * The account's key share and key check ([[Sync-API]], sync key).
 * Mounted behind requireAuth, a per-account limit and requireVerified.
 */
export function syncKeyRoutes(keys: KeyShares, auth: AuthService, passwordLimit: RequestHandler): Router {
  const router = Router();

  router.get('/', async (_req, res) => {
    res.set('cache-control', 'no-store');
    res.json(await keys.read(authOf(res).userId));
  });

  router.put(
    '/check',
    ...validated({ body: putKeyCheckBodySchema }, async ({ body }, _req, res) => {
      const check = await keys.storeCheck(authOf(res).userId, body.check);
      const answer: KeyCheckStored = { check };
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
      res.status(204).end();
    }),
  );

  return router;
}
