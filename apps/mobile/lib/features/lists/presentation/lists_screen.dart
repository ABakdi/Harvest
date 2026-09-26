import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:harvest/app/router.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/core/platform/haptics.dart';
import 'package:harvest/core/ui/format.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/core/ui/widgets/action_snack_bar.dart';
import 'package:harvest/core/ui/widgets/big_bouncy_button.dart';
import 'package:harvest/core/ui/widgets/empty_state.dart';
import 'package:harvest/core/ui/widgets/harvest_fab.dart';
import 'package:harvest/core/ui/widgets/section_header.dart';
import 'package:harvest/core/ui/widgets/text_prompt.dart';
import 'package:harvest/features/commitments/domain/commitment.dart';
import 'package:harvest/features/commitments/presentation/commitment_editor_sheet.dart';
import 'package:harvest/features/commitments/presentation/field_providers.dart';
import 'package:harvest/features/commitments/presentation/seed_providers.dart';
import 'package:harvest/features/finances/domain/expense.dart';
import 'package:harvest/features/finances/presentation/choice_sheet.dart';
import 'package:harvest/features/finances/presentation/expense_sheet.dart';
import 'package:harvest/features/finances/presentation/money.dart';
import 'package:harvest/features/lists/data/lists_repository.dart';
import 'package:harvest/features/lists/domain/lists.dart';
import 'package:harvest/features/lists/presentation/list_item_sheet.dart';
import 'package:harvest/features/lists/presentation/list_labels.dart';
import 'package:harvest/features/notes/data/notes_repository.dart';
import 'package:harvest/features/settings/domain/feature_switches.dart';
import 'package:harvest/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

/// Records → Lists ([[Lists]]): every list as a chip with its open
/// count, the chosen list below — its open items in my order, what is
/// done folded underneath — and each list's menu to rename, reorder or
/// delete it.
///
/// One screen for every list (L1): a list's kind decides what its rows
/// show and what done means (L2), never which screen it gets.
class ListsScreen extends ConsumerStatefulWidget {
  const ListsScreen({this.title, this.tabs, this.initialList, super.key});

  /// The title and tabs of Records, when Lists shares it.
  final String? title;
  final PreferredSizeWidget? tabs;

  /// The list to open on — *To buy*, from the Granary's line.
  final String? initialList;

  @override
  ConsumerState<ListsScreen> createState() => _ListsScreenState();
}

class _ListsScreenState extends ConsumerState<ListsScreen> {
  /// The lists and their items, followed by the screen itself rather
  /// than through provider watches: the Wishlist tab learned that a
  /// watch paused under a sheet and a permission prompt can stay paused
  /// and leave the list saying it is empty ([[Wishlist]]).
  ListsRepository? _repository;
  StreamSubscription<List<ItemList>>? _listsSub;
  StreamSubscription<List<ListItem>>? _itemsSub;
  List<ItemList>? _lists;
  List<ListItem> _items = const [];

  late String? _selected = widget.initialList;

  /// Done items stay folded until asked for.
  var _doneOpen = false;

  void _follow(ListsRepository repository) {
    if (identical(repository, _repository)) return;
    _repository = repository;
    unawaited(_listsSub?.cancel());
    unawaited(_itemsSub?.cancel());
    _listsSub = repository.watchLists().listen((lists) {
      if (mounted) setState(() => _lists = lists);
    });
    _itemsSub = repository.watchAllItems().listen((items) {
      if (mounted) setState(() => _items = items);
    });
  }

  @override
  void didUpdateWidget(ListsScreen old) {
    super.didUpdateWidget(old);
    if (widget.initialList != null && widget.initialList != old.initialList) {
      _selected = widget.initialList;
    }
  }

  @override
  void dispose() {
    unawaited(_listsSub?.cancel());
    unawaited(_itemsSub?.cancel());
    super.dispose();
  }

