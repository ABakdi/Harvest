import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// The farmer heatmap's label counts in words that agree with the
/// number: "1 active days in the last 27 weeks" read as a slip.
void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final ar = lookupAppLocalizations(const Locale('ar'));

  String label(AppLocalizations l10n, int days, int weeks) =>
      l10n.activitySemantics(days, l10n.activityLastWeeks(weeks));

  test('English agrees in number', () {
    expect(label(en, 1, 27), '1 active day in the last 27 weeks');
    expect(label(en, 5, 27), '5 active days in the last 27 weeks');
    expect(label(en, 0, 27), 'No active days in the last 27 weeks');
    expect(label(en, 3, 1), '3 active days in the last week');
  });

  test('Arabic takes its own plural forms', () {
    expect(label(ar, 1, 27), 'يوم نشط واحد في آخر 27 أسبوعًا');
    expect(label(ar, 2, 3), 'يومان نشطان في آخر 3 أسابيع');
  });
}
