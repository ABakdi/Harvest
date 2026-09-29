/// Digits as Harvest reads them: whatever keyboard typed a number, it is
/// read in the ASCII digits 0–9. An Arabic keypad types ٠–٩ (U+0660–0669),
/// a Persian one ۰–۹ (U+06F0–06F9); both become the digits they are, and
/// everything else is left as it is.
///
/// The one normaliser for amounts and the sync PIN, the same as the
/// web's (`packages/core` `westernDigits`); `fixtures/digits.json` holds
/// the two together.
String westernDigits(String input) {
  final buffer = StringBuffer();
  for (final rune in input.runes) {
    if (rune >= 0x0660 && rune <= 0x0669) {
      buffer.writeCharCode(rune - 0x0660 + 0x30);
    } else if (rune >= 0x06F0 && rune <= 0x06F9) {
      buffer.writeCharCode(rune - 0x06F0 + 0x30);
    } else {
      buffer.writeCharCode(rune);
    }
  }
  return buffer.toString();
}
