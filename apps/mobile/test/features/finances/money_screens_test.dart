import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/db/database_provider.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/core/platform/notifications.dart';
import 'package:harvest/features/finances/data/finances_repository.dart';
import 'package:harvest/features/finances/data/vault_repository.dart';
import 'package:harvest/features/finances/domain/currency.dart';
import 'package:harvest/features/finances/domain/expense.dart';
import 'package:harvest/features/finances/presentation/amount_keypad.dart';
import 'package:harvest/features/finances/presentation/expense_sheet.dart';
import 'package:harvest/features/finances/presentation/finance_charts.dart';
import 'package:harvest/features/finances/presentation/finance_providers.dart';
import 'package:harvest/features/finances/presentation/money.dart';
import 'package:harvest/features/finances/presentation/money_sheet.dart';
import 'package:harvest/features/finances/presentation/vault_tab.dart';
import 'package:harvest/features/planner/domain/notification_planner.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// Counts the permission prompts instead of showing them.
class _Notifications extends NotificationService {
  int asked = 0;

  @override
  Future<ReminderPermission> requestPermissionStatus() async {
    asked++;
    return ReminderPermission.granted;
  }
}

/// A planner that only counts: the sheets under test replan, and what
/// the plan holds is the planner's own tests' business.
class _Planner implements NotificationPlanner {
  int plans = 0;

  @override
  Future<void> planToday({DateTime? now}) async => plans++;

  @override
  Future<void> reevaluate({DateTime? now}) async => plans++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late HarvestDatabase db;
  late _Notifications notifications;
  late _Planner planner;

  setUp(() {
    db = HarvestDatabase.forTesting(NativeDatabase.memory());
    notifications = _Notifications();
    planner = _Planner();
  });

  tearDown(() => db.close());

