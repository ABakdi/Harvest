/**
 * The sync secret's rule ([[Accounts]] AC7), the same on every client: a
 * PIN of 4 to 6 ASCII digits, or a passphrase of 8 characters or more.
 *
 * - Anything made only of ASCII digits is read as a PIN, so 3 or 7
 *   digits is a PIN problem, never a short passphrase.
 * - Characters are Unicode code points (the phone counts `runes`), and
 *   nothing is trimmed: the secret is used exactly as typed.
 *
 * - A PIN anyone would try first is refused (`pinTooSimple`): one digit
 *   repeated (`0000`), a run up or down (`1234`, `987654`), or two digits
 *   taking turns (`1212`, `12121`).
 *
 * The key is derived from it unchanged (`deriveSyncKeyV2`).
 * `fixtures/sync-secret.json` pins the cases, and the phone's tests read
 * the same file.
 */
export type SyncSecretProblem = 'empty' | 'pinTooShort' | 'pinTooLong' | 'pinTooSimple' | 'passphraseTooShort';

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
    return isSimplePin(secret) ? 'pinTooSimple' : null;
  }
  return [...secret].length < syncPassphraseMinLength ? 'passphraseTooShort' : null;
}

/**
 * Whether a PIN is one of the first a guesser tries: every digit the
 * same, a run of consecutive digits up or down, or two digits in turn.
 */
export function isSimplePin(pin: string): boolean {
  const digits = [...pin].map(Number);
  if (digits.length < 2) return false;
  const step = digits[1]! - digits[0]!;
  const run = (step === 1 || step === -1 || step === 0) && digits.every((d, i) => i === 0 || d - digits[i - 1]! === step);
  const turns = digits.every((d, i) => d === digits[i % 2]);
  return run || turns;
}

// ------------------------------------------------------ Phase 7: strength

/**
 * How long a secret would stand against someone holding both the
 * database and the server's environment (Phase 7, M7.5): they can try
 * secrets offline, each one costing the 600,000 rounds of PBKDF2. At
 * about ten thousand tries a second on one good graphics card, a PIN of
 * six digits falls in under two minutes; four random words take
 * thousands of years. `fixtures/sync-secret.json` pins the cases, and
 * the phone reads the same file.
 */
export const guessesPerSecond = 10_000;

export const maxStrengthSeconds = 1e15;

export type SyncSecretLevel = 'pin' | 'weak' | 'fair' | 'strong';

export interface SyncSecretStrength {
  /** An estimate of the secret's entropy, in bits, rounded down. */
  bits: number;
  level: SyncSecretLevel;
  /**
   * How long trying half of everything that strong would take, at
   * [guessesPerSecond], in seconds, and never past [maxStrengthSeconds]
   * (some thirty million years), which is as good as for ever.
   */
  seconds: number;
}

/** Passphrases people pick first; lowercase, 8 characters or more. */
const common = new Set([
  'password', 'password1', 'password123', '12345678', '123456789', '1234567890', 'qwertyui', 'qwertyuiop',
  'iloveyou', 'sunshine', 'princess', 'football', 'baseball', 'welcome1', 'abcdefgh', 'trustno1', 'superman',
  'starwars', 'whatever', 'letmein1', 'passw0rd', 'azertyui', 'motdepasse', 'harvest1', 'harvesting',
  'bismillah', 'algerie1', 'qwerty123', '11111111', '00000000', 'computer', 'internet', 'michelle',
]);

/**
 * The estimate: for a PIN, its digits; for a passphrase, the better of
 * two readings — as words (about 12.9 bits each, a word from a list of
 * 7,776, for three or more words of three letters or more) and as
 * characters (half the bits of its length over the kinds of character it
 * uses, since people are not random). A passphrase on the common list,
 * or one of three characters or fewer repeated, is worth 10 bits.
 */
export function syncSecretStrength(secret: string): SyncSecretStrength {
  const chars = [...secret];
  let bits: number;
  if (isSyncPin(secret)) {
    bits = chars.length * Math.log2(10);
  } else {
    const words = secret.split(/[\s\-_.,;:+]+/u).filter((word) => [...word].length >= 3);
    const wordBits = words.length >= 3 ? words.length * Math.log2(7776) : 0;
    let pool = 0;
    if (/[a-z]/.test(secret)) pool += 26;
    if (/[A-Z]/.test(secret)) pool += 26;
    if (/[0-9]/.test(secret)) pool += 10;
    if (/[!-/:-@[-`{-~ ]/.test(secret)) pool += 33;
    if (chars.some((char) => char.codePointAt(0)! > 0x7f)) pool += 100;
    const charBits = pool > 0 ? (chars.length * Math.log2(pool)) / 2 : 0;
    bits = Math.max(wordBits, charBits);
    if (common.has(secret.toLowerCase()) || new Set(chars).size <= 3) bits = Math.min(bits, 10);
  }
  const whole = Math.floor(bits);
  const level: SyncSecretLevel = isSyncPin(secret) ? 'pin' : whole < 40 ? 'weak' : whole < 50 ? 'fair' : 'strong';
  return { bits: whole, level, seconds: Math.min(Math.round(2 ** whole / 2 / guessesPerSecond), maxStrengthSeconds) };
}
