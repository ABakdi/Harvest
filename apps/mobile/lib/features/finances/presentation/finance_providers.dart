import 'package:flutter_riverpod/flutter_riverpod.dart' show StreamProvider;
import 'package:harvest/core/app/current_day.dart';
import 'package:harvest/core/db/database_provider.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/finances/data/finances_repository.dart';
import 'package:harvest/features/finances/data/vault_repository.dart';
import 'package:harvest/features/finances/domain/currency.dart';
import 'package:harvest/features/finances/domain/day_range.dart';
import 'package:harvest/features/finances/domain/expense.dart';
import 'package:harvest/features/finances/domain/vault.dart';
import 'package:harvest/features/settings/data/settings_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'finance_providers.g.dart';

abstract final class FinanceKeys {
  static const monthlyBudget = 'finance.monthlyBudgetMinor';
  static const defaultCurrency = 'finance.defaultCurrency';

  static String savingsFor(Currency currency) =>
      'finance.savings.${currency.code}';
}

// Everything keyed on today watches the live Harvest Day, so a Granary
// left open across 3 AM moves on by itself ([[Audit-v3]] Q5-03).
@riverpod
Stream<List<Expense>> todayExpenses(Ref ref) => ref
    .watch(financesRepositoryProvider)
    .watchDay(ref.watch(currentHarvestDayProvider));

/// Expenses logged on a day still to come — the bill I know is coming
/// ([[Finances]] Quick-log), soonest first. They count on their own day
/// and not before, so no total reads them; this list is how they stay
/// reachable to open, change or remove.
final StreamProvider<List<Expense>> upcomingExpensesProvider =
    StreamProvider.autoDispose<List<Expense>>((
      ref,
    ) {
      final today = ref.watch(currentHarvestDayProvider);
      return ref
          .watch(financesRepositoryProvider)
          .watchRange(today.next, today.addDays(366))
          .map(soonestFirst);
    });

/// [expenses] by day, soonest first, and within a day in the order
/// they were logged.
List<Expense> soonestFirst(List<Expense> expenses) =>
    [...expenses]..sort((a, b) {
      final byDay = a.day.compareTo(b.day);
      return byDay != 0 ? byDay : a.loggedAt.compareTo(b.loggedAt);
    });

@riverpod
Stream<List<Expense>> monthExpenses(Ref ref) => ref
    .watch(financesRepositoryProvider)
    .watchMonth(ref.watch(currentHarvestDayProvider));

@riverpod
Stream<List<Expense>> weekExpenses(Ref ref) => ref
    .watch(financesRepositoryProvider)
    .watchWeek(ref.watch(currentHarvestDayProvider).weekStart);

@riverpod
Stream<List<CustomCategory>> customCategories(Ref ref) =>
    ref.watch(financesRepositoryProvider).watchCategories();

/// Budget, currency, and expectation settings. Savings moved to the
/// vault's transaction ledger (checkpoint round 3).
@Riverpod(keepAlive: true)
class FinanceSettings extends _$FinanceSettings {
  @override
  Stream<
    ({
      int? budgetMinor,
      Currency defaultCurrency,
    })
  >
  build() => ref
      .watch(settingsRepositoryProvider)
      .watchAll(const [
        FinanceKeys.monthlyBudget,
        FinanceKeys.defaultCurrency,
      ])
      .map(
        (values) => (
          budgetMinor: int.tryParse(values[FinanceKeys.monthlyBudget] ?? ''),
          defaultCurrency: Currency.fromCode(
            values[FinanceKeys.defaultCurrency],
          ),
        ),
      );

  /// Sets the month's budget, or clears it with null: an empty value,
  /// which both devices read as no budget at all.
  Future<void> setBudget(int? minor) => ref
      .read(settingsRepositoryProvider)
      .setString(FinanceKeys.monthlyBudget, minor == null ? '' : '$minor');

