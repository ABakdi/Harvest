import { pullQuerySchema, pushBodySchema } from '@harvest/contracts';
import { Router } from 'express';
import { authOf } from '../http/authenticate.js';
import { validated } from '../http/validate.js';
import type { SyncService } from '../sync/service.js';

/** Mounted behind requireAuth and requireVerified. */
export function syncRoutes(sync: SyncService): Router {
  const router = Router();

  router.post(
    '/push',
    ...validated({ body: pushBodySchema }, async ({ body }, _req, res) => {
      res.json(await sync.push(authOf(res).userId, body.deviceId, body.records));
    }),
  );

  router.get(
    '/pull',
    ...validated({ query: pullQuerySchema }, async ({ query }, _req, res) => {
      res.json(await sync.pull(authOf(res).userId, query.after, query.limit));
    }),
  );

  return router;
}
