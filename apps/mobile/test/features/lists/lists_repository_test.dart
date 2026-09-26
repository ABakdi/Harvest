import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/finances/domain/currency.dart';
import 'package:harvest/features/lists/data/lists_repository.dart';
import 'package:harvest/features/lists/domain/lists.dart';

/// Phase 6, M6.12: the data under Lists ([[Lists]] L1–L10).
void main() {
  late HarvestDatabase db;
  late ListsRepository repo;

  setUp(() {
    db = HarvestDatabase.forTesting(NativeDatabase.memory());
    repo = ListsRepository(db);
  });

  tearDown(() async => db.close());

  final buy = BuiltInList.buy.uuid;
  final wish = BuiltInList.wish.uuid;
  final read = BuiltInList.read.uuid;
  final watch = BuiltInList.watch.uuid;

  Future<List<ListItem>> itemsOf(String list) => repo.watchItems(list).first;

  Future<List<String>> logged(String table) async => [
    for (final entry in await db.select(db.outbox).get())
      if (entry.targetTable == table) entry.rowUuid,
  ];

  group('lists are rows (L1)', () {
    test('the four built-ins come first, in order', () async {
      final lists = await repo.watchLists().first;
      expect(lists.map((l) => l.builtIn), BuiltInList.values);
      expect(lists.map((l) => l.kind), [
        ListKind.shopping,
        ListKind.shopping,
        ListKind.media,
        ListKind.media,
      ]);
      expect(lists.every((l) => l.hasDefaultName), isTrue);
    });

    test('a list I make joins the end, and is logged', () async {
      final packing = await repo.createList(
        name: ' Packing ',
        kind: ListKind.plain,
        icon: 'luggage',
      );
      expect(packing.name, 'Packing');
      expect(packing.position, 4);
      final lists = await repo.watchLists().first;
      expect(lists.last.uuid, packing.uuid);
      expect(lists.last.icon, 'luggage');
      expect(await logged('lists'), [packing.uuid]);
    });

    test('rename, icon and reorder bump the stamp', () async {
      await repo.renameList(read, 'Reading pile');
      await repo.setListIcon(read, 'book');
      await repo.reorderLists([read, buy, wish, watch]);
      final lists = await repo.watchLists().first;
      expect(lists.first.uuid, read);
      expect(lists.first.name, 'Reading pile');
      expect(lists.first.hasDefaultName, isFalse);
      expect(lists.first.icon, 'book');
      final row = await (db.select(
        db.lists,
      )..where((l) => l.uuid.equals(read))).getSingle();
      expect(row.updatedAt.isAfter(builtInListsStampedAt), isTrue);
      expect((await logged('lists')).toSet(), {read, buy, wish, watch});
    });

    test('open counts per list', () async {
      final a = await repo.addItem(buy, title: 'Kettle');
      await repo.addItem(buy, title: 'Bread');
      await repo.addItem(read, title: 'Dune');
      await repo.setDone(a.uuid, done: true);
      final counts = await repo.watchOpenCounts().first;
      expect(counts[buy], 1);
      expect(counts[read], 1);
      expect(counts[watch], 0);
    });
  });

  group("a list's kind decides its items' fields (L2)", () {
    test('a media item keeps its type, link and creator', () async {
      final dune = await repo.addItem(
        read,
        title: ' Dune ',
        mediaType: MediaType.book,
        link: 'https://example.com/dune',
        creator: 'Frank Herbert',
        priceMinor: 250000,
        targetDay: HarvestDay.parse('2026-10-01'),
      );
      expect(dune.title, 'Dune');
      expect(dune.listUuid, read);
      expect(dune.mediaType, MediaType.book);
      expect(dune.link, 'https://example.com/dune');
      expect(dune.creator, 'Frank Herbert');
      // Not a shopping item: no estimate, no planned day.
      expect(dune.priceMinor, isNull);
      expect(dune.targetDay, isNull);
      final row = await db.select(db.wishlistItems).getSingle();
      expect(row.list, 'wish');
    });

    test('a shopping item keeps its estimate, not a link', () async {
      final coat = await repo.addItem(
        buy,
        title: 'Coat',
        priceMinor: 1800000,
        currency: Currency.eur,
        targetDay: HarvestDay.parse('2026-10-15'),
        link: 'https://example.com/coat',
      );
      expect(coat.priceMinor, 1800000);
      expect(coat.currency, Currency.eur);
      expect(coat.link, isNull);
      final row = await db.select(db.wishlistItems).getSingle();
      expect(row.list, 'buy');
      expect(row.listUuid, buy);
    });

    test('edit replaces what I typed, within the kind', () async {
      final item = await repo.addItem(watch, title: 'Talk');
      await repo.editItem(
        item.uuid,
        title: 'A good talk',
        note: 'from Sam',
        mediaType: MediaType.video,
        link: 'https://example.com/v',
        creator: 'Someone',
      );
      final edited = (await itemsOf(watch)).single;
      expect(edited.title, 'A good talk');
      expect(edited.note, 'from Sam');
      expect(edited.mediaType, MediaType.video);
    });

    test('an item moves between lists of the same kind only', () async {
      final dune = await repo.addItem(read, title: 'Dune', creator: 'FH');
      await repo.addItem(watch, title: 'Arrival');
      expect(await repo.moveItem(dune.uuid, buy), isFalse);
      expect(await repo.moveItem(dune.uuid, read), isFalse);
      expect(await repo.moveItem(dune.uuid, watch), isTrue);
      final moved = (await itemsOf(watch)).last;
      expect(moved.uuid, dune.uuid);
      expect(moved.creator, 'FH');
      expect(moved.position, 1);
      expect(await itemsOf(read), isEmpty);
    });

    test('moving to To buy writes the old column too', () async {
      final coat = await repo.addItem(wish, title: 'Coat');
      await repo.moveItem(coat.uuid, buy);
      final row = await db.select(db.wishlistItems).getSingle();
      expect((row.list, row.listUuid), ('buy', buy));
    });

    test('a row from before lists reads from its old column', () async {
      await db
          .into(db.wishlistItems)
          .insert(
            WishlistItemsCompanion.insert(
              uuid: 'old',
              list: const Value('wish'),
              title: 'Espresso machine',
            ),
          );
      expect((await itemsOf(wish)).single.uuid, 'old');
      final next = await repo.addItem(wish, title: 'Lamp');
      expect(next.position, 1);
    });
  });

  group('done, started, rated', () {
    test('done is a stamp and pays nothing (L4, L8)', () async {
      final coat = await repo.addItem(buy, title: 'Coat', priceMinor: 100);
      expect(await repo.setDone(coat.uuid, done: true), isTrue);
      expect((await itemsOf(buy)).single.isDone, isTrue);
      expect(await db.select(db.expenses).get(), isEmpty);
      expect(await db.select(db.moneyTxns).get(), isEmpty);
      expect(await db.select(db.ledger).get(), isEmpty);
      await repo.setDone(coat.uuid, done: false);
      expect((await itemsOf(buy)).single.isDone, isFalse);
    });

    test('a wish is not bought: it moves to To buy first (L7)', () async {
      final machine = await repo.addItem(wish, title: 'Espresso machine');
      expect(await repo.setDone(machine.uuid, done: true), isFalse);
      expect((await itemsOf(wish)).single.isDone, isFalse);
      await repo.moveItem(machine.uuid, buy);
      expect(await repo.setDone(machine.uuid, done: true), isTrue);
    });

    test('plain items are ticked', () async {
      final packing = await repo.createList(
        name: 'Packing',
        kind: ListKind.plain,
      );
      final socks = await repo.addItem(packing.uuid, title: 'Socks');
      expect(await repo.setDone(socks.uuid, done: true), isTrue);
    });

    test('media: want, in progress, finished with a rating', () async {
      final dune = await repo.addItem(read, title: 'Dune');
      expect(await repo.setStarted(dune.uuid, started: true), isTrue);
      expect((await itemsOf(read)).single.inProgress, isTrue);
      await repo.setDone(dune.uuid, done: true);
      expect(await repo.setRating(dune.uuid, 5), isTrue);
      final done = (await itemsOf(read)).single;
      expect(done.inProgress, isFalse);
      expect(done.rating, 5);
      expect(() => repo.setRating(dune.uuid, 6), throwsRangeError);
      expect(await repo.setLink(dune.uuid, '  '), isTrue);
      expect(await repo.setCreator(dune.uuid, 'Frank Herbert'), isTrue);
      expect(await repo.setMediaType(dune.uuid, MediaType.book), isTrue);
      final item = (await itemsOf(read)).single;
      expect(item.link, isNull);
      expect(item.creator, 'Frank Herbert');
      expect(item.mediaType, MediaType.book);
    });

    test('only media items start, rate or carry a link', () async {
      final coat = await repo.addItem(buy, title: 'Coat');
      expect(await repo.setStarted(coat.uuid, started: true), isFalse);
      expect(await repo.setRating(coat.uuid, 3), isFalse);
      expect(await repo.setLink(coat.uuid, 'https://x'), isFalse);
      expect((await itemsOf(buy)).single.startedAt, isNull);
    });

    test('seed and note links', () async {
      final dune = await repo.addItem(read, title: 'Dune');
      await repo.linkSeed(dune.uuid, 'seed-1');
      await repo.linkNote(dune.uuid, 'note-1');
      final item = (await itemsOf(read)).single;
      expect((item.seedUuid, item.noteUuid), ('seed-1', 'note-1'));
      await repo.linkSeed(dune.uuid, null);
      expect((await itemsOf(read)).single.seedUuid, isNull);
    });
  });

  group('order, stamps and the change log', () {
    test('reorder bumps every row and logs it', () async {
      final a = await repo.addItem(read, title: 'A');
      final b = await repo.addItem(read, title: 'B');
      await db.update(db.wishlistItems).write(
        WishlistItemsCompanion(updatedAt: Value(DateTime(2000))),
      );
      await db.delete(db.outbox).go();
      await repo.reorderItems(read, [b.uuid, a.uuid]);
      expect((await itemsOf(read)).map((i) => i.title), ['B', 'A']);
      for (final row in await db.select(db.wishlistItems).get()) {
        expect(row.updatedAt.isAfter(DateTime(2001)), isTrue);
      }
      expect((await logged('wishlist_items')).toSet(), {a.uuid, b.uuid});
    });

    test('deleted items hold no place', () async {
      await repo.addItem(read, title: 'A');
      final b = await repo.addItem(read, title: 'B');
      await repo.deleteItem(b.uuid);
      final c = await repo.addItem(read, title: 'C');
      expect(c.position, 1);
      await repo.restoreItem(b.uuid);
      expect(await itemsOf(read), hasLength(3));
    });
  });

  group('deletion (L6, L10)', () {
    test('a built-in list is not deleted', () async {
      expect(await repo.deleteList(read), isFalse);
      expect(await repo.watchLists().first, hasLength(4));
    });

    test('a list takes its items to the trash and brings them back', () async {
      final packing = await repo.createList(
        name: 'Packing',
        kind: ListKind.plain,
      );
      final socks = await repo.addItem(packing.uuid, title: 'Socks');
      final hat = await repo.addItem(packing.uuid, title: 'Hat');
      // Deleted on its own before: stays deleted.
      await repo.deleteItem(hat.uuid, at: DateTime(2026, 9, 20));

      expect(await repo.deleteList(packing.uuid), isTrue);
      expect((await repo.watchLists().first).map((l) => l.uuid), isNot(contains(packing.uuid)));
      expect(await repo.watchAllItems().first, isEmpty);
      expect(
        () => repo.addItem(packing.uuid, title: 'Scarf'),
        throwsArgumentError,
      );

      await repo.restoreList(packing.uuid);
      expect((await itemsOf(packing.uuid)).map((i) => i.uuid), [socks.uuid]);
    });

    test('purge hard-deletes old trash, never a built-in', () async {
      final packing = await repo.createList(
        name: 'Packing',
        kind: ListKind.plain,
      );
      await repo.addItem(packing.uuid, title: 'Socks');
      await repo.deleteList(packing.uuid, at: DateTime(2000));
      await (db.update(db.lists)..where((l) => l.uuid.equals(read))).write(
        ListsCompanion(deletedAt: Value(DateTime(2000))),
      );
      await repo.purgeDeleted(olderThan: const Duration(days: 30));
      expect(await db.select(db.wishlistItems).get(), isEmpty);
      final left = await db.select(db.lists).get();
      expect(left.map((l) => l.uuid).toSet(), {buy, wish, read, watch});
    });

    test('ensureBuiltIns brings back a missing one', () async {
      await (db.delete(db.lists)..where((l) => l.uuid.equals(watch))).go();
      await repo.ensureBuiltIns();
      expect(await repo.watchLists().first, hasLength(4));
    });
  });
}
