import {
  fileIvHeader,
  filePlainBytesHeader,
  fileQuerySchema,
  fileHashSchema,
  maxFileBytes,
  maxFileStoreBytes,
} from '@harvest/contracts';
import { Binary } from 'mongodb';
import express, { Router } from 'express';
import { z } from 'zod';
import type { FilesRepository } from '../db/files.js';
import { authOf } from '../http/authenticate.js';
import { HttpError, validationError } from '../http/errors.js';
import { validated } from '../http/validate.js';

/** A 12-byte nonce, base64, as the envelope carries one. */
const ivSchema = z.string().regex(/^[A-Za-z0-9+/]{16}={0,2}$/, { message: 'Not a 12-byte nonce' });

const nameSchema = z.object({ sha256: fileHashSchema });

/** The two headers an upload carries beside its bytes. */
function sealOf(req: { get(name: string): string | undefined }): { iv: string; plainBytes: number } {
  const parsed = z
    .object({ iv: ivSchema, plainBytes: z.coerce.number().int().nonnegative().max(maxFileBytes) })
    .safeParse({ iv: req.get(fileIvHeader) ?? '', plainBytes: req.get(filePlainBytesHeader) ?? '0' });
  if (!parsed.success) throw validationError(parsed.error, 'body');
  return parsed.data;
}

/**
 * Files: pictures and recordings, content-addressed and sealed by the
 * client ([[Sync-API]]).
 *
 * The server stores bytes it cannot read under a name it cannot check,
 * which is the whole point of the private tier. What it can do is
 * refuse a file that is too big and an account that has kept too much.
 *
 * Mounted behind requireAuth and requireVerified, like sync.
 */
export function fileRoutes(files: FilesRepository, now: () => Date = () => new Date()): Router {
  const router = Router();

  // Ciphertext, not JSON: the body is raw bytes and nothing parses it.
  const bytes = express.raw({ type: 'application/octet-stream', limit: maxFileBytes + 4096 });

  router.post(
    '/missing',
    ...validated({ body: fileQuerySchema }, async ({ body }, _req, res) => {
      const { userId } = authOf(res);
      res.json({
        missing: await files.missing(userId, body.hashes),
        usedBytes: await files.usedBytes(userId),
        quotaBytes: maxFileStoreBytes,
      });
    }),
  );

  router.put(
    '/:sha256',
    bytes,
    ...validated({ params: nameSchema }, async ({ params }, req, res) => {
      const { userId } = authOf(res);
      const { sha256 } = params;
      const { iv, plainBytes } = sealOf(req);
      const blob = req.body as Buffer;
      if (!Buffer.isBuffer(blob) || blob.length === 0) {
        throw new HttpError('validation_failed', 'The body must be the file');
      }

      // Already held: the name is the contents, so there is nothing to
      // replace and nothing to charge for.
      if (await files.has(userId, sha256)) {
        res.json({ sha256, bytes: blob.length, had: true });
        return;
      }
      const used = await files.usedBytes(userId);
      if (used + blob.length > maxFileStoreBytes) {
        throw new HttpError('quota_exceeded', 'This account has no room left for files');
      }
      await files.put({
        userId,
        sha256,
        bytes: blob.length,
        iv,
        plainBytes,
        blob: new Binary(blob),
        uploadedAt: now(),
      });
      res.status(201).json({ sha256, bytes: blob.length, had: false });
    }),
  );

  router.get(
    '/:sha256',
    ...validated({ params: nameSchema }, async ({ params }, _req, res) => {
      const { userId } = authOf(res);
      const doc = await files.get(userId, params.sha256);
      if (!doc) throw new HttpError('not_found', 'No such file');
      res
        .status(200)
        .type('application/octet-stream')
        .set(fileIvHeader, doc.iv)
        .set(filePlainBytesHeader, String(doc.plainBytes))
        .send(Buffer.from(doc.blob.buffer));
    }),
  );

  return router;
}
