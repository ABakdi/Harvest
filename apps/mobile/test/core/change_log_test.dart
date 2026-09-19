import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/features/settings/data/settings_repository.dart';

/// The change log is what sync drains, and since phase 5 it is also
/// where an action gets its place ([[Places]] PL2).
void main() {
  late HarvestDatabase db;

  setUp(() => db = HarvestDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() async => db.close());

  Future<List<GeotagRow>> tags() => db.select(db.geotags).get();

  group('geotags', () {
    test('an insert into an action table leaves one pending geotag', () async {
      db.geotagging = true;
      await db.logChange('expenses', 'e1', 'insert');
      final all = await tags();
      expect(all, hasLength(1));
      expect(all.single.targetTable, 'expenses');
      expect(all.single.targetUuid, 'e1');
      expect(all.single.state, 'pending');
      expect(all.single.uuid, geotagUuid('expenses', 'e1'));

      final logged = await db.select(db.outbox).get();
      expect(logged.map((row) => row.targetTable), ['expenses', 'geotags']);
    });

    test(
      'updates, bookkeeping tables and a second insert tag nothing',
      () async {
        db.geotagging = true;
        await db.logChange('expenses', 'e1', 'insert');
        await db.logChange('expenses', 'e1', 'insert');
        await db.logChange('expenses', 'e1', 'update');
        await db.logChange('streaks', 'global', 'insert');
        await db.logChange('step_days', '2026-09-19', 'insert');
        expect(await tags(), hasLength(1));
      },
    );

    test('nothing is tagged while Places is off', () async {
      await db.logChange('memories', 'm1', 'insert');
      expect(await tags(), isEmpty);
    });
  });

  test('the cap keeps the newest rows', () async {
    for (var i = 0; i < 12; i++) {
      await db.logChange('notes', 'n$i', 'update');
    }
    expect(await db.capOutbox(keep: 5), 7);
    final left = await db.select(db.outbox).get();
    expect(left.map((row) => row.rowUuid), ['n7', 'n8', 'n9', 'n10', 'n11']);
    expect(await db.capOutbox(keep: 5), 0);
  });

  group('the outbox hears every write', () {
    test('a preference is logged, bookkeeping is not', () async {
      final settings = SettingsRepository(db);
      await settings.setString('themeMode', 'dark');
      await settings.setString('streak.lastJudgedDay', '2026-09-18');
      await settings.remove('themeMode');
      final logged = await db.select(db.outbox).get();
      expect(logged.map((row) => (row.rowUuid, row.op)), [
        ('themeMode', 'update'),
        ('themeMode', 'delete'),
      ]);
    });
  });
}
