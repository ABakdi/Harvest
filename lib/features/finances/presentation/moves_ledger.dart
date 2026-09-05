import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/core/ui/widgets/empty_state.dart';
import 'package:harvest/core/ui/widgets/ledger_row.dart';
import 'package:harvest/features/finances/domain/currency.dart';
import 'package:harvest/features/finances/domain/expense.dart';
import 'package:harvest/features/finances/domain/vault.dart';
import 'package:harvest/features/finances/presentation/expense_sheet.dart';
import 'package:harvest/features/finances/presentation/finance_providers.dart';
import 'package:harvest/features/finances/presentation/money.dart';
import 'package:harvest/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

/// A ledger of money movements, grouped by day.
///
/// It was private to the Vault until the Insights page wanted the same
/// list for the range it is showing. One list, one row, one set of
/// words for what each movement was.
class MovesLedger extends ConsumerWidget {
  const MovesLedger({
    required this.txns,
    required this.rates,
    required this.emptyTitle,
    required this.emptyIcon,
    required this.color,
    super.key,
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
            rowOf: (txn) => MoveRow(txn: txn, rates: rates, customs: customs),
          ),
        ),
      ),
    );
  }
}

class MoveRow extends StatelessWidget {
  const MoveRow({
    required this.txn,
    required this.rates,
    required this.customs,
    super.key,
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
