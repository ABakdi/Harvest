import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/platform/haptics.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/core/ui/widgets/big_bouncy_button.dart';
import 'package:harvest/core/ui/widgets/celebration.dart';
import 'package:harvest/features/finances/data/finances_repository.dart';
import 'package:harvest/features/finances/domain/currency.dart';
import 'package:harvest/features/finances/domain/expense.dart';
import 'package:harvest/features/finances/presentation/finance_providers.dart';
import 'package:harvest/features/finances/presentation/money.dart';
import 'package:harvest/features/planner/domain/notification_planner.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// Icons a custom category can pick from (and the preset icons).
const categoryIconRegistry = <String, IconData>{
  'restaurant': Icons.restaurant,
  'bus': Icons.directions_bus,
  'receipt': Icons.receipt_long,
  'bag': Icons.shopping_bag,
  'heart': Icons.favorite,
  'movie': Icons.movie,
  'category': Icons.category,
  'coffee': Icons.local_cafe,
  'home': Icons.home,
  'car': Icons.directions_car,
  'gift': Icons.card_giftcard,
  'pets': Icons.pets,
  'school': Icons.school,
  'fitness': Icons.fitness_center,
  'phone': Icons.smartphone,
  'games': Icons.sports_esports,
  'travel': Icons.flight,
  'baby': Icons.child_friendly,
  'tools': Icons.handyman,
  'music': Icons.music_note,
};

/// Resolves any category key (preset or custom) to an icon.
IconData categoryIcon(String key, {List<CustomCategory> customs = const []}) {
  final preset = ExpenseCategory.values
      .where((category) => category.name == key)
      .firstOrNull;
  if (preset != null) {
    return switch (preset) {
      ExpenseCategory.food => Icons.restaurant,
      ExpenseCategory.transport => Icons.directions_bus,
      ExpenseCategory.bills => Icons.receipt_long,
      ExpenseCategory.shopping => Icons.shopping_bag,
      ExpenseCategory.health => Icons.favorite,
      ExpenseCategory.entertainment => Icons.movie,
      ExpenseCategory.other => Icons.category,
    };
  }
  final custom =
      customs.where((category) => category.name == key).firstOrNull;
  return categoryIconRegistry[custom?.icon] ?? Icons.category;
}

/// Resolves any category key to a display label.
String categoryLabel(AppLocalizations l10n, String key) {
  final preset = ExpenseCategory.values
      .where((category) => category.name == key)
      .firstOrNull;
  if (preset == null) return key; // customs display their own name
  return switch (preset) {
    ExpenseCategory.food => l10n.catFood,
    ExpenseCategory.transport => l10n.catTransport,
    ExpenseCategory.bills => l10n.catBills,
    ExpenseCategory.shopping => l10n.catShopping,
    ExpenseCategory.health => l10n.catHealth,
    ExpenseCategory.entertainment => l10n.catEntertainment,
    ExpenseCategory.other => l10n.catOther,
  };
}

/// The sub-5-second quick-log: amount, category chip, optional note.
/// Pass [existing] to edit a same-day entry in place.
Future<void> showExpenseSheet(BuildContext context, {Expense? existing}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(HarvestRadii.sheet),
        ),
      ),
      builder: (_) => _ExpenseSheet(existing: existing),
    );

class _ExpenseSheet extends ConsumerStatefulWidget {
  const _ExpenseSheet({this.existing});

  final Expense? existing;

  @override
  ConsumerState<_ExpenseSheet> createState() => _ExpenseSheetState();
}

