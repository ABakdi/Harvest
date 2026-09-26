import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/features/sync/domain/row_codec.dart';

import '../generated_migrations/schema.dart';
import '../generated_migrations/schema_v21.dart' as v21;

/// Schema v22 stamps rows from the phone's clock instead of sqlite's.
/// sqlite's `CURRENT_TIMESTAMP` wrote UTC with no zone, which read back
/// as a UTC clock: in Algiers an expense logged at 4:21 PM showed 3:21.
/// Every UTC spelling is rewritten to the local one, keeping its
/// instant, and a date the app already wrote is left alone.
///
/// These hold in any zone, and only bite in one that is not UTC: run
/// them as `TZ=Africa/Algiers flutter test test/core`.
void main() {
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  // 3:21 PM UTC, 4:21 PM in Algiers.
  final logged = DateTime.utc(2026, 9, 25, 15, 21);

  /// What the app writes for [moment]: the local clock and its offset.
  String spelled(HarvestDatabase db, DateTime moment) =>
      db.typeMapping.mapToSqlVariable(moment.toLocal())! as String;

  Future<String> raw(HarvestDatabase db, String sql) async =>
      (await db.customSelect(sql).getSingle()).data.values.first! as String;

  test('v21 UTC dates come back on the local clock', () async {
    final before = DateTime.now().toUtc().subtract(const Duration(seconds: 1));
    late DateTime after;
    const ownSpelling = '2026-09-25T16:21:00.000 +01:00';

    await verifier.testWithDataIntegrity(
      oldVersion: 21,
      newVersion: 24,
      createOld: v21.DatabaseAtV21.new,
      createNew: HarvestDatabase.forTesting,
      openTestedDatabase: HarvestDatabase.forTesting,
      createItems: (batch, old) {
        batch
          // sqlite's own clock, as the old column default wrote it.
          ..insert(
            old.expenses,
            const RawValuesInsertable<dynamic>({
              'uuid': Variable('spelled'),
              'amount_minor': Variable(1200),
              'category': Variable('food'),
              'harvest_day': Variable('2026-09-25'),
              'logged_at': Variable('2026-09-25 15:21:00'),
              // A pulled row, in UTC with a `Z`.
              'updated_at': Variable('2026-09-25T15:21:00.000Z'),
              // The app's own spelling stays exactly as it is.
              'deleted_at': Variable(ownSpelling),
            }),
          )
          // Left to the old default itself.
          ..insert(
            old.expenses,
            const RawValuesInsertable<dynamic>({
              'uuid': Variable('defaulted'),
              'amount_minor': Variable(300),
              'category': Variable('food'),
              'harvest_day': Variable('2026-09-25'),
            }),
          );
        after = DateTime.now().toUtc().add(const Duration(seconds: 1));
      },
      validateItems: (db) async {
        final row = await (db.select(
          db.expenses,
        )..where((e) => e.uuid.equals('spelled'))).getSingle();
        expect(row.loggedAt.isUtc, isFalse);
        expect(row.loggedAt.toUtc(), logged);
        expect(row.loggedAt.hour, logged.toLocal().hour);
        expect(row.updatedAt.isUtc, isFalse);
        expect(row.updatedAt.toUtc(), logged);
        expect(
          await raw(
            db,
            "SELECT logged_at FROM expenses WHERE uuid = 'spelled'",
          ),
          spelled(db, logged),
        );
        expect(
          await raw(
            db,
            "SELECT deleted_at FROM expenses WHERE uuid = 'spelled'",
          ),
          ownSpelling,
        );

        final defaulted = await (db.select(
          db.expenses,
        )..where((e) => e.uuid.equals('defaulted'))).getSingle();
        expect(defaulted.loggedAt.isUtc, isFalse);
        final instant = defaulted.loggedAt.toUtc();
        expect(instant.isAfter(before), isTrue);
        expect(instant.isBefore(after), isTrue);
      },
    );
  });

  test('a default stamp reads back as the instant it was made', () async {
    final db = HarvestDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final before = DateTime.now();
    await db
        .into(db.expenses)
        .insert(
          ExpensesCompanion.insert(
            uuid: 'x',
            amountMinor: 100,
            category: 'food',
            harvestDay: '2026-09-25',
          ),
        );
    final after = DateTime.now();

    final row = await db.select(db.expenses).getSingle();
    expect(row.loggedAt.isUtc, isFalse);
    expect(row.loggedAt.timeZoneOffset, before.timeZoneOffset);
    expect(row.loggedAt.isBefore(before), isFalse);
    expect(row.loggedAt.isAfter(after), isFalse);
    final text = await raw(db, 'SELECT logged_at FROM expenses');
    expect(text, contains('T'));
    expect(text, spelled(db, row.loggedAt));
  });

  group('the sync codec', () {
    late HarvestDatabase db;
    late TableCodec codec;

    setUp(() {
      db = HarvestDatabase.forTesting(NativeDatabase.memory());
      codec = TableCodec(db.expenses);
    });
    tearDown(() => db.close());

    test('sends a zone-less date as the UTC it is, with a Z', () {
      final data = codec.toData({
        'uuid': 'x',
        'logged_at': '2026-09-25 15:21:00',
        'updated_at': spelled(db, logged),
      });
      expect(data['loggedAt'], '2026-09-25T15:21:00.000Z');
      expect(data['updatedAt'], '2026-09-25T15:21:00.000Z');
    });

    test('keeps a pulled Z date on the local clock', () async {
      await codec.upsert(db, {
        'uuid': 'x',
        'amountMinor': 100,
        'currency': 'DZD',
        'category': 'food',
        'note': null,
        'harvestDay': '2026-09-25',
        'loggedAt': '2026-09-25T15:21:00.000Z',
        'deletedAt': null,
        'updatedAt': '2026-09-25T15:21:00.000Z',
      });
      expect(
        await raw(db, 'SELECT logged_at FROM expenses'),
        spelled(db, logged),
      );
      final row = await db.select(db.expenses).getSingle();
      expect(row.loggedAt.isUtc, isFalse);
      expect(row.loggedAt.toUtc(), logged);
    });
  });
}
