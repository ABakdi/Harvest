import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/core/ui/widgets/big_bouncy_button.dart';
import 'package:harvest/core/ui/widgets/gauge_ring.dart';
import 'package:harvest/features/finances/data/finances_repository.dart';
import 'package:harvest/features/finances/domain/currency.dart';
import 'package:harvest/features/finances/domain/expense.dart';
import 'package:harvest/features/finances/presentation/expense_sheet.dart';
import 'package:harvest/features/finances/presentation/finance_charts.dart';
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

/// The Granary: Today (quick log + gauge) and Insights (charts).
class GranaryScreen extends ConsumerWidget {
  const GranaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.granaryTitle),
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.todayTab),
              Tab(text: l10n.insightsTab),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => unawaited(showExpenseSheet(context)),
          icon: const Icon(Icons.add),
          label: Text(l10n.logExpense),
        ),
        body: const TabBarView(
          children: [_TodayTab(), InsightsTab()],
        ),
      ),
    );
  }
}

class _TodayTab extends ConsumerWidget {
  const _TodayTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final snapshot = ref.watch(budgetSnapshotProvider);
    final settings = ref.watch(financeSettingsProvider).value;
    final defaultCurrency = settings?.defaultCurrency ?? Currency.dzd;
    final ratesValue = ref.watch(ratesProvider).value ??
        Rates(defaultCurrency: defaultCurrency);
    final expenses = ref.watch(todayExpensesProvider).value ?? const [];
    final suggestion = ref.watch(repeatSuggestionProvider).value;
    final customs = ref.watch(customCategoriesProvider).value ?? const [];
    final health = ref.watch(savingsHealthProvider);
    final savings = settings?.savings ?? const <Currency, int>{};

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        HarvestSpacing.md,
        HarvestSpacing.sm,
        HarvestSpacing.md,
        120,
      ),
      children: [
        _BudgetCard(
          snapshot: snapshot,
          symbol: defaultCurrency.symbol,
          l10n: l10n,
        ),
        // One savings card per currency (checkpoint P4).
        for (final entry in savings.entries)
          if (entry.value > 0)
            Padding(
              padding: const EdgeInsets.only(top: HarvestSpacing.sm),
              child: _SavingsCard(
                currency: entry.key,
                minor: entry.value,
                rates: ratesValue,
                health: health,
              ),
            ),
        if (suggestion != null) ...[
          const SizedBox(height: HarvestSpacing.md),
          _RepeatCard(suggestion: suggestion, rates: ratesValue),
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
                    categoryIcon(expense.category, customs: customs),
                    color: theme.colorScheme.secondary,
                  ),
                ),
                title: Text(
                  amountWithConversion(
                    minor: expense.amountMinor,
                    currency: expense.currency,
                    rates: ratesValue,
                  ),
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
    );
  }
}

class _SavingsCard extends StatelessWidget {
  const _SavingsCard({
    required this.currency,
    required this.minor,
    required this.rates,
    required this.health,
  });

  final Currency currency;
  final int minor;
  final Rates rates;
  final SavingsHealth health;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final low = health == SavingsHealth.low;
    final color = low ? theme.colorScheme.error : theme.colorScheme.secondary;

    return Card(
      margin: EdgeInsets.zero,
      color: low ? theme.colorScheme.error.withValues(alpha: 0.12) : null,
      child: ListTile(
        leading: Icon(Icons.savings_outlined, color: color),
        title: Text(
          amountWithConversion(
            minor: minor,
            currency: currency,
            rates: rates,
          ),
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w800, color: color),
        ),
        subtitle: Text(
          low ? l10n.savingsLow : l10n.savingsIn(currency.code),
        ),
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
                    icon: Icons.payments,
                    onPressed: () => unawaited(showBudgetSheet(context)),
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
                      Icons.payments,
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
                    onPressed: () => unawaited(showBudgetSheet(context)),
                  ),
                ],
              ),
      ),
    );
  }
}