class _ExpenseSheetState extends ConsumerState<_ExpenseSheet> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String _category = ExpenseCategory.food.name;
  Currency? _currency;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _amountController.text = formatMinor(existing.amountMinor);
      _noteController.text = existing.note ?? '';
      _category = existing.category;
      _currency = existing.currency;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  int? get _amountMinor => parseToMinor(_amountController.text);

  Future<void> _log() async {
    final amount = _amountMinor;
    if (amount == null) return;
    final note = _noteController.text.trim();
    final existing = widget.existing;
    // Coin burst above the sheet before it closes (gap G11).
    final box = context.findRenderObject() as RenderBox?;
    if (box != null) {
      showCheckInBurst(
        context,
        box.localToGlobal(box.size.topCenter(Offset.zero)),
        icon: Icons.paid,
        color: Theme.of(context).colorScheme.tertiary,
      );
    }
    Navigator.of(context).pop();
    final repo = ref.read(financesRepositoryProvider);
    final currency = _currency ??
        ref.read(financeSettingsProvider).value?.defaultCurrency ??
        Currency.dzd;
    if (existing != null) {
      await repo.updateExpense(
        uuid: existing.uuid,
        amountMinor: amount,
        category: _category,
        currency: currency,
        note: note.isEmpty ? null : note,
      );
    } else {
      await repo.log(
        amountMinor: amount,
        category: _category,
        currency: currency,
        note: note.isEmpty ? null : note,
      );
    }
    await HarvestHaptics.thud();
    await ref.read(notificationPlannerProvider).reevaluate();
  }

  Future<void> _createCategory(BuildContext context) async {
    final created = await showCategoryCreator(context, ref);
    if (created != null) setState(() => _category = created);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final customs = ref.watch(customCategoriesProvider).value ?? const [];

    return Padding(
      padding: EdgeInsets.only(
        left: HarvestSpacing.lg,
        right: HarvestSpacing.lg,
        top: HarvestSpacing.lg,
        bottom: MediaQuery.viewInsetsOf(context).bottom + HarvestSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.logExpense,
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: HarvestSpacing.md),
          TextField(
            controller: _amountController,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
            ),
            onChanged: (_) => setState(() {}),
            style: theme.textTheme.headlineMedium
                ?.copyWith(fontWeight: FontWeight.w800),
            decoration: InputDecoration(
              labelText: l10n.amountLabel,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(HarvestRadii.button),
              ),
            ),
          ),
          const SizedBox(height: HarvestSpacing.sm),
          // Per-expense currency (checkpoint P4).
          Row(
            children: [
              Text(l10n.expenseCurrencyLabel),
              const SizedBox(width: HarvestSpacing.sm),
              SegmentedButton<Currency>(
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                ),
                segments: [
                  for (final option in Currency.values)
                    ButtonSegment(
                      value: option,
                      label: Text(option.symbol),
                    ),
                ],
                selected: {
                  _currency ??
                      ref.watch(financeSettingsProvider).value
                              ?.defaultCurrency ??
                          Currency.dzd,
                },
                onSelectionChanged: (selection) =>
                    setState(() => _currency = selection.first),
              ),
            ],
          ),
          const SizedBox(height: HarvestSpacing.md),
          Wrap(
            spacing: HarvestSpacing.xs,
            runSpacing: HarvestSpacing.xs,
            children: [
              for (final key in [
                ...presetCategoryKeys,
                ...customs.map((c) => c.name),
              ])
                ChoiceChip(
                  avatar: Icon(
                    categoryIcon(key, customs: customs),
                    size: 18,
                  ),
                  label: Text(categoryLabel(l10n, key)),
                  selected: _category == key,
                  onSelected: (_) {
                    unawaited(HarvestHaptics.tick());
                    setState(() => _category = key);
                  },
                ),
              ActionChip(
                avatar: const Icon(Icons.add, size: 18),
                label: Text(l10n.newCategory),
                onPressed: () => unawaited(_createCategory(context)),
              ),
            ],
          ),
          const SizedBox(height: HarvestSpacing.md),
          TextField(
            controller: _noteController,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: l10n.noteLabel,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(HarvestRadii.button),
              ),
            ),
          ),
          const SizedBox(height: HarvestSpacing.lg),
          BigBouncySheetButton(
            onPressed: _amountMinor == null ? null : () => unawaited(_log()),
            child: Text(l10n.log),
          ),
        ],
      ),
    );
  }
}


/// Name + icon picker for a new category; returns the created key.
Future<String?> showCategoryCreator(BuildContext context, WidgetRef ref) {
  final l10n = AppLocalizations.of(context);
  final controller = TextEditingController();
  var icon = 'coffee';

  return showDialog<String>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setState) => AlertDialog(
        title: Text(l10n.newCategory),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(labelText: l10n.categoryName),
            ),
            const SizedBox(height: HarvestSpacing.md),
            SizedBox(
              width: 280,
              child: Wrap(
                spacing: HarvestSpacing.xs,
                runSpacing: HarvestSpacing.xs,
                children: [
                  for (final entry in categoryIconRegistry.entries)
                    InkWell(
                      borderRadius:
                          BorderRadius.circular(HarvestRadii.chip),
                      onTap: () => setState(() => icon = entry.key),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          borderRadius:
                              BorderRadius.circular(HarvestRadii.chip),
                          color: icon == entry.key
                              ? Theme.of(dialogContext)
                                  .colorScheme
                                  .secondary
                                  .withValues(alpha: 0.3)
                              : null,
                        ),
                        child: Icon(entry.value, size: 22),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              await ref
                  .read(financesRepositoryProvider)
                  .createCategory(name: name, icon: icon);
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop(name);
              }
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    ),
  );
}
