import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/features/finances/data/currency_guess.dart';
import 'package:harvest/features/finances/data/rates_service.dart';
import 'package:harvest/features/finances/domain/currency.dart';
import 'package:harvest/features/finances/presentation/currency_picker.dart';
import 'package:harvest/features/finances/presentation/finance_providers.dart';
import 'package:harvest/features/finances/presentation/money.dart';
import 'package:harvest/features/settings/data/settings_repository.dart';
import 'package:harvest/l10n/app_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Every currency, and which one is mine by default ([[Finances]],
/// Phase 7 M7.8), against the fixtures `packages/core` holds too.
void main() {
  const core = '../../packages/core/fixtures';
  Map<String, dynamic> read(String name) =>
      jsonDecode(File('$core/$name').readAsStringSync())
          as Map<String, dynamic>;

  group('the table (fixtures/currencies.json)', () {
    final data = read('currencies.json');

    test('is the fixture, currency for currency: run tool/currencies.dart '
        'when it is not', () {
      final fixture = data['currencies'] as List<dynamic>;
      expect(Currency.values, hasLength(fixture.length));
      expect(fixture.length, greaterThanOrEqualTo(150));
      for (final raw in fixture) {
        final one = raw as Map<String, dynamic>;
        final currency = Currency.tryCode(one['code'] as String)!;
        expect(currency.minorUnits, one['minorUnits'], reason: currency.code);
        expect(currency.symbol, one['symbol'], reason: currency.code);
        expect(currency.en, one['en'], reason: currency.code);
        expect(currency.ar, one['ar'], reason: currency.code);
      }
    });

    test('keeps the three it always had, and the dinar for a code it does '
        'not know', () {
      expect(Currency.fromCode('DZD').symbol, 'DA');
      expect(Currency.fromCode('USD').symbol, r'$');
      expect(Currency.fromCode('EUR').symbol, '€');
      expect(Currency.fromCode('XAU'), Currency.dzd);
      expect(Currency.fromCode(null), Currency.dzd);
      expect(Currency.tryCode('XAU'), isNull);
    });
  });

  group('the default (fixtures/currency-defaults.json)', () {
    final data = read('currency-defaults.json');

    for (final raw in data['cases'] as List<dynamic>) {
      final one = raw as Map<String, dynamic>;
      test(one['why'] as String, () {
        final chosen = defaultCurrencyFor(
          countries: (one['countries'] as List<dynamic>).cast<String?>(),
          timeZone: one['timeZone'] as String?,
          locales: (one['locales'] as List<dynamic>).cast<String?>(),
        );
        expect(chosen.code, one['currency']);
      });
    }

    test('shows as many decimals as the fixture says', () {
      for (final MapEntry(:key, :value)
          in (data['decimals'] as Map<String, dynamic>).entries) {
        expect(Currency.fromCode(key).displayDecimals, value, reason: key);
      }
    });
  });

  group('a guessed default', () {
    late HarvestDatabase db;
    setUp(() => db = HarvestDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() => db.close());

    Future<Whereabouts> inJapan() async =>
        (countries: <String?>['jp', null], zone: 'Asia/Tokyo');

    test('is set once, older than any choice, and never queued', () async {
      final guessed = await guessDefaultCurrency(
        db,
        where: inJapan,
        locales: const ['en-US'],
      );
      expect(guessed, Currency.fromCode('JPY'));
      final row = await db.select(db.kvSettings).getSingle();
      expect(row.key, defaultCurrencyKey);
      expect(row.updatedAt.toUtc(), guessedAt);
      expect(await db.select(db.outbox).get(), isEmpty);
      expect(await SettingsRepository(db).getString(defaultCurrencyKey), 'JPY');
    });

    test('never overrides a currency already there', () async {
      await SettingsRepository(db).setString(defaultCurrencyKey, 'EUR');
      expect(
        await guessDefaultCurrency(db, where: inJapan, locales: const []),
        isNull,
      );
      expect(await SettingsRepository(db).getString(defaultCurrencyKey), 'EUR');
    });

    test('leaves a phone that has logged money on the dinar it was on', () async {
      await db
          .into(db.expenses)
          .insert(
            ExpensesCompanion.insert(
              uuid: 'e1',
              amountMinor: 45000,
              category: 'Food',
              harvestDay: '2026-09-18',
            ),
          );
      expect(
        await guessDefaultCurrency(db, where: inJapan, locales: const []),
        isNull,
      );
      expect(await db.select(db.kvSettings).get(), isEmpty);
    });

    test('falls back to the dinar where the phone says nothing', () async {
      final guessed = await guessDefaultCurrency(
        db,
        where: () async => (countries: const <String?>[], zone: 'UTC'),
        locales: const ['ar'],
      );
      expect(guessed, Currency.dzd);
    });
  });

  group('rates for every currency', () {
    final jpy = Currency.fromCode('JPY');
    final gbp = Currency.fromCode('GBP');
    const perUsd = {'EUR': 0.9, 'JPY': 150.0, 'GBP': 0.8, 'DZD': 134.0};

    test('go through the dollar between any two', () {
      const rates = Rates(defaultCurrency: Currency.eur, perUsd: perUsd);
      // ¥15,000.00 is $100, is €90.
      expect(rates.toDefault(1500000, jpy), 9000);
      expect(rates.withDefault(gbp).toDefault(1500000, jpy), 8000);
      expect(rates.withDefault(jpy).toDefault(100, Currency.usd), 15000);
    });

    test('take the dinar typed by hand over the official one', () {
      const rates = Rates(
        defaultCurrency: Currency.dzd,
        perUsd: perUsd,
        dzdPerUsd: 240,
      );
      expect(rates.toDefault(10000, jpy), (10000 / 150 * 240).round());
      expect(
        const Rates(
          defaultCurrency: Currency.dzd,
          perUsd: perUsd,
        ).toDefault(100, Currency.usd),
        13400,
      );
    });

    test('convert nothing without the rate they need', () {
      final rates = Rates(defaultCurrency: gbp, perUsd: const {'EUR': 0.9});
      expect(rates.toDefault(100, jpy), isNull);
      expect(rates.toDefaultOrFace(100, jpy), 100);
    });

    test('read from the settings, keeping only currencies and rates that '
        'are real', () {
      expect(
        perUsdOf('{"EUR": 0.9, "XYZ": 3, "JPY": -1, "GBP": "x", "KRW": 1380}'),
        {'EUR': 0.9, 'KRW': 1380.0},
      );
      expect(perUsdOf('not json'), isNull);
      expect(perUsdOf(null), isNull);
      final rates = ratesFrom({
        RateKeys.perUsd: '{"EUR": 0.5}',
        RateKeys.dzdPerEur: '250',
      }, Currency.dzd);
      expect(rates.perUsd('EUR'), 0.5);
      expect(rates.dzdPerEur, 250);
    });
  });

  group('the fetch', () {
    late HarvestDatabase db;
    setUp(() => db = HarvestDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() => db.close());

    RatesService service(http.Response answer) => RatesService(
      SettingsRepository(db),
      client: MockClient((request) async {
        expect(request.url, RatesService.endpoint);
        return answer;
      }),
    );

    test(
      'keeps every known currency with the day the source updated',
      () async {
        final body = jsonEncode({
          'result': 'success',
          'base_code': 'USD',
          'time_last_update_unix': 1790467200,
          'rates': {'USD': 1, 'EUR': 0.92, 'DZD': 132.4, 'XXX': 7, 'JPY': 148},
        });
        final rates = await service(http.Response(body, 200)).fetchRates();
        expect(rates, {'USD': 1.0, 'EUR': 0.92, 'DZD': 132.4, 'JPY': 148.0});
        final settings = SettingsRepository(db);
        expect(perUsdOf(await settings.getString(RateKeys.perUsd)), rates);
        expect(
          DateTime.parse((await settings.getString(RateKeys.perUsdAt))!),
          DateTime.fromMillisecondsSinceEpoch(1790467200 * 1000, isUtc: true),
        );
        // What 3.1 reads, for a device not updated yet.
        expect(
          double.parse((await settings.getString(RateKeys.usdPerEur))!),
          closeTo(1 / 0.92, 1e-9),
        );
      },
    );

    test('trusts nothing broken', () async {
      for (final body in [
        '{"result": "error"}',
        '{"result": "success", "base_code": "EUR", "rates": {"EUR": 1}}',
        '{"result": "success", "base_code": "USD", "rates": {"EUR": 40}}',
        'not json',
      ]) {
        expect(await service(http.Response(body, 200)).fetchRates(), isNull);
      }
      expect(await service(http.Response('', 503)).fetchRates(), isNull);
      expect(await SettingsRepository(db).getString(RateKeys.perUsd), isNull);
    });
  });

  group('showing and finding them', () {
    test('an amount in a currency without decimals shows none', () {
      expect(formatAmount(1234567, Currency.fromCode('JPY')), '¥12,346');
      expect(formatAmount(1234567, Currency.dzd), 'DA12,345.67');
    });

    test('a search finds by name in the language, by code and by sign', () {
      expect(searchCurrencies('yen', 'en').first.code, 'JPY');
      expect(searchCurrencies('jpy', 'ar').first.code, 'JPY');
      expect(
        searchCurrencies('دينار جزائري', 'ar').map((c) => c.code),
        contains('DZD'),
      );
      expect(searchCurrencies('€', 'en').map((c) => c.code), ['EUR']);
      expect(searchCurrencies('', 'en'), hasLength(Currency.values.length));
      expect(searchCurrencies('nothing like it', 'en'), isEmpty);
    });
  });

  testWidgets('a pill for the usual ones, and any other a search away', (
    tester,
  ) async {
    var chosen = Currency.dzd;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          defaultCurrencyProvider.overrideWith((ref) => Currency.dzd),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => CurrencyChoice(
                selected: chosen,
                onChanged: (currency) => setState(() => chosen = currency),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('DA'), findsOneWidget);
    expect(find.text(r'$'), findsOneWidget);
    expect(find.text('€'), findsOneWidget);

    await tester.tap(find.byTooltip('Another currency'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'yen');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('currency-JPY')));
    await tester.pumpAndSettle();
    expect(chosen.code, 'JPY');
    // Chosen, it joins the pills.
    expect(find.text('¥'), findsOneWidget);
  });
}
