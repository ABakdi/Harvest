import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/platform/haptics.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/features/finances/domain/expense.dart';
import 'package:harvest/features/finances/domain/move_filter.dart';
import 'package:harvest/features/finances/domain/vault.dart';
import 'package:harvest/features/finances/presentation/expense_sheet.dart';
import 'package:harvest/features/finances/presentation/finance_providers.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// The one way to narrow a ledger: what form the movement took, which
/// category it was, and anything I typed in its note.
///
/// It starts collapsed to a single line, because a filter bar that is
/// always open is a filter bar that is always in the way. The count of
/// what is switched on rides on the toggle so a hidden filter can never
/// silently be hiding rows.
class MoveFilterBar extends ConsumerStatefulWidget {
  const MoveFilterBar({
    required this.filter,
    required this.onChanged,
    this.matches,
    this.total,
    super.key,
  });

  final MoveFilter filter;
  final ValueChanged<MoveFilter> onChanged;

  /// How many rows survive the filter, and how many there were.
  final int? matches;
  final int? total;

  @override
  ConsumerState<MoveFilterBar> createState() => _MoveFilterBarState();
}

class _MoveFilterBarState extends ConsumerState<MoveFilterBar> {
  late final TextEditingController _search = TextEditingController(
    text: widget.filter.query,
  );
  var _open = false;

  @override
  void initState() {
    super.initState();
    _open = !widget.filter.isEmpty;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _toggleKind(TxnKind kind) {
    final kinds = {...widget.filter.kinds};
    if (!kinds.remove(kind)) kinds.add(kind);
    HarvestHaptics.tick().ignore();
    widget.onChanged(widget.filter.copyWith(kinds: kinds));
  }

  void _toggleCategory(String key) {
    final categories = {...widget.filter.categories};
    if (!categories.remove(key)) categories.add(key);
    HarvestHaptics.tick().ignore();
    widget.onChanged(widget.filter.copyWith(categories: categories));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final customs = ref.watch(customCategoriesProvider).value ?? const [];
    final filter = widget.filter;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _search,
                textInputAction: TextInputAction.search,
                onChanged: (value) =>
                    widget.onChanged(filter.copyWith(query: value)),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: l10n.movesSearchHint,
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: filter.query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: l10n.clearValue,
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () {
                            _search.clear();
                            widget.onChanged(filter.copyWith(query: ''));
                          },
                        ),
                ),
              ),
            ),
            const SizedBox(width: HarvestSpacing.sm),
            Badge(
              isLabelVisible: filter.activeCount > 0,
              label: Text('${filter.activeCount}'),
              child: IconButton.filledTonal(
                tooltip: l10n.movesFilter,
                isSelected: _open,
                icon: const Icon(Icons.tune),
                onPressed: () => setState(() => _open = !_open),
              ),
            ),
          ],
        ),
        if (_open) ...[
          const SizedBox(height: HarvestSpacing.sm),
          Text(l10n.movesByKind, style: theme.textTheme.labelMedium),
          const SizedBox(height: 4),
          Wrap(
            spacing: HarvestSpacing.xs,
            runSpacing: HarvestSpacing.xs,
            children: [
              for (final kind in TxnKind.values)
                FilterChip(
                  label: Text(_kindLabel(l10n, kind)),
                  selected: filter.kinds.contains(kind),
                  onSelected: (_) => _toggleKind(kind),
                ),
            ],
          ),
          const SizedBox(height: HarvestSpacing.sm),
          Text(l10n.movesByCategory, style: theme.textTheme.labelMedium),
          const SizedBox(height: 4),
          Wrap(
            spacing: HarvestSpacing.xs,
            runSpacing: HarvestSpacing.xs,
            children: [
              for (final key in [
                ...presetCategoryKeys,
                ...customs.map((c) => c.name),
              ])
                FilterChip(
                  avatar: Icon(categoryIcon(key, customs: customs), size: 16),
                  label: Text(categoryLabel(l10n, key)),
                  selected: filter.categories.contains(key),
                  onSelected: (_) => _toggleCategory(key),
                ),
            ],
          ),
          if (!filter.isEmpty) ...[
            const SizedBox(height: HarvestSpacing.xs),
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.matches == null || widget.total == null
                        ? ''
                        : l10n.movesShowing(widget.matches!, widget.total!),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    _search.clear();
                    widget.onChanged(MoveFilter.empty);
                  },
                  icon: const Icon(Icons.filter_alt_off, size: 18),
                  label: Text(l10n.movesClear),
                ),
              ],
            ),
          ],
        ],
      ],
    );
  }

  static String _kindLabel(AppLocalizations l10n, TxnKind kind) =>
      switch (kind) {
        TxnKind.manual => l10n.kindManual,
        TxnKind.transfer => l10n.kindTransfer,
        TxnKind.expense => l10n.kindExpense,
        TxnKind.debt => l10n.kindDebt,
      };
}
