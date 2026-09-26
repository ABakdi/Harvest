import type { Health } from '@harvest/contracts';
import { Router } from 'express';
import type { Db } from 'mongodb';
import { HttpError } from '../http/errors.js';
import type { ReleaseSource } from '../releases/github.js';

export function publicRoutes(db: Db, releases: ReleaseSource): Router {
  const router = Router();

  /** Liveness for the host: the process answers and the database does too. */
  router.get('/health', async (_req, res) => {
    try {
      await db.command({ ping: 1 });
    } catch {
      throw new HttpError('unavailable', 'The database is not answering');
    }
    const body: Health = { status: 'ok' };
    res.json(body);
  });

  router.get('/releases/latest', async (_req, res) => {
    const release = await releases.latest();
    res.setHeader('cache-control', 'public, max-age=300');
    res.json(release);
  });

  return router;
}
