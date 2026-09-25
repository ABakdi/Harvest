import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/db/database.dart';

import '../generated_migrations/schema.dart';
import '../generated_migrations/schema_v17.dart' as v17;
import '../generated_migrations/schema_v20.dart' as v20;

/// Schema v21 gives expense categories a `created_at`, the order the
/// list is kept in, so a restored category keeps its place. A row that
/// was already there takes its last edit as the best guess, which is
/// the order it already had.
void main() {
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  test('a category from v20 is made when it was last edited', () async {
    final edited = DateTime.utc(2026, 9, 2, 10, 0, 0, 123, 456);

    await verifier.testWithDataIntegrity(
      oldVersion: 20,
      newVersion: 21,
      createOld: v20.DatabaseAtV20.new,
      createNew: HarvestDatabase.forTesting,
      openTestedDatabase: HarvestDatabase.forTesting,
      createItems: (batch, old) {
        batch.insert(
          old.expenseCategories,
          RawValuesInsertable<dynamic>({
            'uuid': const Variable('books'),
            'name': const Variable('Books'),
            'icon': const Variable('school'),
            'updated_at': Variable(edited.toIso8601String()),
          }),
        );
      },
      validateItems: (db) async {
        final row = await db.select(db.expenseCategories).getSingle();
        expect(row.createdAt?.toUtc(), edited);
        expect(row.updatedAt.toUtc(), edited);
      },
    );
  });

  test('a category from before the date rewrite converts both', () async {
    final edited = DateTime.utc(2026, 3, 14, 9, 26, 53);
    final seconds = edited.millisecondsSinceEpoch ~/ 1000;

    await verifier.testWithDataIntegrity(
      oldVersion: 17,
      newVersion: 21,
      createOld: v17.DatabaseAtV17.new,
      createNew: HarvestDatabase.forTesting,
      openTestedDatabase: HarvestDatabase.forTesting,
      createItems: (batch, old) {
        batch.insert(
          old.expenseCategories,
          RawValuesInsertable<dynamic>({
            'uuid': const Variable('books'),
            'name': const Variable('Books'),
            'icon': const Variable('school'),
            'updated_at': Variable(seconds),
          }),
        );
      },
      validateItems: (db) async {
        final row = await db.select(db.expenseCategories).getSingle();
        expect(row.createdAt?.toUtc(), edited);
        expect(row.updatedAt.toUtc(), edited);
      },
    );
  });
}
