import 'package:harvest/core/db/built_in_lists.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/finances/domain/currency.dart';
import 'package:meta/meta.dart';

export 'package:harvest/core/db/built_in_lists.dart';

/// Which fields a list's items carry, and what done means ([[Lists]]
/// L2): a plain item is ticked, a shopping item bought, a media item
/// finished.
enum ListKind {
  plain,
  shopping,
  media;

  static ListKind parse(String? value) => values.firstWhere(
    (kind) => kind.name == value,
    orElse: () => ListKind.plain,
  );
}

/// What a media item is.
enum MediaType {
  book,
  article,
  show,
  film,
  video,
  podcast,
  other;

  static MediaType? tryParse(String? value) =>
      values.where((type) => type.name == value).firstOrNull;
}

/// One list ([[Lists]]).
@immutable
class ItemList {
  const ItemList({
    required this.uuid,
    required this.name,
    required this.kind,
    required this.createdAt,
    this.icon,
    this.position = 0,
    this.builtIn,
    this.deletedAt,
  });

  final String uuid;

  /// As stored. For a built-in list see [hasDefaultName].
  final String name;
  final ListKind kind;
  final String? icon;
  final int position;

  /// Which of the four this is; null for a list I made.
  final BuiltInList? builtIn;
  final DateTime createdAt;
  final DateTime? deletedAt;

  /// Built-in lists can be renamed, never deleted (L10).
  bool get isDeletable => builtIn == null;

  /// Whether a built-in list still has the name it was made with, so
  /// the app shows its name in the reader's language instead.
  bool get hasDefaultName => builtIn != null && name == builtIn!.defaultName;

  /// Only a shopping list's items are bought, and not the Wishlist's: a
  /// wish moves to *To buy* first (L7). Plain and media items are
  /// ticked and finished anywhere.
  bool get canBeDone => builtIn != BuiltInList.wish;
}

/// One item of one list ([[Lists]]). Which fields mean something
/// depends on the list's kind (L2); the others stay null.
@immutable
class ListItem {
  const ListItem({
    required this.uuid,
    required this.listUuid,
    required this.title,
    required this.createdAt,
    this.note,
    this.priceMinor,
    this.currency = Currency.dzd,
    this.targetDay,
    this.mediaType,
    this.link,
    this.creator,
    this.startedAt,
    this.rating,
    this.seedUuid,
    this.noteUuid,
    this.doneAt,
    this.position = 0,
    this.deletedAt,
  });

  final String uuid;
  final String listUuid;
  final String title;
  final String? note;

  /// Shopping: an estimate, a plan and never a ledger line (L3).
  final int? priceMinor;
  final Currency currency;

  /// Shopping: the planned day, a plan (L5).
  final HarvestDay? targetDay;

  /// Media.
  final MediaType? mediaType;
  final String? link;
  final String? creator;
  final DateTime? startedAt;
  final int? rating;

  /// The seed it was planted as, and the note written about it.
  final String? seedUuid;
  final String? noteUuid;

  /// Bought, finished or ticked (`boughtAt` in the table).
  final DateTime? doneAt;
  final int position;
  final DateTime createdAt;
  final DateTime? deletedAt;

  bool get isDone => doneAt != null;

  /// A media item between starting and finishing.
  bool get inProgress => startedAt != null && doneAt == null;

  /// Days from [today] to the planned day; negative once it has passed.
  int? daysLeft(HarvestDay today) =>
      targetDay == null ? null : today.daysUntil(targetDay!);
}
