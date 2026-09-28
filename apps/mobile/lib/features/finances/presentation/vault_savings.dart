part of 'vault_tab.dart';

// ----------------------------------------------------------------- savings

class _SavingsSection extends ConsumerWidget {
  const _SavingsSection({required this.filter, required this.onFilter});

  final MoveFilter filter;
  final ValueChanged<MoveFilter> onFilter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final balances = ref.watch(accountBalancesProvider(MoneyAccount.savings));
    final txns =
        ref.watch(accountTxnsProvider(MoneyAccount.savings)).value ?? const [];
    final shown = filter.apply(txns);
    final rates = ref.watch(ratesOrDefaultProvider);
    final defaultCurrency = ref.watch(defaultCurrencyProvider);
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
        MoveFilterBar(
          filter: filter,
          matches: shown.length,
          total: txns.length,
          onChanged: onFilter,
        ),
        const SizedBox(height: HarvestSpacing.sm),
        if (txns.isNotEmpty && shown.isEmpty)
          Card(
            child: EmptyState(
              icon: Icons.search_off,
              title: l10n.movesNoMatch,
              body: l10n.movesNoMatchBody,
              color: scheme.tertiary,
              compact: true,
            ),
          )
        else
          MovesLedger(
            txns: shown,
            rates: rates,
            emptyTitle: l10n.noMovesYet,
            emptyIcon: Icons.savings_outlined,
            color: scheme.secondary,
          ),
      ],
    );
  }

  /// A deposit comes from the wallet (transfer) or from new money.
  /// Saving asks one question: how much. Where it comes from is a
  /// switch inside the same sheet, defaulted to the wallet when the
  /// wallet can cover it.
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
      walletBalances: ref.read(accountBalancesProvider(MoneyAccount.wallet)),
    );
    if (entry == null || !context.mounted) return;
    await runGuarded(
      context,
      ref
          .read(financeActionsProvider)
          .depositSavings(
            amountMinor: entry.minor,
            currency: entry.currency,
            fromWallet: entry.fromWallet,
            note: entry.note,
          ),
    );
  }

  /// A withdrawal always lands in the wallet. Spending it is a separate,
  /// ordinary expense — one path for money leaving, not two.
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
      subtitle: l10n.withdrawToWallet,
      initialCurrency: balances.keys.first,
      lockCurrency: balances.length == 1,
      maxMinor: balances,
      accent: scheme.secondary,
    );
    if (entry == null || !context.mounted) return;
    await runGuarded(
      context,
      ref
          .read(financeActionsProvider)
          .withdrawSavings(
            amountMinor: entry.minor,
            currency: entry.currency,
            note: entry.note,
          ),
    );
  }
}
