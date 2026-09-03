import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/db/database_provider.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/finances/data/finances_repository.dart';
import 'package:harvest/features/finances/data/vault_repository.dart';
import 'package:harvest/features/finances/domain/currency.dart';
import 'package:harvest/features/finances/domain/vault.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'finance_actions.g.dart';

/// Every money flow that touches more than one table, each in a single
/// transaction. Widgets call these instead of stitching repositories
/// together, so an expense and the wallet movement that paid for it can
/// never drift apart.
class FinanceActions {
  FinanceActions(this._db, this._finances, this._vault);

  final HarvestDatabase _db;
  final FinancesRepository _finances;
  final VaultRepository _vault;

  /// Logs an expense, optionally paying for it out of the wallet. The
  /// wallet movement carries the expense's uuid, so editing or deleting
  /// the expense later can find it.
  Future<String> logExpense({
    required int amountMinor,
    required String category,
    required Currency currency,
    bool fromWallet = false,
    String? note,
    HarvestDay? day,
  }) => _db.transaction(() async {
    final uuid = await _finances.log(
      amountMinor: amountMinor,
      category: category,
      currency: currency,
      note: note,
      day: day,
    );
    if (fromWallet) {
      await _vault.move(
        account: MoneyAccount.wallet,
        deltaMinor: -amountMinor,
        currency: currency,
        kind: TxnKind.expense,
        reference: category,
        linkUuid: uuid,
        note: note,
        day: day,
      );
    }
    return uuid;
  });

  /// Edits an expense in place and keeps its wallet movement in step:
  /// the amount follows, and the toggle can add or remove the movement.
  Future<void> updateExpense({
    required String uuid,
    required int amountMinor,
    required String category,
    required Currency currency,
    required bool fromWallet,
    String? note,
  }) => _db.transaction(() async {
    await _finances.updateExpense(
      uuid: uuid,
      amountMinor: amountMinor,
      category: category,
      currency: currency,
      note: note,
    );
    final linked = await _vault.linkedTxn(uuid);
    if (fromWallet) {
      if (linked == null) {
        await _vault.move(
          account: MoneyAccount.wallet,
          deltaMinor: -amountMinor,
          currency: currency,
          kind: TxnKind.expense,
          reference: category,
          linkUuid: uuid,
          note: note,
        );
      } else {
        await _vault.updateLinked(
          linked.uuid,
          deltaMinor: -amountMinor,
          currency: currency,
          reference: category,
          note: note,
        );
      }
    } else if (linked != null) {
      await _vault.removeTxn(linked.uuid);
    }
  });

  /// Removes an expense and whatever it took out of the wallet.
  Future<void> removeExpense(String uuid) => _db.transaction(() async {
    await _finances.remove(uuid);
    final linked = await _vault.linkedTxn(uuid);
    if (linked != null) await _vault.removeTxn(linked.uuid);
  });

  /// Puts back what [removeExpense] took away (the snackbar's Undo).
  Future<void> restoreExpense(String uuid) => _db.transaction(() async {
    await _finances.restore(uuid);
    final linked = await _vault.linkedTxn(uuid, includeDeleted: true);
    if (linked != null) await _vault.restoreTxn(linked.uuid);
  });

  /// Puts money into savings, either moved from the wallet or new.
  Future<void> depositSavings({
    required int amountMinor,
    required Currency currency,
    required bool fromWallet,
    String? note,
  }) async {
    if (fromWallet) {
      await _vault.transferWalletToSavings(
        amountMinor: amountMinor,
        currency: currency,
        note: note,
      );
      return;
    }
    await _vault.move(
      account: MoneyAccount.savings,
      deltaMinor: amountMinor,
      currency: currency,
      note: note,
    );
  }

  /// Takes money out of savings; it always lands in the wallet, and is
  /// spent from there like any other money.
  Future<void> withdrawSavings({
    required int amountMinor,
    required Currency currency,
    String? note,
  }) => _vault.transferSavingsToWallet(
    amountMinor: amountMinor,
    currency: currency,
    note: note,
  );

  /// Pays a debt, optionally out of the wallet.
  Future<void> payDebt({
    required String debtUuid,
    required int amountMinor,
    bool fromWallet = false,
    String? note,
  }) => _vault.payDebt(
    debtUuid,
    amountMinor,
    fromWallet: fromWallet,
    note: note,
  );
}

@Riverpod(keepAlive: true)
FinanceActions financeActions(Ref ref) => FinanceActions(
  ref.watch(databaseProvider),
  ref.watch(financesRepositoryProvider),
  ref.watch(vaultRepositoryProvider),
);
