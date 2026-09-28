import { pullQuerySchema, pushBodySchema, sealedBodySchema } from '@harvest/contracts';
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
      res.json(await sync.push(authOf(res).userId, body.deviceId, body.records, body.keyEpoch));
    }),
  );

  router.get(
    '/pull',
    ...validated({ query: pullQuerySchema }, async ({ query }, _req, res) => {
      res.json(await sync.pull(authOf(res).userId, query.after, query.limit, undefined, query.deviceId));
    }),
  );

  router.post(
    '/sealed',
    ...validated({ body: sealedBodySchema }, async ({ body }, _req, res) => {
      res.json(await sync.sealed(authOf(res).userId, body.keyEpoch));
    }),
  );

  return router;
}
