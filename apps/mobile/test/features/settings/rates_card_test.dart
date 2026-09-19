import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/features/finances/data/rates_service.dart';
import 'package:harvest/features/settings/presentation/rates_card.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// [[Audit-v2]] U3-02: the card must show the stored rates, and must
/// not take a field that has not loaded yet for a rate I cleared.
void main() {
  testWidgets('fills from the first data and never saves before it', (
    tester,
  ) async {
    final stored = StreamController<Map<String, String>>();
    addTearDown(stored.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [rateSettingsProvider.overrideWith((ref) => stored.stream)],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: SingleChildScrollView(child: RatesCard())),
        ),
      ),
    );

    // Into a field and out again while the rates are still loading. A
    // save here would reach for the real settings repository and throw.
    final fields = find.byType(TextField);
    await tester.tap(fields.first);
    await tester.pump();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    expect(tester.takeException(), isNull);

    stored.add({RateKeys.dzdPerUsd: '240', RateKeys.dzdPerEur: '260'});
    await tester.pump();
    await tester.pump();

    expect(
      tester.widget<TextField>(fields.at(0)).controller!.text,
      '240',
    );
    expect(
      tester.widget<TextField>(fields.at(1)).controller!.text,
      '260',
    );

    // Into a loaded field and out again, unchanged: still no save.
    await tester.tap(fields.first);
    await tester.pump();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