  ItemList? get _current {
    final lists = _lists;
    if (lists == null || lists.isEmpty) return null;
    return lists.where((list) => list.uuid == _selected).firstOrNull ??
        lists.first;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    _follow(ref.watch(listsRepositoryProvider));
    final lists = _lists;
    final current = _current;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? l10n.navLists),
        bottom: widget.tabs,
        actions: [
          if (current != null && lists != null)
            _ListMenu(
              list: current,
              lists: lists,
              onDeleted: () => setState(() => _selected = null),
            ),
        ],
      ),
      floatingActionButton: current == null
          ? null
          : HarvestFab(
              onPressed: () => unawaited(_add(current)),
              label: l10n.wishlistAdd,
            ),
      body: lists == null || current == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Chips(
                  lists: lists,
                  items: _items,
                  selected: current.uuid,
                  onSelect: (list) => setState(() => _selected = list.uuid),
                  onNew: () => unawaited(_newList()),
                ),
                Expanded(child: _body(context, l10n, current, lists)),
              ],
            ),
    );
  }

  Widget _body(
    BuildContext context,
    AppLocalizations l10n,
    ItemList list,
    List<ItemList> lists,
  ) {
    final items = [
      for (final item in _items)
        if (item.listUuid == list.uuid) item,
    ];
    // The Wishlist folds nothing away (L7): a wish that arrives bought
    // (an old import, another device) stays in view with the rest,
    // where it can still be moved or deleted.
    final folds = list.canBeDone;
    final open = [
      for (final item in items)
        if (!folds || !item.isDone) item,
    ];
    final done = [
      for (final item in items)
        if (folds && item.isDone) item,
    ];
    if (items.isEmpty) {
      final (title, body) = _emptyText(l10n, list);
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(HarvestSpacing.xl),
          child: EmptyState(
            icon: listIcon(list),
            title: title,
            body: body,
            action: BigBouncyButton(
              icon: Icons.add,
              onPressed: () => unawaited(_add(list)),
              child: Text(l10n.wishlistAdd),
            ),
          ),
        ),
      );
    }
    final totals = list.kind == ListKind.shopping
        ? estimateTotals(l10n, open)
        : '';
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        HarvestSpacing.md,
        0,
        HarvestSpacing.md,
        120,
      ),
      children: [
        SectionHeader(
          l10n.wishlistOpen,
          subtitle: totals.isEmpty ? null : totals,
        ),
        _OpenItems(list: list, lists: lists, items: open),
        if (done.isNotEmpty) ...[
          const SizedBox(height: HarvestSpacing.sm),
          InkWell(
            borderRadius: BorderRadius.circular(HarvestRadii.button),
            onTap: () => setState(() => _doneOpen = !_doneOpen),
            child: SectionHeader(
              _doneLabel(l10n, list, done.length),
              trailing: Icon(
                _doneOpen ? Icons.expand_less : Icons.expand_more,
              ),
            ),
          ),
          if (_doneOpen)
            Card(
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: HarvestSpacing.sm,
                  vertical: HarvestSpacing.xs,
                ),
                child: Column(
                  children: [
                    for (final item in done)
                      _DoneRow(item: item, list: list, lists: lists),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }

  (String, String) _emptyText(AppLocalizations l10n, ItemList list) =>
      switch (list.builtIn) {
        BuiltInList.buy => (
          l10n.wishlistBuyEmptyTitle,
          l10n.wishlistBuyEmptyBody,
        ),
        BuiltInList.wish => (
          l10n.wishlistWishEmptyTitle,
          l10n.wishlistWishEmptyBody,
        ),
        BuiltInList.read => (l10n.listsReadEmptyTitle, l10n.listsShareHint),
        BuiltInList.watch => (l10n.listsWatchEmptyTitle, l10n.listsShareHint),
        null => (l10n.listsEmptyTitle, l10n.listsEmptyBody),
      };

  String _doneLabel(AppLocalizations l10n, ItemList list, int count) =>
      switch (list.kind) {
        ListKind.shopping => l10n.wishlistBought(count),
        ListKind.media => l10n.listsFinishedCount(count),
        ListKind.plain => l10n.listsDoneCount(count),
      };

  Future<void> _add(ItemList list) async {
    final item = await showListItemSheet(context, list: list);
    if (item == null || !mounted) return;
    setState(() => _selected = item.listUuid);
  }

  Future<void> _newList() async {
    final list = await showNewListSheet(context);
    if (list == null || !mounted) return;
    setState(() => _selected = list.uuid);
  }
}

/// The lists as a row of chips, each with its open count, and a last
/// chip that makes a new one.
class _Chips extends StatelessWidget {
  const _Chips({
    required this.lists,
    required this.items,
    required this.selected,
    required this.onSelect,
    required this.onNew,
  });

  final List<ItemList> lists;
  final List<ListItem> items;
  final String selected;
  final ValueChanged<ItemList> onSelect;
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final counts = {for (final list in lists) list.uuid: 0};
    for (final item in items) {
      if (item.isDone || !counts.containsKey(item.listUuid)) continue;
      counts[item.listUuid] = counts[item.listUuid]! + 1;
    }
    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: HarvestSpacing.md,
          vertical: HarvestSpacing.sm,
        ),
        children: [
          for (final list in lists)
            Padding(
              padding: const EdgeInsetsDirectional.only(
                end: HarvestSpacing.xs,
              ),
              child: ChoiceChip(
                avatar: Icon(listIcon(list), size: 18),
                label: Text(
                  counts[list.uuid] == 0
                      ? listName(l10n, list)
                      : '${listName(l10n, list)} · ${counts[list.uuid]}',
                ),
                selected: list.uuid == selected,
                onSelected: (_) => onSelect(list),
              ),
            ),
          ActionChip(
            avatar: const Icon(Icons.add, size: 18),
            label: Text(l10n.listsNew),
            onPressed: onNew,
          ),
        ],
      ),
    );
  }
}

