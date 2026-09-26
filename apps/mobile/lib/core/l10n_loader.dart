import 'dart:convert';
import 'dart:ui' show Locale;

import 'package:harvest/core/db/database.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// Resolves localized strings outside the widget tree (notifications,
/// background jobs) from the saved language setting.
Future<AppLocalizations> localizationsFromSettings(HarvestDatabase db) async {
  final row = await (db.select(
    db.kvSettings,
  )..where((s) => s.key.equals('locale'))).getSingleOrNull();
  var code = 'en';
  if (row != null && jsonDecode(row.valueJson) == 'ar') code = 'ar';
  return lookupAppLocalizations(Locale(code));
}
