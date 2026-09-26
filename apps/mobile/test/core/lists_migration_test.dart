import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/db/built_in_lists.dart';
import 'package:harvest/core/db/database.dart';
import 'package:uuid/uuid.dart';

import '../generated_migrations/schema.dart';
import '../generated_migrations/schema_v19.dart' as v19;
import '../generated_migrations/schema_v22.dart' as v22;

/// Schema v23 is Lists ([[Lists]], M6.12): the Wishlist's two lists
/// become two of four built-in ones under fixed ids, every item is told
/// which list it is in, and someone who kept a Wishlist finds the
/// feature switched on.
void main() {
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  Future<Map<String, ListRow>> listsOf(HarvestDatabase db) async => {
    for (final row in await db.select(db.lists).get()) row.uuid: row,
  };

  Future<String?> listsSwitch(HarvestDatabase db) async =>
      (await (db.select(db.kvSettings)
                ..where((s) => s.key.equals('features.lists')))
              .getSingleOrNull())
          ?.valueJson;

  test('the built-in ids are the ones the contract fixture names', () {
    final fixture =
        jsonDecode(
              File(
                '../../packages/contracts/fixtures/built-in-lists.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    expect(fixture['namespace'], listsNamespace);
    expect(
      const Uuid().v5(Namespace.url.value, 'harvest:lists'),
      listsNamespace,
    );
    final lists = (fixture['lists'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    expect(lists.map((l) => l['key']), BuiltInList.values.map((l) => l.name));
    for (final (i, list) in BuiltInList.values.indexed) {
      expect(lists[i]['uuid'], list.uuid);
      expect(lists[i]['kind'], list.kind);
      expect(lists[i]['name'], list.defaultName);
      expect(lists[i]['position'], list.position);
      expect(const Uuid().v5(listsNamespace, 'lists/${list.name}'), list.uuid);
    }
    expect(
      DateTime.parse(fixture['stampedAt'] as String),
      builtInListsStampedAt,
    );
  });

  test('a fresh install has the four built-in lists, and no switch', () async {
    final db = HarvestDatabase.forTesting(NativeDatabase.memory());
    final lists = await listsOf(db);
    expect(lists.keys.toSet(), {for (final l in BuiltInList.values) l.uuid});
    expect(lists[BuiltInList.read.uuid]!.kind, 'media');
    expect(lists[BuiltInList.buy.uuid]!.builtIn, 'buy');
    expect(lists[BuiltInList.watch.uuid]!.position, 3);
    expect(
      lists[BuiltInList.wish.uuid]!.updatedAt.isAtSameMomentAs(
        builtInListsStampedAt,
      ),
      isTrue,
    );
    expect(await listsSwitch(db), isNull);
    // Made on every device: nothing to queue.
    expect(await db.select(db.outbox).get(), isEmpty);

    // Seeding again changes nothing, and never undoes a rename.
    await (db.update(db.lists)
          ..where((l) => l.uuid.equals(BuiltInList.read.uuid)))
        .write(const ListsCompanion(name: Value('Reading pile')));
    await db.seedBuiltInLists();
    final again = await listsOf(db);
    expect(again, hasLength(4));
    expect(again[BuiltInList.read.uuid]!.name, 'Reading pile');
    await db.close();
  });

  test('v22 items land in To buy and Wishlist, and Lists turns on', () async {
    await verifier.testWithDataIntegrity(
      oldVersion: 22,
      newVersion: 24,
      createOld: v22.DatabaseAtV22.new,
      createNew: HarvestDatabase.forTesting,
      openTestedDatabase: HarvestDatabase.forTesting,
      createItems: (batch, old) {
        batch
          ..insert(
            old.wishlistItems,
            const RawValuesInsertable<dynamic>({
              'uuid': Variable('coat'),
              'list': Variable('buy'),
              'title': Variable('Winter coat'),
              'price_minor': Variable(1800000),
              'currency': Variable('DZD'),
              'position': Variable(0),
              'created_at': Variable('2026-09-20T11:10:00.000 +01:00'),
              'updated_at': Variable('2026-09-20T11:15:00.000 +01:00'),
            }),
          )
          ..insert(
            old.wishlistItems,
            const RawValuesInsertable<dynamic>({
              'uuid': Variable('machine'),
              'list': Variable('wish'),
              'title': Variable('Espresso machine'),
              'currency': Variable('EUR'),
              'position': Variable(0),
              'created_at': Variable('2026-09-20T11:10:00.000 +01:00'),
              'updated_at': Variable('2026-09-20T11:15:00.000 +01:00'),
            }),
          );
      },
      validateItems: (db) async {
        final items = {
          for (final row in await db.select(db.wishlistItems).get())
            row.uuid: row,
        };
        expect(items['coat']!.listUuid, BuiltInList.buy.uuid);
        expect(items['coat']!.list, 'buy');
        expect(items['coat']!.priceMinor, 1800000);
        expect(items['coat']!.mediaType, isNull);
        expect(items['coat']!.rating, isNull);
        expect(items['machine']!.listUuid, BuiltInList.wish.uuid);
        expect(items['machine']!.currency, 'EUR');
        // The upgrade itself is not an edit.
        expect(
          items['coat']!.updatedAt.isAtSameMomentAs(
            DateTime.parse('2026-09-20T10:15:00.000Z'),
          ),
          isTrue,
        );

        expect((await listsOf(db)).keys, hasLength(4));
        expect(await listsSwitch(db), '"true"');
        final queued = await db.select(db.outbox).get();
        expect(
          queued.map((e) => (e.targetTable, e.rowUuid)),
          [('kv_settings', 'features.lists')],
        );
      },
    );
  });

  test('without a Wishlist, the switch stays off', () async {
    await verifier.testWithDataIntegrity(
      oldVersion: 22,
      newVersion: 24,
      createOld: v22.DatabaseAtV22.new,
      createNew: HarvestDatabase.forTesting,
      openTestedDatabase: HarvestDatabase.forTesting,
      createItems: (batch, old) {
        // A deleted item is not a Wishlist anyone keeps.
        batch.insert(
          old.wishlistItems,
          const RawValuesInsertable<dynamic>({
            'uuid': Variable('gone'),
            'list': Variable('buy'),
            'title': Variable('Kettle'),
            'created_at': Variable('2026-09-20T11:10:00.000 +01:00'),
            'updated_at': Variable('2026-09-21T09:00:00.000 +01:00'),
            'deleted_at': Variable('2026-09-21T09:00:00.000 +01:00'),
          }),
        );
      },
      validateItems: (db) async {
        expect(await listsSwitch(db), isNull);
        expect((await listsOf(db)).keys, hasLength(4));
        final row = await db.select(db.wishlistItems).getSingle();
        expect(row.listUuid, BuiltInList.buy.uuid);
      },
    );
  });

  test('a v19 wishlist crosses the v22 rebuild with its new columns', () async {
    await verifier.testWithDataIntegrity(
      oldVersion: 19,
      newVersion: 24,
      createOld: v19.DatabaseAtV19.new,
      createNew: HarvestDatabase.forTesting,
      openTestedDatabase: HarvestDatabase.forTesting,
      createItems: (batch, old) {
        batch.insert(
          old.wishlistItems,
          const RawValuesInsertable<dynamic>({
            'uuid': Variable('coat'),
            'list': Variable('wish'),
            'title': Variable('Winter coat'),
            'note': Variable('Wool, dark grey'),
            'created_at': Variable('2026-09-20 10:10:00'),
            'updated_at': Variable('2026-09-20 10:15:00'),
          }),
        );
      },
      validateItems: (db) async {
        final row = await db.select(db.wishlistItems).getSingle();
        expect(row.listUuid, BuiltInList.wish.uuid);
        expect(row.note, 'Wool, dark grey');
        expect(
          row.updatedAt.isAtSameMomentAs(DateTime.utc(2026, 9, 20, 10, 15)),
          isTrue,
        );
        expect(await listsSwitch(db), '"true"');
      },
    );
  });
}
