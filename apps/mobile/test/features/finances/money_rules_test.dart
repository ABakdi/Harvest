import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/app/current_day.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/db/database_provider.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/finances/data/finances_repository.dart';
import 'package:harvest/features/finances/data/vault_repository.dart';
import 'package:harvest/features/finances/domain/currency.dart';
import 'package:harvest/features/finances/domain/day_range.dart';
import 'package:harvest/features/finances/domain/expense.dart';
import 'package:harvest/features/finances/domain/finance_actions.dart';
import 'package:harvest/features/finances/domain/vault.dart';
import 'package:harvest/features/finances/presentation/finance_providers.dart';
import 'package:harvest/features/settings/data/settings_repository.dart';

class _Day extends CurrentHarvestDay {
  _Day(this._first);
  final HarvestDay _first;

  @override
  HarvestDay build() => _first;

  // The clock ticking over, as a call: a setter would read as state.
  // ignore: use_setters_to_change_properties
  void set(HarvestDay day) => state = day;
}

/// The money rules the repository holds whatever a sheet thought
/// ([[Finances]] The Vault), and the Granary's providers following the
/// live Harvest Day.
void main() {
  late HarvestDatabase db;
  late FinancesRepository finances;
  late VaultRepository vault;
  late FinanceActions actions;
  final today = HarvestDay.today();

  setUp(() {
    db = HarvestDatabase.forTesting(NativeDatabase.memory());
    finances = FinancesRepository(db);
    vault = VaultRepository(db);
    actions = FinanceActions(db, finances, vault);
  });

  tearDown(() => db.close());

  Future<int> wallet() => vault.balanceOf(MoneyAccount.wallet, Currency.dzd);

  Future<void> fund(int minor, [MoneyAccount account = MoneyAccount.wallet]) =>
      vault.move(account: account, deltaMinor: minor, currency: Currency.dzd);

  Future<Debt?> debtNamed(String person) async {
    final debts = await vault.watchDebts().first;
    return debts.where((d) => d.person == person).firstOrNull;
  }

  group('Undo of an expense removal (Q5-16)', () {
    test('does not bring back a movement an earlier edit dropped', () async {
      await fund(10000);
      final uuid = await actions.logExpense(
        amountMinor: 2500,
        category: 'food',
        currency: Currency.dzd,
        fromWallet: true,
      );
      // The switch goes off: the wallet gets its 2500 back.
      await actions.updateExpense(
        uuid: uuid,
        amountMinor: 2500,
        category: 'food',
        currency: Currency.dzd,
        fromWallet: false,
      );
      expect(await wallet(), 10000);
      await actions.removeExpense(uuid);
      await actions.restoreExpense(uuid);
      expect(await wallet(), 10000);
      expect(await vault.linkedTxn(uuid), isNull);
    });

    test('still brings back the movement that went with it', () async {
      await fund(10000);
      final uuid = await actions.logExpense(
        amountMinor: 2500,
        category: 'food',
        currency: Currency.dzd,
        fromWallet: true,
      );
      await actions.removeExpense(uuid);
      expect(await wallet(), 10000);
      await actions.restoreExpense(uuid);
      expect(await wallet(), 7500);
    });
  });

  group('no pot goes below zero (Q5-18)', () {
    test('a hand-made withdrawal past the wallet is refused', () async {
      await fund(1000);
      await expectLater(
        vault.move(
          account: MoneyAccount.wallet,
          deltaMinor: -1500,
          currency: Currency.dzd,
        ),
        throwsArgumentError,
      );
      expect(await wallet(), 1000);
    });

    test('a transfer past the pot is refused', () async {
      await fund(1000);
      await expectLater(
        actions.depositSavings(
          amountMinor: 2000,
          currency: Currency.dzd,
          fromWallet: true,
        ),
        throwsArgumentError,
      );
      await expectLater(
        actions.withdrawSavings(amountMinor: 1, currency: Currency.dzd),
        throwsArgumentError,
      );
      expect(await wallet(), 1000);
    });

    test('a debt paid from an empty wallet is refused', () async {
      await vault.createDebt(
        person: 'Sami',
        amountMinor: 5000,
        currency: Currency.dzd,
      );
      final debt = (await debtNamed('Sami'))!;
      await expectLater(
        vault.payDebt(debt.uuid, 3000, fromWallet: true),
        throwsArgumentError,
      );
      expect((await debtNamed('Sami'))!.paidMinor, 0);
    });

    test('an expense is still logged whatever the wallet holds', () async {
      await actions.logExpense(
        amountMinor: 2500,
        category: 'food',
        currency: Currency.dzd,
        fromWallet: true,
      );
      expect(await wallet(), -2500);
    });
  });

  group('Undo of a payment removal (Q5-17)', () {
    test('is refused when the debt was paid again meanwhile', () async {
      await vault.createDebt(
        person: 'Sami',
        amountMinor: 1000,
        currency: Currency.dzd,
      );
      final debt = (await debtNamed('Sami'))!;
      await vault.payDebt(debt.uuid, 1000);
      final first = (await vault.watchDebtPayments().first).single;
      await vault.removePayment(first.uuid);
      await vault.payDebt(debt.uuid, 1000);
      await expectLater(vault.restorePayment(first.uuid), throwsArgumentError);
      expect((await debtNamed('Sami'))!.paidMinor, 1000);
    });

    test('is refused when the wallet no longer holds it', () async {
      await fund(1000);
      await vault.createDebt(
        person: 'Sami',
        amountMinor: 5000,
        currency: Currency.dzd,
      );
      final debt = (await debtNamed('Sami'))!;
      await vault.payDebt(debt.uuid, 1000, fromWallet: true);
      final payment = (await vault.watchDebtPayments().first).single;
      await vault.removePayment(payment.uuid);
      expect(await wallet(), 1000);
      await vault.move(
        account: MoneyAccount.wallet,
        deltaMinor: -1000,
        currency: Currency.dzd,
      );
      await expectLater(
        vault.restorePayment(payment.uuid),
        throwsArgumentError,
      );
      expect(await wallet(), 0);
      expect((await debtNamed('Sami'))!.paidMinor, 0);
    });
  });

  group('a debt can be corrected and removed (G5-02)', () {
    test('an edit changes it and settles or reopens it', () async {
      await vault.createDebt(
        person: 'Samy',
        amountMinor: 5000,
        currency: Currency.dzd,
      );
      final debt = (await debtNamed('Samy'))!;
      await vault.payDebt(debt.uuid, 3000);
      await vault.updateDebt(
        uuid: debt.uuid,
        person: ' Sami ',
        amountMinor: 3000,
        currency: Currency.dzd,
        remindAt: '20:30',
        note: 'lunch',
      );
      var edited = (await debtNamed('Sami'))!;
      expect(edited.amountMinor, 3000);
      expect(edited.remindAt, '20:30');
      expect(edited.note, 'lunch');
      expect(edited.isSettled, isTrue);

      await vault.updateDebt(
        uuid: debt.uuid,
        person: 'Sami',
        amountMinor: 4000,
        currency: Currency.dzd,
      );
      edited = (await debtNamed('Sami'))!;
      expect(edited.isSettled, isFalse);
      expect(edited.remainingMinor, 1000);
    });

    test('an edit cannot owe less than was paid, nor switch currency '
        'under payments', () async {
      await vault.createDebt(
        person: 'Sami',
        amountMinor: 5000,
        currency: Currency.dzd,
      );
      final debt = (await debtNamed('Sami'))!;
      await vault.payDebt(debt.uuid, 3000);
      await expectLater(
        vault.updateDebt(
          uuid: debt.uuid,
          person: 'Sami',
          amountMinor: 2999,
          currency: Currency.dzd,
        ),
        throwsArgumentError,
      );
      await expectLater(
        vault.updateDebt(
          uuid: debt.uuid,
          person: 'Sami',
          amountMinor: 5000,
          currency: Currency.eur,
        ),
        throwsArgumentError,
      );
      expect((await debtNamed('Sami'))!.amountMinor, 5000);
    });

    test('removing takes its payments along, and Undo brings back just '
        'those', () async {
      await fund(5000);
      await vault.createDebt(
        person: 'Sami',
        amountMinor: 5000,
        currency: Currency.dzd,
      );
      final debt = (await debtNamed('Sami'))!;
      await vault.payDebt(debt.uuid, 1000, fromWallet: true);
      await vault.payDebt(debt.uuid, 500);
      final payments = await vault.watchDebtPayments().first;
      // One removed on its own earlier stays removed.
      await vault.removePayment(
        payments.firstWhere((p) => p.amountMinor == 500).uuid,
      );

      await vault.deleteDebt(debt.uuid);
      expect(await debtNamed('Sami'), isNull);
      expect(await vault.watchDebtPayments().first, isEmpty);
      // The money that left the wallet stays gone.
      expect(await wallet(), 4000);
      final outbox = await db.select(db.outbox).get();
      expect(
        outbox.where((o) => o.rowUuid == debt.uuid && o.op == 'delete'),
        isNotEmpty,
      );

      await vault.restoreDebt(debt.uuid);
      final back = (await debtNamed('Sami'))!;
      expect(back.paidMinor, 1000);
      expect(await wallet(), 4000);
    });
  });

  group('Insights count up to today (G5-03)', () {
    Expense expense(HarvestDay day, int minor) => Expense(
      uuid: '$day-$minor',
      amountMinor: minor,
      currency: Currency.dzd,
      category: 'food',
      day: day,
      loggedAt: DateTime.now(),
    );

    test('an expense logged ahead is left out', () {
      final kept = upToToday([
        expense(today, 100),
        expense(today.addDays(-1), 200),
        expense(today.addDays(3), 90000),
      ], today);
      expect(kept.map((e) => e.amountMinor), [100, 200]);
    });

    test('the range totals and the categories leave it out', () async {
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          currentHarvestDayProvider.overrideWith(() => _Day(today)),
        ],
      );
      addTearDown(container.dispose);
      await finances.log(amountMinor: 1500, category: 'food', day: today);
      await finances.log(
        amountMinor: 90000,
        category: 'rent',
        day: today.addDays(2),
      );
      final range = DayRange(from: today.addDays(-3), to: today.addDays(5));
      container
        ..listen(rangeTotalsProvider(range), (_, _) {})
        ..listen(rangeByCategoryProvider(range), (_, _) {});
      await container.read(rangeExpensesProvider(range).future);
      await pumpEventQueue();
      expect(container.read(rangeTotalsProvider(range)), {today.key: 1500});
      expect(container.read(rangeByCategoryProvider(range)), {'food': 1500});
    });
  });

  group('the Granary follows the Harvest Day (Q5-03)', () {
    test("today's list and the budget move on at the rollover", () async {
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          currentHarvestDayProvider.overrideWith(() => _Day(today)),
        ],
      );
      addTearDown(container.dispose);
      await finances.log(amountMinor: 1500, category: 'food', day: today);
      container.listen(todayExpensesProvider, (_, _) {});
      expect(await container.read(todayExpensesProvider.future), hasLength(1));

      (container.read(currentHarvestDayProvider.notifier) as _Day).set(
        today.next,
      );
      await pumpEventQueue();
      expect(await container.read(todayExpensesProvider.future), isEmpty);
    });
  });

  group('the budget (G5-04, G5-06)', () {
    test('converts into the new default currency', () {
      const rates = Rates(defaultCurrency: Currency.dzd, dzdPerEur: 250);
      expect(
        convertBudget(
          5000000,
          from: Currency.dzd,
          to: Currency.eur,
          rates: rates,
        ),
        20000,
      );
      expect(
        convertBudget(
          20000,
          from: Currency.eur,
          to: Currency.dzd,
          rates: rates,
        ),
        5000000,
      );
      // Without a rate, the number stays as it is.
      expect(
        convertBudget(
          5000000,
          from: Currency.dzd,
          to: Currency.usd,
          rates: rates,
        ),
        5000000,
      );
    });

    test('the shared fixture says the same (packages/core money.json)', () {
      final spec = jsonDecode(
        File(
          '../../packages/core/fixtures/money.json',
        ).readAsStringSync(),
      ) as Map<String, Object?>;
      for (final raw in spec['budgetSwitches']! as List<Object?>) {
        final entry = raw! as Map<String, Object?>;
        final rates = entry['rates']! as Map<String, Object?>;
        double? rate(String key) => (rates[key] as num?)?.toDouble();
        expect(
          convertBudget(
            entry['budget']! as int,
            from: Currency.fromCode(entry['from']! as String),
            to: Currency.fromCode(entry['to']! as String),
            rates: Rates(
              defaultCurrency: Currency.fromCode(
                rates['defaultCurrency']! as String,
              ),
              dzdPerUsd: rate('dzdPerUsd'),
              dzdPerEur: rate('dzdPerEur'),
              usdPerEur: rate('usdPerEur'),
            ),
          ),
          entry['result'],
          reason: entry['why'] as String?,
        );
      }
    });

    test('switching the currency carries the budget across, and clearing '
        'leaves none', () async {
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);
      final settings = SettingsRepository(db);
      await settings.setString('rate.dzdPerEur', '250');
      await settings.setString(FinanceKeys.monthlyBudget, '5000000');
      final notifier = container.read(financeSettingsProvider.notifier);

      await notifier.setDefaultCurrency(Currency.eur);
      expect(await settings.getString(FinanceKeys.monthlyBudget), '20000');
      expect(await settings.getString(FinanceKeys.defaultCurrency), 'EUR');

      await notifier.setBudget(null);
      container.listen(financeSettingsProvider, (_, _) {});
      final value = await container.read(financeSettingsProvider.future);
      expect(value.budgetMinor, isNull);
    });
  });
  group('logging ahead (Q5-67)', () {
    Future<int> xp() async {
      final rows = await db.select(db.ledger).get();
      return rows.fold<int>(0, (sum, row) => sum + row.delta);
    }

    test('pays no XP for a day still to come', () async {
      final uuid = await finances.log(
        amountMinor: 500,
        category: 'bills',
        day: today.addDays(10),
      );
      expect(await xp(), 0);
      // Moved to today, it is paid like any other.
      await finances.updateExpense(
        uuid: uuid,
        amountMinor: 500,
        category: 'bills',
        day: today,
      );
      expect(await xp(), expenseLogXp);
    });
  });
}
