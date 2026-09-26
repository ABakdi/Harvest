import { generateKeyPair, importPKCS8, importSPKI, type CryptoKey } from 'jose';
import { z } from 'zod';

/**
 * Everything the server reads from its environment, parsed once at boot.
 * A missing or malformed variable stops the process before it listens,
 * which is kinder than a 500 on the first request that needs it.
 */

const booleanFlag = z
  .enum(['true', 'false', '1', '0', 'yes', 'no'])
  .transform((value) => value === 'true' || value === '1' || value === 'yes');

const commaList = z
  .string()
  .transform((value) =>
    value
      .split(',')
      .map((item) => item.trim())
      .filter((item) => item.length > 0),
  );

const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.coerce.number().int().min(1).max(65535).default(8080),
  LOG_LEVEL: z.enum(['fatal', 'error', 'warn', 'info', 'debug', 'trace', 'silent']).optional(),

  MONGO_URL: z.string().min(1).optional(),

  /** PEM, PKCS#8 and SPKI, Ed25519. Newlines may be written as `\n`. */
  JWT_PRIVATE_KEY: z.string().min(1).optional(),
  JWT_PUBLIC_KEY: z.string().min(1).optional(),

  CORS_ORIGINS: commaList.default([]),
  COOKIE_SECURE: booleanFlag.optional(),
  /** Hops of reverse proxy in front of the server, for the client's real address. */
  TRUST_PROXY: z.coerce.number().int().min(0).default(0),
  BODY_LIMIT: z.string().default('5mb'),

  SMTP_HOST: z.string().min(1).optional(),
  SMTP_PORT: z.coerce.number().int().min(1).max(65535).default(587),
  SMTP_SECURE: booleanFlag.default(false),
  SMTP_USER: z.string().optional(),
  SMTP_PASS: z.string().optional(),
  SMTP_FROM: z.string().default('Harvest <no-reply@localhost>'),

  /** Where the web app lives; the emailed links point into it. */
  APP_URL: z.url().default('http://localhost:5173'),

  /**
   * The key the server lends to signed-in accounts
   * ([[ADR-013-Assist-Providers]]). Without it there is no server
   * assist, and the clients say so rather than failing at the sheet.
   */
  ASSIST_API_KEY: z.string().min(1).optional(),
  ASSIST_MODEL: z.string().min(1).default('gemini-2.5-flash'),
  /** Requests per account per UTC day. */
  ASSIST_DAILY_LIMIT: z.coerce.number().int().min(0).default(50),

  GITHUB_REPO: z
    .string()
    .regex(/^[\w.-]+\/[\w.-]+$/, { message: 'owner/name' })
    .default('ABakdi/Harvest'),
  GITHUB_TOKEN: z.string().optional(),
});

export type Env = z.input<typeof envSchema>;

export interface SmtpConfig {
  host: string;
  port: number;
  secure: boolean;
  user: string | undefined;
  pass: string | undefined;
}

export interface Config {
  env: 'development' | 'test' | 'production';
  port: number;
  logLevel: string;
  mongoUrl: string;
  jwt: { privateKey: CryptoKey; publicKey: CryptoKey };
  corsOrigins: string[];
  cookieSecure: boolean;
  trustProxy: number;
  bodyLimit: string;
  smtp: SmtpConfig | null;
  mailFrom: string;
  appUrl: string;
  /** The server-held assist; `apiKey` null means it offers none. */
  assist: { apiKey: string | null; model: string; dailyLimit: number };
  githubRepo: string;
  githubToken: string | undefined;
}

export class ConfigError extends Error {
  override readonly name = 'ConfigError';
}

const pem = (value: string) => value.replace(/\\n/g, '\n');

/**
 * Reads [source] (the process environment by default) into a [Config].
 *
 * Outside production two things are forgiven: no signing keys (a fresh
 * pair is made for this process, so every restart signs everyone out,
 * which is fine on a laptop) and no SMTP (mail goes to the log).
 * Production forgives neither.
 */
export async function loadConfig(source: Record<string, string | undefined> = process.env): Promise<Config> {
  // A variable set to nothing is a variable not set: an .env with
  // `ASSIST_API_KEY=` left blank, or a compose file passing
  // `${ASSIST_API_KEY:-}`, means "none", not an invalid empty key.
  const given = Object.fromEntries(Object.entries(source).filter(([, value]) => value !== undefined && value.trim() !== ''));
  const parsed = envSchema.safeParse(given);
  if (!parsed.success) {
    const problems = parsed.error.issues.map((issue) => `${issue.path.join('.')}: ${issue.message}`);
    throw new ConfigError(`Invalid environment:\n  ${problems.join('\n  ')}`);
  }
  const env = parsed.data;
  const production = env.NODE_ENV === 'production';

  if (production && !env.MONGO_URL) throw new ConfigError('MONGO_URL is required in production');
  if (production && (!env.JWT_PRIVATE_KEY || !env.JWT_PUBLIC_KEY)) {
    throw new ConfigError('JWT_PRIVATE_KEY and JWT_PUBLIC_KEY are required in production');
  }
  if (production && !env.SMTP_HOST) {
    throw new ConfigError('SMTP_HOST is required in production: without mail nobody can verify');
  }
  if ((env.JWT_PRIVATE_KEY === undefined) !== (env.JWT_PUBLIC_KEY === undefined)) {
    throw new ConfigError('Set both JWT_PRIVATE_KEY and JWT_PUBLIC_KEY, or neither');
  }

  const jwt =
    env.JWT_PRIVATE_KEY && env.JWT_PUBLIC_KEY
      ? {
          privateKey: await importPKCS8(pem(env.JWT_PRIVATE_KEY), 'EdDSA'),
          publicKey: await importSPKI(pem(env.JWT_PUBLIC_KEY), 'EdDSA'),
        }
      : await generateKeyPair('EdDSA', { crv: 'Ed25519' });

  return {
    env: env.NODE_ENV,
    port: env.PORT,
    logLevel: env.LOG_LEVEL ?? (env.NODE_ENV === 'test' ? 'silent' : 'info'),
    mongoUrl: env.MONGO_URL ?? 'mongodb://127.0.0.1:27017/harvest',
    jwt,
    corsOrigins: env.CORS_ORIGINS,
    // A cookie marked Secure is never sent over plain http, which is
    // what a laptop serves; everywhere else it must be.
    cookieSecure: env.COOKIE_SECURE ?? env.NODE_ENV !== 'development',
    trustProxy: env.TRUST_PROXY,
    bodyLimit: env.BODY_LIMIT,
    smtp: env.SMTP_HOST
      ? {
          host: env.SMTP_HOST,
          port: env.SMTP_PORT,
          secure: env.SMTP_SECURE,
          user: env.SMTP_USER,
          pass: env.SMTP_PASS,
        }
      : null,
    mailFrom: env.SMTP_FROM,
    appUrl: env.APP_URL.replace(/\/+$/, ''),
    assist: {
      apiKey: env.ASSIST_API_KEY ?? null,
      model: env.ASSIST_MODEL,
      dailyLimit: env.ASSIST_DAILY_LIMIT,
    },
    githubRepo: env.GITHUB_REPO,
    githubToken: env.GITHUB_TOKEN,
  };
}
