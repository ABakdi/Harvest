import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/db/database.dart';

import '../generated_migrations/schema.dart';
import '../generated_migrations/schema_v15.dart' as v15;
import '../generated_migrations/schema_v23.dart' as v23;

/// Schema v24 lets a goal item belong to another: subtasks ([[Goals]]
/// GL8, M6.13). Every item already there stays top-level and keeps
/// every other column, and the upgrade itself is not an edit.
void main() {
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  test('v23 items stay top-level, untouched', () async {
    await verifier.testWithDataIntegrity(
      oldVersion: 23,
      newVersion: 24,
      createOld: v23.DatabaseAtV23.new,
      createNew: HarvestDatabase.forTesting,
      openTestedDatabase: HarvestDatabase.forTesting,
      createItems: (batch, old) {
        batch
          ..insert(
            old.goals,
            const RawValuesInsertable<dynamic>({
              'uuid': Variable('g1'),
              'title': Variable('Half marathon'),
              'created_at': Variable('2026-09-01T08:00:00.000 +01:00'),
              'updated_at': Variable('2026-09-01T08:00:00.000 +01:00'),
            }),
          )
          ..insert(
            old.goalItems,
            const RawValuesInsertable<dynamic>({
              'uuid': Variable('shoes'),
              'goal_uuid': Variable('g1'),
              'kind': Variable('need'),
              'body': Variable('Running shoes'),
              'note': Variable('not the old ones'),
              'done_at': Variable('2026-09-05T13:00:00.000 +01:00'),
              'position': Variable(2),
              'commitment_uuid': Variable('c1'),
              'created_at': Variable('2026-09-01T08:03:00.000 +01:00'),
              'updated_at': Variable('2026-09-05T13:00:00.000 +01:00'),
            }),
          );
      },
      validateItems: (db) async {
        final row = await db.select(db.goalItems).getSingle();
        expect(row.parentUuid, isNull);
        expect(row.kind, 'need');
        expect(row.body, 'Running shoes');
        expect(row.note, 'not the old ones');
        expect(row.position, 2);
        expect(row.commitmentUuid, 'c1');
        expect(
          row.doneAt!.isAtSameMomentAs(DateTime.utc(2026, 9, 5, 12)),
          isTrue,
        );
        expect(
          row.updatedAt.isAtSameMomentAs(DateTime.utc(2026, 9, 5, 12)),
          isTrue,
        );
        expect(await db.select(db.outbox).get(), isEmpty);
      },
    );
  });

  test('a v15 item crosses both date rewrites with the new column', () async {
    final done = DateTime.utc(2026, 3, 14, 9, 26, 53);
    final seconds = done.millisecondsSinceEpoch ~/ 1000;

    await verifier.testWithDataIntegrity(
      oldVersion: 15,
      newVersion: 24,
      createOld: v15.DatabaseAtV15.new,
      createNew: HarvestDatabase.forTesting,
      openTestedDatabase: HarvestDatabase.forTesting,
      createItems: (batch, old) {
        batch
          ..insert(
            old.goals,
            RawValuesInsertable<dynamic>({
              'uuid': const Variable('g1'),
              'title': const Variable('Car'),
              'created_at': Variable(seconds),
              'updated_at': Variable(seconds),
            }),
          )
          ..insert(
            old.goalItems,
            RawValuesInsertable<dynamic>({
              'uuid': const Variable('save'),
              'goal_uuid': const Variable('g1'),
              'body': const Variable('Save 1000'),
              'done_at': Variable(seconds),
              'created_at': Variable(seconds),
              'updated_at': Variable(seconds),
            }),
          );
      },
      validateItems: (db) async {
        final row = await db.select(db.goalItems).getSingle();
        expect(row.parentUuid, isNull);
        expect(row.kind, 'step');
        expect(row.body, 'Save 1000');
        expect(row.doneAt!.toUtc(), done);
        expect(row.updatedAt.toUtc(), done);
      },
    );
  });
}
