import { pipeline } from 'node:stream/promises';
import {
  fileIvHeader,
  fileKeyEpochHeader,
  filePlainBytesHeader,
  fileQuerySchema,
  fileHashSchema,
  maxFileBytes,
  maxFileStoreBytes,
} from '@harvest/contracts';
import express, { Router } from 'express';
import { z } from 'zod';
import type { FilesRepository } from '../db/files.js';
import type { RecordsRepository } from '../db/records.js';
import type { TotalsRepository } from '../db/totals.js';
import type { UsersRepository } from '../db/users.js';
import { authOf } from '../http/authenticate.js';
import { HttpError, unauthorized, validationError } from '../http/errors.js';
import { validated } from '../http/validate.js';
import { unnamedFileGraceMs } from '../sync/file-sweep.js';
import type { KeyedMutex } from '../sync/mutex.js';

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

export interface FileDeps {
  files: FilesRepository;
  records: RecordsRepository;
  users: UsersRepository;
  totals: TotalsRepository;
  /** The account lock pushes run under ([[SyncService]]). */
  lock: KeyedMutex;
  now?: () => Date;
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
export function fileRoutes({ files, records, users, totals, lock, now = () => new Date() }: FileDeps): Router {
  const router = Router();

  // Ciphertext, not JSON: the body is raw bytes and nothing parses it.
  const bytes = express.raw({ type: 'application/octet-stream', limit: maxFileBytes + 4096 });
  // 500 hashes of 64 characters, and room around them.
  const json = express.json({ limit: '64kb' });

  router.post(
    '/missing',
    json,
    ...validated({ body: fileQuerySchema }, async ({ body }, _req, res) => {
      const { userId } = authOf(res);
      res.json({
        missing: await files.missing(userId, body.hashes, now()),
        // The running total, not a sum over every file (SV-06).
        usedBytes: await totals.current(userId, 'fileBytes', () => files.usedBytes(userId)),
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
      const epoch = Number(req.get(fileKeyEpochHeader) ?? NaN);
      const blob = req.body as Buffer;
      if (!Buffer.isBuffer(blob) || blob.length === 0) {
        throw new HttpError('validation_failed', 'The body must be the file');
      }

      // Under the account's lock: an account being deleted is not written
      // back to, and the room is charged before the bytes land, so two
      // uploads at once cannot both take the last of it (audit S5-08).
      const had = await lock.run(userId.toHexString(), async () => {
        // Deleted while the bytes were on their way: nothing is written
        // back for it (Q6-02).
        const user = await users.findById(userId);
        if (!user) throw unauthorized();
        // Sealed under a key the account no longer has (S6-07): nothing
        // is stored, not even as "held".
        if (epoch !== (user.keyEpoch ?? 1)) {
          throw new HttpError('key_changed', 'Sealed under a key this account no longer has; ask for the PIN again');
        }
        // Already held: the name is the contents, so there is nothing to
        // replace and nothing to charge for.
        if (await files.claim(userId, sha256, now())) return true;
        const room = await totals.reserve(userId, 'fileBytes', blob.length, maxFileStoreBytes, () =>
          files.usedBytes(userId),
        );
        if (!room) throw new HttpError('quota_exceeded', 'This account has no room left for files');
        let stored = false;
        try {
          const at = now();
          stored = await files.put(
            { userId, sha256, bytes: blob.length, iv, plainBytes, uploadedAt: at, claimedAt: at },
            blob,
          );
        } finally {
          if (!stored) await totals.release(userId, 'fileBytes', blob.length);
        }
        return !stored;
      });
      if (had) {
        res.json({ sha256, bytes: blob.length, had: true });
        return;
      }
      res.status(201).json({ sha256, bytes: blob.length, had: false });
    }),
  );

  router.get(
    '/:sha256',
    ...validated({ params: nameSchema }, async ({ params }, _req, res) => {
      const { userId } = authOf(res);
      const doc = await files.get(userId, params.sha256);
      const stream = doc ? await files.bytesOf(doc) : null;
      if (!doc || !stream) throw new HttpError('not_found', 'No such file');
      // A chunk at a time: a download holds a chunk in memory, not the
      // file (P6-05).
      res
        .status(200)
        .type('application/octet-stream')
        .set('Content-Length', String(doc.bytes))
        .set(fileIvHeader, doc.iv)
        .set(filePlainBytesHeader, String(doc.plainBytes));
      await pipeline(stream, res);
    }),
  );

  /**
   * Lets go of a file the account no longer needs, and gives its room
   * back, by the sweep's own rule ([[FileSweeper]]): not while a row,
   * live or in the trash, still names it, and not within 30 days of its
   * upload or of a "missing?" that said the server has it, because
   * another device may be about to name it. Either answers 409, and the
   * sweep lets it go later. Deleting one that is not there is done all
   * the same: 204.
   */
  router.delete(
    '/:sha256',
    ...validated({ params: nameSchema }, async ({ params }, _req, res) => {
      const { userId } = authOf(res);
      await lock.run(userId.toHexString(), async () => {
        const doc = await files.times(userId, params.sha256);
        if (!doc) return;
        if (await records.namesFile(userId, params.sha256)) {
          throw new HttpError('conflict', 'A row still names this file; it stays until none does');
        }
        const since = now().getTime() - unnamedFileGraceMs;
        const touched = Math.max(doc.uploadedAt.getTime(), doc.claimedAt?.getTime() ?? 0);
        if (touched > since) {
          throw new HttpError('conflict', 'This file was sent or asked about recently; the sweep lets it go later');
        }
        const bytes = await files.delete(userId, params.sha256);
        if (bytes !== null) await totals.release(userId, 'fileBytes', bytes);
      });
      res.status(204).end();
    }),
  );

  return router;
}
