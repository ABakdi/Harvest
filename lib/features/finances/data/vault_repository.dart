import 'package:drift/drift.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/db/database_provider.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/finances/domain/currency.dart';
import 'package:harvest/features/finances/domain/vault.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

part 'vault_repository.g.dart';

/// Wallet, savings, and debts — every movement is a row, balances are
/// sums, and each write lands in the outbox.
class VaultRepository {
  VaultRepository(this._db);

  final HarvestDatabase _db;
  static const _uuid = Uuid();

  // ---------------------------------------------------------------- money

  /// All balances per account+currency.
  Stream<Map<(MoneyAccount, Currency), int>> watchBalances() {
    final query = _db.select(_db.moneyTxns)..where((t) => t.deletedAt.isNull());
    return query.watch().map((rows) {
      final balances = <(MoneyAccount, Currency), int>{};
      for (final row in rows) {
        final key = (
          MoneyAccount.values.byName(row.account),
          Currency.fromCode(row.currency),
        );
        balances.update(
          key,
          (v) => v + row.deltaMinor,
          ifAbsent: () => row.deltaMinor,
        );
      }
      return balances;
    });
  }

  /// Movements newest first — one pot's ledger when [account] is given,
  /// every pot otherwise.
  Stream<List<MoneyTxn>> watchTxns({MoneyAccount? account, int limit = 60}) {
    final query = _db.select(_db.moneyTxns)
      ..where((t) => t.deletedAt.isNull())
      ..orderBy([
        (t) => OrderingTerm.desc(t.loggedAt),
        (t) => OrderingTerm.desc(t.rowId),
      ])
      ..limit(limit);
    if (account != null) {
      query.where((t) => t.account.equals(account.name));
    }
    return query.watch().map((rows) => rows.map(_toTxn).toList());
  }

  /// Recent movements across both pots, newest first.
  Stream<List<MoneyTxn>> watchRecentTxns({int limit = 30}) =>
      watchTxns(limit: limit);

  MoneyTxn _toTxn(MoneyTxnRow row) => MoneyTxn(
    uuid: row.uuid,
    account: MoneyAccount.values.byName(row.account),
    deltaMinor: row.deltaMinor,
    currency: Currency.fromCode(row.currency),
    day: HarvestDay.parse(row.harvestDay),
    loggedAt: row.loggedAt,
    kind: TxnKind.fromName(row.kind),
    reference: row.reference,
    note: row.note,
  );

  /// Records one movement. Positive [deltaMinor] deposits, negative
  /// withdraws.
  Future<void> move({
    required MoneyAccount account,
    required int deltaMinor,
    required Currency currency,
    TxnKind kind = TxnKind.manual,
    String? reference,
    String? note,
    HarvestDay? day,
  }) async {
    final uuid = _uuid.v4();
    await _db.transaction(() async {
      await _db
          .into(_db.moneyTxns)
          .insert(
            MoneyTxnsCompanion.insert(
              uuid: uuid,
              account: account.name,
              deltaMinor: deltaMinor,
              currency: Value(currency.code),
              note: Value(note),
              kind: Value(kind.name),
              reference: Value(reference),
              harvestDay: (day ?? HarvestDay.today()).key,
            ),
          );
      await _outbox('money_txns', uuid, 'insert');
    });
  }

  /// Savings → wallet in one gesture (two linked movements).
  Future<void> transferSavingsToWallet({
    required int amountMinor,
    required Currency currency,
    String? note,
  }) => _transfer(
    from: MoneyAccount.savings,
    to: MoneyAccount.wallet,
    amountMinor: amountMinor,
    currency: currency,
    note: note,
  );

  /// Wallet → savings in one gesture (two linked movements).
  Future<void> transferWalletToSavings({
    required int amountMinor,
    required Currency currency,
    String? note,
  }) => _transfer(
    from: MoneyAccount.wallet,
    to: MoneyAccount.savings,
    amountMinor: amountMinor,
    currency: currency,
    note: note,
  );

  Future<void> _transfer({
    required MoneyAccount from,
    required MoneyAccount to,
    required int amountMinor,
    required Currency currency,
    String? note,
  }) async {
    await _db.transaction(() async {
      await move(
        account: from,
        deltaMinor: -amountMinor,
        currency: currency,
        kind: TxnKind.transfer,
        reference: to.name,
        note: note,
      );
      await move(
        account: to,
        deltaMinor: amountMinor,
        currency: currency,
        kind: TxnKind.transfer,
        reference: from.name,
        note: note,
      );
    });
  }

  // ---------------------------------------------------------------- debts

