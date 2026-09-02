import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/core/platform/haptics.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/core/ui/widgets/big_bouncy_button.dart';
import 'package:harvest/features/finances/data/finances_repository.dart';
import 'package:harvest/features/finances/data/vault_repository.dart';
import 'package:harvest/features/finances/domain/currency.dart';
import 'package:harvest/features/finances/domain/expense.dart';
import 'package:harvest/features/finances/domain/vault.dart';
import 'package:harvest/features/finances/presentation/finance_providers.dart';
import 'package:harvest/features/finances/presentation/money.dart';
import 'package:harvest/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

/// The vault: wallet (meant to be spent), savings (meant to be saved),
/// and debts — every movement on record (checkpoint round 3).
class VaultTab extends ConsumerWidget {
  const VaultTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final balances = ref.watch(vaultBalancesProvider).value ?? const {};
    final debtsList = ref.watch(debtsProvider).value ?? const [];
    final txns = ref.watch(recentTxnsProvider).value ?? const [];
    final ratesValue = ref.watch(ratesProvider).value ??
        const Rates(defaultCurrency: Currency.dzd);
    final health = ref.watch(savingsHealthProvider);
    final defaultCurrency =
        ref.watch(financeSettingsProvider).value?.defaultCurrency ??
            Currency.dzd;

