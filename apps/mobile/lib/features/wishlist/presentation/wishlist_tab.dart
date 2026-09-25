import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/core/platform/haptics.dart';
import 'package:harvest/core/ui/format.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/core/ui/widgets/big_bouncy_button.dart';
import 'package:harvest/core/ui/widgets/empty_state.dart';
import 'package:harvest/core/ui/widgets/section_header.dart';
import 'package:harvest/features/finances/domain/currency.dart';
import 'package:harvest/features/finances/presentation/money.dart';
import 'package:harvest/features/wishlist/data/wishlist_repository.dart';
import 'package:harvest/features/wishlist/domain/wishlist.dart';
import 'package:harvest/features/wishlist/presentation/wishlist_editor_sheet.dart';
import 'package:harvest/features/wishlist/presentation/wishlist_providers.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// The Wishlist tab of the Granary ([[Wishlist]]): the buy list and the
/// wishlist, one segment each, with the open items' estimated total per
/// currency on the header and bought things folded below.
class WishlistTab extends ConsumerStatefulWidget {
  const WishlistTab({super.key});

  @override
  ConsumerState<WishlistTab> createState() => _WishlistTabState();
}

class _WishlistTabState extends ConsumerState<WishlistTab> {
  WishlistList _list = WishlistList.buy;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final all = ref.watch(wishlistItemsProvider).value ?? const [];
    final current = [
      for (final item in all)
        if (item.list == _list) item,
    ];
    // Only the buy list folds bought things away (W7). A wish item that
    // arrives bought (an old import, another device) stays in view with
    // the rest of the wishlist, where it can still be moved or deleted.
    final folds = _list == WishlistList.buy;
    final open = [
      for (final item in current)
        if (!folds || !item.isBought) item,
    ];
    final bought = [
      for (final item in current)
        if (folds && item.isBought) item,
    ];

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              HarvestSpacing.md,
              HarvestSpacing.sm,
              HarvestSpacing.md,
              0,
            ),
            child: SegmentedButton<WishlistList>(
              segments: [
                ButtonSegment(
                  value: WishlistList.buy,
                  icon: const Icon(Icons.shopping_cart_outlined, size: 18),
                  label: Text(l10n.wishlistBuyList),
                ),
                ButtonSegment(
                  value: WishlistList.wish,
                  icon: const Icon(Icons.star_outline, size: 18),
                  label: Text(l10n.wishlistWishlist),
                ),
              ],
              selected: {_list},
              onSelectionChanged: (selection) =>
                  setState(() => _list = selection.first),
            ),
          ),
          Expanded(
            child: open.isEmpty && bought.isEmpty
                ? _Empty(
                    title: _list == WishlistList.wish
                        ? l10n.wishlistWishEmptyTitle
                        : l10n.wishlistBuyEmptyTitle,
                    body: _list == WishlistList.wish
                        ? l10n.wishlistWishEmptyBody
                        : l10n.wishlistBuyEmptyBody,
                    onAdd: _add,
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(
                      HarvestSpacing.md,
                      HarvestSpacing.sm,
                      HarvestSpacing.md,
                      120,
                    ),
                    children: [
                      SectionHeader(
                        l10n.wishlistOpen,
                        subtitle: _totals(open),
                        trailing: TextButton.icon(
                          onPressed: _add,
                          icon: const Icon(Icons.add, size: 18),
                          label: Text(l10n.wishlistAdd),
                        ),
                      ),
                      _OpenItems(
                        items: open,
                        list: _list,
                        onMove: (item) => unawaited(_move(item)),
                      ),
                      if (bought.isNotEmpty) ...[
                        const SizedBox(height: HarvestSpacing.md),
                        SectionHeader(l10n.wishlistBought(bought.length)),
                        Card(
                          clipBehavior: Clip.antiAlias,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: HarvestSpacing.sm,
                              vertical: HarvestSpacing.xs,
                            ),
                            child: Column(
                              children: [
                                for (final item in bought)
                                  _BoughtRow(
                                    item: item,
                                    onRestore: () => unawaited(_buy(item, false)),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  /// "≈ DA24,000 + $65" — per currency, never added across (W2).
  String _totals(List<WishlistItem> items) {
    final sums = <Currency, int>{};
    for (final item in items) {
      final minor = item.priceMinor;
      if (minor == null) continue;
      sums.update(
        item.currency,
        (value) => value + minor,
        ifAbsent: () => minor,
      );
    }
    if (sums.isEmpty) return '';
    return sums.entries
        .map((entry) => formatAmount(entry.value, entry.key))
        .join(AppLocalizations.of(context).wishlistTotalsSeparator);
  }

  void _add() {
    unawaited(
      showWishlistEditor(context, initialList: _list).then((draft) {
        if (draft == null) return;
        setState(() => _list = draft.list);
      }),
    );
  }

  Future<void> _move(WishlistItem item) async {
    final repository = ref.read(wishlistRepositoryProvider);
    await repository.move(item.uuid, _other(item.list));
    setState(() {});
  }

  Future<void> _buy(WishlistItem item, bool bought) async {
    unawaited(HarvestHaptics.tick());
    await ref.read(wishlistRepositoryProvider).setBought(item.uuid, bought: bought);
    setState(() {});
  }

  WishlistList _other(WishlistList list) => switch (list) {
    WishlistList.buy => WishlistList.wish,
    WishlistList.wish => WishlistList.buy,
  };
}

class _Empty extends StatelessWidget {
  const _Empty({required this.title, required this.body, required this.onAdd});

  final String title;
  final String body;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(HarvestSpacing.xl),
        child: EmptyState(
          icon: Icons.shopping_bag_outlined,
          title: title,
          body: body,
          action: BigBouncyButton(
            icon: Icons.add,
            onPressed: onAdd,
            child: Text(l10n.wishlistAdd),
          ),
        ),
      ),
    );
  }
}

class _OpenItems extends ConsumerWidget {
  const _OpenItems({
    required this.items,
    required this.list,
    required this.onMove,
  });

  final List<WishlistItem> items;
  final WishlistList list;
  final ValueChanged<WishlistItem> onMove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.read(wishlistRepositoryProvider);

    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: items.length,
      onReorderItem: (from, to) {
        final uuids = [for (final item in items) item.uuid];
        final moved = uuids.removeAt(from);
        uuids.insert(to, moved);
        unawaited(repository.reorder(list, uuids));
      },
      itemBuilder: (context, i) {
        final item = items[i];
        return _Row(
          key: ValueKey(item.uuid),
          item: item,
          index: i,
          list: list,
          onEdit: () => unawaited(showWishlistEditor(context, existing: item)),
          onMove: onMove,
          onBuy: () => unawaited(_buyRow(context, item, repository)),
          onDelete: () => unawaited(_deleteRow(context, item, repository)),
        );
      },
    );
  }
}

Future<void> _buyRow(
  BuildContext context,
  WishlistItem item,
  WishlistRepository repository,
) async {
  unawaited(HarvestHaptics.tick());
  await repository.setBought(item.uuid, bought: true);
}

Future<void> _deleteRow(
  BuildContext context,
  WishlistItem item,
  WishlistRepository repository,
) async {
  await repository.delete(item.uuid);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(AppLocalizations.of(context).wishlistRemoved),
      action: SnackBarAction(
        label: AppLocalizations.of(context).undoAction,
        onPressed: () => unawaited(repository.restore(item.uuid)),
      ),
    ),
  );
}

