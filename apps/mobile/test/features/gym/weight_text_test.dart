import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/ui/format.dart';
import 'package:harvest/features/gym/presentation/weight_text.dart';
import 'package:harvest/features/health/domain/body_weight.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// A weight is written in the language on screen, and a weight in a
/// field is written in the language the field is parsed back with —
/// which are not the same language ([[Audit-v2]] U3-18, U3-19).
void main() {
  Future<BuildContext> contextIn(WidgetTester tester, Locale locale) async {
    late BuildContext captured;
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            captured = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return captured;
  }

  testWidgets('a load carries the language it is read in', (tester) async {
    final english = await contextIn(tester, const Locale('en'));
    expect(formatLoad(english, 82500, WeightUnit.kg), '82.5 kg');
    expect(formatLoad(english, 100000, WeightUnit.kg), '100 kg');

    final arabic = await contextIn(tester, const Locale('ar'));
    final load = formatLoad(arabic, 82500, WeightUnit.kg);
    expect(load, contains('كغ'));
    expect(load, isNot(contains('kg')));
    // The digits stay Western, as money's do ([[Finances]]).
    expect(load, contains('82.5'));
  });

  testWidgets('a big number is grouped, not run together', (tester) async {
    final english = await contextIn(tester, const Locale('en'));
    expect(formatNumber(english, 1240), '1,240');
    expect(formatNumber(english, 12.04, decimals: 2), '12.04');
    expect(formatNumber(english, 12.40, decimals: 2), '12.4');
  });

  test('a field gets a number it can be parsed back from', () {
    // 100 kg in pounds is 220.46226218487757, which is what the field
    // used to be filled with.
    final value = loadFieldValue(100000, WeightUnit.lb);
    expect(value, '220.46');
    expect(double.tryParse(value), isNotNull);
    expect(loadFieldValue(100000, WeightUnit.kg), '100');
    expect(loadFieldValue(82500, WeightUnit.kg), '82.5');
  });
}
