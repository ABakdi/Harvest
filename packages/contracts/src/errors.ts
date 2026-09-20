import { z } from 'zod';

/**
 * Every failure the server answers with, and the status each one
 * travels under. Clients switch on the code, never on the message: the
 * message is for a person reading a log, and it may change.
 */
export const errorStatus = {
  validation_failed: 400,
  unauthorized: 401,
  forbidden: 403,
  not_found: 404,
  conflict: 409,
  payload_too_large: 413,
  /** The account has kept as many file bytes as it may ([[Sync-API]]). */
  quota_exceeded: 507,
  rate_limited: 429,
  internal: 500,
  // Not in the first table of the Sync API page: the one route that
  // depends on a third party (the GitHub release proxy) needs a way to
  // say "not now, and not your fault".
  unavailable: 503,
} as const;

export type ErrorCode = keyof typeof errorStatus;

export const errorCodes = Object.keys(errorStatus) as [ErrorCode, ...ErrorCode[]];

export const errorCodeSchema = z.enum(errorCodes);

/** One problem found in a body, a query or a record. */
export const issueSchema = z.object({
  path: z.array(z.union([z.string(), z.number()])),
  message: z.string(),
  code: z.string().optional(),
});
export type Issue = z.infer<typeof issueSchema>;

export const errorBodySchema = z.object({
  error: z.object({
    code: errorCodeSchema,
    message: z.string(),
    details: z.array(issueSchema).optional(),
  }),
});
export type ErrorBody = z.infer<typeof errorBodySchema>;

/**
 * Turns zod's issues into the wire shape. zod's own issue objects carry
 * the offending input on some codes, and an error body must never echo
 * a password back, so only the path, the message and the code survive.
 */
export function toIssues(error: z.ZodError): Issue[] {
  return error.issues.map((issue) => ({
    path: issue.path.map((part) => (typeof part === 'symbol' ? String(part) : part)),
    message: issue.message,
    code: issue.code,
  }));
}
