import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/db/database_provider.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/finances/domain/currency.dart';
import 'package:harvest/features/wishlist/domain/wishlist.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

part 'wishlist_repository.g.dart';

/// The two lists of the Granary's Wishlist tab ([[Wishlist]]).
///
/// Nothing here touches money: an estimated price is a plan (W2), so no
/// wallet movement, no ledger row and no XP are ever written. Only the
/// list, the order and the bought stamp change.
class WishlistRepository {
  WishlistRepository(this._db);

  final HarvestDatabase _db;
  static const _uuid = Uuid();

  // ---------------------------------------------------------------- reads

  /// Fires on any write to the list.
  Stream<void> _changes() => _db
      .customSelect('SELECT 1', readsFrom: {_db.wishlistItems})
      .watch();

  /// Every live item, list by list, in hand order. Deleted ones are
  /// gone.
  Stream<List<WishlistItem>> watchAll() => _changes().asyncMap((_) async {
    final rows =
        await (_db.select(_db.wishlistItems)
              ..where((i) => i.deletedAt.isNull())
              ..orderBy([
                (i) => OrderingTerm.asc(i.list),
                (i) => OrderingTerm.asc(i.position),
                (i) => OrderingTerm.asc(i.createdAt),
              ]))
            .get();
    return [for (final row in rows) _toItem(row)];
  });

  // --------------------------------------------------------------- writes

  Future<WishlistItem> add({
    required WishlistList list,
    required String title,
    int? priceMinor,
    Currency currency = Currency.dzd,
    String? note,
    HarvestDay? targetDay,
  }) {
    final uuid = _uuid.v4();
    return _db.transaction(() async {
      final position = await _nextPosition(list);
      await _db.into(_db.wishlistItems).insert(
        WishlistItemsCompanion.insert(
          uuid: uuid,
          list: Value(list.name),
          title: title,
          priceMinor: Value(priceMinor),
          currency: Value(currency.code),
          note: Value(note),
          targetDay: Value(targetDay?.key),
          position: Value(position),
        ),
      );
      await _db.logChange('wishlist_items', uuid, 'insert');
      return WishlistItem(
        uuid: uuid,
        list: list,
        title: title,
        priceMinor: priceMinor,
        currency: currency,
        note: note,
        targetDay: targetDay,
        position: position,
        createdAt: DateTime.now(),
      );
    });
  }

  Future<void> edit(
    String uuid, {
    required String title,
    int? priceMinor,
    Currency currency = Currency.dzd,
    String? note,
    HarvestDay? targetDay,
  }) => _write(
    uuid,
    WishlistItemsCompanion(
      title: Value(title),
      priceMinor: Value(priceMinor),
      currency: Value(currency.code),
      note: Value(note),
      targetDay: Value(targetDay?.key),
    ),
  );

  /// A mood, not a copy (W4): the row keeps its price, note, target day
  /// and history — it just answers to the other list now, joining it at
  /// the bottom so it never collides with an order already there.
  Future<void> move(String uuid, WishlistList to) => _db.transaction(() async {
    final row = await (_db.select(
      _db.wishlistItems,
    )..where((i) => i.uuid.equals(uuid))).getSingleOrNull();
    if (row == null || row.list == to.name) return;
    await _write(
      uuid,
      WishlistItemsCompanion(
        list: Value(to.name),
        position: Value(await _nextPosition(to)),
      ),
    );
  });

  /// One list's order, as dragged (or arrowed). Every row goes through
  /// [_write], so the new order carries a fresh `updatedAt` and wins the
  /// sync merge.
  Future<void> reorder(WishlistList list, List<String> uuids) =>
      _db.transaction(() async {
        for (final (i, uuid) in uuids.indexed) {
          await _write(
            uuid,
            WishlistItemsCompanion(
              list: Value(list.name),
              position: Value(i),
            ),
          );
        }
      });

  /// Marks it bought; un-buying with a null `boughtAt` brings it back if
  /// the purchase fell through (W3). The stamp is not a transaction.
  Future<void> setBought(String uuid, {required bool bought, DateTime? at}) =>
      _write(
        uuid,
        WishlistItemsCompanion(
          boughtAt: Value(bought ? (at ?? DateTime.now()) : null),
        ),
      );

  /// Soft delete, like the rest of the table (W6).
  Future<void> delete(String uuid, {DateTime? at}) =>
      _write(uuid, WishlistItemsCompanion(deletedAt: Value(at ?? DateTime.now())));
  Future<void> restore(String uuid) =>
      _write(uuid, const WishlistItemsCompanion(deletedAt: Value(null)));

  /// Hard-deletes items soft-deleted longer than [olderThan] ago —
  /// "delete" must eventually mean gone.
  Future<void> purgeDeleted({required Duration olderThan}) async {
    final cutoff = DateTime.now().subtract(olderThan);
    await (_db.delete(
      _db.wishlistItems,
    )..where((i) => i.deletedAt.isSmallerThanValue(cutoff))).go();
  }

  // ------------------------------------------------------------- helpers

  Future<void> _write(String uuid, WishlistItemsCompanion changes) =>
      _db.transaction(() async {
        await (_db.update(
          _db.wishlistItems,
        )..where((i) => i.uuid.equals(uuid))).write(
          changes.copyWith(updatedAt: Value(DateTime.now())),
        );
        await _db.logChange('wishlist_items', uuid, 'update');
      });

  /// One past the last live item of [list] — deleted rows don't hold a
  /// place, the same count the web makes.
  Future<int> _nextPosition(WishlistList list) async {
    final max = _db.wishlistItems.position.max();
    final value = await (_db.selectOnly(
      _db.wishlistItems,
    )
      ..addColumns([max])
      ..where(
        _db.wishlistItems.list.equals(list.name) &
            _db.wishlistItems.deletedAt.isNull(),
      ))
        .map((row) => row.read(max))
        .getSingleOrNull();
    return (value ?? -1) + 1;
  }

  static WishlistItem _toItem(WishlistItemRow row) {
    final list = WishlistList.values
        .where((list) => list.name == row.list)
        .firstOrNull;
    if (list == null) {
      debugPrint('[wishlist] unknown list for ${row.uuid}: ${row.list}');
    }
    return WishlistItem(
      uuid: row.uuid,
      list: list ?? WishlistList.wish,
      title: row.title,
      priceMinor: row.priceMinor,
      currency: Currency.fromCode(row.currency),
      note: row.note,
      targetDay: HarvestDay.tryParse(row.targetDay),
      boughtAt: row.boughtAt,
      position: row.position,
      createdAt: row.createdAt,
    );
  }
}

@Riverpod(keepAlive: true)
WishlistRepository wishlistRepository(Ref ref) =>
    WishlistRepository(ref.watch(databaseProvider));
