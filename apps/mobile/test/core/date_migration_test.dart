import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/db/database.dart';

import '../generated_migrations/schema.dart';
import '../generated_migrations/schema_v17.dart' as v17;

/// Schema v18 turns every stored date from unix seconds into ISO-8601
/// text ([[Sync-API]], M6.8). What a date *is* must not change in the
/// crossing: a seed planted at a moment is still planted at that
/// moment, and what is written afterwards keeps the microseconds that
/// seconds never had.
void main() {
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  test('a date written as seconds reads back as the same instant', () async {
    // A moment with no round number about it.
    final logged = DateTime.utc(2026, 3, 14, 9, 26, 53);
    final seconds = logged.millisecondsSinceEpoch ~/ 1000;

    await verifier.testWithDataIntegrity(
      oldVersion: 17,
      newVersion: 21,
      createOld: v17.DatabaseAtV17.new,
      createNew: HarvestDatabase.forTesting,
      openTestedDatabase: HarvestDatabase.forTesting,
      createItems: (batch, old) {
        batch
          ..insert(
            old.commitments,
            RawValuesInsertable<dynamic>({
              'uuid': const Variable('seed'),
              'type': const Variable('habit'),
              'title': const Variable('Read'),
              'start_day': const Variable('2026-03-14'),
              'created_at': Variable(seconds),
              'updated_at': Variable(seconds),
            }),
          )
          ..insert(
            old.checkIns,
            RawValuesInsertable<dynamic>({
              'uuid': const Variable('tick'),
              'commitment_uuid': const Variable('seed'),
              'harvest_day': const Variable('2026-03-14'),
              'quantity': const Variable(1),
              'logged_at': Variable(seconds),
              'updated_at': Variable(seconds),
            }),
          );
      },
      validateItems: (db) async {
        // Read back through the app's own database, because what
        // matters is the instant the app sees, not the spelling.
        final seed = await db.select(db.commitments).getSingle();
        expect(seed.title, 'Read');
        expect(seed.createdAt.toUtc(), logged);
        expect(seed.updatedAt.toUtc(), logged);

        final tick = await db.select(db.checkIns).getSingle();
        expect(tick.loggedAt.toUtc(), logged);

        // And the spelling, once, so the format is not a guess: sqlite
        // writes UTC with no offset, which drift reads as UTC.
        final raw = await db
            .customSelect('SELECT created_at FROM commitments')
            .getSingle();
        expect(raw.read<String>('created_at'), '2026-03-14 09:26:53');
      },
    );
  });

  test('what is written now keeps its microseconds', () async {
    final db = HarvestDatabase.forTesting(await verifier.startAt(18));
    final precise = DateTime.utc(2026, 9, 20, 11, 22, 33, 444, 555);
    await db
        .into(db.commitments)
        .insert(
          CommitmentsCompanion.insert(
            uuid: 'seed',
            type: 'habit',
            title: 'Walk',
            createdAt: Value(precise),
            updatedAt: Value(precise),
          ),
        );

    final row = await db.select(db.commitments).getSingle();
    expect(row.updatedAt.toUtc(), precise);
    expect(row.updatedAt.toUtc().microsecond, 555);

    // Two edits in the same second no longer carry the same clock,
    // which is the whole point of the change.
    await (db.update(
      db.commitments,
    )..where((c) => c.uuid.equals('seed'))).write(
      CommitmentsCompanion(
        updatedAt: Value(precise.add(const Duration(microseconds: 1))),
      ),
    );
    final after = await db.select(db.commitments).getSingle();
    expect(after.updatedAt.toUtc().isAfter(precise), isTrue);
    await db.close();
  });
}
