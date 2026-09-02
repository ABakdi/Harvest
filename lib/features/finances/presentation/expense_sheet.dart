import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/platform/haptics.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/core/ui/widgets/big_bouncy_button.dart';
import 'package:harvest/features/finances/data/finances_repository.dart';
import 'package:harvest/features/finances/domain/expense.dart';
import 'package:harvest/features/finances/presentation/money.dart';
import 'package:harvest/features/planner/domain/notification_planner.dart';
import 'package:harvest/l10n/app_localizations.dart';

IconData categoryIcon(ExpenseCategory category) => switch (category) {
      ExpenseCategory.food => Icons.restaurant,
      ExpenseCategory.transport => Icons.directions_bus,
      ExpenseCategory.bills => Icons.receipt_long,
      ExpenseCategory.shopping => Icons.shopping_bag,
      ExpenseCategory.health => Icons.favorite,
      ExpenseCategory.entertainment => Icons.movie,
      ExpenseCategory.other => Icons.category,
    };

String categoryLabel(AppLocalizations l10n, ExpenseCategory category) =>
    switch (category) {
      ExpenseCategory.food => l10n.catFood,
      ExpenseCategory.transport => l10n.catTransport,
      ExpenseCategory.bills => l10n.catBills,
      ExpenseCategory.shopping => l10n.catShopping,
      ExpenseCategory.health => l10n.catHealth,
      ExpenseCategory.entertainment => l10n.catEntertainment,
      ExpenseCategory.other => l10n.catOther,
    };

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
  ExpenseCategory _category = ExpenseCategory.food;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _amountController.text = formatMinor(existing.amountMinor);
      _noteController.text = existing.note ?? '';
      _category = existing.category;
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
    Navigator.of(context).pop();
    final repo = ref.read(financesRepositoryProvider);
    if (existing != null) {
      await repo.updateExpense(
        uuid: existing.uuid,
        amountMinor: amount,
        category: _category,
        note: note.isEmpty ? null : note,
      );
    } else {
      await repo.log(
        amountMinor: amount,
        category: _category,
        note: note.isEmpty ? null : note,
      );
    }
    await HarvestHaptics.thud();
    await ref.read(notificationPlannerProvider).reevaluate();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

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
          const SizedBox(height: HarvestSpacing.md),
          Wrap(
            spacing: HarvestSpacing.xs,
            runSpacing: HarvestSpacing.xs,
            children: [
              for (final category in ExpenseCategory.values)
                ChoiceChip(
                  avatar: Icon(categoryIcon(category), size: 18),
                  label: Text(categoryLabel(l10n, category)),
                  selected: _category == category,
                  onSelected: (_) {
                    unawaited(HarvestHaptics.tick());
                    setState(() => _category = category);
                  },
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