enum _ListAction { rename, left, right, delete }

/// A list's menu: rename it, move it along the row, or delete it — a
/// list I made only (L10), with undo (L6).
class _ListMenu extends ConsumerWidget {
  const _ListMenu({
    required this.list,
    required this.lists,
    required this.onDeleted,
  });

  final ItemList list;
  final List<ItemList> lists;
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final index = lists.indexWhere((l) => l.uuid == list.uuid);
    return PopupMenuButton<_ListAction>(
      tooltip: l10n.listsOptions,
      onSelected: (action) => unawaited(_act(context, ref, action, index)),
      itemBuilder: (_) => [
        PopupMenuItem(value: _ListAction.rename, child: Text(l10n.listsRename)),
        PopupMenuItem(
          value: _ListAction.left,
          enabled: index > 0,
          child: Text(l10n.listsMoveEarlier),
        ),
        PopupMenuItem(
          value: _ListAction.right,
          enabled: index < lists.length - 1,
          child: Text(l10n.listsMoveLater),
        ),
        if (list.isDeletable)
          PopupMenuItem(
            value: _ListAction.delete,
            child: Text(l10n.listsDelete),
          ),
      ],
    );
  }

  Future<void> _act(
    BuildContext context,
    WidgetRef ref,
    _ListAction action,
    int index,
  ) async {
    final l10n = AppLocalizations.of(context);
    final repository = ref.read(listsRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    switch (action) {
      case _ListAction.rename:
        final name = await promptForText(
          context,
          title: l10n.listsRename,
          initial: listName(l10n, list),
        );
        if (name == null || name.trim().isEmpty) return;
        // Renaming a built-in back to its shown name keeps it
        // localised rather than pinning the English one.
        if (list.hasDefaultName && name.trim() == listName(l10n, list)) {
          return;
        }
        await repository.renameList(list.uuid, name);
      case _ListAction.left:
      case _ListAction.right:
        final to = action == _ListAction.left ? index - 1 : index + 1;
        if (index < 0 || to < 0 || to >= lists.length) return;
        final uuids = [for (final l in lists) l.uuid];
        final moved = uuids.removeAt(index);
        uuids.insert(to, moved);
        await repository.reorderLists(uuids);
      case _ListAction.delete:
        if (!await repository.deleteList(list.uuid)) return;
        onDeleted();
        messenger.showSnackBar(
          actionSnackBar(
            messenger,
            content: Text(l10n.listsDeleted(listName(l10n, list))),
            action: SnackBarAction(
              label: l10n.undoAction,
              onPressed: () => unawaited(repository.restoreList(list.uuid)),
            ),
          ),
        );
    }
  }
}

/// The open items, in my order: dragged by the handle.
class _OpenItems extends ConsumerWidget {
  const _OpenItems({
    required this.list,
    required this.lists,
    required this.items,
  });

  final ItemList list;
  final List<ItemList> lists;
  final List<ListItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.read(listsRepositoryProvider);
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: items.length,
      onReorderItem: (from, to) {
        final uuids = [for (final item in items) item.uuid];
        final moved = uuids.removeAt(from);
        uuids.insert(to, moved);
        unawaited(repository.reorderItems(list.uuid, uuids));
      },
      itemBuilder: (context, i) => _OpenRow(
        key: ValueKey(items[i].uuid),
        item: items[i],
        index: i,
        list: list,
        lists: lists,
      ),
    );
  }
}

enum _ItemAction { edit, move, link, plant, write, delete }

