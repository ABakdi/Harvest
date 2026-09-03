import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/core/ui/widgets/big_bouncy_button.dart';
import 'package:harvest/core/ui/widgets/empty_state.dart';
import 'package:harvest/core/ui/widgets/gauge_ring.dart';
import 'package:harvest/core/ui/widgets/harvest_fab.dart';
import 'package:harvest/core/ui/widgets/hero_card.dart';
import 'package:harvest/core/ui/widgets/icon_badge.dart';
import 'package:harvest/core/ui/widgets/ledger_row.dart';
import 'package:harvest/core/ui/widgets/section_header.dart';
import 'package:harvest/features/finances/data/finances_repository.dart';
import 'package:harvest/features/finances/domain/currency.dart';
import 'package:harvest/features/finances/domain/expense.dart';
import 'package:harvest/features/finances/presentation/budget_colors.dart';
import 'package:harvest/features/finances/presentation/expense_sheet.dart';
import 'package:harvest/features/finances/presentation/finance_charts.dart';
import 'package:harvest/features/finances/presentation/finance_providers.dart';
import 'package:harvest/features/finances/presentation/money.dart';
import 'package:harvest/features/finances/presentation/vault_tab.dart';
import 'package:harvest/features/planner/domain/notification_planner.dart';
import 'package:harvest/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

/// The Granary: Today (gauge + quick log), Vault (wallet, savings,
/// debts) and Insights (charts). The expense action floats on Today
/// only — the vault carries its own actions.
class GranaryScreen extends StatefulWidget {
  const GranaryScreen({super.key});

  @override
  State<GranaryScreen> createState() => _GranaryScreenState();
}

class _GranaryScreenState extends State<GranaryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this)
    ..addListener(() => setState(() {}));

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final showFab = _tabs.index == 0 && !_tabs.indexIsChanging;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.granaryTitle),
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: l10n.todayTab),
            Tab(text: l10n.vaultTab),
            Tab(text: l10n.insightsTab),
          ],
        ),
      ),
      floatingActionButton: AnimatedScale(
        scale: showFab ? 1 : 0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutBack,
        child: HarvestFab(
          onPressed: () => unawaited(showExpenseSheet(context)),
          label: l10n.logExpense,
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [_TodayTab(), VaultTab(), InsightsTab()],
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
    final ratesValue =
        ref.watch(ratesProvider).value ??
        Rates(defaultCurrency: defaultCurrency);
    final expenses = ref.watch(todayExpensesProvider).value ?? const [];
    final suggestion = ref.watch(repeatSuggestionProvider).value;
    final customs = ref.watch(customCategoriesProvider).value ?? const [];

    var todayTotal = 0;
    for (final expense in expenses) {
      todayTotal +=
          ratesValue.toDefault(expense.amountMinor, expense.currency) ??
          expense.amountMinor;
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        HarvestSpacing.md,
        HarvestSpacing.sm,
        HarvestSpacing.md,
        120,
      ),
      children: [
        _BudgetCard(snapshot: snapshot, currency: defaultCurrency),
        if (suggestion != null) ...[
          const SizedBox(height: HarvestSpacing.md),
          _RepeatCard(suggestion: suggestion, rates: ratesValue),
        ],
        SectionHeader(
          l10n.todaySpending,
          subtitle: l10n.expensesToday(expenses.length),
          trailing: expenses.isEmpty
              ? null
              : Text(
                  formatAmount(todayTotal, defaultCurrency),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.primary,
                  ),
                ),
        ),
        if (expenses.isEmpty)
          Card(
            child: EmptyState(
              icon: Icons.receipt_long_outlined,
              title: l10n.granaryEmpty,
              body: l10n.notifExpenseBody,
              compact: true,
            ),
          )
        else
          Card(
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: HarvestSpacing.sm,
                vertical: HarvestSpacing.xs,
              ),
              child: Column(
                children: [
                  for (final expense in expenses)
                    _ExpenseRow(
                      expense: expense,
                      rates: ratesValue,
                      customs: customs,
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _ExpenseRow extends ConsumerWidget {
  const _ExpenseRow({
    required this.expense,
    required this.rates,
    required this.customs,
  });

  final Expense expense;
  final Rates rates;
  final List<CustomCategory> customs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toString();

    return Dismissible(
      key: ValueKey(expense.uuid),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsetsDirectional.only(end: HarvestSpacing.md),
        decoration: BoxDecoration(
          color: scheme.error.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(HarvestRadii.button),
        ),
        child: Icon(Icons.delete_outline, color: scheme.error),
      ),
      onDismissed: (_) {
        unawaited(ref.read(financesRepositoryProvider).remove(expense.uuid));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.deleted),
            duration: const Duration(seconds: 1),
          ),
        );
      },
      child: LedgerRow(
        icon: categoryIcon(expense.category, customs: customs),
        color: scheme.secondary,
        title: categoryLabel(l10n, expense.category),
        subtitle: expense.note == null || expense.note!.isEmpty
            ? DateFormat.jm(locale).format(expense.loggedAt)
            : expense.note,
        amount: formatSigned(-expense.amountMinor, expense.currency),
        caption: conversionCaption(
          minor: expense.amountMinor,
          currency: expense.currency,
          rates: rates,
        ),
        onTap: () => unawaited(showExpenseSheet(context, existing: expense)),
      ),
    );
  }
}

