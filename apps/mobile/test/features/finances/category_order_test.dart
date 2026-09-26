import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/features/finances/data/finances_repository.dart';

/// Custom categories are listed by when each was made. A restore (from
/// the web, arriving through sync) bumps `updated_at`, and must not move
/// the category to the end of the list for it.
void main() {
  late HarvestDatabase db;
  late FinancesRepository repo;

  setUp(() {
    db = HarvestDatabase.forTesting(NativeDatabase.memory());
    repo = FinancesRepository(db);
  });

  tearDown(() => db.close());

  Future<List<String>> names() async =>
      (await repo.watchCategories().first).map((c) => c.name).toList();

  test('a new category remembers when it was made', () async {
    await repo.createCategory(name: 'Books', icon: 'school');
    final row = await db.select(db.expenseCategories).getSingle();
    expect(row.createdAt, isNotNull);
  });

  test('a restored category keeps its place', () async {
    final made = DateTime.utc(2026, 9);
    for (final (i, name) in ['Books', 'Coffee', 'Gifts'].indexed) {
      final at = made.add(Duration(hours: i));
      await db
          .into(db.expenseCategories)
          .insert(
            ExpenseCategoriesCompanion.insert(
              uuid: name,
              name: name,
              icon: 'category',
              createdAt: Value(at),
              updatedAt: Value(at),
            ),
          );
    }
    await repo.deleteCategory('Books');
    await (db.update(
      db.expenseCategories,
    )..where((c) => c.uuid.equals('Books'))).write(
      ExpenseCategoriesCompanion(
        deletedAt: const Value(null),
        updatedAt: Value(DateTime.utc(2026, 9, 20)),
      ),
    );

    expect(await names(), ['Books', 'Coffee', 'Gifts']);
  });

  test('a category from before created_at orders by its last edit', () async {
    await db
        .into(db.expenseCategories)
        .insert(
          ExpenseCategoriesCompanion.insert(
            uuid: 'coffee',
            name: 'Coffee',
            icon: 'coffee',
            createdAt: Value(DateTime.utc(2026, 9, 2)),
            updatedAt: Value(DateTime.utc(2026, 9, 2)),
          ),
        );
    await db
        .into(db.expenseCategories)
        .insert(
          ExpenseCategoriesCompanion.insert(
            uuid: 'books',
            name: 'Books',
            icon: 'school',
            updatedAt: Value(DateTime.utc(2026, 9)),
          ),
        );

    expect(await names(), ['Books', 'Coffee']);
  });
}
