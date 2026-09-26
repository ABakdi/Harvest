/**
 * The sync secret's rule ([[Accounts]] AC7), the same on every client: a
 * PIN of 4 to 6 ASCII digits, or a passphrase of 8 characters or more.
 *
 * - Anything made only of ASCII digits is read as a PIN, so 3 or 7
 *   digits is a PIN problem, never a short passphrase.
 * - Characters are Unicode code points (the phone counts `runes`), and
 *   nothing is trimmed: the secret is used exactly as typed.
 *
 * The key is derived from it unchanged (`deriveSyncKey`).
 * `fixtures/sync-secret.json` pins the cases, and the phone's tests read
 * the same file.
 */
export type SyncSecretProblem = 'empty' | 'pinTooShort' | 'pinTooLong' | 'passphraseTooShort';

export const syncPinMinLength = 4;
export const syncPinMaxLength = 6;
export const syncPassphraseMinLength = 8;

/** Whether [secret] is all ASCII digits, the shape of a PIN. */
export function isSyncPin(secret: string): boolean {
  return /^[0-9]+$/.test(secret);
}

/** Why [secret] can't be the sync secret, or null when it can. */
export function syncSecretProblem(secret: string): SyncSecretProblem | null {
  if (secret.length === 0) return 'empty';
  if (isSyncPin(secret)) {
    if (secret.length < syncPinMinLength) return 'pinTooShort';
    if (secret.length > syncPinMaxLength) return 'pinTooLong';
    return null;
  }
  return [...secret].length < syncPassphraseMinLength ? 'passphraseTooShort' : null;
}
