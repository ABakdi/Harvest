/**
 * The real server on a throwaway database, for the phone's end-to-end
 * sync test (apps/mobile/test/e2e). Never deployed: it verifies every
 * new account on its own, because a test cannot read an email.
 *
 *   pnpm --filter @harvest/server e2e   # listens on E2E_PORT (4100)
 */
import { MongoMemoryServer } from 'mongodb-memory-server';
import { createApp } from '../src/app.js';
import { loadConfig } from '../src/config.js';
import { createRepositories } from '../src/db/index.js';
import { connectMongo } from '../src/db/mongo.js';
import { createLogger } from '../src/logger.js';
import { MemoryMailer } from '../src/mail/mailer.js';
import { ReleaseSource } from '../src/releases/github.js';

const port = Number(process.env.E2E_PORT ?? 4100);
const mongod = await MongoMemoryServer.create();
const mongo = await connectMongo(mongod.getUri(), 'harvest_e2e');
const repos = await createRepositories(mongo.db);
const config = await loadConfig({
  NODE_ENV: 'test',
  CORS_ORIGINS: 'http://localhost:5173',
  APP_URL: 'http://localhost:5173',
});
const app = createApp({
  config,
  db: mongo.db,
  repos,
  mailer: new MemoryMailer(),
  releases: new ReleaseSource({
    repo: config.githubRepo,
    fetch: () => Promise.reject(new Error('offline')),
  }),
  logger: createLogger('silent'),
  rateLimits: { loginFailures: 1000, authRequests: 1000, refreshes: 1000 },
});

const verify = setInterval(() => {
  void mongo.db
    .collection('users')
    .updateMany({ verifiedAt: null }, { $set: { verifiedAt: new Date() } });
}, 200);

const server = app.listen(port, () => {
  console.log(`e2e server ready on http://localhost:${port}`);
});

async function stop() {
  clearInterval(verify);
  server.close();
  await mongo.close();
  await mongod.stop();
  process.exit(0);
}
process.on('SIGINT', () => void stop());
process.on('SIGTERM', () => void stop());