class _Row extends StatelessWidget {
  const _Row({
    required this.item,
    required this.index,
    required this.list,
    required this.onEdit,
    required this.onMove,
    required this.onBuy,
    required this.onDelete,
    super.key,
  });

  final WishlistItem item;
  final int index;
  final WishlistList list;
  final VoidCallback onEdit;
  final ValueChanged<WishlistItem> onMove;
  final VoidCallback onBuy;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final subtitle = _subtitle(context, l10n);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: list == WishlistList.buy
          ? Checkbox(
              value: false,
              onChanged: (_) => onBuy(),
            )
          : Icon(
              Icons.star_outline,
              color: scheme.onSurface.withValues(alpha: 0.35),
            ),
      title: Text(item.title),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (item.priceMinor != null)
            Text(
              formatAmount(item.priceMinor!, item.currency),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
                color: scheme.primary,
              ),
            ),
          PopupMenuButton<_ItemAction>(
            tooltip: l10n.wishlistOptions,
            onSelected: (action) {
              switch (action) {
                case _ItemAction.edit:
                  onEdit();
                case _ItemAction.move:
                  onMove(item);
                case _ItemAction.delete:
                  onDelete();
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: _ItemAction.edit,
                child: Text(l10n.wishlistEdit),
              ),
              PopupMenuItem(
                value: _ItemAction.move,
                child: Text(
                  list == WishlistList.buy
                      ? l10n.wishlistMoveToWish
                      : l10n.wishlistMoveToBuy,
                ),
              ),
              PopupMenuItem(
                value: _ItemAction.delete,
                child: Text(l10n.wishlistDelete),
              ),
            ],
          ),
          const SizedBox(width: HarvestSpacing.xs),
          ReorderableDragStartListener(
            index: index,
            child: const Padding(
              padding: EdgeInsets.all(HarvestSpacing.sm),
              child: Icon(Icons.drag_handle),
            ),
          ),
        ],
      ),
      onTap: onEdit,
    );
  }

  /// The target day (with days left) and the note, both when both are
  /// there ([[Wishlist]] "the screen").
  String? _subtitle(BuildContext context, AppLocalizations l10n) {
    final parts = <String>[];
    final day = item.targetDay;
    if (day != null) {
      final left = item.daysLeft(HarvestDay.today());
      parts.add(
        left == null || left < 0
            ? formatDay(context, day)
            : left == 0
            ? l10n.wishlistToday
            : l10n.wishlistInDays(left),
      );
    }
    final note = item.note?.trim();
    if (note != null && note.isNotEmpty) parts.add(note);
    return parts.isEmpty ? null : parts.join(' · ');
  }
}

enum _ItemAction { edit, move, delete }

/// A bought item: struck through, price kept, one tap to un-buy.
class _BoughtRow extends StatelessWidget {
  const _BoughtRow({required this.item, required this.onRestore});

  final WishlistItem item;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Checkbox(
        value: true,
        onChanged: (_) => onRestore(),
      ),
      title: Text(
        item.title,
        style: theme.textTheme.bodyLarge?.copyWith(
          decoration: TextDecoration.lineThrough,
          color: scheme.onSurfaceVariant,
        ),
      ),
      subtitle: item.isBought && item.boughtAt != null
          ? Text(
              l10n.wishlistBoughtOn(formatDay(context, HarvestDay.of(item.boughtAt!))),
            )
          : null,
      trailing: item.priceMinor == null
          ? null
          : Text(
              formatAmount(item.priceMinor!, item.currency),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.onSurfaceVariant,
              ),
            ),
      onTap: onRestore,
    );
  }
}
