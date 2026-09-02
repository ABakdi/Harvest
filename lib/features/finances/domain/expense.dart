import 'package:harvest/core/domain/harvest_day.dart';
import 'package:meta/meta.dart';

/// The preset spending categories.
enum ExpenseCategory {
  food,
  transport,
  bills,
  shopping,
  health,
  entertainment,
  other,
}

@immutable
class Expense {
  const Expense({
    required this.uuid,
    required this.amountMinor,
    required this.category,
    required this.day,
    required this.loggedAt,
    this.note,
  });

  final String uuid;

  /// Minor units (cents); always positive.
  final int amountMinor;
  final ExpenseCategory category;
  final HarvestDay day;
  final DateTime loggedAt;
  final String? note;
}

/// A pre-filled suggestion: the same amount + category was logged on
/// three consecutive days — offer day four as a one-tap confirm.
@immutable
class RepeatSuggestion {
  const RepeatSuggestion({
    required this.amountMinor,
    required this.category,
    this.note,
  });

  final int amountMinor;
  final ExpenseCategory category;
  final String? note;
}

/// Gauge status for the floating daily limit (green/yellow/red).
enum BudgetStatus { under, close, over }

/// A day's budget picture, all in minor units.
@immutable
class BudgetSnapshot {
  const BudgetSnapshot({
    required this.monthlyBudget,
    required this.spentThisMonth,
    required this.spentToday,
    required this.floatingDailyLimit,
  });

  /// Computes the snapshot for [day].
  ///
  /// The floating limit divides what's left of the budget — excluding
  /// today's own spending — across today and the days still to come, so
  /// overspending early in the month visibly tightens the tap.
  factory BudgetSnapshot.compute({
    required int monthlyBudget,
    required int spentBeforeToday,
    required int spentToday,
    required HarvestDay day,
  }) {
    final daysInMonth = DateTime(day.year, day.month + 1, 0).day;
    final remainingDays = daysInMonth - day.day + 1;
    final remainingBudget = (monthlyBudget - spentBeforeToday).clamp(
      0,
      monthlyBudget,
    );
    return BudgetSnapshot(
      monthlyBudget: monthlyBudget,
      spentThisMonth: spentBeforeToday + spentToday,
      spentToday: spentToday,
      floatingDailyLimit: remainingBudget ~/ remainingDays,
    );
  }

  final int monthlyBudget;
  final int spentThisMonth;
  final int spentToday;

  /// Remaining budget spread over the remaining days of the month,
  /// recomputed daily (spec: Financial Granary budget logic).
  final int floatingDailyLimit;

  BudgetStatus get status {
    if (spentToday > floatingDailyLimit) return BudgetStatus.over;
    if (spentToday >= 0.85 * floatingDailyLimit) return BudgetStatus.close;
    return BudgetStatus.under;
  }
}
