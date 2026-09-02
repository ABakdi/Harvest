import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/finances/data/finances_repository.dart';
import 'package:harvest/features/finances/domain/currency.dart';
import 'package:harvest/features/finances/domain/expense.dart';
import 'package:harvest/features/finances/presentation/finance_providers.dart';
import 'package:harvest/features/finances/presentation/money.dart';

void main() {
  group('BudgetSnapshot.compute', () {
    // September has 30 days.
    final day10 = HarvestDay.parse('2026-09-10');

    test('spreads the remaining budget over the remaining days', () {
      final snap = BudgetSnapshot.compute(
        monthlyBudget: 60000, // 600.00
        spentBeforeToday: 18000,
        spentToday: 0,
        day: day10,
      );
      // 21 days left (10th..30th): 42000 / 21 = 2000.
      expect(snap.floatingDailyLimit, 2000);
      expect(snap.status, BudgetStatus.under);
    });

    test('gauge turns yellow near the limit and red over it', () {
      BudgetSnapshot at(int spentToday) => BudgetSnapshot.compute(
            monthlyBudget: 60000,
            spentBeforeToday: 18000,
            spentToday: spentToday,
            day: day10,
          );
      expect(at(1699).status, BudgetStatus.under);
      expect(at(1700).status, BudgetStatus.close); // 85% of 2000
      expect(at(2001).status, BudgetStatus.over);
    });

    test('an overspent month floors the limit at zero', () {
      final snap = BudgetSnapshot.compute(
        monthlyBudget: 10000,
        spentBeforeToday: 15000,
        spentToday: 500,
        day: day10,
      );
      expect(snap.floatingDailyLimit, 0);
      expect(snap.status, BudgetStatus.over);
    });

    test('last day of the month gets the full remainder', () {
      final snap = BudgetSnapshot.compute(
        monthlyBudget: 30000,
        spentBeforeToday: 27000,
        spentToday: 0,
        day: HarvestDay.parse('2026-09-30'),
      );
      expect(snap.floatingDailyLimit, 3000);
    });
  });

  group('money parsing', () {
    test('accepts whole, one and two decimal forms', () {
      expect(parseToMinor('12'), 1200);
      expect(parseToMinor('12.5'), 1250);
      expect(parseToMinor('12.50'), 1250);
      expect(parseToMinor('12,50'), 1250);
      expect(parseToMinor('0.05'), 5);
    });

    test('rejects junk and non-positive amounts', () {
      expect(parseToMinor(''), isNull);
      expect(parseToMinor('abc'), isNull);
      expect(parseToMinor('1.2.3'), isNull);
      expect(parseToMinor('12.345'), isNull);
      expect(parseToMinor('0'), isNull);
    });

    test('formats minor units back', () {
      expect(formatMinor(1200), '12');
      expect(formatMinor(1250), '12.50');
      expect(formatMinor(5), '0.05');
    });
  });

  group('FinancesRepository', () {
    late HarvestDatabase db;
    late FinancesRepository repo;
    final day = HarvestDay.parse('2026-09-10');

    setUp(() {
      db = HarvestDatabase.forTesting(NativeDatabase.memory());
      repo = FinancesRepository(db);
    });

    tearDown(() => db.close());

    Future<int> xpTotal() async {
      final sum = db.ledger.delta.sum();
      final query = db.selectOnly(db.ledger)..addColumns([sum]);
      return (await query.getSingle()).read(sum) ?? 0;
    }

    test('first log of the day earns XP once', () async {
      await repo.log(
        amountMinor: 500,
        category: ExpenseCategory.food.name,
        day: day,
      );
      await repo.log(
        amountMinor: 1200,
        category: ExpenseCategory.transport.name,
        day: day,
      );
      expect(await xpTotal(), expenseLogXp);

      // A new day earns again.
      await repo.log(
        amountMinor: 800,
        category: ExpenseCategory.food.name,
        day: day.next,
      );
      expect(await xpTotal(), 2 * expenseLogXp);
    });

    test('writes land in the outbox', () async {
      await repo.log(
        amountMinor: 500,
        category: ExpenseCategory.food.name,
        day: day,
      );
      final ops = await db.select(db.outbox).get();
      expect(ops.single.targetTable, 'expenses');
    });

    test('smart repeat appears after three straight days', () async {
      for (var i = 1; i <= 3; i++) {
        final d = HarvestDay.parse('2026-09-0$i');
        await repo.log(
          amountMinor: 500,
          category: ExpenseCategory.food.name,
          note: 'Coffee',
          day: d,
        );
      }
      final suggestion =
          await repo.repeatSuggestion(HarvestDay.parse('2026-09-04'));
      expect(suggestion, isNotNull);
      expect(suggestion!.amountMinor, 500);
      expect(suggestion.category, ExpenseCategory.food.name);
      expect(suggestion.note, 'Coffee');
    });

    test('no repeat when a day is missing or already logged today',
        () async {
      for (final key in ['2026-09-01', '2026-09-03']) {
        await repo.log(
          amountMinor: 500,
          category: ExpenseCategory.food.name,
          day: HarvestDay.parse(key),
        );
      }
      expect(
        await repo.repeatSuggestion(HarvestDay.parse('2026-09-04')),
        isNull,
      );

      // Three straight days, but day four already has the same entry.
      for (final key in ['2026-09-02', '2026-09-04']) {
        await repo.log(
          amountMinor: 500,
          category: ExpenseCategory.food.name,
          day: HarvestDay.parse(key),
        );
      }
      expect(
        await repo.repeatSuggestion(HarvestDay.parse('2026-09-04')),
        isNull,
      );
    });

    test('removed expenses vanish from totals', () async {
      await repo.log(
        amountMinor: 500,
        category: ExpenseCategory.food.name,
        day: day,
      );
      final logged = await repo.watchDay(day).first;
      await repo.remove(logged.single.uuid);
      expect(await repo.watchDay(day).first, isEmpty);
      final month = await repo.watchMonth(day).first;
      final totals = totalsByDay(
        month,
        const Rates(defaultCurrency: Currency.dzd),
      );
      expect(totals[day.key], isNull);
    });
  });
}