  /// Switches the default currency and carries the budget across: the
  /// budget is a sum in the default currency, so DA50,000 has to become
  /// its worth in euros, not €50,000 ([[Audit-v3]] G5-04). Without a
  /// rate it keeps its number, the way every sum falls back to face
  /// value.
  Future<void> setDefaultCurrency(Currency currency) async {
    final settings = ref.read(settingsRepositoryProvider);
    await ref.read(databaseProvider).transaction(() async {
      final from = Currency.fromCode(
        await settings.getString(FinanceKeys.defaultCurrency),
      );
      if (from == currency) return;
      final budget = int.tryParse(
        await settings.getString(FinanceKeys.monthlyBudget) ?? '',
      );
      await settings.setString(FinanceKeys.defaultCurrency, currency.code);
      if (budget == null || budget <= 0) return;
      final converted = convertBudget(
        budget,
        from: from,
        to: currency,
        rates: Rates(
          defaultCurrency: currency,
          dzdPerUsd: double.tryParse(
            await settings.getString('rate.dzdPerUsd') ?? '',
          ),
          dzdPerEur: double.tryParse(
            await settings.getString('rate.dzdPerEur') ?? '',
          ),
          usdPerEur: double.tryParse(
            await settings.getString('rate.usdPerEur') ?? '',
          ),
        ),
      );
      if (converted != budget) await setBudget(converted);
    });
  }
}

/// [budget] in [from] as a budget in [to]: converted when [rates] know
/// the way, its face value otherwise, and never below one minor unit.
int convertBudget(
  int budget, {
  required Currency from,
  required Currency to,
  required Rates rates,
}) {
  if (from == to) return budget;
  final converted = Rates(
    defaultCurrency: to,
    dzdPerUsd: rates.dzdPerUsd,
    dzdPerEur: rates.dzdPerEur,
    usdPerEur: rates.usdPerEur,
  ).toDefault(budget, from);
  if (converted == null) return budget;
  return converted < 1 ? 1 : converted;
}

/// The default currency, DZD until the setting says otherwise.
@riverpod
Currency defaultCurrency(Ref ref) =>
    ref.watch(financeSettingsProvider).value?.defaultCurrency ?? Currency.dzd;

/// [ratesProvider] with a safe fallback while the stream warms up, keyed
/// on the real default currency so nothing converts into DZD by mistake.
@riverpod
Rates ratesOrDefault(Ref ref) =>
    ref.watch(ratesProvider).value ??
    Rates(defaultCurrency: ref.watch(defaultCurrencyProvider));

// ------------------------------------------------------------------ vault

/// The pots as of the Harvest Day: movements logged ahead wait for
/// their day, and join the balance when it comes.
@riverpod
Stream<Map<(MoneyAccount, Currency), int>> vaultBalances(Ref ref) => ref
    .watch(vaultRepositoryProvider)
    .watchBalances(asOf: ref.watch(currentHarvestDayProvider));

@riverpod
Stream<List<MoneyTxn>> recentTxns(Ref ref) =>
    ref.watch(vaultRepositoryProvider).watchRecentTxns();

/// One pot's own ledger (round 4: each section lists its atomic moves).
@riverpod
Stream<List<MoneyTxn>> accountTxns(Ref ref, MoneyAccount account) =>
    ref.watch(vaultRepositoryProvider).watchTxns(account: account);

@riverpod
Stream<List<Debt>> debts(Ref ref) =>
    ref.watch(vaultRepositoryProvider).watchDebts();

@riverpod
Stream<List<DebtPayment>> debtPayments(Ref ref) =>
    ref.watch(vaultRepositoryProvider).watchDebtPayments();

/// Per-currency balances of one pot, zero balances dropped.
@riverpod
Map<Currency, int> accountBalances(Ref ref, MoneyAccount account) {
  final balances = ref.watch(vaultBalancesProvider).value ?? const {};
  return {
    for (final entry in balances.entries)
      if (entry.key.$1 == account && entry.value != 0)
        entry.key.$2: entry.value,
  };
}