  Widget app(Widget Function(BuildContext context) body) => ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      notificationServiceProvider.overrideWithValue(notifications),
      notificationPlannerProvider.overrideWithValue(planner),
      // No network in a test: the rates stay whatever is stored.
      ratesProvider.overrideWith(
        (ref) => Stream.value(const Rates(defaultCurrency: Currency.dzd)),
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: Builder(builder: body)),
    ),
  );

  /// Drift's stream store closes queries on a zero timer; letting the
  /// tree go and pumping once drains it before the test ends.
  Future<void> settle(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  }

  /// Taps [finder] once it is scrolled into view: a sheet is taller than
  /// the test's 800×600 surface.
  Future<void> tapShown(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pump();
    await tester.tap(finder);
    await tester.pump();
  }

  /// Types [amount] on the sheet's own keypad: the amount box is
  /// read-only to the system keyboard (U6-10).
  Future<void> keyIn(WidgetTester tester, String amount) async {
    for (final key in amount.split('')) {
      await tapShown(
        tester,
        find.descendant(
          of: find.byType(AmountKeypad),
          matching: find.text(key),
        ),
      );
    }
  }

  /// Pumps until [done] holds, letting drift's real-time work land in
  /// between: a condition, not a fixed wait (PH-16).
  Future<void> until(
    WidgetTester tester,
    FutureOr<bool> Function() done,
  ) async {
    for (var i = 0; i < 400; i++) {
      final ok = await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 5));
        return done();
      });
      await tester.pump();
      if (ok ?? false) return;
    }
    fail('the condition never held');
  }

  Widget opener(String label, Future<void> Function(BuildContext) open) =>
      Center(
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () => open(context),
            child: Text(label),
          ),
        ),
      );

  group('a new debt', () {
    Future<void> fill(WidgetTester tester) async {
      await tester.pumpWidget(app((_) => opener('open', showDebtSheet)));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), 'Sami');
      await keyIn(tester, '1500');
    }

    testWidgets('with no reminder never asks to notify', (tester) async {
      await fill(tester);
      await tapShown(tester, find.text('Save'));
      await until(tester, () => planner.plans == 1);

      final debts = await tester.runAsync(
        () => db.select(db.debts).get(),
      );
      expect(debts, hasLength(1));
      expect(notifications.asked, 0);
      // The plan still runs — after the sheet has gone, with no "ref
      // used after unmount" thrown on the way.
      expect(planner.plans, 1);
      expect(tester.takeException(), isNull);
      await settle(tester);
    });
  });

  group('the money sheet', () {
    testWidgets('the whole "From the wallet" row toggles, label included', (
      tester,
    ) async {
      MoneyEntry? entry;
      await tester.pumpWidget(
        app(
          (_) => opener('open', (context) async {
            entry = await showMoneySheet(
              context,
              title: 'Deposit',
              initialCurrency: Currency.dzd,
              walletBalances: const {Currency.dzd: 1000000},
            );
          }),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      Switch toggle() => tester.widget<Switch>(find.byType(Switch));
      // Before any amount: the row already takes the answer.
      expect(toggle().value, isTrue);
      await tester.tap(find.text('From the wallet'));
      await tester.pump();
      expect(toggle().value, isFalse);
      await keyIn(tester, '50');
      await tester.pump();
      expect(toggle().value, isFalse, reason: 'the early choice holds');
      await tester.tap(find.text('From the wallet'));
      await tester.pump();
      await tester.tap(find.text('From the wallet'));
      await tester.pump();
      expect(toggle().value, isFalse);
      await tester.tap(find.text('From the wallet'));
      await tester.pump();
      expect(toggle().value, isTrue);

      await tapShown(tester, find.text('Save'));
      await tester.pumpAndSettle();
      expect(entry?.fromWallet, isTrue);
      await settle(tester);
    });

    testWidgets('takes a sum, as the expense sheet does (G5-06)', (
      tester,
    ) async {
      MoneyEntry? entry;
      await tester.pumpWidget(
        app(
          (_) => opener('open', (context) async {
            entry = await showMoneySheet(
              context,
              title: 'Deposit',
              initialCurrency: Currency.dzd,
            );
          }),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await keyIn(tester, '120+30');
      await tester.pump();
      expect(find.textContaining('DA150'), findsOneWidget);
      await tapShown(tester, find.text('Save'));
      await tester.pumpAndSettle();
      expect(entry?.minor, 15000);
      await settle(tester);
    });

    testWidgets('an over-cap amount names the cap grouped', (tester) async {
      await tester.pumpWidget(
        app(
          (_) => opener(
            'open',
            (context) => showMoneySheet(
              context,
              title: 'Take',
              initialCurrency: Currency.dzd,
              maxMinor: const {Currency.dzd: 500000},
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.textContaining('DA5,000'), findsOneWidget);
      await keyIn(tester, '6000');
      await tester.pump();
      expect(
        find.textContaining('≤ ${formatMoney(500000, Currency.dzd)}'),
        findsOneWidget,
      );
      expect(find.textContaining('DA5000'), findsNothing);
      await settle(tester);
    });
  });

  testWidgets('editing an expense saves, it does not log', (tester) async {
    final expense = Expense(
      uuid: 'e1',
      amountMinor: 1200,
      category: 'food',
      currency: Currency.dzd,
      loggedAt: DateTime(2026, 9, 19, 12),
      day: HarvestDay.parse('2026-09-19'),
    );
    await tester.pumpWidget(
      app(
        (_) => opener(
          'open',
          (context) => showExpenseSheet(context, existing: expense),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Log'), findsNothing);
    await settle(tester);
  });

  testWidgets('on a 1080×2400 phone, Log shows without scrolling (U6-11)', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(1080, 2400)
      ..devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app((_) => opener('open', showExpenseSheet)));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await keyIn(tester, '12');
    final log = find.text('Log');
    expect(log, findsOneWidget);
    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    expect(tester.getRect(log).bottom, lessThanOrEqualTo(screen.height));
    // And the amount is still in view above it.
    expect(tester.getRect(find.text('12')).top, greaterThanOrEqualTo(0));
    await settle(tester);
  });

  testWidgets('at 320 dp the Insights segments are words alone (U6-12)', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(840, 1800)
      ..devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app((_) => const FinanceInsights()));
    await tester.pump();
    for (final label in ['Week', 'Month', 'Custom']) {
      final text = tester.widget<Text>(find.text(label));
      expect(text.maxLines, 1, reason: label);
    }
    expect(find.byIcon(Icons.calendar_month), findsNothing);
    expect(tester.takeException(), isNull);
    await settle(tester);
  });

  testWidgets('a huge amount is asked about before it is saved (W6-15)', (
    tester,
  ) async {
    MoneyEntry? entry;
    await tester.pumpWidget(
      app(
        (_) => opener('open', (context) async {
          entry = await showMoneySheet(
            context,
            title: 'Deposit',
            initialCurrency: Currency.dzd,
          );
        }),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await keyIn(tester, '99999999999');
    await tapShown(tester, find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.textContaining('99,999,999,999'), findsWidgets);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(entry, isNull);
    await tapShown(tester, find.text('Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Yes, it's right"));
    await tester.pumpAndSettle();
    expect(entry?.minor, 9999999999900);
    await settle(tester);
  });

  group('expenses logged ahead', () {
    test('are listed soonest first and counted by no total', () async {
      final repository = FinancesRepository(db);
      final today = HarvestDay.today();
      await repository.log(
        amountMinor: 900,
        category: 'bills',
        day: today.addDays(9),
      );
      await repository.log(
        amountMinor: 300,
        category: 'food',
        day: today.addDays(2),
      );
      await repository.log(
        amountMinor: 100,
        category: 'food',
      );

      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);
      final keep = container.listen(upcomingExpensesProvider, (_, _) {});
      addTearDown(keep.close);
      final upcoming = await container.read(upcomingExpensesProvider.future);

      expect([for (final e in upcoming) e.amountMinor], [300, 900]);
      expect(
        [for (final e in upcoming) e.day],
        [today.addDays(2), today.addDays(9)],
      );
      final todays = await repository.watchDay(today).first;
      expect([for (final e in todays) e.amountMinor], [100]);
    });

    test('ties on a day keep the order they were logged in', () {
      final day = HarvestDay.parse('2026-10-01');
      Expense at(String uuid, HarvestDay day, int hour) => Expense(
        uuid: uuid,
        amountMinor: 1,
        category: 'food',
        currency: Currency.dzd,
        loggedAt: DateTime(2026, 9, 19, hour),
        day: day,
      );
      final sorted = soonestFirst([
        at('c', day.next, 1),
        at('b', day, 9),
        at('a', day, 8),
      ]);
      expect([for (final e in sorted) e.uuid], ['a', 'b', 'c']);
    });
  });

  group('a settled debt', () {
    Future<String> settled() async {
      final vault = VaultRepository(db);
      await vault.createDebt(
        person: 'Sami',
        amountMinor: 150000,
        currency: Currency.dzd,
      );
      final debt = (await db.select(db.debts).get()).single;
      await vault.payDebt(debt.uuid, 150000);
      return debt.uuid;
    }

    testWidgets('keeps its payments, and removing the last reopens it', (
      tester,
    ) async {
      final uuid = (await tester.runAsync(settled))!;
      await tester.pumpWidget(app((_) => const VaultTab()));
      await until(tester, () => find.text('Debts').evaluate().isNotEmpty);
      await tester.tap(find.text('Debts'));
      await until(tester, () => find.text('Settled').evaluate().isNotEmpty);

      expect(find.text('Settled'), findsWidgets);
      await tester.tap(find.text('Payments · 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Remove payment'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
      await until(
        tester,
        () => find
            .text('Payment removed. The debt is open again.')
            .evaluate()
            .isNotEmpty,
      );
      final row = await tester.runAsync(
        () => (db.select(
          db.debts,
        )..where((d) => d.uuid.equals(uuid))).getSingle(),
      );
      expect(row!.settledAt, isNull);
      await settle(tester);
    });

    testWidgets('the last payment is celebrated', (tester) async {
      await tester.runAsync(
        () => VaultRepository(db).createDebt(
          person: 'Sami',
          amountMinor: 150000,
          currency: Currency.dzd,
        ),
      );
      await tester.pumpWidget(app((_) => const VaultTab()));
      await until(tester, () => find.text('Debts').evaluate().isNotEmpty);
      await tester.tap(find.text('Debts'));
      final pay = find.widgetWithText(FilledButton, 'Pay');
      await until(tester, () => pay.evaluate().isNotEmpty);
      await tester.tap(pay);
      await tester.pumpAndSettle();
      // The sheet opens on what is left; paying it all settles it.
      await tapShown(tester, find.text('Save'));
      await until(
        tester,
        () => find
            .text('Settled with Sami. Nothing left to pay!')
            .evaluate()
            .isNotEmpty,
      );
      await tester.pumpAndSettle();
      final debt = await tester.runAsync(
        () => db.select(db.debts).getSingle(),
      );
      expect(debt!.settledAt, isNotNull);
      await settle(tester);
    });
  });

  group('a debt can be corrected and removed (G5-02)', () {
    Future<void> openVault(WidgetTester tester) async {
      await tester.runAsync(
        () => VaultRepository(db).createDebt(
          person: 'Samy',
          amountMinor: 150000,
          currency: Currency.dzd,
        ),
      );
      await tester.pumpWidget(app((_) => const VaultTab()));
      await until(tester, () => find.text('Debts').evaluate().isNotEmpty);
      await tester.tap(find.text('Debts'));
      await until(tester, () => find.text('Samy').evaluate().isNotEmpty);
      await tester.tap(find.text('Samy'));
      await tester.pumpAndSettle();
    }

    testWidgets('a tap on it opens the sheet on what it is', (tester) async {
      await openVault(tester);
      expect(find.text('Edit debt'), findsOneWidget);
      await tester.enterText(find.byType(TextField).at(0), 'Sami');
      // Long-press on ⌫ clears the box; then the keypad types.
      await tester.longPress(find.text('⌫'));
      await keyIn(tester, '2000');
      await tapShown(tester, find.text('Save'));
      await until(
        tester,
        () async => (await db.select(db.debts).getSingle()).person == 'Sami',
      );
      final debt = await tester.runAsync(
        () => db.select(db.debts).getSingle(),
      );
      expect(debt!.person, 'Sami');
      expect(debt.amountMinor, 200000);
      await settle(tester);
    });

    testWidgets('removing it asks, and Undo brings it back', (tester) async {
      await openVault(tester);
      await tester.tap(find.widgetWithIcon(IconButton, Icons.delete_outline));
      await tester.pumpAndSettle();
      expect(find.text('Remove this debt?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await until(tester, () => find.text('Undo').evaluate().isNotEmpty);
      final debt = await tester.runAsync(
        () => db.select(db.debts).getSingle(),
      );
      expect(debt!.deletedAt, isNotNull);
      // Let the bar finish sliding in before tapping its action.
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Undo'));
      await until(
        tester,
        () async => (await db.select(db.debts).getSingle()).deletedAt == null,
      );
      await settle(tester);
    });
  });
}
