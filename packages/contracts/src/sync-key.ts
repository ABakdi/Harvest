import { z } from 'zod';
import { passwordMaxLength } from './auth.js';

/**
 * The account's half of the private tier's key, the check that says
 * whether a PIN is the account's PIN, and the proof a device shows to be
 * handed the half ([[Sync-API]], [[Accounts]]).
 *
 * - `GET /v1/me/sync-key` answers the salt, whether a PIN is set, and
 *   the key epoch. While none is set it also answers the key share:
 *   nothing is protected yet, and the first device needs it to choose.
 * - `POST /v1/me/sync-key/unlock` takes the PIN proof and, when it is
 *   the account's, answers the key share, the key check and the epoch.
 *   A wrong proof is 403 `wrong_pin` with the tries left; past the limit
 *   (5 wrong in 15 minutes, 20 in a day) 429 with `Retry-After`.
 * - `PUT /v1/me/sync-key` sets the PIN, only while none is set: the
 *   verifier and the key check, 201 with the epoch; 409 when another
 *   device chose first.
 * - `DELETE /v1/me/sync-key` starts the private tier over (a forgotten
 *   PIN, or a new one): with the account's password, it drops the
 *   verifier, the check, the key share, every private-tier row and every
 *   file, and moves the epoch on. 204.
 *
 * The proof is HKDF over the PIN's PBKDF2 base (`crypto.ts`
 * `pinProofOf`); the server keeps only its SHA-256, the verifier. The
 * check is a version 2 envelope sealing `harvest-key-check` with the
 * additional data `key-check`; the server stores it and cannot open it.
 *
 * The epoch names the key: it starts at 1 and moves on with every start
 * over. Every sealed push and every file upload says which epoch it was
 * sealed under, and the server refuses a stale one (`key_changed`).
 */

const base64 = z.base64({ message: 'Not base64' });

/** How many bytes a base64 string decodes to, from its length alone. */
function decodedLength(value: string): number {
  const padding = value.endsWith('==') ? 2 : value.endsWith('=') ? 1 : 0;
  return (value.length / 4) * 3 - padding;
}

const bytes = (length: number) =>
  base64.refine((value) => decodedLength(value) === length, { message: `Must be ${length} bytes` });

/** The key share's length, in bytes. */
export const keyShareBytes = 32;

/** The PIN proof's length, in bytes. */
export const pinProofBytes = 32;

export const keyEpochSchema = z.int().min(1);

/**
 * A sealed key check: `harvest-key-check` (17 bytes) and the 16-byte
 * tag are 33 bytes, 44 characters of base64. The cap leaves room and
 * nothing more.
 */
export const keyCheckSchema = z.strictObject({
  v: z.literal(2),
  iv: bytes(12),
  ct: base64.min(1).max(256),
});
export type KeyCheck = z.infer<typeof keyCheckSchema>;

/** SHA-256 of the PIN proof, lowercase hex. */
export const pinVerifierSchema = z.string().regex(/^[0-9a-f]{64}$/, { message: 'Not a SHA-256 in lowercase hex' });

/** `GET /v1/me/sync-key`. */
export const syncKeyStateSchema = z.discriminatedUnion('state', [
  z.object({
    state: z.literal('none'),
    salt: z.string(),
    epoch: keyEpochSchema,
    /** Only while no PIN is set: the first device chooses with it. */
    keyShare: bytes(keyShareBytes),
  }),
  z.object({
    state: z.literal('set'),
    salt: z.string(),
    epoch: keyEpochSchema,
  }),
]);
export type SyncKeyState = z.infer<typeof syncKeyStateSchema>;

/** `POST /v1/me/sync-key/unlock`. */
export const unlockBodySchema = z.strictObject({ proof: bytes(pinProofBytes) });
export type UnlockBody = z.infer<typeof unlockBodySchema>;

export const unlockResultSchema = z.object({
  keyShare: bytes(keyShareBytes),
  check: keyCheckSchema,
  epoch: keyEpochSchema,
});
export type UnlockResult = z.infer<typeof unlockResultSchema>;

/** 403 on a wrong proof: the error, and how many tries are left today. */
export const wrongPinSchema = z.object({
  error: z.object({ code: z.literal('wrong_pin'), message: z.string() }),
  triesLeft: z.int().nonnegative(),
});
export type WrongPin = z.infer<typeof wrongPinSchema>;

/** The unlock limit: wrong proofs per account. */
export const unlockLimits = {
  shortWindowMs: 15 * 60_000,
  shortWindowTries: 5,
  dayMs: 24 * 60 * 60_000,
  dayTries: 20,
} as const;

/** `PUT /v1/me/sync-key`: the first device's PIN. */
export const setSyncKeyBodySchema = z.strictObject({
  verifier: pinVerifierSchema,
  check: keyCheckSchema,
});
export type SetSyncKeyBody = z.infer<typeof setSyncKeyBodySchema>;

export const syncKeySetSchema = z.object({ epoch: keyEpochSchema });
export type SyncKeySet = z.infer<typeof syncKeySetSchema>;

/**
 * `DELETE /v1/me/sync-key`: starting over asks for the password, like
 * deleting the account: it drops everything private the server holds.
 */
export const deleteSyncKeyBodySchema = z.strictObject({ password: z.string().min(1).max(passwordMaxLength) });
export type DeleteSyncKeyBody = z.infer<typeof deleteSyncKeyBodySchema>;
