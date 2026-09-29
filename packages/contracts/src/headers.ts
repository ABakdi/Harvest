/**
 * The file endpoints' own headers, in a module with no schema in it:
 * the web's public pages import these two names, and taking them from
 * the package root would load zod and every schema along with them.
 */

/**
 * The 12-byte nonce a file's ciphertext was sealed with, base64, sent
 * as a header rather than in the body so the body stays raw bytes.
 */
export const fileIvHeader = 'x-harvest-iv';

/**
 * The length of what was sealed, so a reader can check what it
 * decrypted: since Phase 7 the padded length, which the ciphertext's
 * own length already says, and never the file's.
 */
export const filePlainBytesHeader = 'x-harvest-plain-bytes';

/**
 * The key epoch a file was sealed under (`sync-key.ts`). An upload
 * without it, or with one that is not the account's, is refused with
 * 409 `key_changed` and nothing is stored.
 */
export const fileKeyEpochHeader = 'x-harvest-key-epoch';
