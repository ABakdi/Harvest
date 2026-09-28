import { fileIvHeader, filePlainBytesHeader, maxAssistAudioBytes } from '@harvest/contracts';
import cookieParser from 'cookie-parser';
import cors from 'cors';
import express, { type Express } from 'express';
import helmet from 'helmet';
import type { Db } from 'mongodb';
import type { Logger } from 'pino';
import { pinoHttp } from 'pino-http';
import type { Config } from './config.js';
import { KeyShares } from './auth/key-shares.js';
import { AuthService } from './auth/service.js';
import type { Repositories } from './db/index.js';
import { requireAuth, requireVerified } from './http/authenticate.js';
import { errorHandler, notFoundHandler } from './http/errors.js';
import { authLimiters, defaultRateLimits, type RateLimitSettings } from './http/rate-limits.js';
import type { Mailer } from './mail/mailer.js';
import type { ReleaseSource } from './releases/github.js';
import { authRoutes } from './routes/auth.js';
import { meRoutes } from './routes/me.js';
import { publicRoutes } from './routes/public.js';
import { GeminiUpstream, type Fetch as AssistFetch } from './assist/gemini.js';
import { assistRoutes } from './routes/assist.js';
import { fileRoutes } from './routes/files.js';
import { syncKeyRoutes } from './routes/sync-key.js';
import { syncRoutes } from './routes/sync.js';
import { FileSweeper } from './sync/file-sweep.js';
import { SyncService } from './sync/service.js';

/** The assist's body limit, in bytes ([[Notes]] N10). */
export const assistBodyLimit = Math.ceil((maxAssistAudioBytes * 4) / 3) + 4 * 1024 * 1024;

export interface AppDeps {
  config: Pick<
    Config,
    'corsOrigins' | 'cookieSecure' | 'trustProxy' | 'bodyLimit' | 'appUrl' | 'jwt' | 'assist' | 'keyShareKey'
  >;
  db: Db;
  repos: Repositories;
  mailer: Mailer;
  releases: ReleaseSource;
  logger: Logger;
  rateLimits?: Partial<RateLimitSettings>;
  now?: () => Date;
  /** The model, for tests: the real one is reached over the network. */
  assistFetch?: AssistFetch;
  /**
   * How often to sweep files no row names; the entry point sets it,
   * tests leave it off and sweep by hand.
   */
  fileSweepIntervalMs?: number;
}

/** The small JSON bodies: sign-in, the account, the key check. */
const smallBody = '16kb';

/**
 * Builds the app without listening, so tests can drive it with
 * supertest and the entry point can put it on a port.
 */
export function createApp(deps: AppDeps): Express {
  const { config, logger } = deps;
  const app = express();

  app.disable('x-powered-by');
  app.set('trust proxy', config.trustProxy);

  app.use(
    pinoHttp({
      logger,
      // Method, path without the query, status and time: nothing else.
      serializers: {
        req: (req: { method: string; url: string; id: unknown }) => ({
          id: req.id,
          method: req.method,
          path: req.url.split('?')[0],
        }),
        res: (res: { statusCode: number }) => ({ status: res.statusCode }),
      },
    }),
  );
  app.use(helmet());
  app.use(
    cors({
      // Requests with no Origin (the phone, curl) are not a browser's,
      // and CORS has nothing to say about them. The web is served from
      // the same origin as /v1 ([[Deployment]]); these are for a setup
      // that is not.
      origin: (origin, callback) => callback(null, origin === undefined || config.corsOrigins.includes(origin)),
      credentials: true,
      methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'],
      allowedHeaders: ['Content-Type', 'Authorization', fileIvHeader, filePlainBytesHeader],
      exposedHeaders: [fileIvHeader, filePlainBytesHeader, 'Retry-After'],
      maxAge: 600,
    }),
  );
  app.use(cookieParser());

  const sync = new SyncService(deps.repos, deps.now);
  const settings = { ...defaultRateLimits, ...deps.rateLimits };
  const limits = authLimiters(settings);
  const cookies = { secure: config.cookieSecure };
  const auth = new AuthService({
    repos: deps.repos,
    mailer: deps.mailer,
    logger,
    keys: config.jwt,
    appUrl: config.appUrl,
    accountLock: sync.accountLock,
    emailLimit: {
      failures: settings.emailLoginFailures,
      globalFailures: settings.emailGlobalLoginFailures,
      windowMs: settings.emailWindowMs,
    },
    ...(deps.now ? { now: deps.now } : {}),
  });
  const verified = requireVerified();

  // Bodies are parsed per router, after the caller is known: nobody
  // signed out can make the server read and parse megabytes, and each
  // route takes only the size it needs (audit S5-07).
  const v1 = express.Router();
  // Nothing the API answers belongs in a cache: a browser would keep the
  // pulled notes and lists on disk after sign-out (S6-01). The release
  // route alone sets its own.
  v1.use((_req, res, next) => {
    res.set('Cache-Control', 'no-store');
    next();
  });
  v1.use(publicRoutes(deps.db, deps.releases));
  v1.use('/auth', express.json({ limit: smallBody }), authRoutes(auth, limits, cookies));
  v1.use(
    '/me/sync-key',
    requireAuth(auth),
    limits.syncKey,
    verified,
    express.json({ limit: smallBody }),
    syncKeyRoutes(
      new KeyShares(deps.repos.users, deps.repos.windowedCounts, config.keyShareKey, deps.now),
      auth,
      limits.deleteAccount,
    ),
  );
  v1.use('/me', requireAuth(auth), express.json({ limit: smallBody }), meRoutes(auth, deps.repos, cookies, limits));
  v1.use(
    '/sync',
    requireAuth(auth),
    limits.sync,
    verified,
    express.json({ limit: config.bodyLimit }),
    syncRoutes(sync),
  );
  v1.use(
    '/files',
    requireAuth(auth),
    limits.files,
    verified,
    fileRoutes({
      files: deps.repos.files,
      records: deps.repos.records,
      users: deps.repos.users,
      totals: deps.repos.totals,
      lock: sync.accountLock,
      ...(deps.now ? { now: deps.now } : {}),
    }),
  );
  v1.use(
    '/assist',
    requireAuth(auth),
    verified,
    // A recording sent to be transcribed is the largest body the server
    // takes, and its cap is the contract's, not the general limit: the
    // base64 of the largest recording, with room for the words beside it.
    express.json({ limit: assistBodyLimit }),
    assistRoutes({
      upstream: config.assist.apiKey
        ? new GeminiUpstream({
            apiKey: config.assist.apiKey,
            model: config.assist.model,
            ...(deps.assistFetch ? { fetch: deps.assistFetch } : {}),
          })
        : null,
      usage: deps.repos.assistUsage,
      dailyLimit: config.assist.dailyLimit,
      globalDailyLimit: config.assist.globalDailyLimit,
      ...(deps.now ? { now: deps.now } : {}),
    }),
  );
  app.use('/v1', v1);

  app.use(notFoundHandler);
  app.use(errorHandler(logger));
  // What was left to run after an answer went ("forgot", "resend").
  app.locals.settled = () => auth.settled();

  if (deps.fileSweepIntervalMs) {
    const sweeper = new FileSweeper(deps.repos, sync.accountLock, deps.now);
    const sweep = () => void sweeper.sweepAll(logger).catch((error: unknown) => logger.error({ err: error }, 'file sweep failed'));
    // The first a few minutes after start, then on the interval.
    setTimeout(sweep, 10 * 60_000).unref();
    setInterval(sweep, deps.fileSweepIntervalMs).unref();
  }
  return app;
}
