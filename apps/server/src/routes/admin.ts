import {
  adminHistoryQuerySchema,
  adminUsersQuerySchema,
  announcementBodySchema,
  announcementParamsSchema,
  announcementPatchSchema,
  type AdminHistory,
  type AdminOverview,
  type AdminUsers,
  type AnnouncementsResult,
} from '@harvest/contracts';
import { Router, type RequestHandler } from 'express';
import type { Logger } from 'pino';
import type { WebPush } from '../admin/web-push.js';
import type { AuthService } from '../auth/service.js';
import { toAnnouncement } from '../db/announcements.js';
import type { Repositories } from '../db/index.js';
import { authOf } from '../http/authenticate.js';
import { HttpError } from '../http/errors.js';
import { validated } from '../http/validate.js';
import type { ReleaseSource } from '../releases/github.js';

/**
 * Only an admin gets past: anyone else, signed in or not, is answered
 * as if the route did not exist ([[Admin]] AD6). Behind [requireAuth].
 */
export function requireAdmin(auth: AuthService): RequestHandler {
  return async (_req, res, next) => {
    const user = await auth.me(authOf(res).userId).catch(() => null);
    if (!user || !auth.isAdmin(user)) throw new HttpError('not_found', 'No such route');
    next();
  };
}

export interface AdminDeps {
  repos: Repositories;
  releases: ReleaseSource;
  push: WebPush | null;
  logger?: Logger;
  now?: () => Date;
  /** Runs work after the answer has gone (a push to every browser). */
  later: (work: () => Promise<void>) => void;
}

/** The admin panel's routes ([[Admin]]). Mounted behind requireAuth, requireAdmin and a limit. */
export function adminRoutes({ repos, releases, push, logger, now = () => new Date(), later }: AdminDeps): Router {
  const router = Router();

  router.get('/overview', async (_req, res) => {
    const at = now();
    const [counts, downloads] = await Promise.all([repos.adminStats.overview(at), releases.downloads()]);
    const body: AdminOverview = { ...counts, downloads, generatedAt: at.toISOString() };
    res.json(body);
  });

  router.get(
    '/history',
    ...validated({ query: adminHistoryQuerySchema }, async ({ query }, _req, res) => {
      const body: AdminHistory = { days: await repos.adminStats.history(query.days, now()) };
      res.json(body);
    }),
  );

  router.get(
    '/users',
    ...validated({ query: adminUsersQuerySchema }, async ({ query }, _req, res) => {
      const page = await repos.users.page(query.q, query.cursor, query.limit);
      const body: AdminUsers = {
        users: page.users.map((user) => ({
          id: user._id.toHexString(),
          email: user.email,
          displayName: user.displayName,
          createdAt: user.createdAt.toISOString(),
          verifiedAt: user.verifiedAt?.toISOString() ?? null,
          lastActiveAt: user.lastActiveAt?.toISOString() ?? null,
          platform: user.lastPlatform ?? null,
          appVersion: user.lastAppVersion ?? null,
          streak: user.streak ? { current: user.streak.current, best: user.streak.best } : null,
        })),
        next: page.next,
      };
      res.json(body);
    }),
  );

  router.get('/announcements', async (_req, res) => {
    const docs = await repos.announcements.all();
    res.json({ announcements: docs.map((doc) => ({ ...toAnnouncement(doc), pushed: doc.pushed })) });
  });

  router.post(
    '/announcements',
    ...validated({ body: announcementBodySchema }, async ({ body }, _req, res) => {
      const at = now();
      const doc = await repos.announcements.create({
        title: body.title,
        body: body.body,
        link: body.link,
        push: body.push,
        popup: body.popup,
        audience: body.audience,
        startsAt: body.startsAt ? new Date(body.startsAt) : at,
        endsAt: body.endsAt ? new Date(body.endsAt) : null,
        createdAt: at,
      });
      // Browsers get a push at once when it is live now; the phones ask
      // for it themselves ([[Admin]]). A piece that starts later is not
      // pushed to browsers: they see it when they next open.
      if (doc.push && push && doc.startsAt <= at) {
        later(async () => {
          const delivered = await push.broadcast(doc);
          if (delivered > 0) await repos.announcements.countPushed(doc._id, delivered);
          logger?.info({ delivered }, 'news pushed to browsers');
        });
      }
      res.status(201).json(toAnnouncement(doc));
    }),
  );

  router.patch(
    '/announcements/:id',
    ...validated({ params: announcementParamsSchema, body: announcementPatchSchema }, async ({ params, body }, _req, res) => {
      const doc = await repos.announcements.setEnd(params.id, body.endsAt ? new Date(body.endsAt) : null);
      if (!doc) throw new HttpError('not_found', 'No such news');
      res.json(toAnnouncement(doc));
    }),
  );

  router.delete(
    '/announcements/:id',
    ...validated({ params: announcementParamsSchema }, async ({ params }, _req, res) => {
      if (!(await repos.announcements.delete(params.id))) throw new HttpError('not_found', 'No such news');
      res.status(204).end();
    }),
  );

  return router;
}

/**
 * The news for a device ([[Admin]]): what is live now, for everyone, and
 * for account holders too when the caller is signed in. Nothing about
 * who asked is kept (AD5). [guards] go in front of each route: the
 * limit and the optional session.
 */
export function newsRoutes(
  repos: Repositories,
  push: WebPush | null,
  guards: RequestHandler[],
  now: () => Date = () => new Date(),
): Router {
  const router = Router();

  router.get('/announcements', ...guards, async (_req, res) => {
    const signedIn = res.locals.auth !== undefined;
    const docs = await repos.announcements.live(now(), signedIn);
    const body: AnnouncementsResult = { announcements: docs.map(toAnnouncement) };
    res.json(body);
  });

  router.get('/push/key', ...guards, async (_req, res) => {
    if (!push) throw new HttpError('not_found', 'This server sends no pushes');
    res.json({ publicKey: await push.publicKey() });
  });

  return router;
}
