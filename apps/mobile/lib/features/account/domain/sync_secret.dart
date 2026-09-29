import 'dart:math' as math;

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

// ------------------------------------------------------ Phase 7: strength

/// How strong a sync secret is, as `syncSecretStrength` in
/// `packages/contracts/src/sync-secret.ts` has it: how long it would
/// stand against someone holding both the database and the server's
/// environment, trying secrets offline at the cost of PBKDF2's 600,000
/// rounds each ([[Accounts]], Phase 7 M7.5). `fixtures/sync-secret.json`
/// pins the cases.
enum SyncSecretLevel { pin, weak, fair, strong }

/// About ten thousand tries a second, on one good graphics card.
const guessesPerSecond = 10000;

/// Some thirty million years: as good as for ever.
const maxStrengthSeconds = 1e15;

typedef SyncSecretStrength = ({int bits, SyncSecretLevel level, int seconds});

/// Passphrases people pick first; lowercase, 8 characters or more.
const _common = {
  'password', 'password1', 'password123', '12345678', '123456789', //
  '1234567890', 'qwertyui', 'qwertyuiop', 'iloveyou', 'sunshine',
  'princess', 'football', 'baseball', 'welcome1', 'abcdefgh', 'trustno1',
  'superman', 'starwars', 'whatever', 'letmein1', 'passw0rd', 'azertyui',
  'motdepasse', 'harvest1', 'harvesting', 'bismillah', 'algerie1',
  'qwerty123', '11111111', '00000000', 'computer', 'internet', 'michelle',
};

final _wordBreaks = RegExp(r'[\s\-_.,;:+]+', unicode: true);
final _lower = RegExp('[a-z]');
final _upper = RegExp('[A-Z]');
final _digit = RegExp('[0-9]');
final _symbol = RegExp(r'[!-/:-@\[-`{-~ ]');

double _log2(num value) => math.log(value) / math.ln2;

/// The estimate: for a PIN, its digits; for a passphrase, the better of
/// two readings — as words (about 12.9 bits each, a word from a list of
/// 7,776, for three or more words of three letters or more) and as
/// characters (half the bits of its length over the kinds of character
/// it uses, since people are not random). A passphrase on the common
/// list, or one of three characters or fewer repeated, is worth 10 bits.
SyncSecretStrength syncSecretStrength(String secret) {
  final chars = secret.runes.toList();
  double bits;
  final pin = isSyncPin(secret);
  if (pin) {
    bits = chars.length * _log2(10);
  } else {
    final words = secret
        .split(_wordBreaks)
        .where((word) => word.runes.length >= 3)
        .length;
    final wordBits = words >= 3 ? words * _log2(7776) : 0.0;
    var pool = 0;
    if (_lower.hasMatch(secret)) pool += 26;
    if (_upper.hasMatch(secret)) pool += 26;
    if (_digit.hasMatch(secret)) pool += 10;
    if (_symbol.hasMatch(secret)) pool += 33;
    if (chars.any((rune) => rune > 0x7f)) pool += 100;
    final charBits = pool > 0 ? chars.length * _log2(pool) / 2 : 0.0;
    bits = math.max(wordBits, charBits);
    if (_common.contains(secret.toLowerCase()) || chars.toSet().length <= 3) {
      bits = math.min(bits, 10);
    }
  }
  final whole = bits.floor();
  final level = pin
      ? SyncSecretLevel.pin
      : whole < 40
      ? SyncSecretLevel.weak
      : whole < 50
      ? SyncSecretLevel.fair
      : SyncSecretLevel.strong;
  final seconds = math
      .min(math.pow(2.0, whole) / 2 / guessesPerSecond, maxStrengthSeconds)
      .round();
  return (bits: whole, level: level, seconds: seconds);
}
