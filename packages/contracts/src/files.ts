import { z } from 'zod';

/**
 * Pictures and recordings, content-addressed ([[Sync-API]]).
 *
 * A file is named by the SHA-256 of its **plaintext**, so two devices
 * holding the same picture name it the same thing and it travels once.
 * What the server stores is the ciphertext, sealed with the private
 * tier's own key — it can check the shape and the size and nothing
 * else, and it cannot verify the name it is given, which is only ever
 * a claim about the uploader's own data.
 */
export const fileHashSchema = z
  .string()
  .regex(/^[0-9a-f]{64}$/, { message: 'Not a SHA-256 hash in lowercase hex' });

/** The biggest single file, before encryption: a minute of 4K is not a memory. */
export const maxFileBytes = 25 * 1024 * 1024;

/** What one account may keep in files, all told. */
export const maxFileStoreBytes = 2 * 1024 * 1024 * 1024;

/** How many hashes one "do you have these?" question may carry. */
export const maxFileQuery = 500;

/**
 * The 12-byte nonce a file's ciphertext was sealed with, base64, sent
 * as a header rather than in the body so the body stays raw bytes.
 */
export const fileIvHeader = 'x-harvest-iv';

/** The plaintext's own length, so a reader can check what it decrypted. */
export const filePlainBytesHeader = 'x-harvest-plain-bytes';

export const fileUploadedSchema = z.object({
  sha256: fileHashSchema,
  /** The stored ciphertext's length. */
  bytes: z.int().nonnegative(),
  /** True when the server already had it and the bytes were not needed. */
  had: z.boolean(),
});
export type FileUploaded = z.infer<typeof fileUploadedSchema>;

export const fileQuerySchema = z.object({
  hashes: z.array(fileHashSchema).max(maxFileQuery),
});
export type FileQuery = z.infer<typeof fileQuerySchema>;

export const fileQueryResultSchema = z.object({
  /** The ones the server does not have, so only those are uploaded. */
  missing: z.array(fileHashSchema),
  /** What the account is using, and what it may use. */
  usedBytes: z.int().nonnegative(),
  quotaBytes: z.int().nonnegative(),
});
export type FileQueryResult = z.infer<typeof fileQueryResultSchema>;
