/// The four lists every device has from the start ([[Lists]] L10).
///
/// Their ids are fixed — a uuid v5 of `lists/<key>` under
/// [listsNamespace], itself the v5 of `harvest:lists` under the URL
/// namespace — and written out here as `@harvest/contracts` writes them
/// (`packages/contracts/fixtures/built-in-lists.json` holds both sides
/// to the same numbers). Two devices that upgrade on their own make the
/// same four rows, never two *To read*s.
library;

const listsNamespace = '41156d84-936a-5a92-bd30-68dd604b6acb';

enum BuiltInList {
  buy('c4de613f-e027-5f99-bf47-f64aca9d6dfd', 'shopping', 'To buy'),
  wish('c89712ef-e04a-50a7-841f-0f698b7ec26c', 'shopping', 'Wishlist'),
  read('f09ec3ec-5479-525d-9c50-5dd509700907', 'media', 'To read'),
  watch('6711774e-0b76-5b66-81cd-09ce52a56399', 'media', 'To watch');

  const BuiltInList(this.uuid, this.kind, this.defaultName);

  /// The fixed id.
  final String uuid;

  /// `shopping` | `media`.
  final String kind;

  /// The stored name. The app shows a localised one while the stored
  /// name is still this.
  final String defaultName;

  /// Order among the lists when first made.
  int get position => index;

  static BuiltInList? ofKey(String? key) =>
      values.where((list) => list.name == key).firstOrNull;

  static BuiltInList? ofUuid(String? uuid) =>
      values.where((list) => list.uuid == uuid).firstOrNull;
}

/// The stamp a seeded built-in carries: older than anything I could
/// write, so a device that upgrades late never outranks a rename made
/// on the other one.
final builtInListsStampedAt = DateTime.utc(2020);

/// The list an item belongs to: [listUuid] when it has one, else the
/// shopping list its old `list` column names (a row from before lists).
String listUuidOfItem({required String list, String? listUuid}) =>
    listUuid ??
    (list == 'buy' ? BuiltInList.buy.uuid : BuiltInList.wish.uuid);

/// The old `list` column for an item in [listUuid]: `buy` only for
/// *To buy*, so a client from before lists shows every other item as a
/// wish, which it cannot mark bought.
String legacyListOf(String listUuid) =>
    listUuid == BuiltInList.buy.uuid ? 'buy' : 'wish';
