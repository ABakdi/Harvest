import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/finances/domain/currency.dart';
import 'package:meta/meta.dart';

/// The two money pots: the wallet is meant to be spent, savings are
/// meant to be saved (checkpoint round 3).
enum MoneyAccount { wallet, savings }

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
    this.note,
  });

  final String uuid;
  final MoneyAccount account;
  final int deltaMinor;
  final Currency currency;
  final HarvestDay day;
  final DateTime loggedAt;
  final String? note;
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
}
