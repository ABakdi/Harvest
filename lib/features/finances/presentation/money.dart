import 'package:harvest/features/finances/domain/currency.dart';
import 'package:intl/intl.dart';

/// The largest amount the app will accept, in major units. Beyond this
/// an entry is a typo, and past 2^63/100 it would silently wrap.
const maxMajorUnits = 1000000000000;

/// Formats minor units for display: 1250 → "12.50", 500 → "5",
/// -50 → "-0.50".
String formatMinor(int minor) {
  final sign = minor < 0 ? '-' : '';
  final abs = minor.abs();
  final major = abs ~/ 100;
  final cents = abs % 100;
  if (cents == 0) return '$sign$major';
  return '$sign$major.${cents.toString().padLeft(2, '0')}';
}

final _grouped = NumberFormat('#,##0.00', 'en');

/// Display formatting with thousands grouping: 6666776 → "66,667.76",
/// 50000 → "500". Whole amounts drop the cents; digits stay Latin in
/// every locale so columns line up.
String formatGrouped(int minor) {
  final text = _grouped.format(minor / 100);
  return text.endsWith('.00') ? text.substring(0, text.length - 3) : text;
}

/// Symbol + grouped amount: "DA66,667.76".
String formatAmount(int minor, Currency currency) =>
    '${currency.symbol}${formatGrouped(minor)}';

/// Signed display: "+DA500" / "−DA500".
String formatSigned(int minor, Currency currency) =>
    '${minor >= 0 ? '+' : '−'}${formatAmount(minor.abs(), currency)}';

/// Arabic-Indic and extended Arabic-Indic digits → ASCII, so a number
/// typed on an Arabic keyboard parses like any other.
String _latinDigits(String input) {
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

/// Parses user input ("12", "12.5", "12,50", "1,234") into minor units.
/// Returns null for anything that isn't a positive amount within
/// [maxMajorUnits]. A comma is a thousands separator when it is
/// followed by exactly three digits, and a decimal point otherwise.
int? parseToMinor(String input) {
  var text = _latinDigits(input).trim();
  if (text.isEmpty || text.startsWith('+') || text.startsWith('-')) return null;

  // "1,234" / "1,234,567" are grouped; "1,5" is a decimal comma.
  if (RegExp(r'^\d{1,3}(,\d{3})+(\.\d+)?$').hasMatch(text)) {
    text = text.replaceAll(',', '');
  } else {
    text = text.replaceAll(',', '.');
  }

  final parts = text.split('.');
  if (parts.length > 2) return null;
  final major = int.tryParse(parts[0]);
  if (major == null || major < 0 || major > maxMajorUnits) return null;
  var cents = 0;
  if (parts.length == 2) {
    final fraction = parts[1];
    if (fraction.isEmpty || fraction.length > 2) return null;
    final parsed = int.tryParse(fraction);
    if (parsed == null) return null;
    cents = fraction.length == 1 ? parsed * 10 : parsed;
  }
  final total = major * 100 + cents;
  return total > 0 ? total : null;
}

/// The default-currency equivalent as "≈DA1,080", or null when the
/// amount is already in the default currency or the rate is unknown.
String? conversionCaption({
  required int minor,
  required Currency currency,
  required Rates rates,
}) {
  if (currency == rates.defaultCurrency) return null;
  final converted = rates.toDefault(minor, currency);
  if (converted == null) return null;
  return '≈${formatAmount(converted, rates.defaultCurrency)}';
}

/// The amount in its own currency, with the default-currency
/// conversion in parentheses when known (P5).
String amountWithConversion({
  required int minor,
  required Currency currency,
  required Rates rates,
}) {
  final base = formatAmount(minor, currency);
  final caption = conversionCaption(
    minor: minor,
    currency: currency,
    rates: rates,
  );
  return caption == null ? base : '$base  ($caption)';
}
