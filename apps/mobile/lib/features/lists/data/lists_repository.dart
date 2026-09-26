import 'package:drift/drift.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/db/database_provider.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/finances/domain/currency.dart';
import 'package:harvest/features/lists/domain/lists.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

part 'lists_repository.g.dart';

/// Every list and every item ([[Lists]]): the `lists` table, and the
/// items in `wishlist_items`, which kept its name for the devices and
/// archives from before.
///
/// Nothing here pays or costs anything (L8), and nothing touches money
/// (L3, L4): marking a shopping item bought is a stamp. Every write
/// bumps `updatedAt` and goes to the change log, so the other devices
/// hear of it.
class ListsRepository {
  ListsRepository(this._db);

  final HarvestDatabase _db;
  static const _uuid = Uuid();

  // ---------------------------------------------------------------- reads

  /// Fires on any write to a list or an item.
  Stream<void> _changes() => _db
      .customSelect('SELECT 1', readsFrom: {_db.lists, _db.wishlistItems})
      .watch();

  /// The live lists, in my order.
  Stream<List<ItemList>> watchLists() =>
      _changes().asyncMap((_) => _liveLists());

  /// One list's live items, open and done, in my order.
  Stream<List<ListItem>> watchItems(String listUuid) =>
      _changes().asyncMap((_) async {
        final items = await _liveItems();
        return [
          for (final item in items)
            if (item.listUuid == listUuid) item,
        ];
      });

  /// Every live item of every live list, list by list in my order.
  Stream<List<ListItem>> watchAllItems() => _changes().asyncMap((_) async {
    final items = await _liveItems();
    return [
      for (final list in await _liveLists())
        for (final item in items)
          if (item.listUuid == list.uuid) item,
    ];
  });

  /// How many open items each live list has — the count on its chip.
  Stream<Map<String, int>> watchOpenCounts() => _changes().asyncMap((_) async {
    final counts = {for (final list in await _liveLists()) list.uuid: 0};
    for (final item in await _liveItems()) {
      if (item.isDone || !counts.containsKey(item.listUuid)) continue;
      counts[item.listUuid] = counts[item.listUuid]! + 1;
    }
    return counts;
  });

  Future<ItemList?> list(String uuid) async {
    final row = await (_db.select(
      _db.lists,
    )..where((l) => l.uuid.equals(uuid))).getSingleOrNull();
    return row == null ? null : _toList(row);
  }

  Future<ListItem?> item(String uuid) async {
    final row = await (_db.select(
      _db.wishlistItems,
    )..where((i) => i.uuid.equals(uuid))).getSingleOrNull();
    return row == null ? null : toItem(row);
  }

  // ---------------------------------------------------------------- lists

  /// The four built-in lists, made again if they are missing (L10).
  Future<void> ensureBuiltIns() => _db.seedBuiltInLists();

