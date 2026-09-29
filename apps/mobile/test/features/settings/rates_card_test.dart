import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/features/finances/data/rates_service.dart';
import 'package:harvest/features/finances/domain/currency.dart';
import 'package:harvest/features/finances/presentation/finance_providers.dart';
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
        overrides: [
          rateSettingsProvider.overrideWith((ref) => stored.stream),
          defaultCurrencyProvider.overrideWith((ref) => Currency.dzd),
        ],
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

  test('reads the fetch time as a local moment, stored either way', () {
    // The web's `toISOString()`: UTC with a Z.
    final fromWeb = rateFetchedAt('2026-09-19T12:00:00.000Z')!;
    expect(fromWeb.isUtc, isFalse);
    expect(fromWeb, DateTime.utc(2026, 9, 19, 12).toLocal());
    // The phone's own `toIso8601String()` of a local time: no offset.
    final fromPhone = rateFetchedAt('2026-09-19T13:00:00.000')!;
    expect(fromPhone.isUtc, isFalse);
    expect(fromPhone, DateTime(2026, 9, 19, 13));
    expect(rateFetchedAt(null), isNull);
    expect(rateFetchedAt('not a time'), isNull);
  });

  testWidgets('says the dinar rates are typed by hand, next to them', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rateSettingsProvider.overrideWith(
            (ref) => Stream.value(const {RateKeys.usdPerEur: '1.08'}),
          ),
          defaultCurrencyProvider.overrideWith((ref) => Currency.dzd),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: SingleChildScrollView(child: RatesCard())),
        ),
      ),
    );
    await tester.pump();
    // Fetched EUR→USD, empty DZD fields — and the reason on screen.
    expect(find.textContaining('typed by hand'), findsOneWidget);
    expect(
      find.textContaining('Fetch updates every other currency'),
      findsOneWidget,
    );
  });

  testWidgets('shows no dinar fields to someone counting in euros, and the '
      'fetched rate with its day and its source', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rateSettingsProvider.overrideWith(
            (ref) => Stream.value(const {
              RateKeys.perUsd: '{"EUR": 0.9123, "DZD": 132.5, "JPY": 148.2}',
              RateKeys.perUsdAt: '2026-09-27T12:00:00.000Z',
            }),
          ),
          defaultCurrencyProvider.overrideWith((ref) => Currency.eur),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: SingleChildScrollView(child: RatesCard())),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(TextField), findsNothing);
    expect(find.textContaining('DZD'), findsNothing);
    expect(find.text('1 USD = 0.9123 EUR'), findsOneWidget);
    expect(find.textContaining('Rates of Sep 27, 2026'), findsOneWidget);
    expect(find.text('Rates by Exchange Rate API'), findsOneWidget);
  });
}
