part of 'vault_tab.dart';

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
    final rates = ref.watch(ratesOrDefaultProvider);
    final defaultCurrency = ref.watch(defaultCurrencyProvider);

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
                onEdit: () => unawaited(showDebtSheet(context, existing: debt)),
                onRemovePayment: (payment) =>
                    unawaited(_removePayment(context, payment)),
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
                    _SettledDebt(
                      debt: debt,
                      payments: payments
                          .where((p) => p.debtUuid == debt.uuid)
                          .toList(),
                      expanded: _expanded.contains(debt.uuid),
                      onToggle: () => setState(() {
                        if (!_expanded.remove(debt.uuid)) {
                          _expanded.add(debt.uuid);
                        }
                      }),
                      onEdit: () =>
                          unawaited(showDebtSheet(context, existing: debt)),
                      onRemovePayment: (payment) => unawaited(
                        _removePayment(context, payment, settled: true),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// A payment logged by mistake goes the way an expense does: ask,
  /// remove, offer Undo ([[Audit-v2-Beta]] N-01).
  /// On a settled debt ([settled]) the removal reopens it, and the bar
  /// says so.
  Future<void> _removePayment(
    BuildContext context,
    DebtPayment payment, {
    bool settled = false,
  }) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final actions = ref.read(financeActionsProvider);
    final ok = await confirm(
      context,
      title: l10n.debtPaymentRemoveTitle,
      body: l10n.debtPaymentRemoveBody,
      confirmLabel: l10n.removeAction,
      destructive: true,
    );
    if (!ok) return;
    await actions.removePayment(payment.uuid);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          // An action is an offer for a few seconds, not a fixture.
          persist: false,
          content: Text(settled ? l10n.debtReopened : l10n.deleted),
          action: SnackBarAction(
            label: l10n.undoAction,
            // The debt or the wallet may have moved on while Undo was
            // showing; a refused Undo says so ([[Audit-v3]] Q5-17).
            onPressed: () => unawaited(
              actions.restorePayment(payment.uuid).catchError((Object _) {
                messenger.showSnackBar(
                  SnackBar(content: Text(l10n.undoRefused)),
                );
              }),
            ),
          ),
        ),
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
      walletBalances: ref.read(accountBalancesProvider(MoneyAccount.wallet)),
    );
    if (entry == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await runGuarded(
      context,
      ref
          .read(financeActionsProvider)
          .payDebt(
            debtUuid: debt.uuid,
            amountMinor: entry.minor,
            fromWallet: entry.fromWallet,
            note: entry.note,
          ),
    );
    // The last payment gets the small celebration [[Finances]]
    // promises: a burst over the vault and a line that says it is done.
    if (!ok || entry.minor < debt.remainingMinor || !context.mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      showCheckInBurst(
        context,
        box.localToGlobal(box.size.topCenter(const Offset(0, 48))),
        icon: Icons.celebration,
        color: scheme.secondary,
        particles: 12,
      );
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(l10n.debtSettledWith(debt.person))),
      );
  }
}

/// A settled debt in the quiet list: who, how much, and its payments
/// one tap away — a mistaken last payment can still be taken back, and
/// taking it back reopens the debt ([[Audit-v2-Beta]] N-01).
class _SettledDebt extends StatelessWidget {
  const _SettledDebt({
    required this.debt,
    required this.payments,
    required this.expanded,
    required this.onToggle,
    required this.onEdit,
    required this.onRemovePayment,
  });

  final Debt debt;
  final List<DebtPayment> payments;
  final bool expanded;
  final VoidCallback onToggle;

  /// Long-press: correct it or remove it ([[Finances]] The Vault).
  final VoidCallback onEdit;
  final ValueChanged<DebtPayment> onRemovePayment;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LedgerRow(
          icon: Icons.check_circle,
          color: scheme.secondary,
          title: debt.person,
          subtitle: l10n.debtSettled,
          amount: formatMoney(debt.amountMinor, debt.currency),
          amountColor: scheme.onSurface.withValues(alpha: 0.55),
          onTap: payments.isEmpty ? onEdit : onToggle,
          onLongPress: onEdit,
        ),
        if (payments.isNotEmpty)
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              onPressed: onToggle,
              icon: Icon(
                expanded ? Icons.expand_less : Icons.expand_more,
                size: 18,
              ),
              label: Text('${l10n.debtPayments} · ${payments.length}'),
            ),
          ),
        if (expanded && payments.isNotEmpty)
          _PaymentsList(
            payments: payments,
            currency: debt.currency,
            onRemove: onRemovePayment,
          ),
      ],
    );
  }
}

/// A debt's payments, each removable by its own button (or a long
/// press, the way an expense goes). The same list sits under an open
/// debt and a settled one.
class _PaymentsList extends StatelessWidget {
  const _PaymentsList({
    required this.payments,
    required this.currency,
    required this.onRemove,
  });

  final List<DebtPayment> payments;
  final Currency currency;
  final ValueChanged<DebtPayment> onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toString();
    return Column(
      children: [
        for (final payment in payments)
          Row(
            children: [
              Expanded(
                child: LedgerRow(
                  icon: Icons.payments,
                  color: scheme.secondary,
                  title: dayLabel(context, payment.day),
                  subtitle: DateFormat.jm(locale).format(payment.loggedAt),
                  amount: formatMoneySigned(-payment.amountMinor, currency),
                  onLongPress: () => onRemove(payment),
                ),
              ),
              IconButton(
                tooltip: l10n.debtPaymentRemove,
                icon: Icon(
                  Icons.delete_outline,
                  color: scheme.onSurfaceVariant,
                ),
                onPressed: () => onRemove(payment),
              ),
            ],
          ),
      ],
    );
  }
}

class _DebtCard extends StatelessWidget {
  const _DebtCard({
    required this.debt,
    required this.payments,
    required this.expanded,
    required this.onToggle,
    required this.onPay,
    required this.onEdit,
    required this.onRemovePayment,
  });

  final Debt debt;
  final List<DebtPayment> payments;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onPay;

  /// A tap on the header: correct the debt or remove it.
  final VoidCallback onEdit;

  /// Long-press on a payment: the way an expense is removed.
  final ValueChanged<DebtPayment> onRemovePayment;

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
            InkWell(
              onTap: onEdit,
              borderRadius: BorderRadius.circular(HarvestRadii.chip),
              child: Row(
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
                    formatMoney(debt.remainingMinor, debt.currency),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: scheme.tertiary,
                    ),
                  ),
                ],
              ),
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
                      formatMoney(debt.paidMinor, debt.currency),
                      formatMoney(debt.amountMinor, debt.currency),
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
              _PaymentsList(
                payments: payments,
                currency: debt.currency,
                onRemove: onRemovePayment,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
