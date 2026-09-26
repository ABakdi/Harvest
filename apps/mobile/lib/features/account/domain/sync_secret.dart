/// Why a sync secret cannot be used, by the names the web gives them
/// (`packages/contracts/src/sync-secret.ts`).
enum SyncSecretProblem { empty, pinTooShort, pinTooLong, passphraseTooShort }

const syncPinMinLength = 4;
const syncPinMaxLength = 6;
const syncPassphraseMinLength = 8;

final _asciiDigits = RegExp(r'^[0-9]+$');

/// Whether [secret] is all ASCII digits, the shape of a PIN.
bool isSyncPin(String secret) => _asciiDigits.hasMatch(secret);

/// The sync secret's rule ([[Accounts]] AC7), the same on every client:
/// a PIN of 4 to 6 digits, or a passphrase of 8 characters or more.
///
/// Anything made only of ASCII digits is read as a PIN, so seven digits
/// is a long PIN, never a short passphrase. Characters are code points,
/// and nothing is trimmed: the key is made from the secret as typed.
/// `fixtures/sync-secret.json` pins the cases.
SyncSecretProblem? syncSecretProblem(String secret) {
  if (secret.isEmpty) return SyncSecretProblem.empty;
  if (isSyncPin(secret)) {
    if (secret.length < syncPinMinLength) return SyncSecretProblem.pinTooShort;
    if (secret.length > syncPinMaxLength) return SyncSecretProblem.pinTooLong;
    return null;
  }
  return secret.runes.length < syncPassphraseMinLength
      ? SyncSecretProblem.passphraseTooShort
      : null;
}
