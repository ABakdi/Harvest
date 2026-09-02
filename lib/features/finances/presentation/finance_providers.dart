import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/finances/data/finances_repository.dart';
import 'package:harvest/features/finances/domain/expense.dart';
import 'package:harvest/features/settings/data/settings_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'finance_providers.g.dart';

abstract final class FinanceKeys {
  static const monthlyBudget = 'finance.monthlyBudgetMinor';
  static const currencySymbol = 'finance.currencySymbol';
  static const savings = 'finance.savingsMinor';
  static const expectedDaily = 'finance.expectedDailyMinor';
}

@riverpod
Stream<List<Expense>> todayExpenses(Ref ref) =>
    ref.watch(financesRepositoryProvider).watchDay(HarvestDay.today());

@riverpod
Stream<Map<String, int>> monthTotals(Ref ref) => ref
    .watch(financesRepositoryProvider)
    .watchMonthTotals(HarvestDay.today());

@riverpod
Stream<Map<String, int>> monthByCategory(Ref ref) => ref
    .watch(financesRepositoryProvider)
    .watchMonthByCategory(HarvestDay.today());

@riverpod
Stream<Map<String, int>> weekByCategory(Ref ref) => ref
    .watch(financesRepositoryProvider)
    .watchWeekByCategory(HarvestDay.today().weekStart);

@riverpod
Stream<List<CustomCategory>> customCategories(Ref ref) =>
    ref.watch(financesRepositoryProvider).watchCategories();

/// Budget + currency settings.
@Riverpod(keepAlive: true)
class FinanceSettings extends _$FinanceSettings {
  @override
  Stream<
      ({
        int? budgetMinor,
        String symbol,
        int? savingsMinor,
        int? expectedDailyMinor,
      })> build() =>
      ref.watch(settingsRepositoryProvider).watchAll(const [
        FinanceKeys.monthlyBudget,
        FinanceKeys.currencySymbol,
        FinanceKeys.savings,
        FinanceKeys.expectedDaily,
      ]).map(
        (values) => (
          budgetMinor: int.tryParse(values[FinanceKeys.monthlyBudget] ?? ''),
          symbol: values[FinanceKeys.currencySymbol] ?? r'$',
          savingsMinor: int.tryParse(values[FinanceKeys.savings] ?? ''),
          expectedDailyMinor:
              int.tryParse(values[FinanceKeys.expectedDaily] ?? ''),
        ),
      );

  Future<void> setBudget(int minor) => ref
      .read(settingsRepositoryProvider)
      .setString(FinanceKeys.monthlyBudget, '$minor');

  Future<void> setSymbol(String symbol) => ref
      .read(settingsRepositoryProvider)
      .setString(FinanceKeys.currencySymbol, symbol);

  Future<void> setSavings(int minor) => ref
      .read(settingsRepositoryProvider)
      .setString(FinanceKeys.savings, '$minor');

  Future<void> setExpectedDaily(int minor) => ref
      .read(settingsRepositoryProvider)
      .setString(FinanceKeys.expectedDaily, '$minor');
}

/// Savings health (checkpoint gap G5/G11): warn when the pot drops
/// below 10% of the monthly budget.
enum SavingsHealth { unknown, healthy, low }

@riverpod
SavingsHealth savingsHealth(Ref ref) {
  final settings = ref.watch(financeSettingsProvider).value;
  final savings = settings?.savingsMinor;
  final budget = settings?.budgetMinor;
  if (savings == null || budget == null || budget <= 0) {
    return SavingsHealth.unknown;
  }
  return savings < budget ~/ 10 ? SavingsHealth.low : SavingsHealth.healthy;
}

/// Daily totals for the current week (Mon..today).
@riverpod
Stream<Map<String, int>> weekTotals(Ref ref) => ref
    .watch(financesRepositoryProvider)
    .watchWeekTotals(HarvestDay.today().weekStart);

/// Today's budget picture; null while no budget is set.
@riverpod
BudgetSnapshot? budgetSnapshot(Ref ref) {
  final settings = ref.watch(financeSettingsProvider).value;
  final budget = settings?.budgetMinor;
  if (budget == null || budget <= 0) return null;

  final totals = ref.watch(monthTotalsProvider).value ?? const {};
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

/// The smart-repeat suggestion, refreshed as today's log changes.
@riverpod
Future<RepeatSuggestion?> repeatSuggestion(Ref ref) {
  ref.watch(todayExpensesProvider);
  return ref
      .watch(financesRepositoryProvider)
      .repeatSuggestion(HarvestDay.today());
}
