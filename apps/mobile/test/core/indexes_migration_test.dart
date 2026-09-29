import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/db/database.dart';

import '../generated_migrations/schema.dart';

/// Schema v25: the hot filters read by index, not by scanning the
/// table ([[Audit-v3]] P6-11).
void main() {
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  const wanted = {
    'check_ins_day',
    'check_ins_seed',
    'seed_notes_seed_day',
    'note_links_from',
    'note_links_to',
    'memories_album_day',
    'session_exercises_session',
    'workout_sets_exercise',
    'ledger_reason',
    'ledger_day',
    'expenses_day',
    'money_txns_day',
    'debt_payments_debt',
    'outbox_row',
    'goal_items_goal',
    'location_points_day_time',
  };

  Future<Set<String>> indexes(HarvestDatabase db) async => {
    for (final row
        in await db
            .customSelect("SELECT name FROM sqlite_master WHERE type = 'index'")
            .get())
      row.read<String>('name'),
  };

  Future<String> plan(HarvestDatabase db, String sql) async => [
    for (final row in await db.customSelect('EXPLAIN QUERY PLAN $sql').get())
      row.read<String>('detail'),
  ].join(' | ');

  for (final from in [12, 21, 24]) {
    test('v$from gains every index on its way to v25', () async {
      final db = HarvestDatabase.forTesting(await verifier.startAt(from));
      await verifier.migrateAndValidate(db, 25);
      expect(await indexes(db), containsAll(wanted));
      await db.close();
    });
  }

  test("a seed's check-ins and an undo's ledger rows are searched, not "
      'scanned', () async {
    final db = HarvestDatabase.forTesting(await verifier.startAt(24));
    await verifier.migrateAndValidate(db, 25);
    expect(
      await plan(db, "SELECT * FROM check_ins WHERE commitment_uuid = 'x'"),
      contains('USING INDEX check_ins_seed'),
    );
    expect(
      await plan(db, "SELECT * FROM ledger WHERE reason = 'checkin:x'"),
      contains('USING INDEX ledger_reason'),
    );
    expect(
      await plan(
        db,
        "SELECT * FROM outbox WHERE target_table = 't' AND row_uuid = 'x'",
      ),
      contains('USING INDEX outbox_row'),
    );
    await db.close();
  });
}
