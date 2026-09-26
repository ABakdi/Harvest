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
import 'package:harvest/features/finances/presentation/expense_sheet.dart';
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
      await tester.enterText(find.byType(TextField).at(1), '1500');
      await tester.pump();
    }

    testWidgets('with no reminder never asks to notify', (tester) async {
      await tester.runAsync(() async {
        await fill(tester);
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pumpAndSettle();
      });

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
      await tester.enterText(find.byType(TextField).first, '50');
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

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(entry?.fromWallet, isTrue);
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
      await tester.enterText(find.byType(TextField).first, '6000');
      await tester.pump();
      expect(find.textContaining('≤ ${formatMoney(500000, Currency.dzd)}'),
          findsOneWidget);
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
      await tester.runAsync(() async {
        await tester.pumpWidget(
          app((_) => const VaultTab()),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Debts'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pumpAndSettle();
      });

      expect(find.text('Settled'), findsWidgets);
      await tester.tap(find.text('Payments · 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Remove payment'));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();
      });

      expect(
        find.text('Payment removed. The debt is open again.'),
        findsOneWidget,
      );
      final row = await tester.runAsync(
        () => (db.select(db.debts)..where((d) => d.uuid.equals(uuid)))
            .getSingle(),
      );
      expect(row!.settledAt, isNull);
      await settle(tester);
    });

    testWidgets('the last payment is celebrated', (tester) async {
      await tester.runAsync(() async {
        await VaultRepository(db).createDebt(
          person: 'Sami',
          amountMinor: 150000,
          currency: Currency.dzd,
        );
        await tester.pumpWidget(
          app((_) => const VaultTab()),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Debts'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Pay'));
        await tester.pumpAndSettle();
        // The sheet opens on what is left; paying it all settles it.
        await tester.tap(find.text('Save'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
      });

      expect(
        find.text('Settled with Sami. Nothing left to pay!'),
        findsOneWidget,
      );
      await tester.pumpAndSettle();
      final debt = await tester.runAsync(
        () => db.select(db.debts).getSingle(),
      );
      expect(debt!.settledAt, isNotNull);
      await settle(tester);
    });
  });
}
