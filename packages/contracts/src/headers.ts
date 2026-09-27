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

/** The plaintext's own length, so a reader can check what it decrypted. */
export const filePlainBytesHeader = 'x-harvest-plain-bytes';
