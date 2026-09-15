import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/finances/data/finances_repository.dart';
import 'package:harvest/features/finances/domain/currency.dart';
import 'package:harvest/features/finances/domain/expense.dart';
import 'package:harvest/features/finances/presentation/finance_providers.dart';

void main() {
  late HarvestDatabase db;
  late FinancesRepository repo;
  final day = HarvestDay.parse('2026-09-02');

  setUp(() {
    db = HarvestDatabase.forTesting(NativeDatabase.memory());
    repo = FinancesRepository(db);
  });

  tearDown(() => db.close());

  test('edit-in-place changes amount, category and note', () async {
    await repo.log(
      amountMinor: 500,
      category: ExpenseCategory.food.name,
      day: day,
    );
    final logged = (await repo.watchDay(day).first).single;

    await repo.updateExpense(
      uuid: logged.uuid,
      amountMinor: 750,
      category: ExpenseCategory.transport.name,
      note: 'Bus pass',
    );
    final updated = (await repo.watchDay(day).first).single;
    expect(updated.amountMinor, 750);
    expect(updated.category, ExpenseCategory.transport.name);
    expect(updated.note, 'Bus pass');

    final ops = await db.select(db.outbox).get();
    expect(ops.map((o) => o.op), containsAll(['insert', 'update']));
  });

  test('weekly category totals cover exactly the week', () async {
    // Monday 2026-08-31 starts this week.
    await repo.log(
      amountMinor: 100,
      category: ExpenseCategory.food.name,
      day: HarvestDay.parse('2026-08-31'),
    );
    await repo.log(
      amountMinor: 200,
      category: ExpenseCategory.food.name,
      day: HarvestDay.parse('2026-09-02'),
    );
    // Outside the week.
    await repo.log(
      amountMinor: 999,
      category: ExpenseCategory.food.name,
      day: HarvestDay.parse('2026-08-30'),
    );
    final week = await repo.watchWeek(HarvestDay.parse('2026-08-31')).first;
    final totals = totalsByCategory(
      week,
      const Rates(defaultCurrency: Currency.dzd),
    );
    expect(totals[ExpenseCategory.food.name], 300);
  });

  group('moving an expense to another day', () {
    Future<int> xpOn(HarvestDay on) async {
      final rows = await db.select(db.ledger).get();
      return rows
          .where((row) => row.harvestDay == on.key)
          .fold<int>(0, (sum, row) => sum + row.delta);
    }

    test("takes the old day's XP back and pays the new day", () async {
      final tuesday = HarvestDay.parse('2026-09-01');
      await repo.log(
        amountMinor: 500,
        category: ExpenseCategory.food.name,
        day: day,
      );
      final logged = (await repo.watchDay(day).first).single;
      expect(await xpOn(day), expenseLogXp);

      await repo.updateExpense(
        uuid: logged.uuid,
        amountMinor: 500,
        category: ExpenseCategory.food.name,
        day: tuesday,
      );
      expect(await repo.watchDay(day).first, isEmpty);
      expect((await repo.watchDay(tuesday).first).single.day, tuesday);
      expect(await xpOn(day), 0, reason: 'its last expense left');
      expect(await xpOn(tuesday), expenseLogXp);
    });

    test('leaves the old day paid while it still has an expense', () async {
      final tuesday = HarvestDay.parse('2026-09-01');
      await repo.log(
        amountMinor: 500,
        category: ExpenseCategory.food.name,
        day: day,
      );
      await repo.log(
        amountMinor: 200,
        category: ExpenseCategory.food.name,
        day: day,
      );
      final first = (await repo.watchDay(day).first).last;
      await repo.updateExpense(
        uuid: first.uuid,
        amountMinor: 500,
        category: ExpenseCategory.food.name,
        day: tuesday,
      );
      expect(await xpOn(day), expenseLogXp);
      expect(await xpOn(tuesday), expenseLogXp);
    });

    test('the same day is not a move', () async {
      await repo.log(
        amountMinor: 500,
        category: ExpenseCategory.food.name,
        day: day,
      );
      final logged = (await repo.watchDay(day).first).single;
      await repo.updateExpense(
        uuid: logged.uuid,
        amountMinor: 600,
        category: ExpenseCategory.food.name,
        day: day,
      );
      expect(await xpOn(day), expenseLogXp);
    });
  });
}
