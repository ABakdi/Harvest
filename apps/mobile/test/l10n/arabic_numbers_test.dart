import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// Arabic counts in all their forms, and in Western digits only.
void main() {
  final ar = lookupAppLocalizations(const Locale('ar'));

  test('a count takes the form Arabic gives it', () {
    expect(ar.dayCount(0), 'لا أيام');
    expect(ar.dayCount(1), 'يوم واحد');
    expect(ar.dayCount(2), 'يومان');
    expect(ar.dayCount(5), '5 أيام');
    expect(ar.dayCount(15), '15 يومًا');
    expect(ar.dayCount(100), '100 يوم');
    expect(ar.gymExerciseCount(4, '4'), '4 تمارين');
    expect(ar.gymExerciseCount(12, '12'), '12 تمرينًا');
    expect(ar.scheduleEveryDays(2), 'كل يومين');
    expect(ar.scheduleEveryDays(3), 'كل 3 أيام');
    expect(ar.streakSemantics(0), 'السلسلة: لا أيام');
  });

  test('every Arabic plural has the zero, 3–10 and 11–99 forms', () {
    final missing = <String>[];
    final text = File('lib/l10n/app_ar.arb').readAsStringSync();
    for (final match in RegExp(
      r'^  "(\w+)": "(.*plural.*)",?$',
      multiLine: true,
    ).allMatches(text)) {
      final value = match.group(2)!;
      // Zero too: a count that can be 0 must not read "0 يوم" (U6-13).
      if (!value.contains('few{') ||
          !value.contains('many{') ||
          !value.contains('=0{')) {
        missing.add(match.group(1)!);
      }
    }
    expect(missing, isEmpty);
  });

  test('no string carries Eastern Arabic digits', () {
    for (final name in ['app_ar.arb', 'app_en.arb']) {
      final text = File('lib/l10n/$name').readAsStringSync();
      expect(RegExp('[٠-٩۰-۹]').hasMatch(text), isFalse, reason: name);
    }
    final web = File('../web/src/i18n/ar.json').readAsStringSync();
    expect(RegExp('[٠-٩۰-۹]').hasMatch(web), isFalse, reason: 'web ar.json');
  });
}
