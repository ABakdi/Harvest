import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/db/database.dart';

import '../generated_migrations/schema.dart';

/// Schema migration harness. Today it verifies that a freshly created
/// database matches schema v1 exactly; every future schema bump adds a
/// migration path test here (v1 → v2, …) before it may ship.
///
/// Workflow for a schema change:
///   1. bump schemaVersion + write the migration in database.dart
///   2. dart run drift_dev schema dump lib/core/db/database.dart drift_schemas/
///   3. dart run drift_dev schema generate drift_schemas/ test/generated_migrations/
///   4. add the upgrade test below
void main() {
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  test('fresh database creates schema v1 correctly', () async {
    final connection = await verifier.startAt(1);
    final db = HarvestDatabase.forTesting(connection);
    await verifier.migrateAndValidate(db, 1);
    await db.close();
  });
}