/// The vault at a glance, everything converted into the default
/// currency (face value when a rate is missing — never blocks).
@riverpod
({int wallet, int savings, int owed}) vaultTotals(Ref ref) {
  final ratesValue =
      ref.watch(ratesProvider).value ??
      const Rates(defaultCurrency: Currency.dzd);
  int sum(Map<Currency, int> balances) {
    var total = 0;
    balances.forEach((currency, minor) {
      total += ratesValue.toDefault(minor, currency) ?? minor;
    });
    return total;
  }

  var owed = 0;
  for (final debt in ref.watch(debtsProvider).value ?? const <Debt>[]) {
    if (debt.isSettled) continue;
    owed +=
        ratesValue.toDefault(debt.remainingMinor, debt.currency) ??
        debt.remainingMinor;
  }
  return (
    wallet: sum(ref.watch(accountBalancesProvider(MoneyAccount.wallet))),
    savings: sum(ref.watch(accountBalancesProvider(MoneyAccount.savings))),
    owed: owed,
  );
}

/// The live exchange-rate picture (checkpoint P5).
@Riverpod(keepAlive: true)
Stream<Rates> rates(Ref ref) {
  final defaultCurrency =
      ref.watch(financeSettingsProvider).value?.defaultCurrency ?? Currency.dzd;
  return ref
      .watch(settingsRepositoryProvider)
      .watchAll(const [
        'rate.dzdPerUsd',
        'rate.dzdPerEur',
        'rate.usdPerEur',
      ])
      .map(
        (values) => Rates(
          defaultCurrency: defaultCurrency,
          dzdPerUsd: double.tryParse(values['rate.dzdPerUsd'] ?? ''),
          dzdPerEur: double.tryParse(values['rate.dzdPerEur'] ?? ''),
          usdPerEur: double.tryParse(values['rate.usdPerEur'] ?? ''),
        ),
      );
}

// ------------------------------------------------------------ aggregation

/// Sums [expenses] per Harvest Day in the default currency
/// (face value when a rate is missing — never blocks).
Map<String, int> totalsByDay(List<Expense> expenses, Rates rates) {
  final totals = <String, int>{};
  for (final expense in expenses) {
    final value =
        rates.toDefault(expense.amountMinor, expense.currency) ??
        expense.amountMinor;
    totals.update(expense.day.key, (v) => v + value, ifAbsent: () => value);
  }
  return totals;
}

/// Sums [expenses] per category in the default currency.
Map<String, int> totalsByCategory(List<Expense> expenses, Rates rates) {
  final totals = <String, int>{};
  for (final expense in expenses) {
    final value =
        rates.toDefault(expense.amountMinor, expense.currency) ??
        expense.amountMinor;
    totals.update(expense.category, (v) => v + value, ifAbsent: () => value);
  }
  return totals;
}

/// Every expense in a span — the one source the Insights page reads,
/// whichever of the three ranges is chosen.
@riverpod
Stream<List<Expense>> rangeExpenses(Ref ref, DayRange range) =>
    ref.watch(financesRepositoryProvider).watchRange(range.from, range.to);

@riverpod
Map<String, int> rangeTotals(Ref ref, DayRange range) => totalsByDay(
  upToToday(
    ref.watch(rangeExpensesProvider(range)).value ?? const [],
    ref.watch(currentHarvestDayProvider),
  ),
  ref.watch(ratesOrDefaultProvider),
);

@riverpod
Map<String, int> rangeByCategory(Ref ref, DayRange range) => totalsByCategory(
  upToToday(
    ref.watch(rangeExpensesProvider(range)).value ?? const [],
    ref.watch(currentHarvestDayProvider),
  ),
  ref.watch(ratesOrDefaultProvider),
);

/// [expenses] without the ones logged ahead: the month counts up to
/// today ([[Finances]] Quick-log), so next week's rent is not spent yet
/// and no total, chart or average may read it ([[Audit-v3]] G5-03).
List<Expense> upToToday(List<Expense> expenses, HarvestDay today) => [
  for (final expense in expenses)
    if (expense.day.compareTo(today) <= 0) expense,
];

