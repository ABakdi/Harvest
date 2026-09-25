import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/finances/domain/currency.dart';
import 'package:meta/meta.dart';

/// Which list an item sits in ([[Wishlist]] W1): the buy list is day
/// to day — what comes out of the wallet soon — and the wishlist is
/// future planning. Same rows, two moods.
enum WishlistList {
  buy,
  wish;

  static WishlistList parse(String? value) => values.firstWhere(
    (list) => list.name == value,
    orElse: () => WishlistList.wish,
  );
}

/// One thing I want to buy, planned ([[Wishlist]]). An estimate is a
/// plan, not a ledger line (W2): the wallet, budget and ledger never
/// read it.
@immutable
class WishlistItem {
  const WishlistItem({
    required this.uuid,
    required this.list,
    required this.title,
    required this.createdAt,
    this.priceMinor,
    this.currency = Currency.dzd,
    this.note,
    this.targetDay,
    this.boughtAt,
    this.position = 0,
  });

  final String uuid;
  final WishlistList list;
  final String title;
  final int? priceMinor;
  final Currency currency;
  final String? note;
  final HarvestDay? targetDay;
  final DateTime? boughtAt;
  final int position;
  final DateTime createdAt;

  bool get isBought => boughtAt != null;

  /// Days from [today] to the planned purchase day; negative once it
  /// has passed. A plan, not a commitment (W5): nothing judges it.
  int? daysLeft(HarvestDay today) =>
      targetDay == null ? null : today.daysUntil(targetDay!);
}