class _OpenRow extends ConsumerWidget {
  const _OpenRow({
    required this.item,
    required this.index,
    required this.list,
    required this.lists,
    super.key,
  });

  final ListItem item;
  final int index;
  final ItemList list;
  final List<ItemList> lists;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final actions = ItemActions(context, ref, item: item, list: list);
    final subtitle = _subtitle(context, l10n);
    final media = list.kind == ListKind.media;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: media
          ? Icon(
              mediaTypeIcon(item.mediaType),
              color: item.inProgress ? scheme.primary : scheme.onSurfaceVariant,
            )
          : list.canBeDone
          ? Checkbox(
              value: false,
              onChanged: (_) => unawaited(actions.markDone()),
            )
          : Icon(
              Icons.star_outline,
              color: scheme.onSurface.withValues(alpha: 0.35),
            ),
      title: Text(item.title),
      subtitle: subtitle == null && item.seedUuid == null
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (subtitle != null) Text(subtitle),
                if (item.seedUuid != null)
                  _SeedLine(item: item, list: list, actions: actions),
              ],
            ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (item.priceMinor != null)
            Text(
              formatMoney(item.priceMinor!, item.currency),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
                // A plan, not a debt: plain text, not the accent that
                // reads as money owed.
                color: scheme.onSurface,
              ),
            ),
          if (media && item.inProgress)
            IconButton(
              tooltip: l10n.listsFinish,
              icon: const Icon(Icons.check_circle_outline),
              onPressed: () => unawaited(actions.finish()),
            )
          else if (media)
            IconButton(
              tooltip: l10n.listsStart,
              icon: const Icon(Icons.play_circle_outline),
              onPressed: () => unawaited(actions.start()),
            ),
          _ItemMenu(actions: actions, lists: lists),
          ReorderableDragStartListener(
            index: index,
            child: const Padding(
              padding: EdgeInsets.all(HarvestSpacing.sm),
              child: Icon(Icons.drag_handle),
            ),
          ),
        ],
      ),
      onTap: () => unawaited(actions.edit()),
    );
  }

  /// Shopping: the planned day (with days left) and the note. Media:
  /// in progress, the type and the creator, then the note. Plain: the
  /// note.
  String? _subtitle(BuildContext context, AppLocalizations l10n) {
    final parts = <String>[];
    switch (list.kind) {
      case ListKind.shopping:
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
      case ListKind.media:
        if (item.inProgress) parts.add(l10n.listsInProgress);
        if (item.mediaType case final type?) {
          parts.add(mediaTypeLabel(l10n, type));
        }
        if (item.creator case final creator?) parts.add(creator);
      case ListKind.plain:
        break;
    }
    final note = item.note?.trim();
    if (note != null && note.isNotEmpty) parts.add(note);
    return parts.isEmpty ? null : parts.join(' · ');
  }
}

/// A done item: struck through, one tap to take it back.
class _DoneRow extends ConsumerWidget {
  const _DoneRow({required this.item, required this.list, required this.lists});

  final ListItem item;
  final ItemList list;
  final List<ItemList> lists;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final actions = ItemActions(context, ref, item: item, list: list);
    final day = item.doneAt == null
        ? null
        : formatDay(context, HarvestDay.of(item.doneAt!));
    final rating = item.rating;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Checkbox(
        value: true,
        onChanged: (_) => unawaited(actions.undoDone()),
      ),
      title: Text(
        item.title,
        style: theme.textTheme.bodyLarge?.copyWith(
          decoration: TextDecoration.lineThrough,
          color: scheme.onSurfaceVariant,
        ),
      ),
      subtitle: day == null
          ? null
          : Text(
              [
                switch (list.kind) {
                  ListKind.shopping => l10n.wishlistBoughtOn(day),
                  ListKind.media => l10n.listsFinishedOn(day),
                  ListKind.plain => l10n.listsDoneOn(day),
                },
                if (rating != null) '★' * rating,
              ].join(' · '),
            ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (item.priceMinor != null)
            Text(
              formatMoney(item.priceMinor!, item.currency),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.onSurfaceVariant,
              ),
            ),
          _ItemMenu(actions: actions, lists: lists),
        ],
      ),
      onTap: () => unawaited(actions.edit()),
    );
  }
}

class _ItemMenu extends ConsumerWidget {
  const _ItemMenu({required this.actions, required this.lists});