    Map<Currency, int> of(MoneyAccount account) => {
          for (final entry in balances.entries)
            if (entry.key.$1 == account && entry.value != 0)
              entry.key.$2: entry.value,
        };
    final wallet = of(MoneyAccount.wallet);
    final savings = of(MoneyAccount.savings);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        HarvestSpacing.md,
        HarvestSpacing.sm,
        HarvestSpacing.md,
        120,
      ),
      children: [
        // ------------------------------------------------------- wallet
        Card(
          child: Padding(
            padding: const EdgeInsets.all(HarvestSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.account_balance_wallet,
                        color: theme.colorScheme.primary),
                    const SizedBox(width: HarvestSpacing.sm),
                    Text(
                      l10n.walletTitle,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const Spacer(),
                    IconButton.filledTonal(
                      icon: const Icon(Icons.add),
                      tooltip: l10n.walletAdd,
                      onPressed: () => unawaited(
                        _moveMoney(context, ref, MoneyAccount.wallet,
                            deposit: true, defaultCurrency: defaultCurrency),
                      ),
                    ),
                    const SizedBox(width: HarvestSpacing.xs),
                    IconButton.filledTonal(
                      icon: const Icon(Icons.remove),
                      tooltip: l10n.walletTake,
                      onPressed: () => unawaited(
                        _moveMoney(context, ref, MoneyAccount.wallet,
                            deposit: false, defaultCurrency: defaultCurrency),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: HarvestSpacing.xs),
                if (wallet.isEmpty)
                  Text('${defaultCurrency.symbol}0',
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800))
                else
                  for (final entry in wallet.entries)
                    Text(
                      amountWithConversion(
                        minor: entry.value,
                        currency: entry.key,
                        rates: ratesValue,
                      ),
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
              ],
            ),
          ),
        ),
        const SizedBox(height: HarvestSpacing.md),
        // ------------------------------------------------------ savings
        Text(
          l10n.savingsSectionTitle,
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: HarvestSpacing.sm),
        if (savings.isEmpty)
          Card(
            child: ListTile(
              leading: const Icon(Icons.savings_outlined),
              title: Text(l10n.nothingInVault),
              trailing: IconButton.filledTonal(
                icon: const Icon(Icons.add),
                onPressed: () => unawaited(
                  _moveMoney(context, ref, MoneyAccount.savings,
                      deposit: true, defaultCurrency: defaultCurrency),
                ),
              ),
            ),
          )
        else
          for (final entry in savings.entries)
            Card(
              color: health == SavingsHealth.low
                  ? theme.colorScheme.error.withValues(alpha: 0.12)
                  : null,
              child: ListTile(
                leading: Icon(
                  Icons.savings_outlined,
                  color: health == SavingsHealth.low
                      ? theme.colorScheme.error
                      : theme.colorScheme.secondary,
                ),
                title: Text(
                  amountWithConversion(
                    minor: entry.value,
                    currency: entry.key,
                    rates: ratesValue,
                  ),
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  health == SavingsHealth.low
                      ? l10n.savingsLow
                      : l10n.savingsIn(entry.key.code),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton.filledTonal(
                      icon: const Icon(Icons.add),
                      tooltip: l10n.savingsDeposit,
                      onPressed: () => unawaited(
                        _moveMoney(context, ref, MoneyAccount.savings,
                            deposit: true,
                            defaultCurrency: entry.key),
                      ),
                    ),
                    const SizedBox(width: HarvestSpacing.xs),
                    IconButton.filledTonal(
                      icon: const Icon(Icons.remove),
                      tooltip: l10n.savingsWithdraw,
                      onPressed: () => unawaited(
                        _withdrawFromSavings(context, ref, entry.key),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        const SizedBox(height: HarvestSpacing.md),
        // -------------------------------------------------------- debts
        Row(
          children: [
            Text(
              l10n.debtsTitle,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const Spacer(),
            TextButton.icon(
              icon: const Icon(Icons.add),
              label: Text(l10n.addDebt),
              onPressed: () => unawaited(showDebtSheet(context)),
            ),
          ],
        ),
        for (final debt in debtsList)
          Card(
            child: ListTile(
              leading: Icon(
                debt.isSettled
                    ? Icons.check_circle
                    : Icons.handshake_outlined,
                color: debt.isSettled
                    ? theme.colorScheme.secondary
                    : theme.colorScheme.tertiary,
              ),
              title: Text(
                debt.isSettled
                    ? '${debt.person} · ${l10n.debtSettled}'
                    : l10n.debtRemaining(
                        '${debt.currency.symbol}'
                        '${formatMinor(debt.remainingMinor)}',
                        debt.person,
                      ),
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              subtitle: debt.payOffBy == null || debt.isSettled
                  ? (debt.note == null ? null : Text(debt.note!))
                  : Text(
                      '${l10n.debtPayOffBy} ${DateFormat.MMMd(
                        Localizations.localeOf(context).toString(),
                      ).format(DateTime(
                        debt.payOffBy!.year,
                        debt.payOffBy!.month,
                        debt.payOffBy!.day,
                      ))}',
                    ),
              trailing: debt.isSettled
                  ? null
                  : FilledButton.tonal(
                      onPressed: () =>
                          unawaited(_payDebt(context, ref, debt)),
                      child: Text(l10n.debtPay),
                    ),
            ),
          ),
        const SizedBox(height: HarvestSpacing.md),
        // ------------------------------------------------- recent moves
        if (txns.isNotEmpty) ...[
          Text(
            l10n.recentMoves,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: HarvestSpacing.sm),
          for (final txn in txns.take(12))
            ListTile(
              dense: true,
              leading: Icon(
                txn.deltaMinor >= 0
                    ? Icons.arrow_downward
                    : Icons.arrow_upward,
                size: 18,
                color: txn.deltaMinor >= 0
                    ? theme.colorScheme.secondary
                    : theme.colorScheme.error,
              ),
              title: Text(
                '${txn.deltaMinor >= 0 ? '+' : '−'}'
                '${txn.currency.symbol}${formatMinor(txn.deltaMinor.abs())}'
                ' · ${txn.account == MoneyAccount.wallet ? l10n.txnWallet : l10n.txnSavings}',
              ),
              subtitle: txn.note == null ? null : Text(txn.note!),
              trailing: Text(
                DateFormat.MMMd(
                  Localizations.localeOf(context).toString(),
                ).format(
                  DateTime(txn.day.year, txn.day.month, txn.day.day),
                ),
                style: theme.textTheme.labelSmall,
              ),
            ),
        ],
      ],
    );
  }

  /// Plain deposit/withdraw dialog for a pot.
  Future<void> _moveMoney(
    BuildContext context,
    WidgetRef ref,
    MoneyAccount account, {
    required bool deposit,
    required Currency defaultCurrency,
  }) async {
    final result = await _askAmount(
      context,
      title: account == MoneyAccount.wallet
          ? (deposit
              ? AppLocalizations.of(context).walletAdd
              : AppLocalizations.of(context).walletTake)
          : (deposit
              ? AppLocalizations.of(context).savingsDeposit
              : AppLocalizations.of(context).savingsWithdraw),
      initialCurrency: defaultCurrency,
    );
    if (result == null) return;
    await ref.read(vaultRepositoryProvider).move(
          account: account,
          deltaMinor: deposit ? result.$1 : -result.$1,
          currency: result.$2,
          note: result.$3,
        );
    unawaited(HarvestHaptics.thud());
  }

  /// Savings withdrawal always lands somewhere: wallet or an expense.
  Future<void> _withdrawFromSavings(
    BuildContext context,
    WidgetRef ref,
    Currency currency,
  ) async {
    final l10n = AppLocalizations.of(context);
    final result = await _askAmount(
      context,
      title: l10n.savingsWithdraw,
      initialCurrency: currency,
      lockCurrency: true,
    );
    if (result == null || !context.mounted) return;

    final destination = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.withdrawDestination),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop('expense'),
            child: Text(l10n.asExpense),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop('wallet'),
            child: Text(l10n.toWallet),
          ),
        ],
      ),
    );
    if (destination == null) return;

    final vault = ref.read(vaultRepositoryProvider);
    if (destination == 'wallet') {
      await vault.transferSavingsToWallet(
        amountMinor: result.$1,
        currency: result.$2,
        note: result.$3,
      );
    } else {
      await vault.move(
        account: MoneyAccount.savings,
        deltaMinor: -result.$1,
        currency: result.$2,
        note: result.$3,
      );
      await ref.read(financesRepositoryProvider).log(
            amountMinor: result.$1,
            category: ExpenseCategory.other.name,
            currency: result.$2,
            note: result.$3,
          );
    }
    unawaited(HarvestHaptics.thud());
  }

  Future<void> _payDebt(
    BuildContext context,
    WidgetRef ref,
    Debt debt,
  ) async {
    final l10n = AppLocalizations.of(context);
    final result = await _askAmount(
      context,
      title: '${l10n.debtPay} · ${debt.person}',
      initialCurrency: debt.currency,
      lockCurrency: true,
      initialAmountMinor: debt.remainingMinor,
    );
    if (result == null) return;
    await ref
        .read(vaultRepositoryProvider)
        .payDebt(debt.uuid, result.$1);
    unawaited(HarvestHaptics.thud());
  }

  /// Amount + currency + note dialog → (minor, currency, note?).
  Future<(int, Currency, String?)?> _askAmount(
    BuildContext context, {
    required String title,
    required Currency initialCurrency,
    bool lockCurrency = false,
    int? initialAmountMinor,
  }) {
    final l10n = AppLocalizations.of(context);
    final amountController = TextEditingController(
      text: initialAmountMinor == null
          ? ''
          : formatMinor(initialAmountMinor),
    );
    final noteController = TextEditingController();
    var currency = initialCurrency;

    return showDialog<(int, Currency, String?)>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountController,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: l10n.amountPrompt),
              ),
              const SizedBox(height: HarvestSpacing.sm),
              if (!lockCurrency)
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
                  selected: {currency},
                  onSelectionChanged: (selection) =>
                      setState(() => currency = selection.first),
                ),
              const SizedBox(height: HarvestSpacing.sm),
              TextField(
                controller: noteController,
                decoration: InputDecoration(labelText: l10n.noteLabel),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () {
                final minor = parseToMinor(amountController.text);
                if (minor == null) return;
                final note = noteController.text.trim();
                Navigator.of(dialogContext).pop(
                  (minor, currency, note.isEmpty ? null : note),
                );
              },
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet to log a new debt with its advanced options.
Future<void> showDebtSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(HarvestRadii.sheet),
        ),
      ),
      builder: (_) => const _DebtSheet(),
    );

