import { createApp } from './app.js';
import { ConfigError, loadConfig } from './config.js';
import { createRepositories } from './db/index.js';
import { connectMongo } from './db/mongo.js';
import { createLogger } from './logger.js';
import { LogMailer } from './mail/mailer.js';
import { SmtpMailer } from './mail/smtp.js';
import { ReleaseSource } from './releases/github.js';

async function main(): Promise<void> {
  const config = await loadConfig();
  const logger = createLogger(config.logLevel);

  const mongo = await connectMongo(config.mongoUrl);
  const repos = await createRepositories(mongo.db);
  const mailer = config.smtp ? new SmtpMailer(config.smtp, config.mailFrom) : new LogMailer(logger);
  if (!config.smtp) logger.warn('no SMTP configured: emails go to the log');

  const app = createApp({
    config,
    db: mongo.db,
    repos,
    mailer,
    releases: new ReleaseSource({ repo: config.githubRepo, token: config.githubToken }),
    logger,
  });

  const server = app.listen(config.port, () => {
    logger.info({ port: config.port, env: config.env }, 'listening');
  });

  // Finish what is in flight, then let go of the database.
  const stop = (signal: string) => {
    logger.info({ signal }, 'shutting down');
    server.close(() => {
      void mongo.close().finally(() => process.exit(0));
    });
    setTimeout(() => process.exit(1), 10_000).unref();
  };
  process.once('SIGTERM', () => stop('SIGTERM'));
  process.once('SIGINT', () => stop('SIGINT'));
}

main().catch((error: unknown) => {
  if (error instanceof ConfigError) {
    console.error(error.message);
  } else {
    console.error(error);
  }
  process.exit(1);
});