/// Every movement in a span, for the Insights page's own ledger.
@riverpod
Stream<List<MoneyTxn>> rangeTxns(Ref ref, DayRange range) =>
    ref.watch(vaultRepositoryProvider).watchTxnsBetween(range.from, range.to);

@riverpod
Map<String, int> monthTotals(Ref ref) => totalsByDay(
  upToToday(
    ref.watch(monthExpensesProvider).value ?? const [],
    ref.watch(currentHarvestDayProvider),
  ),
  ref.watch(ratesProvider).value ?? const Rates(defaultCurrency: Currency.dzd),
);

@riverpod
Map<String, int> weekTotals(Ref ref) => totalsByDay(
  upToToday(
    ref.watch(weekExpensesProvider).value ?? const [],
    ref.watch(currentHarvestDayProvider),
  ),
  ref.watch(ratesProvider).value ?? const Rates(defaultCurrency: Currency.dzd),
);

@riverpod
Map<String, int> monthByCategory(Ref ref) => totalsByCategory(
  upToToday(
    ref.watch(monthExpensesProvider).value ?? const [],
    ref.watch(currentHarvestDayProvider),
  ),
  ref.watch(ratesProvider).value ?? const Rates(defaultCurrency: Currency.dzd),
);

@riverpod
Map<String, int> weekByCategory(Ref ref) => totalsByCategory(
  upToToday(
    ref.watch(weekExpensesProvider).value ?? const [],
    ref.watch(currentHarvestDayProvider),
  ),
  ref.watch(ratesProvider).value ?? const Rates(defaultCurrency: Currency.dzd),
);

/// Today's budget picture in the default currency; null without a budget.
@riverpod
BudgetSnapshot? budgetSnapshot(Ref ref) {
  final settings = ref.watch(financeSettingsProvider).value;
  final budget = settings?.budgetMinor;
  if (budget == null || budget <= 0) return null;

  final totals = ref.watch(monthTotalsProvider);
  final today = ref.watch(currentHarvestDayProvider);
  var spentBefore = 0;
  var spentToday = 0;
  totals.forEach((day, amount) {
    if (day == today.key) {
      spentToday = amount;
    } else if (day.compareTo(today.key) < 0) {
      spentBefore += amount;
    }
  });
  return BudgetSnapshot.compute(
    monthlyBudget: budget,
    spentBeforeToday: spentBefore,
    spentToday: spentToday,
    day: today,
  );
}

/// Savings health: total savings (converted) below 10% of the budget.
enum SavingsHealth { unknown, healthy, low }

/// The rule itself (`savingsHealth` in `packages/core`, held to its
/// fixture): savings below a tenth of the monthly budget, converted at
/// the rates known (face value where one is missing), are low. With no
/// savings or no budget there is nothing to say (Q6-20).
SavingsHealth savingsHealthOf(
  Map<Currency, int> savings,
  int? monthlyBudget,
  Rates rates,
) {
  final held = {
    for (final entry in savings.entries)
      if (entry.value != 0) entry.key: entry.value,
  };
  if (held.isEmpty || monthlyBudget == null || monthlyBudget <= 0) {
    return SavingsHealth.unknown;
  }
  return rates.sumInDefault(held) < monthlyBudget ~/ 10
      ? SavingsHealth.low
      : SavingsHealth.healthy;
}

@riverpod
SavingsHealth savingsHealth(Ref ref) => savingsHealthOf(
  ref.watch(accountBalancesProvider(MoneyAccount.savings)),
  ref.watch(financeSettingsProvider).value?.budgetMinor,
  ref.watch(ratesProvider).value ?? const Rates(defaultCurrency: Currency.dzd),
);

/// The smart-repeat suggestion, refreshed as today's log changes.
@riverpod
Future<RepeatSuggestion?> repeatSuggestion(Ref ref) {
  ref.watch(todayExpensesProvider);
  return ref
      .watch(financesRepositoryProvider)
      .repeatSuggestion(ref.watch(currentHarvestDayProvider));
}
