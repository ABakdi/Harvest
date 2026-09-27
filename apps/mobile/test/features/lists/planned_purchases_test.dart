import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:harvest/app/router.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/db/database_provider.dart';
import 'package:harvest/features/finances/domain/currency.dart';
import 'package:harvest/features/finances/presentation/finance_providers.dart';
import 'package:harvest/features/finances/presentation/granary_screen.dart';
import 'package:harvest/features/lists/data/lists_repository.dart';
import 'package:harvest/features/lists/domain/lists.dart';
import 'package:harvest/features/settings/domain/feature_switches.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// The Granary keeps one line of the shopping lists on Today: the open
/// estimates per currency, a plan summed into nothing else ([[Lists]]
/// L3), opening the lists on *To buy*. The Wishlist tab is gone, and
/// the Wishlist is not a plan (`packages/core/fixtures/lists.json`).
void main() {
  group('core/lists.json', () {
    final data = jsonDecode(
      File('../../packages/core/fixtures/lists.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final lists = [
      for (final l in (data['lists'] as List).cast<Map<String, dynamic>>())
        ItemList(
          uuid: l['uuid'] as String,
          name: l['uuid'] as String,
          kind: ListKind.parse(l['kind'] as String),
          builtIn: BuiltInList.ofKey(l['builtIn'] as String?),
          createdAt: DateTime(2026),
        ),
    ];
    for (final c
        in (data['plannedPurchases'] as List).cast<Map<String, dynamic>>()) {
      test(c['why'] as String, () {
        final items = [
          for (final (i, it)
              in (c['items'] as List).cast<Map<String, dynamic>>().indexed)
            ListItem(
              uuid: 'i$i',
              listUuid: it['listUuid'] as String,
              title: 'i$i',
              priceMinor: it['priceMinor'] as int?,
              currency: Currency.fromCode(it['currency'] as String),
              doneAt: it['done'] as bool ? DateTime(2026) : null,
              createdAt: DateTime(2026),
            ),
        ];
        expect(
          {
            for (final e in plannedPurchaseTotals(lists, items).entries)
              e.key.code: e.value,
          },
          c['sums'],
        );
      });
    }
  });

  late HarvestDatabase db;
  late ListsRepository repo;

  setUp(() {
    db = HarvestDatabase.forTesting(NativeDatabase.memory());
    repo = ListsRepository(db);
  });

  tearDown(() async => db.close());

  Future<void> drain(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> pumpGranary(WidgetTester tester, {required bool listsOn}) async {
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const GranaryScreen()),
        GoRoute(
          path: AppRoutes.lists,
          builder: (_, state) =>
              Text('lists:${state.uri.queryParameters['list']}'),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          listsEnabledProvider.overrideWithValue(listsOn),
          ratesProvider.overrideWith(
            (ref) => Stream.value(const Rates(defaultCurrency: Currency.dzd)),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await drain(tester);
  }

  Future<void> leave(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> seed(WidgetTester tester) => tester.runAsync(() async {
    await repo.addItem(
      BuiltInList.buy.uuid,
      title: 'Kettle',
      priceMinor: 85000,
    );
    await repo.addItem(
      BuiltInList.wish.uuid,
      title: 'Espresso machine',
      priceMinor: 1800000,
    );
    await repo.addItem(
      BuiltInList.buy.uuid,
      title: 'Headphones',
      priceMinor: 6500,
      currency: Currency.usd,
    );
    final bought = await repo.addItem(
      BuiltInList.buy.uuid,
      title: 'Coat',
      priceMinor: 999900,
    );
    await repo.setDone(bought.uuid, done: true);
  });

  testWidgets('sums the open estimates per currency and opens To buy', (
    tester,
  ) async {
    await seed(tester);
    await pumpGranary(tester, listsOn: true);

    expect(find.text('Wishlist'), findsNothing); // no tab any more
    final line = find.textContaining('Planned purchases · ');
    expect(line, findsOneWidget);
    final text = tester.widget<Text>(line).data!;
    // DA850 open; the wished-for espresso machine is not a plan, and
    // the bought coat is not planned any more.
    expect(text, contains('850'));
    expect(text, isNot(contains('18,')));
    expect(text, contains('65'));
    expect(text, isNot(contains('9,999')));

    await tester.tap(line);
    await tester.pumpAndSettle();
    expect(find.text('lists:${BuiltInList.buy.uuid}'), findsOneWidget);
    await leave(tester);
  });

  testWidgets('stays away while Lists is off, or nothing has an estimate', (
    tester,
  ) async {
    await seed(tester);
    await pumpGranary(tester, listsOn: false);
    expect(find.textContaining('Planned purchases'), findsNothing);
    await leave(tester);

    await tester.runAsync(() async {
      for (final item in await repo.watchAllItems().first) {
        await repo.deleteItem(item.uuid);
      }
      await repo.addItem(BuiltInList.buy.uuid, title: 'Bread');
    });
    await pumpGranary(tester, listsOn: true);
    expect(find.textContaining('Planned purchases'), findsNothing);
    await leave(tester);
  });
}
