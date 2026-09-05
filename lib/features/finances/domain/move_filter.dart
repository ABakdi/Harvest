import 'package:harvest/features/finances/domain/vault.dart';
import 'package:meta/meta.dart';

/// What to keep when looking at a ledger.
///
/// The vault's history gets long fast, and "what did I spend on food
/// last month" or "where did that note about the car go" are the two
/// questions actually being asked of it. Empty means everything: a
/// filter nobody set should never hide a row.
@immutable
class MoveFilter {
  const MoveFilter({
    this.kinds = const {},
    this.categories = const {},
    this.query = '',
  });

  /// Which forms of movement to keep; empty is all of them.
  final Set<TxnKind> kinds;

  /// Which expense categories to keep; empty is all of them. Only an
  /// expense-kind movement carries a category, so choosing one narrows
  /// the ledger to expenses by construction.
  final Set<String> categories;

  /// Free text, matched against the note and the reference.
  final String query;

  static const empty = MoveFilter();

  bool get isEmpty => kinds.isEmpty && categories.isEmpty && query.isEmpty;

  int get activeCount =>
      (kinds.isEmpty ? 0 : 1) +
      (categories.isEmpty ? 0 : 1) +
      (query.isEmpty ? 0 : 1);

  bool matches(MoneyTxn txn) {
    if (kinds.isNotEmpty && !kinds.contains(txn.kind)) return false;
    if (categories.isNotEmpty) {
      if (txn.kind != TxnKind.expense) return false;
      if (!categories.contains(txn.reference)) return false;
    }
    if (query.isEmpty) return true;
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return true;
    return (txn.note ?? '').toLowerCase().contains(needle) ||
        (txn.reference ?? '').toLowerCase().contains(needle);
  }

  List<MoneyTxn> apply(List<MoneyTxn> txns) =>
      isEmpty ? txns : txns.where(matches).toList();

  MoveFilter copyWith({
    Set<TxnKind>? kinds,
    Set<String>? categories,
    String? query,
  }) => MoveFilter(
    kinds: kinds ?? this.kinds,
    categories: categories ?? this.categories,
    query: query ?? this.query,
  );

  @override
  bool operator ==(Object other) =>
      other is MoveFilter &&
      other.query == query &&
      other.kinds.length == kinds.length &&
      other.kinds.containsAll(kinds) &&
      other.categories.length == categories.length &&
      other.categories.containsAll(categories);

  @override
  int get hashCode => Object.hash(
    query,
    Object.hashAllUnordered(kinds),
    Object.hashAllUnordered(categories),
  );
}
