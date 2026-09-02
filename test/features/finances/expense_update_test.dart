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
    final week =
        await repo.watchWeek(HarvestDay.parse('2026-08-31')).first;
    final totals = totalsByCategory(
      week,
      const Rates(defaultCurrency: Currency.dzd),
    );
    expect(totals[ExpenseCategory.food.name], 300);
  });
}
