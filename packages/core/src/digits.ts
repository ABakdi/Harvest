/**
 * Digits as Harvest reads them: whatever keyboard typed a number, it is
 * read in the ASCII digits 0–9 ([[Accounts]], [[Finances]]). An Arabic
 * keypad types the Arabic-Indic digits ٠–٩ (U+0660–0669), a Persian one
 * the extended ۰–۹ (U+06F0–06F9); both become the digits they are, and
 * everything else is left as it is.
 *
 * The one normaliser for amounts, the sync PIN and anything else typed
 * as a number, on the web and on the phone (`western_digits.dart`);
 * `fixtures/digits.json` holds them together.
 */
export function westernDigits(input: string): string {
  return input.replace(/[٠-٩۰-۹]/g, (digit) => {
    const code = digit.charCodeAt(0);
    return String(code - (code >= 0x06f0 ? 0x06f0 : 0x0660));
  });
}
