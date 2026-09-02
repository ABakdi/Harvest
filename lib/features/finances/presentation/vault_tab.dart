import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/platform/haptics.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/core/ui/widgets/empty_state.dart';
import 'package:harvest/core/ui/widgets/hero_card.dart';
import 'package:harvest/core/ui/widgets/icon_badge.dart';
import 'package:harvest/core/ui/widgets/ledger_row.dart';
import 'package:harvest/core/ui/widgets/section_header.dart';
import 'package:harvest/core/ui/widgets/stat_tile.dart';
import 'package:harvest/features/finances/data/finances_repository.dart';
import 'package:harvest/features/finances/data/vault_repository.dart';
import 'package:harvest/features/finances/domain/currency.dart';
import 'package:harvest/features/finances/domain/expense.dart';
import 'package:harvest/features/finances/domain/vault.dart';
import 'package:harvest/features/finances/presentation/choice_sheet.dart';
import 'package:harvest/features/finances/presentation/debt_sheet.dart';
import 'package:harvest/features/finances/presentation/expense_sheet.dart';
import 'package:harvest/features/finances/presentation/finance_providers.dart';
import 'package:harvest/features/finances/presentation/money.dart';
import 'package:harvest/features/finances/presentation/money_sheet.dart';
import 'package:harvest/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

export 'package:harvest/features/finances/presentation/debt_sheet.dart'
    show showDebtSheet;

/// The three pots of the vault (round 4: one clear section each).
enum VaultSection { wallet, savings, debts }

/// The vault: wallet (meant to be spent), savings (meant to be saved),
/// and debts — each section with its total and its own atomic moves.
class VaultTab extends ConsumerStatefulWidget {
  const VaultTab({super.key});

  @override
  ConsumerState<VaultTab> createState() => _VaultTabState();
}

class _VaultTabState extends ConsumerState<VaultTab> {
  VaultSection _section = VaultSection.wallet;

