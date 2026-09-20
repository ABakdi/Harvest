import cookieParser from 'cookie-parser';
import cors from 'cors';
import express, { type Express } from 'express';
import helmet from 'helmet';
import type { Db } from 'mongodb';
import type { Logger } from 'pino';
import { pinoHttp } from 'pino-http';
import type { Config } from './config.js';
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
import { syncRoutes } from './routes/sync.js';
import { SyncService } from './sync/service.js';

export interface AppDeps {
  config: Pick<
    Config,
    'corsOrigins' | 'cookieSecure' | 'trustProxy' | 'bodyLimit' | 'appUrl' | 'jwt' | 'assist'
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
}

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
      // and CORS has nothing to say about them.
      origin: (origin, callback) => callback(null, origin === undefined || config.corsOrigins.includes(origin)),
      credentials: true,
      methods: ['GET', 'POST', 'PATCH', 'DELETE'],
      allowedHeaders: ['Content-Type', 'Authorization'],
      maxAge: 600,
    }),
  );
  app.use(express.json({ limit: config.bodyLimit }));
  app.use(cookieParser());

  const auth = new AuthService({
    repos: deps.repos,
    mailer: deps.mailer,
    logger,
    keys: config.jwt,
    appUrl: config.appUrl,
    ...(deps.now ? { now: deps.now } : {}),
  });
  const sync = new SyncService(deps.repos, deps.now);
  const limits = authLimiters({ ...defaultRateLimits, ...deps.rateLimits });
  const cookies = { secure: config.cookieSecure };

  const v1 = express.Router();
  v1.use(publicRoutes(deps.db, deps.releases));
  v1.use('/auth', authRoutes(auth, limits, cookies));
  v1.use('/me', requireAuth(auth), meRoutes(auth, deps.repos, cookies));
  v1.use('/sync', requireAuth(auth), requireVerified(deps.repos.users), syncRoutes(sync));
  v1.use(
    '/files',
    requireAuth(auth),
    requireVerified(deps.repos.users),
    fileRoutes(deps.repos.files, deps.now),
  );
  v1.use(
    '/assist',
    requireAuth(auth),
    requireVerified(deps.repos.users),
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
      ...(deps.now ? { now: deps.now } : {}),
    }),
  );
  app.use('/v1', v1);

  app.use(notFoundHandler);
  app.use(errorHandler(logger));
  return app;
}
