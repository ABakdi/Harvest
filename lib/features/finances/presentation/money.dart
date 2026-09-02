import 'package:harvest/features/finances/domain/currency.dart';
import 'package:intl/intl.dart';

/// Formats minor units for display: 1250 → "12.50", 500 → "5".
String formatMinor(int minor) {
  final major = minor ~/ 100;
  final cents = minor % 100;
  if (cents == 0) return '$major';
  return '$major.${cents.toString().padLeft(2, '0')}';
}

final _grouped = NumberFormat('#,##0.##', 'en');

/// Display formatting with thousands grouping: 6666776 → "66,667.76".
/// Digits stay Latin in every locale so amounts line up.
String formatGrouped(int minor) => _grouped.format(minor / 100);

/// Symbol + grouped amount: "DA66,667.76".
String formatAmount(int minor, Currency currency) =>
    '${currency.symbol}${formatGrouped(minor)}';

/// Signed display: "+DA500" / "−DA500".
String formatSigned(int minor, Currency currency) =>
    '${minor >= 0 ? '+' : '−'}${formatAmount(minor.abs(), currency)}';

/// Parses user input ("12", "12.5", "12.50") into minor units.
/// Returns null for anything that isn't a positive amount.
int? parseToMinor(String input) {
  final cleaned = input.trim().replaceAll(',', '.');
  if (cleaned.isEmpty) return null;
  final parts = cleaned.split('.');
  if (parts.length > 2) return null;
  final major = int.tryParse(parts[0]);
  if (major == null || major < 0) return null;
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