class _DebtSheet extends ConsumerStatefulWidget {
  const _DebtSheet();

  @override
  ConsumerState<_DebtSheet> createState() => _DebtSheetState();
}

class _DebtSheetState extends ConsumerState<_DebtSheet> {
  final _personController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  Currency _currency = Currency.dzd;
  HarvestDay? _payOffBy;
  TimeOfDay? _remindAt;

  @override
  void initState() {
    super.initState();
    _currency = ref.read(financeSettingsProvider).value?.defaultCurrency ??
        Currency.dzd;
  }

  @override
  void dispose() {
    _personController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  bool get _valid =>
      _personController.text.trim().isNotEmpty &&
      parseToMinor(_amountController.text) != null;

  Future<void> _save() async {
    final minor = parseToMinor(_amountController.text)!;
    final person = _personController.text.trim();
    final note = _noteController.text.trim();
    Navigator.of(context).pop();
    await ref.read(vaultRepositoryProvider).createDebt(
          person: person,
          amountMinor: minor,
          currency: _currency,
          payOffBy: _payOffBy,
          remindAt: _remindAt == null
              ? null
              : '${_remindAt!.hour}:'
                  '${_remindAt!.minute.toString().padLeft(2, '0')}',
          note: note.isEmpty ? null : note,
        );
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
    final locale = Localizations.localeOf(context).toString();

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
              l10n.addDebt,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: HarvestSpacing.md),
            TextField(
              controller: _personController,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              decoration: _decoration(l10n.debtPerson),
            ),
            const SizedBox(height: HarvestSpacing.md),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (_) => setState(() {}),
                    decoration: _decoration(l10n.amountLabel),
                  ),
                ),
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
                  selected: {_currency},
                  onSelectionChanged: (selection) =>
                      setState(() => _currency = selection.first),
                ),
              ],
            ),
            const SizedBox(height: HarvestSpacing.sm),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: Text(l10n.debtPayOffBy),
              subtitle: Text(
                _payOffBy == null
                    ? l10n.notSet
                    : DateFormat.MMMd(locale).format(
                        DateTime(
                          _payOffBy!.year,
                          _payOffBy!.month,
                          _payOffBy!.day,
                        ),
                      ),
              ),
              onTap: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: now,
                  firstDate: now,
                  lastDate: now.add(const Duration(days: 365 * 5)),
                );
                if (picked != null) {
                  setState(() => _payOffBy = HarvestDay.fromDate(picked));
                }
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.alarm),
              title: Text(l10n.debtRemindAt),
              subtitle: Text(
                _remindAt == null ? l10n.notSet : _remindAt!.format(context),
              ),
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime:
                      _remindAt ?? const TimeOfDay(hour: 19, minute: 0),
                );
                if (picked != null) setState(() => _remindAt = picked);
              },
            ),
            TextField(
              controller: _noteController,
              decoration: _decoration(l10n.noteLabel),
            ),
            const SizedBox(height: HarvestSpacing.lg),
            BigBouncySheetButton(
              onPressed: _valid ? () => unawaited(_save()) : null,
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
  }
}
