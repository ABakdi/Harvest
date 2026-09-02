import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/platform/haptics.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/core/ui/widgets/big_bouncy_button.dart';
import 'package:harvest/core/ui/widgets/gauge_ring.dart';
import 'package:harvest/features/finances/data/finances_repository.dart';
import 'package:harvest/features/finances/domain/expense.dart';
import 'package:harvest/features/finances/presentation/expense_sheet.dart';
import 'package:harvest/features/finances/presentation/finance_providers.dart';
import 'package:harvest/features/finances/presentation/money.dart';
import 'package:harvest/features/planner/domain/notification_planner.dart';
import 'package:harvest/l10n/app_localizations.dart';

Color budgetColor(ColorScheme scheme, BudgetStatus status) =>
    switch (status) {
      BudgetStatus.under => scheme.secondary,
      BudgetStatus.close => scheme.tertiary,
      BudgetStatus.over => scheme.error,
    };

class GranaryScreen extends ConsumerWidget {
  const GranaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final snapshot = ref.watch(budgetSnapshotProvider);
    final settings = ref.watch(financeSettingsProvider).value;
    final symbol = settings?.symbol ?? r'$';
    final expenses = ref.watch(todayExpensesProvider).value ?? const [];
    final suggestion = ref.watch(repeatSuggestionProvider).value;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.granaryTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => unawaited(showExpenseSheet(context)),
        icon: const Icon(Icons.add),
        label: Text(l10n.logExpense),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          HarvestSpacing.md,
          HarvestSpacing.sm,
          HarvestSpacing.md,
          120,
        ),
        children: [
          _BudgetCard(
            snapshot: snapshot,
            symbol: symbol,
            l10n: l10n,
          ),
          if (suggestion != null) ...[
            const SizedBox(height: HarvestSpacing.md),
            _RepeatCard(suggestion: suggestion, symbol: symbol),
          ],
          const SizedBox(height: HarvestSpacing.lg),
          Text(
            l10n.todaySpending,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: HarvestSpacing.sm),
          if (expenses.isEmpty)
            Padding(
              padding: const EdgeInsets.all(HarvestSpacing.lg),
              child: Text(
                l10n.granaryEmpty,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge,
              ),
            )
          else
            for (final expense in expenses)
              Card(
                child: ListTile(
                  onTap: () => unawaited(
                    showExpenseSheet(context, existing: expense),
                  ),
                  leading: CircleAvatar(
                    backgroundColor:
                        theme.colorScheme.secondary.withValues(alpha: 0.18),
                    child: Icon(
                      categoryIcon(expense.category),
                      color: theme.colorScheme.secondary,
                    ),
                  ),
                  title: Text(
                    '$symbol${formatMinor(expense.amountMinor)}',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    expense.note == null || expense.note!.isEmpty
                        ? categoryLabel(l10n, expense.category)
                        : '${categoryLabel(l10n, expense.category)} · '
                            '${expense.note}',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => unawaited(
                      ref
                          .read(financesRepositoryProvider)
                          .remove(expense.uuid),
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _BudgetCard extends ConsumerWidget {
  const _BudgetCard({
    required this.snapshot,
    required this.symbol,
    required this.l10n,
  });

  final BudgetSnapshot? snapshot;
  final String symbol;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final snap = snapshot;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(HarvestSpacing.md),
        child: snap == null
            ? Column(
                children: [
                  Text(l10n.budgetTitle, style: theme.textTheme.titleMedium),
                  const SizedBox(height: HarvestSpacing.sm),
                  BigBouncyButton(
                    icon: Icons.savings,
                    onPressed: () => unawaited(_showBudgetSheet(context)),
                    child: Text(l10n.budgetSet),
                  ),
                ],
              )
            : Row(
                children: [
                  GaugeRing(
                    progress: snap.floatingDailyLimit == 0
                        ? 1
                        : snap.spentToday / snap.floatingDailyLimit,
                    color: budgetColor(theme.colorScheme, snap.status),
                    child: Icon(
                      Icons.savings,
                      size: 32,
                      color: budgetColor(theme.colorScheme, snap.status),
                    ),
                  ),
                  const SizedBox(width: HarvestSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.budgetFloating(
                            '$symbol${formatMinor(snap.spentToday)}',
                            '$symbol${formatMinor(snap.floatingDailyLimit)}',
                          ),
                          style: theme.textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: HarvestSpacing.xs),
                        Text(
                          l10n.budgetSpentOf(
                            '$symbol${formatMinor(snap.spentThisMonth)}',
                            '$symbol${formatMinor(snap.monthlyBudget)}',
                          ),
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => unawaited(_showBudgetSheet(context)),
                  ),
                ],
              ),
      ),
    );
  }
}

Future<void> _showBudgetSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(HarvestRadii.sheet),
        ),
      ),
      builder: (_) => const _BudgetSheet(),
    );

class _BudgetSheet extends ConsumerStatefulWidget {
  const _BudgetSheet();

  @override
  ConsumerState<_BudgetSheet> createState() => _BudgetSheetState();
}

class _BudgetSheetState extends ConsumerState<_BudgetSheet> {
  final _amountController = TextEditingController();
  final _symbolController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final settings = ref.read(financeSettingsProvider).value;
    if (settings?.budgetMinor != null) {
      _amountController.text = formatMinor(settings!.budgetMinor!);
    }
    _symbolController.text = settings?.symbol ?? r'$';
  }

  @override
  void dispose() {
    _amountController.dispose();
    _symbolController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final minor = parseToMinor(_amountController.text);
    if (minor == null) return;
    final symbol = _symbolController.text.trim();
    Navigator.of(context).pop();
    final notifier = ref.read(financeSettingsProvider.notifier);
    await notifier.setBudget(minor);
    if (symbol.isNotEmpty) await notifier.setSymbol(symbol);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

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
            l10n.budgetTitle,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: HarvestSpacing.md),
          TextField(
            controller: _amountController,
            autofocus: true,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: l10n.budgetAmountLabel,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(HarvestRadii.button),
              ),
            ),
          ),
          const SizedBox(height: HarvestSpacing.md),
          TextField(
            controller: _symbolController,
            decoration: InputDecoration(
              labelText: l10n.currencyLabel,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(HarvestRadii.button),
              ),
            ),
          ),
          const SizedBox(height: HarvestSpacing.lg),
          BigBouncySheetButton(
            onPressed: parseToMinor(_amountController.text) == null
                ? null
                : () => unawaited(_save()),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }
}

class _RepeatCard extends ConsumerWidget {
  const _RepeatCard({required this.suggestion, required this.symbol});

  final RepeatSuggestion suggestion;
  final String symbol;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Card(
      color: theme.colorScheme.secondary.withValues(alpha: 0.15),
      child: ListTile(
        leading: Icon(
          categoryIcon(suggestion.category),
          color: theme.colorScheme.secondary,
        ),
        title: Text(
          '$symbol${formatMinor(suggestion.amountMinor)} · '
          '${categoryLabel(l10n, suggestion.category)}',
          style:
              theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(l10n.repeatSuggestionTitle),
        trailing: FilledButton(
          onPressed: () async {
            await ref.read(financesRepositoryProvider).log(
                  amountMinor: suggestion.amountMinor,
                  category: suggestion.category,
                  note: suggestion.note,
                );
            unawaited(HarvestHaptics.thud());
            await ref.read(notificationPlannerProvider).reevaluate();
          },
          child: Text(l10n.logIt),
        ),
      ),
    );
  }
}
