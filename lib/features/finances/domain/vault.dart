import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/finances/domain/currency.dart';
import 'package:meta/meta.dart';

/// The two money pots: the wallet is meant to be spent, savings are
/// meant to be saved (checkpoint round 3).
enum MoneyAccount { wallet, savings }

/// Why a movement happened (round 4): plain deposits and withdrawals,
/// a transfer between pots, an expense taken from the wallet, or a
/// debt payment taken from the wallet.
enum TxnKind {
  manual,
  transfer,
  expense,
  debt;

  static TxnKind fromName(String? name) => TxnKind.values.firstWhere(
    (kind) => kind.name == name,
    orElse: () => TxnKind.manual,
  );
}

/// One movement on a pot; positive deposits, negative withdrawals.
@immutable
class MoneyTxn {
  const MoneyTxn({
    required this.uuid,
    required this.account,
    required this.deltaMinor,
    required this.currency,
    required this.day,
    required this.loggedAt,
    this.kind = TxnKind.manual,
    this.reference,
    this.note,
  });

  final String uuid;
  final MoneyAccount account;
  final int deltaMinor;
  final Currency currency;
  final HarvestDay day;
  final DateTime loggedAt;
  final TxnKind kind;

  /// Context for [kind]: the counterpart account name for a transfer,
  /// the category key for an expense, the person for a debt payment.
  final String? reference;
  final String? note;

  bool get isDeposit => deltaMinor >= 0;
}

/// A debt: an amount owed to someone, no interest.
@immutable
class Debt {
  const Debt({
    required this.uuid,
    required this.person,
    required this.amountMinor,
    required this.currency,
    required this.paidMinor,
    this.payOffBy,
    this.remindAt,
    this.note,
    this.settledAt,
  });

  final String uuid;
  final String person;
  final int amountMinor;
  final Currency currency;

  /// Sum of payments so far.
  final int paidMinor;
  final HarvestDay? payOffBy;

  /// "HH:mm"; when unset the default reminder time applies.
  final String? remindAt;
  final String? note;
  final DateTime? settledAt;

  bool get isSettled => settledAt != null;
  int get remainingMinor => (amountMinor - paidMinor).clamp(0, amountMinor);

  /// 0..1 share of the debt already paid.
  double get paidFraction =>
      amountMinor == 0 ? 1 : (paidMinor / amountMinor).clamp(0, 1);
}

/// One payment against a debt — the atomic record under each debt.
@immutable
class DebtPayment {
  const DebtPayment({
    required this.uuid,
    required this.debtUuid,
    required this.amountMinor,
    required this.day,
    required this.loggedAt,
  });

  final String uuid;
  final String debtUuid;
  final int amountMinor;
  final HarvestDay day;
  final DateTime loggedAt;
}