  /// A list of my own, at the end of the row (L1: a list is a row).
  Future<ItemList> createList({
    required String name,
    required ListKind kind,
    String? icon,
  }) {
    final uuid = _uuid.v4();
    return _db.transaction(() async {
      final position = await _nextListPosition();
      final now = DateTime.now();
      await _db
          .into(_db.lists)
          .insert(
            ListsCompanion.insert(
              uuid: uuid,
              name: name.trim(),
              kind: Value(kind.name),
              icon: Value(icon),
              position: Value(position),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      await _db.logChange('lists', uuid, 'insert');
      return ItemList(
        uuid: uuid,
        name: name.trim(),
        kind: kind,
        icon: icon,
        position: position,
        createdAt: now,
      );
    });
  }

  /// Built-in lists can be renamed too; the app then shows my name
  /// instead of the localised one.
  Future<void> renameList(String uuid, String name) =>
      _writeList(uuid, ListsCompanion(name: Value(name.trim())));

  Future<void> setListIcon(String uuid, String? icon) =>
      _writeList(uuid, ListsCompanion(icon: Value(icon)));

  /// The lists' order, as arranged. Every row is written, so the order
  /// carries a fresh stamp and wins the sync merge.
  Future<void> reorderLists(List<String> uuids) => _db.transaction(() async {
    for (final (i, uuid) in uuids.indexed) {
      await _writeList(uuid, ListsCompanion(position: Value(i)));
    }
  });

  /// Soft-deletes a list I made, and its live items with it, under one
  /// stamp so [restoreList] brings back exactly those (L6). A built-in
  /// list is not deleted (L10): false.
  Future<bool> deleteList(String uuid, {DateTime? at}) =>
      _db.transaction(() async {
        final found = await list(uuid);
        if (found == null || !found.isDeletable || found.deletedAt != null) {
          return false;
        }
        final stamp = at ?? DateTime.now();
        await _writeList(uuid, ListsCompanion(deletedAt: Value(stamp)));
        for (final item in await _items()) {
          if (item.listUuid != uuid || item.deletedAt != null) continue;
          await _writeItem(
            item.uuid,
            WishlistItemsCompanion(deletedAt: Value(stamp)),
          );
        }
        return true;
      });

  /// Undoes [deleteList]: the list, and the items that went with it.
  /// An item deleted on its own before stays in the trash.
  Future<void> restoreList(String uuid) => _db.transaction(() async {
    final found = await list(uuid);
    final stamp = found?.deletedAt;
    if (found == null || stamp == null) return;
    await _writeList(uuid, const ListsCompanion(deletedAt: Value(null)));
    for (final item in await _items()) {
      if (item.listUuid != uuid) continue;
      if (item.deletedAt?.isAtSameMomentAs(stamp) ?? false) {
        await _writeItem(
          item.uuid,
          const WishlistItemsCompanion(deletedAt: Value(null)),
        );
      }
    }
  });

  // ---------------------------------------------------------------- items

  /// Adds an item at the bottom of [listUuid]. Only the fields of the
  /// list's kind are kept (L2): an estimate on a shopping list, a link
  /// on a media list. Adding pays nothing (L8).
  Future<ListItem> addItem(
    String listUuid, {
    required String title,
    String? note,
    int? priceMinor,
    Currency currency = Currency.dzd,
    HarvestDay? targetDay,
    MediaType? mediaType,
    String? link,
    String? creator,
  }) => _db.transaction(() async {
    final target = await list(listUuid);
    if (target == null || target.deletedAt != null) {
      throw ArgumentError.value(listUuid, 'listUuid', 'No such list');
    }
    final uuid = _uuid.v4();
    final position = await _nextPosition(listUuid);
    final now = DateTime.now();
    final fields = _fieldsOf(
      target.kind,
      note: note,
      priceMinor: priceMinor,
      currency: currency,
      targetDay: targetDay,
      mediaType: mediaType,
      link: link,
      creator: creator,
    );
    await _db
        .into(_db.wishlistItems)
        .insert(
          fields.copyWith(
            uuid: Value(uuid),
            list: Value(legacyListOf(listUuid)),
            listUuid: Value(listUuid),
            title: Value(title.trim()),
            position: Value(position),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    await _db.logChange('wishlist_items', uuid, 'insert');
    return (await item(uuid))!;
  });

  /// Edits what I typed about an item; the fields of other kinds stay
  /// empty (L2).
  Future<void> editItem(
    String uuid, {
    required String title,
    String? note,
    int? priceMinor,
    Currency currency = Currency.dzd,
    HarvestDay? targetDay,
    MediaType? mediaType,
    String? link,
    String? creator,
  }) => _db.transaction(() async {
    final found = await item(uuid);
    if (found == null) return;
    final kind = (await list(found.listUuid))?.kind ?? ListKind.shopping;
    await _writeItem(
      uuid,
      _fieldsOf(
        kind,
        note: note,
        priceMinor: priceMinor,
        currency: currency,
        targetDay: targetDay,
        mediaType: mediaType,
        link: link,
        creator: creator,
      ).copyWith(title: Value(title.trim())),
    );
  });

  /// Moves an item to another list of the same kind, as the same row
  /// (L2): it keeps every field and its history, and joins the bottom.
  /// Another kind, a deleted list, or the list it is on: false.
  Future<bool> moveItem(String uuid, String toListUuid) =>
      _db.transaction(() async {
        final found = await item(uuid);
        if (found == null || found.listUuid == toListUuid) return false;
        final from = await list(found.listUuid);
        final to = await list(toListUuid);
        if (to == null || to.deletedAt != null) return false;
        if (from != null && from.kind != to.kind) return false;
        await _writeItem(
          uuid,
          WishlistItemsCompanion(
            list: Value(legacyListOf(toListUuid)),
            listUuid: Value(toListUuid),
            position: Value(await _nextPosition(toListUuid)),
          ),
        );
        return true;
      });

  /// One list's order, as dragged (or arrowed).
  Future<void> reorderItems(String listUuid, List<String> uuids) =>
      _db.transaction(() async {
        for (final (i, uuid) in uuids.indexed) {
          await _writeItem(
            uuid,
            WishlistItemsCompanion(
              list: Value(legacyListOf(listUuid)),
              listUuid: Value(listUuid),
              position: Value(i),
            ),
          );
        }
      });

  /// Bought, finished or ticked — a stamp, not a transaction (L4) — and
  /// undone if it was not. The Wishlist's items are not bought: a wish
  /// moves to *To buy* first (L7), so marking one is refused (false).
  Future<bool> setDone(String uuid, {required bool done, DateTime? at}) =>
      _db.transaction(() async {
        final found = await item(uuid);
        if (found == null) return false;
        if (done && found.listUuid == BuiltInList.wish.uuid) return false;
        await _writeItem(
          uuid,
          WishlistItemsCompanion(
            boughtAt: Value(done ? (at ?? DateTime.now()) : null),
          ),
        );
        return true;
      });

  /// A media item in progress, or back to wanted ([[Lists]]: want → in
  /// progress → finished). Other kinds have no start: false.
  Future<bool> setStarted(
    String uuid, {
    required bool started,
    DateTime? at,
  }) => _media(
    uuid,
    WishlistItemsCompanion(
      startedAt: Value(started ? (at ?? DateTime.now()) : null),
    ),
  );

  /// A media item's rating, 1–5, or none.
  Future<bool> setRating(String uuid, int? rating) {
    if (rating != null && (rating < 1 || rating > 5)) {
      throw RangeError.range(rating, 1, 5, 'rating');
    }
    return _media(uuid, WishlistItemsCompanion(rating: Value(rating)));
  }

  /// A media item's link. Saved as typed; nothing is fetched (L9).
  Future<bool> setLink(String uuid, String? link) =>
      _media(uuid, WishlistItemsCompanion(link: Value(_blankToNull(link))));

  Future<bool> setCreator(String uuid, String? creator) => _media(
    uuid,
    WishlistItemsCompanion(creator: Value(_blankToNull(creator))),
  );

  Future<bool> setMediaType(String uuid, MediaType? type) =>
      _media(uuid, WishlistItemsCompanion(mediaType: Value(type?.name)));

  /// The seed this item was planted as, or none. The seed carries the
  /// doing and pays as any seed does (L8); the link is all this keeps.
  Future<void> linkSeed(String uuid, String? seedUuid) =>
      _writeItem(uuid, WishlistItemsCompanion(seedUuid: Value(seedUuid)));

  /// The note written about this item, or none.
  Future<void> linkNote(String uuid, String? noteUuid) =>
      _writeItem(uuid, WishlistItemsCompanion(noteUuid: Value(noteUuid)));

  /// Soft delete (L6); [restoreItem] undoes it.
  Future<void> deleteItem(String uuid, {DateTime? at}) => _writeItem(
    uuid,
    WishlistItemsCompanion(deletedAt: Value(at ?? DateTime.now())),
  );

  Future<void> restoreItem(String uuid) =>
      _writeItem(uuid, const WishlistItemsCompanion(deletedAt: Value(null)));

  /// Hard-deletes items and lists soft-deleted longer than [olderThan]
  /// ago — "delete" must eventually mean gone. A built-in list is never
  /// purged.
  Future<void> purgeDeleted({required Duration olderThan}) async {
    final cutoff = DateTime.now().subtract(olderThan);
    await _db.transaction(() async {
      await (_db.delete(
        _db.wishlistItems,
      )..where((i) => i.deletedAt.isSmallerThanValue(cutoff))).go();
      await (_db.delete(_db.lists)..where(
            (l) => l.deletedAt.isSmallerThanValue(cutoff) & l.builtIn.isNull(),
          ))
          .go();
    });
  }

  // ------------------------------------------------------------- helpers

  Future<List<ItemList>> _liveLists() async {
    final rows =
        await (_db.select(_db.lists)
              ..where((l) => l.deletedAt.isNull())
              ..orderBy([
                (l) => OrderingTerm.asc(l.position),
                (l) => OrderingTerm.asc(l.createdAt),
              ]))
            .get();
    return [for (final row in rows) _toList(row)];
  }

  /// Every item, deleted ones too, in hand order.
  Future<List<ListItem>> _items() async {
    final rows =
        await (_db.select(_db.wishlistItems)..orderBy([
              (i) => OrderingTerm.asc(i.position),
              (i) => OrderingTerm.asc(i.createdAt),
            ]))
            .get();
    return [for (final row in rows) toItem(row)];
  }

  Future<List<ListItem>> _liveItems() async => [
    for (final item in await _items())
      if (item.deletedAt == null) item,
  ];

  /// Only the fields [kind] carries; the rest are written empty (L2).
  static WishlistItemsCompanion _fieldsOf(
    ListKind kind, {
    String? note,
    int? priceMinor,
    Currency currency = Currency.dzd,
    HarvestDay? targetDay,
    MediaType? mediaType,
    String? link,
    String? creator,
  }) {
    final shopping = kind == ListKind.shopping;
    final media = kind == ListKind.media;
    return WishlistItemsCompanion(
      note: Value(_blankToNull(note)),
      priceMinor: Value(shopping ? priceMinor : null),
      currency: Value(currency.code),
      targetDay: Value(shopping ? targetDay?.key : null),
      mediaType: Value(media ? mediaType?.name : null),
      link: Value(media ? _blankToNull(link) : null),
      creator: Value(media ? _blankToNull(creator) : null),
    );
  }

  static String? _blankToNull(String? text) {
    final trimmed = text?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  /// A write that only a media item takes.
  Future<bool> _media(String uuid, WishlistItemsCompanion changes) =>
      _db.transaction(() async {
        final found = await item(uuid);
        if (found == null) return false;
        if ((await list(found.listUuid))?.kind != ListKind.media) return false;
        await _writeItem(uuid, changes);
        return true;
      });

  Future<void> _writeList(String uuid, ListsCompanion changes) =>
      _db.transaction(() async {
        await (_db.update(_db.lists)..where((l) => l.uuid.equals(uuid))).write(
          changes.copyWith(updatedAt: Value(DateTime.now())),
        );
        await _db.logChange('lists', uuid, 'update');
      });

  Future<void> _writeItem(String uuid, WishlistItemsCompanion changes) =>
      _db.transaction(() async {
        await (_db.update(
          _db.wishlistItems,
        )..where((i) => i.uuid.equals(uuid))).write(
          changes.copyWith(updatedAt: Value(DateTime.now())),
        );
        await _db.logChange('wishlist_items', uuid, 'update');
      });

  /// One past the last live item of [listUuid] — deleted rows hold no
  /// place, the same count the web makes.
  Future<int> _nextPosition(String listUuid) async {
    var max = -1;
    for (final item in await _liveItems()) {
      if (item.listUuid == listUuid && item.position > max) max = item.position;
    }
    return max + 1;
  }

  Future<int> _nextListPosition() async {
    final max = _db.lists.position.max();
    final value =
        await (_db.selectOnly(_db.lists)
              ..addColumns([max])
              ..where(_db.lists.deletedAt.isNull()))
            .map((row) => row.read(max))
            .getSingleOrNull();
    return (value ?? -1) + 1;
  }

  static ItemList _toList(ListRow row) => ItemList(
    uuid: row.uuid,
    name: row.name,
    kind: ListKind.parse(row.kind),
    icon: row.icon,
    position: row.position,
    builtIn: BuiltInList.ofKey(row.builtIn),
    createdAt: row.createdAt,
    deletedAt: row.deletedAt,
  );

  /// An item as the app reads it: a row from before lists has no
  /// `listUuid`, and its old `list` names the list.
  static ListItem toItem(WishlistItemRow row) => ListItem(
    uuid: row.uuid,
    listUuid: listUuidOfItem(list: row.list, listUuid: row.listUuid),
    title: row.title,
    note: row.note,
    priceMinor: row.priceMinor,
    currency: Currency.fromCode(row.currency),
    targetDay: HarvestDay.tryParse(row.targetDay),
    mediaType: MediaType.tryParse(row.mediaType),
    link: row.link,
    creator: row.creator,
    startedAt: row.startedAt,
    rating: row.rating,
    seedUuid: row.seedUuid,
    noteUuid: row.noteUuid,
    doneAt: row.boughtAt,
    position: row.position,
    createdAt: row.createdAt,
    deletedAt: row.deletedAt,
  );
}

@Riverpod(keepAlive: true)
ListsRepository listsRepository(Ref ref) =>
    ListsRepository(ref.watch(databaseProvider));