  Stream<List<Debt>> watchDebts() {
    final query = _db.select(_db.debts)
      ..where((d) => d.deletedAt.isNull())
      ..orderBy([
        (d) => OrderingTerm.asc(d.settledAt, nulls: NullsOrder.first),
        (d) => OrderingTerm.asc(d.createdAt),
      ]);
    return query.watch().asyncMap((rows) async {
      final paid = await _paidByDebt();
      return rows
          .map(
            (row) => Debt(
              uuid: row.uuid,
              person: row.person,
              amountMinor: row.amountMinor,
              currency: Currency.fromCode(row.currency),
              paidMinor: paid[row.uuid] ?? 0,
              payOffBy: row.payOffBy == null
                  ? null
                  : HarvestDay.parse(row.payOffBy!),
              remindAt: row.remindAt,
              note: row.note,
              settledAt: row.settledAt,
            ),
          )
          .toList();
    });
  }

  /// Every payment on record, newest first.
  Stream<List<DebtPayment>> watchDebtPayments() =>
      (_db.select(_db.debtPayments)
            ..where((p) => p.deletedAt.isNull())
            ..orderBy([
              (p) => OrderingTerm.desc(p.loggedAt),
              (p) => OrderingTerm.desc(p.rowId),
            ]))
          .watch()
          .map(
            (rows) => rows
                .map(
                  (row) => DebtPayment(
                    uuid: row.uuid,
                    debtUuid: row.debtUuid,
                    amountMinor: row.amountMinor,
                    day: HarvestDay.parse(row.harvestDay),
                    loggedAt: row.loggedAt,
                  ),
                )
                .toList(),
          );

  Future<Map<String, int>> _paidByDebt() async {
    final sum = _db.debtPayments.amountMinor.sum();
    final query = _db.selectOnly(_db.debtPayments)
      ..addColumns([_db.debtPayments.debtUuid, sum])
      ..where(_db.debtPayments.deletedAt.isNull())
      ..groupBy([_db.debtPayments.debtUuid]);
    return {
      for (final row in await query.get())
        row.read(_db.debtPayments.debtUuid)!: row.read(sum) ?? 0,
    };
  }

  Future<void> createDebt({
    required String person,
    required int amountMinor,
    required Currency currency,
    HarvestDay? payOffBy,
    String? remindAt,
    String? note,
  }) async {
    final uuid = _uuid.v4();
    await _db.transaction(() async {
      await _db
          .into(_db.debts)
          .insert(
            DebtsCompanion.insert(
              uuid: uuid,
              person: person,
              amountMinor: amountMinor,
              currency: Value(currency.code),
              payOffBy: Value(payOffBy?.key),
              remindAt: Value(remindAt),
              note: Value(note),
            ),
          );
      await _outbox('debts', uuid, 'insert');
    });
  }

  /// Pays part (or all) of a debt; settles it when fully paid. With
  /// [fromWallet] the money also leaves the wallet as a debt-kind row.
  Future<void> payDebt(
    String debtUuid,
    int amountMinor, {
    bool fromWallet = false,
    String? note,
  }) async {
    final paymentUuid = _uuid.v4();
    await _db.transaction(() async {
      final debt = await (_db.select(
        _db.debts,
      )..where((d) => d.uuid.equals(debtUuid))).getSingle();
      await _db
          .into(_db.debtPayments)
          .insert(
            DebtPaymentsCompanion.insert(
              uuid: paymentUuid,
              debtUuid: debtUuid,
              amountMinor: amountMinor,
              harvestDay: HarvestDay.today().key,
            ),
          );
      await _outbox('debt_payments', paymentUuid, 'insert');

      if (fromWallet) {
        await move(
          account: MoneyAccount.wallet,
          deltaMinor: -amountMinor,
          currency: Currency.fromCode(debt.currency),
          kind: TxnKind.debt,
          reference: debt.person,
          note: note,
        );
      }

      final paid = (await _paidByDebt())[debtUuid] ?? 0;
      if (paid >= debt.amountMinor && debt.settledAt == null) {
        await (_db.update(
          _db.debts,
        )..where((d) => d.uuid.equals(debtUuid))).write(
          DebtsCompanion(
            settledAt: Value(DateTime.now()),
            updatedAt: Value(DateTime.now()),
          ),
        );
        await _outbox('debts', debtUuid, 'update');
      }
    });
  }

  /// Hard-deletes movements, debts and payments soft-deleted longer
  /// than [olderThan] ago.
  Future<void> purgeDeleted({required Duration olderThan}) async {
    final cutoff = DateTime.now().subtract(olderThan);
    await _db.transaction(() async {
      await (_db.delete(_db.moneyTxns)
            ..where((t) => t.deletedAt.isSmallerThanValue(cutoff)))
          .go();
      await (_db.delete(_db.debtPayments)
            ..where((p) => p.deletedAt.isSmallerThanValue(cutoff)))
          .go();
      await (_db.delete(_db.debts)
            ..where((d) => d.deletedAt.isSmallerThanValue(cutoff)))
          .go();
    });
  }

  Future<void> _outbox(String table, String uuid, String op) => _db
      .into(_db.outbox)
      .insert(
        OutboxCompanion.insert(
          targetTable: table,
          rowUuid: uuid,
          op: op,
        ),
      );
}

@Riverpod(keepAlive: true)
VaultRepository vaultRepository(Ref ref) =>
    VaultRepository(ref.watch(databaseProvider));
