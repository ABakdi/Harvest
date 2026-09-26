import { pino, type Logger } from 'pino';

/**
 * The process logger. Requests are logged by method, path and status
 * only: never a body, never a header, never an email (ADR-011).
 * Authorization headers and cookies are redacted as well, in case some
 * later log line includes a request by accident.
 */
export function createLogger(level: string): Logger {
  return pino({
    level,
    redact: {
      paths: ['req.headers.authorization', 'req.headers.cookie', 'res.headers["set-cookie"]', '*.email', '*.password'],
      censor: '[redacted]',
    },
  });
}