Future<void> showBudgetSheet(BuildContext context) =>
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
  final _expectedController = TextEditingController();
  final Map<Currency, TextEditingController> _savingsControllers = {
    for (final currency in Currency.values) currency: TextEditingController(),
  };
  Currency _defaultCurrency = Currency.dzd;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(financeSettingsProvider).value;
    if (settings == null) return;
    _defaultCurrency = settings.defaultCurrency;
    if (settings.budgetMinor != null) {
      _amountController.text = formatMinor(settings.budgetMinor!);
    }
    if (settings.expectedDailyMinor != null) {
      _expectedController.text = formatMinor(settings.expectedDailyMinor!);
    }
    settings.savings.forEach((currency, minor) {
      _savingsControllers[currency]!.text = formatMinor(minor);
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _expectedController.dispose();
    for (final controller in _savingsControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final minor = parseToMinor(_amountController.text);
    if (minor == null) return;
    final expected = parseToMinor(_expectedController.text);
    Navigator.of(context).pop();
    final notifier = ref.read(financeSettingsProvider.notifier);
    await notifier.setBudget(minor);
    await notifier.setDefaultCurrency(_defaultCurrency);
    if (expected != null) await notifier.setExpectedDaily(expected);
    for (final entry in _savingsControllers.entries) {
      final value = parseToMinor(entry.value.text);
      if (value != null || entry.value.text.trim().isEmpty) {
        await notifier.setSavings(entry.key, value ?? 0);
      }
    }
  }

  InputDecoration _decoration(String label) => InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(HarvestRadii.button),
        ),
      );

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
      child: SingleChildScrollView(
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
              decoration: _decoration(l10n.budgetAmountLabel),
            ),
            const SizedBox(height: HarvestSpacing.md),
            Text(l10n.defaultCurrencyLabel),
            const SizedBox(height: HarvestSpacing.xs),
            SegmentedButton<Currency>(
              segments: [
                for (final currency in Currency.values)
                  ButtonSegment(
                    value: currency,
                    label: Text(currency.symbol),
                  ),
              ],
              selected: {_defaultCurrency},
              onSelectionChanged: (selection) =>
                  setState(() => _defaultCurrency = selection.first),
            ),
            const SizedBox(height: HarvestSpacing.md),
            TextField(
              controller: _expectedController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: _decoration(l10n.expectedDailyLabel),
            ),
            const SizedBox(height: HarvestSpacing.md),
            // One savings pot per currency (checkpoint P4).
            for (final currency in Currency.values) ...[
              TextField(
                controller: _savingsControllers[currency],
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: _decoration(
                  '${l10n.savingsLabel} (${currency.code})',
                ),
              ),
              const SizedBox(height: HarvestSpacing.sm),
            ],
            const SizedBox(height: HarvestSpacing.xs),
            const _ManageCategories(),
            const SizedBox(height: HarvestSpacing.md),
            BigBouncySheetButton(
              onPressed: parseToMinor(_amountController.text) == null
                  ? null
                  : () => unawaited(_save()),
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
  }
}

class _RepeatCard extends ConsumerWidget {
  const _RepeatCard({required this.suggestion, required this.rates});

  final RepeatSuggestion suggestion;
  final Rates rates;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final customs = ref.watch(customCategoriesProvider).value ?? const [];

    return Card(
      color: theme.colorScheme.secondary.withValues(alpha: 0.15),
      child: ListTile(
        leading: Icon(
          categoryIcon(suggestion.category, customs: customs),
          color: theme.colorScheme.secondary,
        ),
        title: Text(
          '${rates.defaultCurrency.symbol}'
          '${formatMinor(suggestion.amountMinor)} · '
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
                  currency: rates.defaultCurrency,
                  note: suggestion.note,
                );
            await ref.read(notificationPlannerProvider).reevaluate();
          },
          child: Text(l10n.logIt),
        ),
      ),
    );
  }
}

/// Custom category list with delete — finance settings (gap G8).
class _ManageCategories extends ConsumerWidget {
  const _ManageCategories();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final customs = ref.watch(customCategoriesProvider).value ?? const [];
    if (customs.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.manageCategories,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: HarvestSpacing.xs),
        Wrap(
          spacing: HarvestSpacing.xs,
          runSpacing: HarvestSpacing.xs,
          children: [
            for (final category in customs)
              InputChip(
                avatar: Icon(
                  categoryIconRegistry[category.icon] ?? Icons.category,
                  size: 18,
                ),
                label: Text(category.name),
                onDeleted: () => unawaited(
                  ref
                      .read(financesRepositoryProvider)
                      .deleteCategory(category.uuid),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

// The charts tab lives in finance_charts.dart.
class InsightsTab extends StatelessWidget {
  const InsightsTab({super.key});

  @override
  Widget build(BuildContext context) => const FinanceInsights();
}