  void _select(VaultSection section) {
    if (section == _section) return;
    unawaited(HarvestHaptics.tick());
    setState(() => _section = section);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final totals = ref.watch(vaultTotalsProvider);
    final health = ref.watch(savingsHealthProvider);
    final defaultCurrency =
        ref.watch(financeSettingsProvider).value?.defaultCurrency ??
        Currency.dzd;
    final savingsColor = health == SavingsHealth.low
        ? scheme.error
        : scheme.secondary;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        HarvestSpacing.md,
        HarvestSpacing.sm,
        HarvestSpacing.md,
        HarvestSpacing.xl,
      ),
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: StatTile(
                  icon: Icons.account_balance_wallet,
                  color: scheme.primary,
                  label: l10n.walletTitle,
                  value: formatAmount(totals.wallet, defaultCurrency),
                  selected: _section == VaultSection.wallet,
                  onTap: () => _select(VaultSection.wallet),
                ),
              ),
              const SizedBox(width: HarvestSpacing.sm),
              Expanded(
                child: StatTile(
                  icon: Icons.savings,
                  color: savingsColor,
                  label: l10n.savingsSectionTitle,
                  value: formatAmount(totals.savings, defaultCurrency),
                  selected: _section == VaultSection.savings,
                  onTap: () => _select(VaultSection.savings),
                ),
              ),
              const SizedBox(width: HarvestSpacing.sm),
              Expanded(
                child: StatTile(
                  icon: Icons.handshake,
                  color: scheme.tertiary,
                  label: l10n.vaultOwed,
                  value: formatAmount(totals.owed, defaultCurrency),
                  selected: _section == VaultSection.debts,
                  onTap: () => _select(VaultSection.debts),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: HarvestSpacing.md),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0, 0.02),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.topCenter,
            children: [...previous, ?current],
          ),
          child: KeyedSubtree(
            key: ValueKey(_section),
            child: switch (_section) {
              VaultSection.wallet => const _WalletSection(),
              VaultSection.savings => const _SavingsSection(),
              VaultSection.debts => const _DebtsSection(),
            },
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------ wallet

class _WalletSection extends ConsumerWidget {
  const _WalletSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final balances = ref.watch(accountBalancesProvider(MoneyAccount.wallet));
    final txns =
        ref.watch(accountTxnsProvider(MoneyAccount.wallet)).value ?? const [];
    final rates =
        ref.watch(ratesProvider).value ??
        const Rates(defaultCurrency: Currency.dzd);
    final defaultCurrency =
        ref.watch(financeSettingsProvider).value?.defaultCurrency ??
        Currency.dzd;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HeroCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const IconBadge(
                    Icons.account_balance_wallet,
                    color: Colors.white,
                    size: 36,
                    iconSize: 20,
                  ),
                  const SizedBox(width: HarvestSpacing.sm),
                  Eyebrow(l10n.walletTitle),
                ],
              ),
              const SizedBox(height: HarvestSpacing.md),
              _Balances(
                balances: balances,
                rates: rates,
                defaultCurrency: defaultCurrency,
              ),
              const SizedBox(height: HarvestSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: _HeroAction(
                      icon: Icons.add,
                      label: l10n.walletAdd,
                      onTap: () => unawaited(
                        _walletMove(
                          context,
                          ref,
                          deposit: true,
                          currency: defaultCurrency,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: HarvestSpacing.sm),
                  Expanded(
                    child: _HeroAction(
                      icon: Icons.remove,
                      label: l10n.walletTake,
                      onTap: () => unawaited(
                        _walletMove(
                          context,
                          ref,
                          deposit: false,
                          currency: defaultCurrency,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        SectionHeader(l10n.movesTitle),
        _Ledger(
          txns: txns,
          rates: rates,
          emptyTitle: l10n.noMovesYet,
          emptyIcon: Icons.account_balance_wallet_outlined,
          color: theme.colorScheme.primary,
        ),
      ],
    );
  }

  Future<void> _walletMove(
    BuildContext context,
    WidgetRef ref, {
    required bool deposit,
    required Currency currency,
  }) async {
    final l10n = AppLocalizations.of(context);
    final entry = await showMoneySheet(
      context,
      title: deposit ? l10n.walletAdd : l10n.walletTake,
      subtitle: l10n.walletTitle,
      initialCurrency: currency,
    );
    if (entry == null) return;
    await ref
        .read(vaultRepositoryProvider)
        .move(
          account: MoneyAccount.wallet,
          deltaMinor: deposit ? entry.minor : -entry.minor,
          currency: entry.currency,
          note: entry.note,
        );
    unawaited(HarvestHaptics.thud());
  }
}

// ----------------------------------------------------------------- savings

class _SavingsSection extends ConsumerWidget {
  const _SavingsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final balances = ref.watch(accountBalancesProvider(MoneyAccount.savings));
    final txns =
        ref.watch(accountTxnsProvider(MoneyAccount.savings)).value ?? const [];
    final rates =
        ref.watch(ratesProvider).value ??
        const Rates(defaultCurrency: Currency.dzd);
    final defaultCurrency =
        ref.watch(financeSettingsProvider).value?.defaultCurrency ??
        Currency.dzd;
    final low = ref.watch(savingsHealthProvider) == SavingsHealth.low;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HeroCard(
          tint: low ? scheme.error : scheme.secondary,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconBadge(
                    Icons.savings,
                    color: low ? scheme.error : scheme.secondary,
                    size: 36,
                    iconSize: 20,
                  ),
                  const SizedBox(width: HarvestSpacing.sm),
                  Eyebrow(l10n.savingsSectionTitle),
                  if (low) ...[
                    const Spacer(),
                    Icon(Icons.warning_amber_rounded, color: scheme.error),
                    const SizedBox(width: HarvestSpacing.xs),
                    Text(
                      l10n.savingsLow,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: scheme.error,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: HarvestSpacing.md),
              _Balances(
                balances: balances,
                rates: rates,
                defaultCurrency: defaultCurrency,
              ),
              const SizedBox(height: HarvestSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: _HeroAction(
                      icon: Icons.add,
                      label: l10n.savingsDeposit,
                      color: low ? scheme.error : scheme.secondary,
                      onTap: () => unawaited(
                        _deposit(context, ref, currency: defaultCurrency),
                      ),
                    ),
                  ),
                  const SizedBox(width: HarvestSpacing.sm),
                  Expanded(
                    child: _HeroAction(
                      icon: Icons.remove,
                      label: l10n.savingsWithdraw,
                      color: low ? scheme.error : scheme.secondary,
                      onTap: balances.isEmpty
                          ? null
                          : () => unawaited(
                              _withdraw(context, ref, balances: balances),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        SectionHeader(l10n.movesTitle),
        _Ledger(
          txns: txns,
          rates: rates,
          emptyTitle: l10n.noMovesYet,
          emptyIcon: Icons.savings_outlined,
          color: scheme.secondary,
        ),
      ],
    );
  }

  /// A deposit comes from the wallet (transfer) or from new money.
  Future<void> _deposit(
    BuildContext context,
    WidgetRef ref, {
    required Currency currency,
  }) async {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final entry = await showMoneySheet(
      context,
      title: l10n.savingsDeposit,
      subtitle: l10n.savingsSectionTitle,
      initialCurrency: currency,
      accent: scheme.secondary,
    );
    if (entry == null || !context.mounted) return;

    final walletBalance =
        ref.read(
          accountBalancesProvider(MoneyAccount.wallet),
        )[entry.currency] ??
        0;
    final source = await showChoiceSheet<String>(
      context,
      title: l10n.depositSource,
      options: [
        ChoiceOption(
          value: 'wallet',
          icon: Icons.account_balance_wallet,
          label: l10n.fromWalletOption,
          hint: formatAmount(walletBalance, entry.currency),
          color: scheme.primary,
        ),
        ChoiceOption(
          value: 'new',
          icon: Icons.add_circle,
          label: l10n.newMoneyOption,
          color: scheme.secondary,
        ),
      ],
    );
    if (source == null) return;

    final vault = ref.read(vaultRepositoryProvider);
    if (source == 'wallet') {
      await vault.transferWalletToSavings(
        amountMinor: entry.minor,
        currency: entry.currency,
        note: entry.note,
      );
    } else {
      await vault.move(
        account: MoneyAccount.savings,
        deltaMinor: entry.minor,
        currency: entry.currency,
        note: entry.note,
      );
    }
    unawaited(HarvestHaptics.thud());
  }

  /// A withdrawal always lands somewhere: the wallet or an expense.
  Future<void> _withdraw(
    BuildContext context,
    WidgetRef ref, {
    required Map<Currency, int> balances,
  }) async {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final entry = await showMoneySheet(
      context,
      title: l10n.savingsWithdraw,
      subtitle: l10n.savingsSectionTitle,
      initialCurrency: balances.keys.first,
      lockCurrency: balances.length == 1,
      maxMinor: balances,
      accent: scheme.secondary,
    );
    if (entry == null || !context.mounted) return;

    final destination = await showChoiceSheet<String>(
      context,
      title: l10n.withdrawDestination,
      options: [
        ChoiceOption(
          value: 'wallet',
          icon: Icons.account_balance_wallet,
          label: l10n.toWallet,
          color: scheme.primary,
        ),
        ChoiceOption(
          value: 'expense',
          icon: Icons.receipt_long,
          label: l10n.asExpense,
          color: scheme.tertiary,
        ),
      ],
    );
    if (destination == null) return;

    final vault = ref.read(vaultRepositoryProvider);
    if (destination == 'wallet') {
      await vault.transferSavingsToWallet(
        amountMinor: entry.minor,
        currency: entry.currency,
        note: entry.note,
      );
    } else {
      await vault.move(
        account: MoneyAccount.savings,
        deltaMinor: -entry.minor,
        currency: entry.currency,
        kind: TxnKind.expense,
        reference: ExpenseCategory.other.name,
        note: entry.note,
      );
      await ref
          .read(financesRepositoryProvider)
          .log(
            amountMinor: entry.minor,
            category: ExpenseCategory.other.name,
            currency: entry.currency,
            note: entry.note,
          );
    }
    unawaited(HarvestHaptics.thud());
  }
}

// ------------------------------------------------------------------- debts

class _DebtsSection extends ConsumerStatefulWidget {
  const _DebtsSection();

  @override
  ConsumerState<_DebtsSection> createState() => _DebtsSectionState();
}

class _DebtsSectionState extends ConsumerState<_DebtsSection> {
  final _expanded = <String>{};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final debts = ref.watch(debtsProvider).value ?? const <Debt>[];
    final payments =
        ref.watch(debtPaymentsProvider).value ?? const <DebtPayment>[];
    final rates =
        ref.watch(ratesProvider).value ??
        const Rates(defaultCurrency: Currency.dzd);
    final defaultCurrency =
        ref.watch(financeSettingsProvider).value?.defaultCurrency ??
        Currency.dzd;

    final open = debts.where((d) => !d.isSettled).toList();
    final settled = debts.where((d) => d.isSettled).toList();
    final owed = <Currency, int>{};
    for (final debt in open) {
      owed.update(
        debt.currency,
        (v) => v + debt.remainingMinor,
        ifAbsent: () => debt.remainingMinor,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HeroCard(
          tint: scheme.tertiary,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconBadge(
                    Icons.handshake,
                    color: scheme.tertiary,
                    size: 36,
                    iconSize: 20,
                  ),
                  const SizedBox(width: HarvestSpacing.sm),
                  Eyebrow(l10n.vaultOwed),
                  const Spacer(),
                  Text(
                    l10n.vaultOpenDebts(open.length),
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: HarvestSpacing.md),
              _Balances(
                balances: owed,
                rates: rates,
                defaultCurrency: defaultCurrency,
              ),
              const SizedBox(height: HarvestSpacing.md),
              _HeroAction(
                icon: Icons.add,
                label: l10n.addDebt,
                color: scheme.tertiary,
                onTap: () => unawaited(showDebtSheet(context)),
              ),
            ],
          ),
        ),
        if (debts.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: HarvestSpacing.md),
            child: Card(
              child: EmptyState(
                icon: Icons.handshake_outlined,
                title: l10n.debtsEmptyTitle,
                body: l10n.debtsEmptyBody,
                color: scheme.tertiary,
                compact: true,
              ),
            ),
          ),
        if (open.isNotEmpty) ...[
          SectionHeader(l10n.debtOpen),
          for (final debt in open)
            Padding(
              padding: const EdgeInsets.only(bottom: HarvestSpacing.sm + 4),
              child: _DebtCard(
                debt: debt,
                payments: payments
                    .where((p) => p.debtUuid == debt.uuid)
                    .toList(),
                expanded: _expanded.contains(debt.uuid),
                onToggle: () => setState(() {
                  if (!_expanded.remove(debt.uuid)) _expanded.add(debt.uuid);
                }),
                onPay: () => unawaited(_pay(context, debt)),
              ),
            ),
        ],
        if (settled.isNotEmpty) ...[
          SectionHeader(l10n.debtSettledSection),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: HarvestSpacing.sm,
                vertical: HarvestSpacing.xs,
              ),
              child: Column(
                children: [
                  for (final debt in settled)
                    LedgerRow(
                      icon: Icons.check_circle,
                      color: scheme.secondary,
                      title: debt.person,
                      subtitle: l10n.debtSettled,
                      amount: formatAmount(debt.amountMinor, debt.currency),
                      amountColor: scheme.onSurface.withValues(alpha: 0.55),
                    ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _pay(BuildContext context, Debt debt) async {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final entry = await showMoneySheet(
      context,
      title: l10n.debtPay,
      subtitle: debt.person,
      initialCurrency: debt.currency,
      lockCurrency: true,
      initialAmountMinor: debt.remainingMinor,
      maxMinor: {debt.currency: debt.remainingMinor},
      accent: scheme.tertiary,
    );
    if (entry == null || !context.mounted) return;

    final walletBalance =
        ref.read(accountBalancesProvider(MoneyAccount.wallet))[debt.currency] ??
        0;
    final fromWallet = await showChoiceSheet<bool>(
      context,
      title: l10n.payFromWallet,
      options: [
        ChoiceOption(
          value: true,
          icon: Icons.account_balance_wallet,
          label: l10n.walletYes,
          hint: formatAmount(walletBalance, debt.currency),
          color: scheme.primary,
        ),
        ChoiceOption(
          value: false,
          icon: Icons.receipt_long,
          label: l10n.walletNo,
          color: scheme.tertiary,
        ),
      ],
    );
    if (fromWallet == null) return;
    await ref
        .read(vaultRepositoryProvider)
        .payDebt(
          debt.uuid,
          entry.minor,
          fromWallet: fromWallet,
          note: entry.note,
        );
    unawaited(HarvestHaptics.thud());
  }
}

class _DebtCard extends StatelessWidget {
  const _DebtCard({
    required this.debt,
    required this.payments,
    required this.expanded,
    required this.onToggle,
    required this.onPay,
  });

  final Debt debt;
  final List<DebtPayment> payments;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final locale = Localizations.localeOf(context).toString();
    final payOffBy = debt.payOffBy;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(HarvestSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconBadge(Icons.handshake, color: scheme.tertiary),
                const SizedBox(width: HarvestSpacing.sm + 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        debt.person,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (payOffBy != null || debt.note != null)
                        Text(
                          [
                            if (payOffBy != null)
                              '${l10n.debtPayOffBy} ${DateFormat.MMMd(locale).format(
                                DateTime(payOffBy.year, payOffBy.month, payOffBy.day),
                              )}',
                            if (debt.note != null) debt.note!,
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: HarvestSpacing.sm),
                Text(
                  formatAmount(debt.remainingMinor, debt.currency),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: scheme.tertiary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: HarvestSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(HarvestRadii.chip),
              child: LinearProgressIndicator(
                value: debt.paidFraction,
                minHeight: 8,
                backgroundColor: scheme.onSurface.withValues(alpha: 0.08),
                valueColor: AlwaysStoppedAnimation(scheme.secondary),
              ),
            ),
            const SizedBox(height: HarvestSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.debtPaidOf(
                      formatAmount(debt.paidMinor, debt.currency),
                      formatAmount(debt.amountMinor, debt.currency),
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.65),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (payments.isNotEmpty)
                  TextButton.icon(
                    onPressed: onToggle,
                    icon: Icon(
                      expanded ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                    ),
                    label: Text('${l10n.debtPayments} · ${payments.length}'),
                  ),
                const SizedBox(width: HarvestSpacing.xs),
                FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(64, 40),
                    backgroundColor: scheme.tertiary.withValues(alpha: 0.2),
                    foregroundColor: scheme.onSurface,
                  ),
                  onPressed: onPay,
                  child: Text(l10n.debtPay),
                ),
              ],
            ),
            if (expanded && payments.isNotEmpty) ...[
              const Divider(height: HarvestSpacing.md),
              for (final payment in payments)
                LedgerRow(
                  icon: Icons.payments,
                  color: scheme.secondary,
                  title: dayLabel(context, payment.day),
                  subtitle: DateFormat.jm(locale).format(payment.loggedAt),
                  amount: formatSigned(-payment.amountMinor, debt.currency),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------- shared bits

/// Per-currency balances inside a hero card: the default currency big,
/// the rest with their converted caption.
class _Balances extends StatelessWidget {
  const _Balances({
    required this.balances,
    required this.rates,
    required this.defaultCurrency,
  });

  final Map<Currency, int> balances;
  final Rates rates;
  final Currency defaultCurrency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = balances.entries.toList()
      ..sort((a, b) {
        if (a.key == defaultCurrency) return -1;
        if (b.key == defaultCurrency) return 1;
        return a.key.index.compareTo(b.key.index);
      });
    if (entries.isEmpty) {
      return Text(
        formatAmount(0, defaultCurrency),
        style: theme.textTheme.displaySmall?.copyWith(
          fontWeight: FontWeight.w800,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < entries.length; i++)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : HarvestSpacing.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  formatAmount(entries[i].value, entries[i].key),
                  style:
                      (i == 0
                              ? theme.textTheme.displaySmall
                              : theme.textTheme.titleLarge)
                          ?.copyWith(
                            fontWeight: FontWeight.w800,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                ),
                if (conversionCaption(
                      minor: entries[i].value,
                      currency: entries[i].key,
                      rates: rates,
                    )
                    case final caption?) ...[
                  const SizedBox(width: HarvestSpacing.sm),
                  Opacity(
                    opacity: 0.8,
                    child: Text(
                      caption,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

/// A translucent pill button living on a hero card.
class _HeroAction extends StatelessWidget {
  const _HeroAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  /// Foreground on tinted cards; white on gradients when null.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = color ?? Colors.white;
    return Opacity(
      opacity: onTap == null ? 0.45 : 1,
      child: Material(
        color: foreground.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(HarvestRadii.button),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap == null
              ? null
              : () {
                  unawaited(HarvestHaptics.tick());
                  onTap!();
                },
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: HarvestSpacing.md,
              vertical: HarvestSpacing.sm + 4,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20, color: foreground),
                const SizedBox(width: HarvestSpacing.xs + 2),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: foreground,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One pot's ledger, grouped by day, inside a card.
class _Ledger extends ConsumerWidget {
  const _Ledger({
    required this.txns,
    required this.rates,
    required this.emptyTitle,
    required this.emptyIcon,
    required this.color,
  });

  final List<MoneyTxn> txns;
  final Rates rates;
  final String emptyTitle;
  final IconData emptyIcon;
  final Color color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customs = ref.watch(customCategoriesProvider).value ?? const [];
    if (txns.isEmpty) {
      return Card(
        child: EmptyState(
          icon: emptyIcon,
          title: emptyTitle,
          color: color,
          compact: true,
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          HarvestSpacing.sm,
          0,
          HarvestSpacing.sm,
          HarvestSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: groupByDay<MoneyTxn>(
            items: txns,
            dayOf: (txn) => txn.day,
            rowOf: (txn) => _TxnRow(txn: txn, rates: rates, customs: customs),
          ),
        ),
      ),
    );
  }
}

class _TxnRow extends StatelessWidget {
  const _TxnRow({
    required this.txn,
    required this.rates,
    required this.customs,
  });

  final MoneyTxn txn;
  final Rates rates;
  final List<CustomCategory> customs;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toString();
    final deposit = txn.isDeposit;
    final wallet = txn.account == MoneyAccount.wallet;

    final (IconData icon, Color color, String title) = switch (txn.kind) {
      TxnKind.manual => (
        deposit ? Icons.add_circle : Icons.remove_circle,
        deposit ? scheme.secondary : scheme.onSurface.withValues(alpha: 0.7),
        wallet
            ? (deposit ? l10n.txnAdded : l10n.txnTaken)
            : (deposit ? l10n.txnSaved : l10n.txnWithdrawn),
      ),
      TxnKind.transfer => (
        Icons.swap_horiz,
        scheme.primary,
        wallet
            ? (deposit ? l10n.txnFromSavings : l10n.txnToSavings)
            : (deposit ? l10n.txnFromWallet : l10n.txnToWallet),
      ),
      TxnKind.expense => (
        categoryIcon(txn.reference ?? '', customs: customs),
        scheme.error,
        '${l10n.txnExpense} · ${categoryLabel(l10n, txn.reference ?? ExpenseCategory.other.name)}',
      ),
      TxnKind.debt => (
        Icons.handshake,
        scheme.tertiary,
        l10n.txnDebtPayment(txn.reference ?? ''),
      ),
    };

    return LedgerRow(
      icon: icon,
      color: color,
      title: title,
      subtitle: txn.note ?? DateFormat.jm(locale).format(txn.loggedAt),
      amount: formatSigned(txn.deltaMinor, txn.currency),
      amountColor: deposit ? scheme.secondary : null,
      caption: conversionCaption(
        minor: txn.deltaMinor.abs(),
        currency: txn.currency,
        rates: rates,
      ),
    );
  }
}