  final ItemActions actions;
  final List<ItemList> lists;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final item = actions.item;
    final list = actions.list;
    final notesOn = ref.watch(notesEnabledProvider);
    final others = actions.sameKind(lists);
    return PopupMenuButton<_ItemAction>(
      tooltip: l10n.wishlistOptions,
      onSelected: (action) => unawaited(switch (action) {
        _ItemAction.edit => actions.edit(),
        _ItemAction.move => actions.move(others),
        _ItemAction.link => actions.openLink(),
        _ItemAction.plant => actions.plant(),
        _ItemAction.write => actions.writeAbout(),
        _ItemAction.delete => actions.delete(),
      }),
      itemBuilder: (_) => [
        PopupMenuItem(value: _ItemAction.edit, child: Text(l10n.wishlistEdit)),
        if (others.isNotEmpty)
          PopupMenuItem(value: _ItemAction.move, child: Text(l10n.listsMoveTo)),
        if (item.link != null)
          PopupMenuItem(
            value: _ItemAction.link,
            child: Text(l10n.listsOpenLink),
          ),
        if (item.seedUuid == null && !item.isDone)
          PopupMenuItem(value: _ItemAction.plant, child: Text(l10n.listsPlant)),
        if (list.kind == ListKind.media && notesOn)
          PopupMenuItem(
            value: _ItemAction.write,
            child: Text(
              item.noteUuid == null ? l10n.listsWriteAbout : l10n.listsOpenNote,
            ),
          ),
        PopupMenuItem(
          value: _ItemAction.delete,
          child: Text(l10n.wishlistDelete),
        ),
      ],
    );
  }
}

/// The seed an item was planted as: its progress, and once it is done
/// an offer to mark the item finished too ([[Lists]]: Plant as a seed).
class _SeedLine extends ConsumerWidget {
  const _SeedLine({
    required this.item,
    required this.list,
    required this.actions,
  });

  final ListItem item;
  final ItemList list;
  final ItemActions actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final seed = ref.watch(seedProvider(item.seedUuid!)).value;
    if (seed == null) return const SizedBox.shrink();
    final logged = ref.watch(lifetimeTotalsProvider).value?[seed.uuid] ?? 0;
    final done = seedIsDone(seed, logged);
    final total = seed.totalTarget;
    final text = done
        ? l10n.listsSeedDone
        : seed.type == CommitmentType.project && total != null
        ? l10n.listsSeedProgress(logged, total)
        : l10n.listsSeedGrowing;
    return Row(
      children: [
        Icon(Icons.eco_outlined, size: 14, color: theme.colorScheme.primary),
        const SizedBox(width: 4),
        Flexible(child: Text(text)),
        if (done && !item.isDone && list.canBeDone)
          TextButton(
            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
            onPressed: () => unawaited(
              list.kind == ListKind.media
                  ? actions.finish()
                  : actions.markDone(offerExpense: false),
            ),
            child: Text(l10n.listsMarkFinished),
          ),
      ],
    );
  }
}

/// Whether a seed has got where it was going: a project that reached
/// its total, a to-do done, or any seed put away in the archive.
bool seedIsDone(Commitment seed, int logged) =>
    seed.isArchived ||
    switch (seed.type) {
      CommitmentType.project => logged >= (seed.totalTarget ?? 0),
      CommitmentType.todo => logged > 0,
      CommitmentType.habit => false,
    };

/// What can be done to one item, from its row or its menu.
class ItemActions {
  ItemActions(this.context, this.ref, {required this.item, required this.list});

  final BuildContext context;
  final WidgetRef ref;
  final ListItem item;
  final ItemList list;

  ListsRepository get _repository => ref.read(listsRepositoryProvider);

  /// The other live lists an item here can move to: the same kind only
  /// (L2).
  List<ItemList> sameKind(List<ItemList> lists) => [
    for (final other in lists)
      if (other.kind == list.kind && other.uuid != list.uuid) other,
  ];

  Future<void> edit() => showListItemSheet(context, list: list, existing: item);

  /// Ticked, or bought — a stamp, not a transaction (L4). Buying then
  /// offers the expense, prefilled; it is logged only if I log it.
  Future<void> markDone({bool offerExpense = true}) async {
    unawaited(HarvestHaptics.tick());
    if (!await _repository.setDone(item.uuid, done: true)) return;
    if (!offerExpense || list.kind != ListKind.shopping) return;
    if (!context.mounted) return;
    await showExpenseSheet(
      context,
      prefill: (
        amountMinor: item.priceMinor,
        currency: item.priceMinor == null ? null : item.currency,
        note: item.title,
        category: ExpenseCategory.shopping.name,
      ),
    );
  }

