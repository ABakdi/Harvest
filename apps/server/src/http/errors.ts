import { errorStatus, toIssues, type ErrorBody, type ErrorCode, type Issue } from '@harvest/contracts';
import type { ErrorRequestHandler, RequestHandler } from 'express';
import type { Logger } from 'pino';
import type { z } from 'zod';

/**
 * A failure with a code the clients switch on. Thrown anywhere in a
 * handler; the error middleware turns it into the envelope.
 */
export class HttpError extends Error {
  override readonly name = 'HttpError';

  constructor(
    readonly code: ErrorCode,
    message: string,
    readonly details?: Issue[],
    readonly headers: Record<string, string> = {},
  ) {
    super(message);
  }

  get status(): number {
    return errorStatus[this.code];
  }
}

export function validationError(error: z.ZodError, part: string): HttpError {
  const details = toIssues(error).map((issue) => ({ ...issue, path: [part, ...issue.path] }));
  return new HttpError('validation_failed', `The ${part} did not parse`, details);
}

export const unauthorized = (message = 'Sign in again') => new HttpError('unauthorized', message);

export const notFoundHandler: RequestHandler = (req, _res, next) => {
  next(new HttpError('not_found', `No route for ${req.method} ${req.path}`));
};

/** The errors body-parser raises, by their `type`. */
function fromBodyParser(error: unknown): HttpError | null {
  if (typeof error !== 'object' || error === null || !('type' in error)) return null;
  switch ((error).type) {
    case 'entity.too.large':
      return new HttpError('payload_too_large', 'The body is over the size cap');
    case 'entity.parse.failed':
      return new HttpError('validation_failed', 'The body is not valid JSON');
    case 'encoding.unsupported':
    case 'charset.unsupported':
    case 'request.aborted':
    case 'request.size.invalid':
    case 'entity.verify.failed':
      return new HttpError('validation_failed', 'The body could not be read');
    default:
      return null;
  }
}

/**
 * The last middleware: every failure leaves as `{ error: { code,
 * message, details? } }` (ADR-011 rule 5). Anything that is not an
 * [HttpError] is the server's fault; it is logged whole and answered
 * with nothing but `internal`, because a stack trace never leaves the
 * process.
 */
export function errorHandler(logger: Logger): ErrorRequestHandler {
  return (error: unknown, req, res, next) => {
    if (res.headersSent) {
      next(error);
      return;
    }
    const known = error instanceof HttpError ? error : fromBodyParser(error);
    const failure = known ?? new HttpError('internal', 'Something went wrong on the server');
    if (!known) logger.error({ err: error, method: req.method, path: req.path }, 'unhandled error');

    for (const [name, value] of Object.entries(failure.headers)) res.setHeader(name, value);
    const body: ErrorBody = {
      error: {
        code: failure.code,
        message: failure.message,
        ...(failure.details ? { details: failure.details } : {}),
      },
    };
    res.status(failure.status).json(body);
  };
}
