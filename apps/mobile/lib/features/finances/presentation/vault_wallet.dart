part of 'vault_tab.dart';

// ------------------------------------------------------------------ wallet

class _WalletSection extends ConsumerWidget {
  const _WalletSection({required this.filter, required this.onFilter});

  final MoveFilter filter;
  final ValueChanged<MoveFilter> onFilter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final balances = ref.watch(accountBalancesProvider(MoneyAccount.wallet));
    final txns =
        ref.watch(accountTxnsProvider(MoneyAccount.wallet)).value ?? const [];
    final shown = filter.apply(txns);
    final rates = ref.watch(ratesOrDefaultProvider);
    final defaultCurrency = ref.watch(defaultCurrencyProvider);

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
                          balances: balances,
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
                          balances: balances,
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
              color: theme.colorScheme.tertiary,
              compact: true,
            ),
          )
        else
          MovesLedger(
            txns: shown,
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
    required Map<Currency, int> balances,
  }) async {
    final l10n = AppLocalizations.of(context);
    final entry = await showMoneySheet(
      context,
      title: deposit ? l10n.walletAdd : l10n.walletTake,
      subtitle: l10n.walletTitle,
      initialCurrency: currency,
      // Taking out more than the wallet holds is a typo, not a wish.
      maxMinor: deposit ? null : balances,
    );
    if (entry == null || !context.mounted) return;
    await runGuarded(
      context,
      ref
          .read(vaultRepositoryProvider)
          .move(
            account: MoneyAccount.wallet,
            deltaMinor: deposit ? entry.minor : -entry.minor,
            currency: entry.currency,
            note: entry.note,
          ),
    );
  }
}
