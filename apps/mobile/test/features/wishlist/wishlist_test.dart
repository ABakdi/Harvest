import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/finances/domain/currency.dart';
import 'package:harvest/features/wishlist/data/wishlist_repository.dart';
import 'package:harvest/features/wishlist/domain/wishlist.dart';

/// Phase 6, M6.10: the wishlist ([[Wishlist]] W1–W7).
void main() {
  late HarvestDatabase db;
  late WishlistRepository repo;

  setUp(() {
    db = HarvestDatabase.forTesting(NativeDatabase.memory());
    repo = WishlistRepository(db);
  });

  tearDown(() async => db.close());

  Future<List<WishlistItem>> inList(WishlistList list) async =>
      (await repo.watchAll().first)
          .where((item) => item.list == list && !item.isBought)
          .toList();

  group('two lists, one table (W1)', () {
    test('an item lands where it was added, in my order', () async {
      final coat = await repo.add(
        list: WishlistList.buy,
        title: 'Winter coat',
        priceMinor: 1800000,
        targetDay: HarvestDay.parse('2026-10-15'),
      );
      final kettle = await repo.add(list: WishlistList.buy, title: 'Kettle');
      final machine = await repo.add(
        list: WishlistList.wish,
        title: 'Espresso machine',
        note: 'one day',
      );

      expect(await inList(WishlistList.buy), hasLength(2));
      expect(await inList(WishlistList.wish), hasLength(1));
      expect((await inList(WishlistList.buy)).first.uuid, coat.uuid);
      expect((await inList(WishlistList.buy)).last.uuid, kettle.uuid);
      expect((await inList(WishlistList.wish)).first.uuid, machine.uuid);
    });
  });

  group('an estimate is a plan, not money (W2)', () {
    test('adding and buying touch no ledger, wallet or expense row', () async {
      final coat = await repo.add(
        list: WishlistList.buy,
        title: 'Winter coat',
        priceMinor: 1800000,
      );
      await repo.setBought(coat.uuid, bought: true);

      expect(await db.select(db.expenses).get(), isEmpty);
      expect(await db.select(db.moneyTxns).get(), isEmpty);
      expect(await db.select(db.ledger).get(), isEmpty);
      expect(await db.select(db.debts).get(), isEmpty);
    });
  });

  group('buying marks it bought (W3)', () {
    test('bought items fold under the open ones, and un-buying returns', () async {
      final coat = await repo.add(
        list: WishlistList.buy,
        title: 'Winter coat',
        priceMinor: 1800000,
      );
      final open = await repo.watchAll().first;
      expect(open.single.isBought, isFalse);

      await repo.setBought(coat.uuid, bought: true);
      final bought = (await repo.watchAll().first).single;
      expect(bought.isBought, isTrue);
      expect(bought.boughtAt, isNotNull);

      await repo.setBought(coat.uuid, bought: false);
      expect((await repo.watchAll().first).single.isBought, isFalse);
    });
  });

  group('moving is a mood, not a copy (W4)', () {
    test('an item keeps its price, note and day when it moves', () async {
      final coat = await repo.add(
        list: WishlistList.wish,
        title: 'Winter coat',
        priceMinor: 1800000,
        currency: Currency.eur,
        note: 'Wool, dark grey',
        targetDay: HarvestDay.parse('2026-10-15'),
      );
      await repo.move(coat.uuid, WishlistList.buy);

      final moved = (await repo.watchAll().first).single;
      expect(moved.list, WishlistList.buy);
      expect(moved.title, 'Winter coat');
      expect(moved.priceMinor, 1800000);
      expect(moved.currency, Currency.eur);
      expect(moved.note, 'Wool, dark grey');
      expect(moved.targetDay, HarvestDay.parse('2026-10-15'));
    });

    test('the wishlist has no buy button: an item moves, then is bought', () async {
      final machine = await repo.add(
        list: WishlistList.wish,
        title: 'Espresso machine',
      );
      await repo.setBought(machine.uuid, bought: true);
      expect((await repo.watchAll().first).single.isBought, isTrue);

      // Editing a bought wish item does not change what it is.
      await repo.edit(machine.uuid, title: 'Espresso machine (tall)');
      final edited = (await repo.watchAll().first).single;
      expect(edited.title, 'Espresso machine (tall)');
    });
  });

  group('order is mine', () {
    test('reorder within one list, drag-style', () async {
      final a = await repo.add(list: WishlistList.buy, title: 'A');
      final b = await repo.add(list: WishlistList.buy, title: 'B');
      final c = await repo.add(list: WishlistList.buy, title: 'C');

      await repo.reorder(WishlistList.buy, [c.uuid, a.uuid, b.uuid]);
      final order = (await repo.watchAll().first)
          .where((item) => item.list == WishlistList.buy)
          .map((item) => item.title)
          .toList();
      expect(order, ['C', 'A', 'B']);
      expect(await inList(WishlistList.buy), hasLength(3));
    });
  });

  group('order and sync stamps', () {
    test('a reorder bumps updatedAt and logs every row for sync', () async {
      final a = await repo.add(list: WishlistList.buy, title: 'A');
      final b = await repo.add(list: WishlistList.buy, title: 'B');
      // Age both rows so a fresh stamp is unmistakable.
      await db.update(db.wishlistItems).write(
        WishlistItemsCompanion(updatedAt: Value(DateTime(2000))),
      );
      await db.delete(db.outbox).go();

      await repo.reorder(WishlistList.buy, [b.uuid, a.uuid]);

      final rows = await db.select(db.wishlistItems).get();
      for (final row in rows) {
        expect(row.updatedAt.isAfter(DateTime(2001)), isTrue, reason: row.title);
      }
      final logged = await db.select(db.outbox).get();
      expect(
        logged.map((entry) => entry.rowUuid).toSet(),
        {a.uuid, b.uuid},
      );
      expect(logged.every((entry) => entry.targetTable == 'wishlist_items'), isTrue);
    });

    test('a moved item joins the bottom of the other list (W4)', () async {
      final coat = await repo.add(list: WishlistList.wish, title: 'Coat');
      final kettle = await repo.add(list: WishlistList.buy, title: 'Kettle');
      final bread = await repo.add(list: WishlistList.buy, title: 'Bread');
      expect(coat.position, 0);

      await repo.move(coat.uuid, WishlistList.buy);
      final buy = (await repo.watchAll().first)
          .where((item) => item.list == WishlistList.buy)
          .toList();
      expect(buy.map((item) => item.uuid), [kettle.uuid, bread.uuid, coat.uuid]);
      expect(buy.last.position, 2);
    });

    test('deleted rows hold no place in the next position', () async {
      final a = await repo.add(list: WishlistList.buy, title: 'A');
      final b = await repo.add(list: WishlistList.buy, title: 'B');
      await repo.delete(b.uuid);
      final c = await repo.add(list: WishlistList.buy, title: 'C');
      expect(a.position, 0);
      expect(c.position, 1);
    });
  });

  group('deletion is soft, and history is kept (W6)', () {
    test('deleted rows vanish from the lists and return on undo', () async {
      final coat = await repo.add(list: WishlistList.buy, title: 'Winter coat');
      await repo.delete(coat.uuid);
      expect(await repo.watchAll().first, isEmpty);

      await repo.restore(coat.uuid);
      expect((await repo.watchAll().first).single.title, 'Winter coat');
    });

    test('purge eventually hard-deletes', () async {
      final old = await repo.add(list: WishlistList.wish, title: 'Old idea');
      await repo.add(list: WishlistList.wish, title: 'New idea');
      await repo.delete(old.uuid);

      await repo.purgeDeleted(olderThan: const Duration(days: 30));
      expect(await db.select(db.wishlistItems).get(), hasLength(2));

      // Age the deleted row past the cutoff, then purge.
      await (db.update(db.wishlistItems)..where((i) => i.uuid.equals(old.uuid)))
          .write(WishlistItemsCompanion(deletedAt: Value(DateTime(2000))));
      await repo.purgeDeleted(olderThan: const Duration(days: 30));
      expect(await db.select(db.wishlistItems).get(), hasLength(1));
    });
  });
}
