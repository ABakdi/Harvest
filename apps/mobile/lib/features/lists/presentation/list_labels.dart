import 'package:flutter/material.dart';
import 'package:harvest/features/finances/domain/currency.dart';
import 'package:harvest/features/finances/presentation/money.dart';
import 'package:harvest/features/lists/domain/lists.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// A list's name as the reader should see it: a built-in list that
/// still has the name it was made with speaks the app's language; one I
/// renamed, and every list I made, shows what I typed.
String listName(AppLocalizations l10n, ItemList list) {
  if (!list.hasDefaultName) return list.name;
  return switch (list.builtIn!) {
    BuiltInList.buy => l10n.wishlistBuyList,
    BuiltInList.wish => l10n.wishlistWishlist,
    BuiltInList.read => l10n.listsToRead,
    BuiltInList.watch => l10n.listsToWatch,
  };
}

IconData listIcon(ItemList list) => switch (list.builtIn) {
  BuiltInList.buy => Icons.shopping_cart_outlined,
  BuiltInList.wish => Icons.star_outline,
  BuiltInList.read => Icons.menu_book_outlined,
  BuiltInList.watch => Icons.live_tv_outlined,
  null => kindIcon(list.kind),
};

IconData kindIcon(ListKind kind) => switch (kind) {
  ListKind.plain => Icons.checklist,
  ListKind.shopping => Icons.shopping_bag_outlined,
  ListKind.media => Icons.auto_stories_outlined,
};

String kindLabel(AppLocalizations l10n, ListKind kind) => switch (kind) {
  ListKind.plain => l10n.listsKindPlain,
  ListKind.shopping => l10n.listsKindShopping,
  ListKind.media => l10n.listsKindMedia,
};

String mediaTypeLabel(AppLocalizations l10n, MediaType type) => switch (type) {
  MediaType.book => l10n.mediaBook,
  MediaType.article => l10n.mediaArticle,
  MediaType.show => l10n.mediaShow,
  MediaType.film => l10n.mediaFilm,
  MediaType.video => l10n.mediaVideo,
  MediaType.podcast => l10n.mediaPodcast,
  MediaType.other => l10n.mediaOther,
};

IconData mediaTypeIcon(MediaType? type) => switch (type) {
  MediaType.book => Icons.menu_book_outlined,
  MediaType.article => Icons.article_outlined,
  MediaType.show => Icons.live_tv_outlined,
  MediaType.film => Icons.movie_outlined,
  MediaType.video => Icons.smart_display_outlined,
  MediaType.podcast => Icons.podcasts,
  MediaType.other || null => Icons.bookmark_outline,
};

/// "DA24,000 · $65" — open estimates per currency, never added across
/// (L3); empty when nothing has an estimate.
String estimateTotals(AppLocalizations l10n, Iterable<ListItem> items) =>
    formatTotals(l10n, openEstimates(items));

/// The open estimates of [items], summed per currency (L3).
Map<Currency, int> openEstimates(Iterable<ListItem> items) {
  final sums = <Currency, int>{};
  for (final item in items) {
    final minor = item.priceMinor;
    if (minor == null || item.isDone) continue;
    sums.update(item.currency, (value) => value + minor, ifAbsent: () => minor);
  }
  return sums;
}

String formatTotals(AppLocalizations l10n, Map<Currency, int> sums) => sums
    .entries
    .map((entry) => formatMoney(entry.value, entry.key))
    .join(l10n.wishlistTotalsSeparator);