class _BudgetCard extends ConsumerWidget {
  const _BudgetCard({required this.snapshot, required this.currency});

  final BudgetSnapshot? snapshot;
  final Currency currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final snap = snapshot;

    if (snap == null) {
      return Card(
        child: EmptyState(
          icon: Icons.payments,
          title: l10n.budgetTitle,
          color: scheme.primary,
          compact: true,
          action: BigBouncyButton(
            icon: Icons.payments,
            onPressed: () => unawaited(showBudgetSheet(context)),
            child: Text(l10n.budgetSet),
          ),
        ),
      );
    }

    final color = budgetColor(scheme, snap.status);
    final leftToday = snap.floatingDailyLimit - snap.spentToday;
    final leftMonth = snap.monthlyBudget - snap.spentThisMonth;
    final monthProgress = snap.monthlyBudget == 0
        ? 1.0
        : (snap.spentThisMonth / snap.monthlyBudget).clamp(0.0, 1.0);

    return HeroCard(
      tint: color,
      padding: const EdgeInsets.all(HarvestSpacing.md),
      onTap: () => unawaited(showBudgetSheet(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GaugeRing(
                progress: snap.floatingDailyLimit == 0
                    ? 1
                    : snap.spentToday / snap.floatingDailyLimit,
                color: color,
                size: 92,
                strokeWidth: 9,
                child: Icon(Icons.payments, size: 28, color: color),
              ),
              const SizedBox(width: HarvestSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Eyebrow(l10n.budgetSpentToday, color: color),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        formatAmount(snap.spentToday, currency),
                        style: theme.textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: color,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    Text(
                      '${l10n.budgetDailyLimit} · '
                      '${formatAmount(snap.floatingDailyLimit, currency)}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    Text(
                      leftToday >= 0
                          ? l10n.budgetLeftToday(
                              formatAmount(leftToday, currency),
                            )
                          : l10n.budgetOverToday(
                              formatAmount(-leftToday, currency),
                            ),
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.tune,
                color: scheme.onSurface.withValues(alpha: 0.4),
              ),
            ],
          ),
          const SizedBox(height: HarvestSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(HarvestRadii.chip),
            child: LinearProgressIndicator(
              value: monthProgress,
              minHeight: 8,
              backgroundColor: scheme.onSurface.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: HarvestSpacing.xs + 2),
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.budgetSpentOf(
                    formatAmount(snap.spentThisMonth, currency),
                    formatAmount(snap.monthlyBudget, currency),
                  ),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.65),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                leftMonth >= 0
                    ? l10n.budgetLeftMonth(formatAmount(leftMonth, currency))
                    : l10n.budgetOverMonth(formatAmount(-leftMonth, currency)),
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: leftMonth >= 0 ? scheme.onSurface : scheme.error,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Future<void> showBudgetSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
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
  }

  @override
  void dispose() {
    _amountController.dispose();
    _expectedController.dispose();
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
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: HarvestSpacing.lg,
        right: HarvestSpacing.lg,
        bottom: MediaQuery.viewInsetsOf(context).bottom + HarvestSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.budgetTitle,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: HarvestSpacing.md),
            TextField(
              controller: _amountController,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) => setState(() {}),
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
              decoration: InputDecoration(
                labelText: l10n.budgetAmountLabel,
                prefixText: '${_defaultCurrency.symbol} ',
              ),
            ),
            const SizedBox(height: HarvestSpacing.md),
            Text(
              l10n.defaultCurrencyLabel,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
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
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(labelText: l10n.expectedDailyLabel),
            ),
            const SizedBox(height: HarvestSpacing.md),
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
    final scheme = theme.colorScheme;
    final customs = ref.watch(customCategoriesProvider).value ?? const [];

    return HeroCard(
      tint: scheme.secondary,
      padding: const EdgeInsets.all(HarvestSpacing.md),
      child: Row(
        children: [
          IconBadge(
            categoryIcon(suggestion.category, customs: customs),
            color: scheme.secondary,
          ),
          const SizedBox(width: HarvestSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${amountWithConversion(
                    minor: suggestion.amountMinor,
                    currency: suggestion.currency,
                    rates: rates,
                  )} · ${categoryLabel(l10n, suggestion.category)}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  l10n.repeatSuggestionTitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: HarvestSpacing.sm),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(64, 44),
              backgroundColor: scheme.secondary,
            ),
            onPressed: () async {
              await ref
                  .read(financesRepositoryProvider)
                  .log(
                    amountMinor: suggestion.amountMinor,
                    category: suggestion.category,
                    currency: suggestion.currency,
                    note: suggestion.note,
                  );
              await ref.read(notificationPlannerProvider).reevaluate();
            },
            child: Text(l10n.logIt),
          ),
        ],
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
          style: Theme.of(context).textTheme.labelLarge
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
