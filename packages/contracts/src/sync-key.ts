import { z } from 'zod';
import { passwordMaxLength } from './auth.js';

/**
 * The account's half of the private tier's key, and the check that says
 * whether a PIN is the account's PIN ([[Sync-API]], [[Accounts]]).
 *
 * - `GET /v1/me/sync-key` answers the salt, the account's `keyShare`
 *   (32 random bytes the server keeps sealed under a key of its own, and
 *   hands only to a signed-in, verified session) and the stored check,
 *   or null when no device has chosen a PIN yet.
 * - `PUT /v1/me/sync-key/check` stores the first check: 201 with it, or
 *   409 with the one already stored, which the device then verifies its
 *   PIN against. The first device wins.
 *
 * - `DELETE /v1/me/sync-key` starts the private tier over (a forgotten
 *   PIN, or a new one): with the account's password, it drops the check,
 *   the key share, every private-tier row and every file. 204.
 *
 * The check is a version 2 envelope sealing `harvest-key-check` with the
 * additional data `key-check` (`crypto.ts`). The server stores it and
 * hands it back; it has no key to open it.
 */

const base64 = z.base64({ message: 'Not base64' });

/** How many bytes a base64 string decodes to, from its length alone. */
function decodedLength(value: string): number {
  const padding = value.endsWith('==') ? 2 : value.endsWith('=') ? 1 : 0;
  return (value.length / 4) * 3 - padding;
}

/** The key share's length, in bytes. */
export const keyShareBytes = 32;

/**
 * A sealed key check: `harvest-key-check` (17 bytes) and the 16-byte
 * tag are 33 bytes, 44 characters of base64. The cap leaves room and
 * nothing more.
 */
export const keyCheckSchema = z.strictObject({
  v: z.literal(2),
  iv: base64.refine((value) => decodedLength(value) === 12, { message: 'The nonce must be 12 bytes' }),
  ct: base64.min(1).max(256),
});
export type KeyCheck = z.infer<typeof keyCheckSchema>;

export const syncKeyResultSchema = z.object({
  /** The account's salt, the same as `Me.syncSalt`. */
  salt: z.string(),
  /** 32 bytes, base64. */
  keyShare: base64.refine((value) => decodedLength(value) === keyShareBytes, {
    message: `The key share must be ${keyShareBytes} bytes`,
  }),
  /** Null until a device has chosen a PIN: the next one chooses, every later one enters. */
  check: keyCheckSchema.nullable(),
});
export type SyncKeyResult = z.infer<typeof syncKeyResultSchema>;

export const putKeyCheckBodySchema = z.strictObject({ check: keyCheckSchema });
export type PutKeyCheckBody = z.infer<typeof putKeyCheckBodySchema>;

/** 201: the check this device sent is now the account's. */
export const keyCheckStoredSchema = z.object({ check: keyCheckSchema });
export type KeyCheckStored = z.infer<typeof keyCheckStoredSchema>;

/** 409: another device chose first; its check comes back beside the error. */
export const keyCheckConflictSchema = z.object({
  error: z.object({ code: z.literal('conflict'), message: z.string() }),
  check: keyCheckSchema,
});
export type KeyCheckConflict = z.infer<typeof keyCheckConflictSchema>;

/**
 * Starting over asks for the password, like deleting the account: it
 * drops everything private the server holds.
 */
export const deleteSyncKeyBodySchema = z.strictObject({ password: z.string().min(1).max(passwordMaxLength) });
export type DeleteSyncKeyBody = z.infer<typeof deleteSyncKeyBodySchema>;
