/// Formats minor units for display: 1250 → "12.50", 500 → "5".
String formatMinor(int minor) {
  final major = minor ~/ 100;
  final cents = minor % 100;
  if (cents == 0) return '$major';
  return '$major.${cents.toString().padLeft(2, '0')}';
}

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