  Future<void> undoDone() async {
    unawaited(HarvestHaptics.tick());
    await _repository.setDone(item.uuid, done: false);
  }

  /// Want → in progress.
  Future<void> start() async {
    unawaited(HarvestHaptics.tick());
    await _repository.setStarted(item.uuid, started: true);
  }

  /// In progress (or wanted) → finished, with a rating if I give one.
  Future<void> finish() async {
    final rating = await showRatingDialog(context, title: item.title);
    if (rating == null) return;
    unawaited(HarvestHaptics.tick());
    await _repository.setDone(item.uuid, done: true);
    if (rating > 0) await _repository.setRating(item.uuid, rating);
  }

  Future<void> move(List<ItemList> to) async {
    final l10n = AppLocalizations.of(context);
    final target = await showChoiceSheet<ItemList>(
      context,
      title: l10n.listsMoveToTitle,
      options: [
        for (final list in to)
          ChoiceOption(
            value: list,
            label: listName(l10n, list),
            icon: listIcon(list),
          ),
      ],
    );
    if (target == null) return;
    await _repository.moveItem(item.uuid, target.uuid);
  }

  /// Opens the link in whatever handles it — on my tap, and only then
  /// (L9, [[Business-Rules]] 13).
  Future<void> openLink() async {
    final link = item.link;
    if (link == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final failed = AppLocalizations.of(context).listsLinkFailed;
    final uri = Uri.tryParse(link);
    var opened = false;
    if (uri != null && uri.hasScheme) {
      try {
        opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } on Object {
        opened = false;
      }
    }
    if (!opened) messenger.showSnackBar(SnackBar(content: Text(failed)));
  }

  /// Plants the item as a seed, as a goal's items are ([[Goals]]): a
  /// book a project of pages, anything else a to-do. The seed pays as
  /// any seed does (L8); the item keeps the link.
  Future<void> plant() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final book = item.mediaType == MediaType.book;
    final seed = await showCommitmentEditor(
      context,
      initialTitle: item.title,
      initialType: book ? CommitmentType.project : CommitmentType.todo,
      initialTotal: book ? 300 : null,
      initialDaily: book ? 10 : null,
    );
    if (seed == null) return;
    await _repository.linkSeed(item.uuid, seed.uuid);
    messenger.showSnackBar(SnackBar(content: Text(l10n.goalPlanted)));
  }

  /// A note named after the item, linked to it; the one already written
  /// when there is one.
  Future<void> writeAbout() async {
    final router = GoRouter.of(context);
    final notes = ref.read(notesRepositoryProvider);
    var uuid = item.noteUuid;
    if (uuid != null && await notes.watchOne(uuid).first == null) uuid = null;
    if (uuid == null) {
      // Notes link by title, so a note already named after it is the
      // one to write in rather than a second of the same name.
      final note =
          await notes.byTitle(item.title) ??
          await notes.create(title: item.title);
      await _repository.linkNote(item.uuid, note.uuid);
      uuid = note.uuid;
    }
    unawaited(router.push('${AppRoutes.notes}/$uuid'));
  }

  Future<void> delete() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final repository = _repository;
    await repository.deleteItem(item.uuid);
    messenger.showSnackBar(
      actionSnackBar(
        messenger,
        content: Text(l10n.wishlistRemoved),
        action: SnackBarAction(
          label: l10n.undoAction,
          onPressed: () => unawaited(repository.restoreItem(item.uuid)),
        ),
      ),
    );
  }
}

/// Finishing asks how it was: one to five stars, or none. Null when the
/// dialog is dismissed, 0 for no rating.
Future<int?> showRatingDialog(BuildContext context, {required String title}) =>
    showDialog<int>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        return AlertDialog(
          title: Text(l10n.listsRateTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, textAlign: TextAlign.center),
              const SizedBox(height: HarvestSpacing.md),
              Wrap(
                alignment: WrapAlignment.center,
                children: [
                  for (var stars = 1; stars <= 5; stars++)
                    IconButton(
                      tooltip: l10n.listsRatingStars(stars),
                      icon: Icon(
                        Icons.star_rounded,
                        color: Theme.of(context).colorScheme.tertiary,
                      ),
                      onPressed: () => Navigator.of(context).pop(stars),
                    ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(0),
              child: Text(l10n.listsRateSkip),
            ),
          ],
        );
      },
    );
