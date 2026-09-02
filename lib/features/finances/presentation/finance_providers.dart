import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/finances/data/finances_repository.dart';
import 'package:harvest/features/finances/data/vault_repository.dart';
import 'package:harvest/features/finances/domain/currency.dart';
import 'package:harvest/features/finances/domain/expense.dart';
import 'package:harvest/features/finances/domain/vault.dart';
import 'package:harvest/features/settings/data/settings_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'finance_providers.g.dart';

abstract final class FinanceKeys {
  static const monthlyBudget = 'finance.monthlyBudgetMinor';
  static const defaultCurrency = 'finance.defaultCurrency';
  static const expectedDaily = 'finance.expectedDailyMinor';

  static String savingsFor(Currency currency) =>
      'finance.savings.${currency.code}';
}

@riverpod
Stream<List<Expense>> todayExpenses(Ref ref) =>
    ref.watch(financesRepositoryProvider).watchDay(HarvestDay.today());

@riverpod
Stream<List<Expense>> monthExpenses(Ref ref) =>
    ref.watch(financesRepositoryProvider).watchMonth(HarvestDay.today());

@riverpod
Stream<List<Expense>> weekExpenses(Ref ref) => ref
    .watch(financesRepositoryProvider)
    .watchWeek(HarvestDay.today().weekStart);

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
        int? expectedDailyMinor,
      })> build() =>
      ref.watch(settingsRepositoryProvider).watchAll(const [
        FinanceKeys.monthlyBudget,
        FinanceKeys.defaultCurrency,
        FinanceKeys.expectedDaily,
      ]).map(
        (values) => (
          budgetMinor: int.tryParse(values[FinanceKeys.monthlyBudget] ?? ''),
          defaultCurrency:
              Currency.fromCode(values[FinanceKeys.defaultCurrency]),
          expectedDailyMinor:
              int.tryParse(values[FinanceKeys.expectedDaily] ?? ''),
        ),
      );

  Future<void> setBudget(int minor) => ref
      .read(settingsRepositoryProvider)
      .setString(FinanceKeys.monthlyBudget, '$minor');

  Future<void> setDefaultCurrency(Currency currency) => ref
      .read(settingsRepositoryProvider)
      .setString(FinanceKeys.defaultCurrency, currency.code);

  Future<void> setExpectedDaily(int minor) => ref
      .read(settingsRepositoryProvider)
      .setString(FinanceKeys.expectedDaily, '$minor');
}

// ------------------------------------------------------------------ vault

@riverpod
Stream<Map<(MoneyAccount, Currency), int>> vaultBalances(Ref ref) =>
    ref.watch(vaultRepositoryProvider).watchBalances();

@riverpod
Stream<List<MoneyTxn>> recentTxns(Ref ref) =>
    ref.watch(vaultRepositoryProvider).watchRecentTxns();

@riverpod
Stream<List<Debt>> debts(Ref ref) =>
    ref.watch(vaultRepositoryProvider).watchDebts();

/// The live exchange-rate picture (checkpoint P5).
@Riverpod(keepAlive: true)
Stream<Rates> rates(Ref ref) {
  final defaultCurrency = ref
          .watch(financeSettingsProvider)
          .value
          ?.defaultCurrency ??
      Currency.dzd;
  return ref.watch(settingsRepositoryProvider).watchAll(const [
    'rate.dzdPerUsd',
    'rate.dzdPerEur',
    'rate.usdPerEur',
  ]).map(
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

@riverpod
Map<String, int> monthTotals(Ref ref) => totalsByDay(
      ref.watch(monthExpensesProvider).value ?? const [],
      ref.watch(ratesProvider).value ??
          const Rates(defaultCurrency: Currency.dzd),
    );

@riverpod
Map<String, int> weekTotals(Ref ref) => totalsByDay(
      ref.watch(weekExpensesProvider).value ?? const [],
      ref.watch(ratesProvider).value ??
          const Rates(defaultCurrency: Currency.dzd),
    );

@riverpod
Map<String, int> monthByCategory(Ref ref) => totalsByCategory(
      ref.watch(monthExpensesProvider).value ?? const [],
      ref.watch(ratesProvider).value ??
          const Rates(defaultCurrency: Currency.dzd),
    );

@riverpod
Map<String, int> weekByCategory(Ref ref) => totalsByCategory(
      ref.watch(weekExpensesProvider).value ?? const [],
      ref.watch(ratesProvider).value ??
          const Rates(defaultCurrency: Currency.dzd),
    );

/// Today's budget picture in the default currency; null without a budget.
@riverpod
BudgetSnapshot? budgetSnapshot(Ref ref) {
  final settings = ref.watch(financeSettingsProvider).value;
  final budget = settings?.budgetMinor;
  if (budget == null || budget <= 0) return null;

  final totals = ref.watch(monthTotalsProvider);
  final today = HarvestDay.today();
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

@riverpod
SavingsHealth savingsHealth(Ref ref) {
  final budget = ref.watch(financeSettingsProvider).value?.budgetMinor;
  final balances = ref.watch(vaultBalancesProvider).value ?? const {};
  final savings = <Currency, int>{
    for (final entry in balances.entries)
      if (entry.key.$1 == MoneyAccount.savings && entry.value != 0)
        entry.key.$2: entry.value,
  };
  if (savings.isEmpty || budget == null || budget <= 0) {
    return SavingsHealth.unknown;
  }
  final ratesValue = ref.watch(ratesProvider).value ??
      const Rates(defaultCurrency: Currency.dzd);
  var total = 0;
  savings.forEach((currency, minor) {
    total += ratesValue.toDefault(minor, currency) ?? minor;
  });
  return total < budget ~/ 10 ? SavingsHealth.low : SavingsHealth.healthy;
}

/// The smart-repeat suggestion, refreshed as today's log changes.
@riverpod
Future<RepeatSuggestion?> repeatSuggestion(Ref ref) {
  ref.watch(todayExpensesProvider);
  return ref
      .watch(financesRepositoryProvider)
      .repeatSuggestion(HarvestDay.today());
}
