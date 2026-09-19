import type { NextFunction, Request, RequestHandler, Response } from 'express';
import type { z } from 'zod';
import { validationError } from './errors.js';

type Part = 'params' | 'query' | 'body';
type Schemas = Partial<Record<Part, z.ZodType>>;

export type Input<S extends Schemas> = {
  [K in Part]: S[K] extends z.ZodType ? z.output<S[K]> : undefined;
};

/**
 * A route whose params, query and body are parsed before the handler
 * runs (ADR-011: nothing reaches a handler unparsed). Returns the pair
 * of middlewares to mount: the check, which answers 400 with the issues,
 * and the handler, which receives the parsed, typed input.
 */
export function validated<S extends Schemas>(
  schemas: S,
  handler: (input: Input<S>, req: Request, res: Response) => Promise<void> | void,
): [RequestHandler, RequestHandler] {
  const check = (req: Request, res: Response, next: NextFunction) => {
    const input: Partial<Record<Part, unknown>> = {};
    for (const part of ['params', 'query', 'body'] as const) {
      const schema = schemas[part];
      if (!schema) continue;
      const parsed = schema.safeParse(req[part] ?? {});
      if (!parsed.success) throw validationError(parsed.error, part);
      input[part] = parsed.data;
    }
    res.locals.input = input;
    next();
  };
  const run = async (req: Request, res: Response) => {
    await handler(res.locals.input as Input<S>, req, res);
  };
  return [check, run];
}
