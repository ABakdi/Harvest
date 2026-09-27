/// Why a sync secret cannot be used, by the names the web gives them
/// (`packages/contracts/src/sync-secret.ts`).
enum SyncSecretProblem {
  empty,
  pinTooShort,
  pinTooLong,
  pinTooSimple,
  passphraseTooShort,
}

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
/// is a long PIN, never a short passphrase. A PIN a guesser would try
/// first — one digit repeated, a run up or down, two digits in turn —
/// is refused. Characters are code points, and nothing is trimmed: the
/// key is made from the secret as typed. `fixtures/sync-secret.json`
/// pins the cases.
SyncSecretProblem? syncSecretProblem(String secret) {
  if (secret.isEmpty) return SyncSecretProblem.empty;
  if (isSyncPin(secret)) {
    if (secret.length < syncPinMinLength) return SyncSecretProblem.pinTooShort;
    if (secret.length > syncPinMaxLength) return SyncSecretProblem.pinTooLong;
    return isSimplePin(secret) ? SyncSecretProblem.pinTooSimple : null;
  }
  return secret.runes.length < syncPassphraseMinLength
      ? SyncSecretProblem.passphraseTooShort
      : null;
}

/// Whether a PIN is one of the first a guesser tries: every digit the
/// same (`0000`), a run of consecutive digits up or down (`1234`,
/// `987654`), or two digits taking turns (`1212`, `12121`).
bool isSimplePin(String pin) {
  final digits = [for (final unit in pin.codeUnits) unit - 0x30];
  if (digits.length < 2) return false;
  final step = digits[1] - digits[0];
  var run = step.abs() <= 1;
  for (var i = 1; run && i < digits.length; i++) {
    run = digits[i] - digits[i - 1] == step;
  }
  var turns = true;
  for (var i = 0; turns && i < digits.length; i++) {
    turns = digits[i] == digits[i % 2];
  }
  return run || turns;
}
