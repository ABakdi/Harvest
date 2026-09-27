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

  /// All balances per account+currency, as of [asOf] (the Harvest Day
  /// by default): a movement dated after it is logged ahead and counts
  /// on its day, not before ([[Finances]]).
  Stream<Map<(MoneyAccount, Currency), int>> watchBalances({
    HarvestDay? asOf,
  }) {
    final today = (asOf ?? HarvestDay.today()).key;
    final query = _db.select(_db.moneyTxns)
      ..where(
        (t) => t.deletedAt.isNull() & t.harvestDay.isSmallerOrEqualValue(today),
      );
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

  /// Movements newest first, by the day each counts on (one logged
  /// ahead sits on top, under its own day) — one pot's ledger when
  /// [account] is given, every pot otherwise.
  Stream<List<MoneyTxn>> watchTxns({MoneyAccount? account, int limit = 60}) {
    final query = _db.select(_db.moneyTxns)
      ..where((t) => t.deletedAt.isNull())
      ..orderBy([
        (t) => OrderingTerm.desc(t.harvestDay),
        (t) => OrderingTerm.desc(t.loggedAt),
        (t) => OrderingTerm.desc(t.rowId),
      ])
      ..limit(limit);
    if (account != null) {
      query.where((t) => t.account.equals(account.name));
    }
    return query.watch().map((rows) => rows.map(_toTxn).toList());
  }

  /// Every movement in a span, newest first — the Insights page's
  /// ledger, which is bounded by dates rather than by a row count.
  Stream<List<MoneyTxn>> watchTxnsBetween(HarvestDay from, HarvestDay to) {
    final query = _db.select(_db.moneyTxns)
      ..where(
        (t) =>
            t.harvestDay.isBiggerOrEqualValue(from.key) &
            t.harvestDay.isSmallerOrEqualValue(to.key) &
            t.deletedAt.isNull(),
      )
      ..orderBy([
        (t) => OrderingTerm.desc(t.harvestDay),
        (t) => OrderingTerm.desc(t.loggedAt),
        (t) => OrderingTerm.desc(t.rowId),
      ]);
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
    day: HarvestDay.tryParse(row.harvestDay) ?? HarvestDay.of(row.loggedAt),
    loggedAt: row.loggedAt,
    kind: TxnKind.fromName(row.kind),
    reference: row.reference,
    note: row.note,
  );

  /// What one pot holds in one currency today: deleted rows and ones
  /// logged ahead aside, as [watchBalances] counts it.
  Future<int> balanceOf(MoneyAccount account, Currency currency) async {
    final sum = _db.moneyTxns.deltaMinor.sum();
    final query = _db.selectOnly(_db.moneyTxns)
      ..addColumns([sum])
      ..where(
        _db.moneyTxns.account.equals(account.name) &
            _db.moneyTxns.currency.equals(currency.code) &
            _db.moneyTxns.deletedAt.isNull() &
            _db.moneyTxns.harvestDay.isSmallerOrEqualValue(
              HarvestDay.today().key,
            ),
      );
    return (await query.getSingle()).read(sum) ?? 0;
  }

  /// Refuses to take [amountMinor] out of a pot that does not hold it.
  /// The sheets cap the amount too, but a sheet opened before a sync
  /// emptied the pot is stale; the repository is where the rule holds
  /// ([[Web]] Money writes, [[Audit-v3]] Q5-18).
  Future<void> _refuseOverdraw(
    MoneyAccount account,
    Currency currency,
    int amountMinor,
  ) async {
    if (amountMinor <= 0) return;
    if (await balanceOf(account, currency) < amountMinor) {
      throw ArgumentError.value(
        amountMinor,
        'amountMinor',
        'more than the ${account.name} holds',
      );
    }
  }

  /// Records one movement. Positive [deltaMinor] deposits, negative
  /// withdraws; a hand-made withdrawal never takes a pot below zero
  /// (throws [ArgumentError]). An expense's movement follows its
  /// expense, which may be logged whatever the wallet holds.
  Future<void> move({
    required MoneyAccount account,
    required int deltaMinor,
    required Currency currency,
    TxnKind kind = TxnKind.manual,
    String? reference,
    String? linkUuid,
    String? note,
    HarvestDay? day,
  }) async {
    final uuid = _uuid.v4();
    await _db.transaction(() async {
      if (kind == TxnKind.manual && deltaMinor < 0) {
        await _refuseOverdraw(account, currency, -deltaMinor);
      }
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
              linkUuid: Value(linkUuid),
              harvestDay: (day ?? HarvestDay.today()).key,
            ),
          );
      await _outbox('money_txns', uuid, 'insert');
    });
  }

  /// The movement that belongs to [linkUuid] (an expense, a payment),
  /// or null when that row was never paid from a pot. With
  /// [includeDeleted], a live one first and then the one deleted last:
  /// the one that went with its owner, not an older row an edit dropped.
  Future<MoneyTxn?> linkedTxn(
    String linkUuid, {
    bool includeDeleted = false,
  }) async {
    final query = _db.select(_db.moneyTxns)
      ..where((t) => t.linkUuid.equals(linkUuid))
      ..orderBy([
        (t) => OrderingTerm.desc(t.deletedAt, nulls: NullsOrder.first),
      ])
      ..limit(1);
    if (!includeDeleted) query.where((t) => t.deletedAt.isNull());
    final row = await query.getSingleOrNull();
    return row == null ? null : _toTxn(row);
  }

  /// The movement [linkUuid] owns that was deleted at [deletedAt]: the
  /// one that went with its owner, never an older row an edit dropped
  /// ([[Audit-v3]] Q5-16).
  Future<MoneyTxnRow?> linkedRowDeletedAt(
    String linkUuid,
    DateTime? deletedAt,
  ) async {
    if (deletedAt == null) return null;
    final rows =
        await (_db.select(
              _db.moneyTxns,
            )..where(
              (t) => t.linkUuid.equals(linkUuid) & t.deletedAt.isNotNull(),
            ))
            .get();
    for (final row in rows) {
      if (row.deletedAt == deletedAt) return row;
    }
    return null;
  }

  /// Re-points a linked movement at an edited amount or category.
  Future<void> updateLinked(
    String uuid, {
    required int deltaMinor,
    required Currency currency,
    String? reference,
    String? note,
    HarvestDay? day,
  }) => _db.transaction(() async {
    await (_db.update(_db.moneyTxns)..where((t) => t.uuid.equals(uuid))).write(
      MoneyTxnsCompanion(
        deltaMinor: Value(deltaMinor),
        currency: Value(currency.code),
        reference: Value(reference),
        note: Value(note),
        harvestDay: day == null ? const Value.absent() : Value(day.key),
        updatedAt: Value(DateTime.now()),
      ),
    );
    await _outbox('money_txns', uuid, 'update');
  });

  /// Soft-deletes one movement (the expense behind it went away). [at]
  /// stamps it with its owner's moment, so an Undo can tell the two
  /// belonged together.
  Future<void> removeTxn(String uuid, {DateTime? at}) =>
      _db.transaction(() async {
        final now = at ?? DateTime.now();
        await (_db.update(
          _db.moneyTxns,
        )..where((t) => t.uuid.equals(uuid))).write(
          MoneyTxnsCompanion(
            deletedAt: Value(now),
            updatedAt: Value(now),
          ),
        );
        await _outbox('money_txns', uuid, 'delete');
      });

  /// Puts a soft-deleted movement back (undo).
  Future<void> restoreTxn(String uuid) => _db.transaction(() async {
    await (_db.update(_db.moneyTxns)..where((t) => t.uuid.equals(uuid))).write(
      MoneyTxnsCompanion(
        deletedAt: const Value(null),
        updatedAt: Value(DateTime.now()),
      ),
    );
    await _outbox('money_txns', uuid, 'update');
  });

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
      await _refuseOverdraw(from, currency, amountMinor);
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

  /// Every debt with what has been paid on it. The join reads from
  /// `debt_payments` too, so a partial payment re-emits and a card's
  /// remaining amount is never stale.
  Stream<List<Debt>> watchDebts() {
    final paid = _db.debtPayments.amountMinor.sum();
    final query =
        _db.select(_db.debts).join([
            leftOuterJoin(
              _db.debtPayments,
              _db.debtPayments.debtUuid.equalsExp(_db.debts.uuid) &
                  _db.debtPayments.deletedAt.isNull(),
            ),
          ])
          ..addColumns([paid])
          ..where(_db.debts.deletedAt.isNull())
          ..groupBy([_db.debts.uuid])
          ..orderBy([
            OrderingTerm.asc(_db.debts.settledAt, nulls: NullsOrder.first),
            OrderingTerm.asc(_db.debts.createdAt),
          ]);
    return query.watch().map(
      (rows) => rows.map((row) {
        final debt = row.readTable(_db.debts);
        return Debt(
          uuid: debt.uuid,
          person: debt.person,
          amountMinor: debt.amountMinor,
          currency: Currency.fromCode(debt.currency),
          paidMinor: row.read(paid) ?? 0,
          payOffBy: HarvestDay.tryParse(debt.payOffBy),
          remindAt: debt.remindAt,
          note: debt.note,
          settledAt: debt.settledAt,
        );
      }).toList(),
    );
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
                    day:
                        HarvestDay.tryParse(row.harvestDay) ??
                        HarvestDay.of(row.loggedAt),
                    loggedAt: row.loggedAt,
                  ),
                )
                .toList(),
          );

  /// What has been paid on each debt, by uuid — the one place that
  /// adds payments up, for the vault and the planner alike.
  Future<Map<String, int>> paidByDebt() => _paidByDebt();

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

  /// Moves one debt's daily reminder, and nothing else about it.
  Future<void> setDebtRemindAt(String uuid, String? remindAt) =>
      _db.transaction(() async {
        await (_db.update(_db.debts)..where((d) => d.uuid.equals(uuid))).write(
          DebtsCompanion(
            remindAt: Value(remindAt),
            updatedAt: Value(DateTime.now()),
          ),
        );
        await _outbox('debts', uuid, 'update');
      });

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
  ///
  /// Throws [ArgumentError] for a non-positive amount, a payment beyond
  /// what is still owed, or a debt already settled or deleted — a
  /// ledger that accepts nonsense is worse than one that refuses.
  Future<void> payDebt(
    String debtUuid,
    int amountMinor, {
    bool fromWallet = false,
    String? note,
    HarvestDay? day,
  }) async {
    if (amountMinor <= 0) {
      throw ArgumentError.value(amountMinor, 'amountMinor', 'must be positive');
    }
    final paymentUuid = _uuid.v4();
    await _db.transaction(() async {
      final debt =
          await (_db.select(
                _db.debts,
              )..where((d) => d.uuid.equals(debtUuid) & d.deletedAt.isNull()))
              .getSingleOrNull();
      if (debt == null) {
        throw ArgumentError.value(debtUuid, 'debtUuid', 'no such debt');
      }
      if (debt.settledAt != null) {
        throw ArgumentError.value(debtUuid, 'debtUuid', 'already settled');
      }
      final alreadyPaid = (await _paidByDebt())[debtUuid] ?? 0;
      if (alreadyPaid + amountMinor > debt.amountMinor) {
        throw ArgumentError.value(
          amountMinor,
          'amountMinor',
          'more than the ${debt.amountMinor - alreadyPaid} still owed',
        );
      }
      if (fromWallet) {
        await _refuseOverdraw(
          MoneyAccount.wallet,
          Currency.fromCode(debt.currency),
          amountMinor,
        );
      }
      await _db
          .into(_db.debtPayments)
          .insert(
            DebtPaymentsCompanion.insert(
              uuid: paymentUuid,
              debtUuid: debtUuid,
              amountMinor: amountMinor,
              harvestDay: (day ?? HarvestDay.today()).key,
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
          linkUuid: paymentUuid,
          note: note,
          day: day,
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

  /// Removes a payment logged by mistake: the payment goes to the
  /// trash, the wallet movement it made goes with it, and a debt it
  /// had settled reopens ([[Audit-v2-Beta]] N-01). The mirror of
  /// [payDebt], the way an expense's remove mirrors its log.
  Future<void> removePayment(String uuid) => _db.transaction(() async {
    final payment =
        await (_db.select(
              _db.debtPayments,
            )..where((p) => p.uuid.equals(uuid) & p.deletedAt.isNull()))
            .getSingleOrNull();
    if (payment == null) return;
    final now = DateTime.now();
    await (_db.update(_db.debtPayments)..where((p) => p.uuid.equals(uuid)))
        .write(DebtPaymentsCompanion(deletedAt: Value(now)));
    await _outbox('debt_payments', uuid, 'delete');

    final linked = await linkedTxn(uuid);
    if (linked != null) await removeTxn(linked.uuid, at: now);
    await _settleIfPaid(payment.debtUuid);
  });

  /// Puts a removed payment back, wallet movement and settlement too.
  ///
  /// The world may have moved while Undo was showing: the debt paid
  /// again, the wallet spent. So the payment comes back under the same
  /// rules as a new one: never past what is owed, never out of a wallet
  /// that no longer holds it, never onto a debt that is gone. Throws
  /// [ArgumentError] otherwise ([[Audit-v3]] Q5-17).
  Future<void> restorePayment(String uuid) => _db.transaction(() async {
    final payment =
        await (_db.select(
              _db.debtPayments,
            )..where((p) => p.uuid.equals(uuid) & p.deletedAt.isNotNull()))
            .getSingleOrNull();
    if (payment == null) return;
    final debt =
        await (_db.select(_db.debts)..where(
              (d) => d.uuid.equals(payment.debtUuid) & d.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    if (debt == null) {
      throw ArgumentError.value(payment.debtUuid, 'debtUuid', 'no such debt');
    }
    final paid = (await _paidByDebt())[debt.uuid] ?? 0;
    if (paid + payment.amountMinor > debt.amountMinor) {
      throw ArgumentError.value(
        payment.amountMinor,
        'amountMinor',
        'more than the ${debt.amountMinor - paid} still owed',
      );
    }
    final linked = await linkedRowDeletedAt(uuid, payment.deletedAt);
    if (linked != null &&
        linked.harvestDay.compareTo(HarvestDay.today().key) <= 0) {
      await _refuseOverdraw(
        MoneyAccount.values.byName(linked.account),
        Currency.fromCode(linked.currency),
        -linked.deltaMinor,
      );
    }
    await (_db.update(_db.debtPayments)..where((p) => p.uuid.equals(uuid)))
        .write(const DebtPaymentsCompanion(deletedAt: Value(null)));
    await _outbox('debt_payments', uuid, 'update');

    if (linked != null) await restoreTxn(linked.uuid);
    await _settleIfPaid(payment.debtUuid);
  });

  /// Corrects a debt: who, how much, when, the reminder and the note
  /// ([[Finances]] The Vault). The amount never drops below what has
  /// been paid, and the currency cannot change under payments made in
  /// the old one. A new amount settles or reopens the debt to match.
  /// Throws [ArgumentError] for anything else.
  Future<void> updateDebt({
    required String uuid,
    required String person,
    required int amountMinor,
    required Currency currency,
    HarvestDay? payOffBy,
    String? remindAt,
    String? note,
  }) async {
    final name = person.trim();
    if (name.isEmpty) {
      throw ArgumentError.value(person, 'person', 'must not be empty');
    }
    if (amountMinor <= 0) {
      throw ArgumentError.value(amountMinor, 'amountMinor', 'must be positive');
    }
    await _db.transaction(() async {
      final debt =
          await (_db.select(
                _db.debts,
              )..where((d) => d.uuid.equals(uuid) & d.deletedAt.isNull()))
              .getSingleOrNull();
      if (debt == null) {
        throw ArgumentError.value(uuid, 'uuid', 'no such debt');
      }
      final paid = (await _paidByDebt())[uuid] ?? 0;
      if (amountMinor < paid) {
        throw ArgumentError.value(
          amountMinor,
          'amountMinor',
          'less than the $paid already paid',
        );
      }
      if (paid > 0 && currency.code != debt.currency) {
        throw ArgumentError.value(
          currency.code,
          'currency',
          'payments were made in ${debt.currency}',
        );
      }
      final trimmedNote = note?.trim();
      await (_db.update(_db.debts)..where((d) => d.uuid.equals(uuid))).write(
        DebtsCompanion(
          person: Value(name),
          amountMinor: Value(amountMinor),
          currency: Value(currency.code),
          payOffBy: Value(payOffBy?.key),
          remindAt: Value(remindAt),
          note: Value(
            trimmedNote == null || trimmedNote.isEmpty ? null : trimmedNote,
          ),
          updatedAt: Value(DateTime.now()),
        ),
      );
      await _outbox('debts', uuid, 'update');
      await _settleIfPaid(uuid);
    });
  }

  /// Removes a debt logged by mistake, and its payments with it, under
  /// one stamp so [restoreDebt] brings back exactly those. The wallet
  /// movements the payments made stay: that money did leave the wallet.
  Future<void> deleteDebt(String uuid) => _db.transaction(() async {
    final now = DateTime.now();
    final changed =
        await (_db.update(
          _db.debts,
        )..where((d) => d.uuid.equals(uuid) & d.deletedAt.isNull())).write(
          DebtsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
        );
    if (changed == 0) return;
    await _outbox('debts', uuid, 'delete');
    final payments =
        await (_db.select(_db.debtPayments)..where(
              (p) => p.debtUuid.equals(uuid) & p.deletedAt.isNull(),
            ))
            .get();
    for (final payment in payments) {
      await (_db.update(_db.debtPayments)
            ..where((p) => p.uuid.equals(payment.uuid)))
          .write(DebtPaymentsCompanion(deletedAt: Value(now)));
      await _outbox('debt_payments', payment.uuid, 'delete');
    }
  });

  /// The Undo for [deleteDebt]: the debt and the payments that went
  /// with it, and none that were removed on their own before.
  Future<void> restoreDebt(String uuid) => _db.transaction(() async {
    final debt =
        await (_db.select(
              _db.debts,
            )..where((d) => d.uuid.equals(uuid) & d.deletedAt.isNotNull()))
            .getSingleOrNull();
    if (debt == null) return;
    final stamp = debt.deletedAt;
    await (_db.update(_db.debts)..where((d) => d.uuid.equals(uuid))).write(
      DebtsCompanion(
        deletedAt: const Value(null),
        updatedAt: Value(DateTime.now()),
      ),
    );
    await _outbox('debts', uuid, 'update');
    final payments =
        await (_db.select(_db.debtPayments)..where(
              (p) => p.debtUuid.equals(uuid) & p.deletedAt.isNotNull(),
            ))
            .get();
    for (final payment in payments) {
      if (payment.deletedAt != stamp) continue;
      await (_db.update(_db.debtPayments)
            ..where((p) => p.uuid.equals(payment.uuid)))
          .write(const DebtPaymentsCompanion(deletedAt: Value(null)));
      await _outbox('debt_payments', payment.uuid, 'update');
    }
    await _settleIfPaid(uuid);
  });

  /// Settles a debt that is now fully paid, and reopens one that is
  /// not — whichever the payments add up to.
  Future<void> _settleIfPaid(String debtUuid) async {
    final debt = await (_db.select(
      _db.debts,
    )..where((d) => d.uuid.equals(debtUuid))).getSingleOrNull();
    if (debt == null) return;
    final paid = (await _paidByDebt())[debtUuid] ?? 0;
    final settled = paid >= debt.amountMinor;
    if (settled == (debt.settledAt != null)) return;
    await (_db.update(_db.debts)..where((d) => d.uuid.equals(debtUuid))).write(
      DebtsCompanion(
        settledAt: Value(settled ? DateTime.now() : null),
        updatedAt: Value(DateTime.now()),
      ),
    );
    await _outbox('debts', debtUuid, 'update');
  }

  /// Hard-deletes movements, debts and payments soft-deleted longer
  /// than [olderThan] ago.
  Future<void> purgeDeleted({required Duration olderThan}) async {
    final cutoff = DateTime.now().subtract(olderThan);
    await _db.transaction(() async {
      await (_db.delete(
        _db.moneyTxns,
      )..where((t) => t.deletedAt.isSmallerThanValue(cutoff))).go();
      await (_db.delete(
        _db.debtPayments,
      )..where((p) => p.deletedAt.isSmallerThanValue(cutoff))).go();
      await (_db.delete(
        _db.debts,
      )..where((d) => d.deletedAt.isSmallerThanValue(cutoff))).go();
    });
  }

  Future<void> _outbox(String table, String uuid, String op) =>
      _db.logChange(table, uuid, op);
}

@Riverpod(keepAlive: true)
VaultRepository vaultRepository(Ref ref) =>
    VaultRepository(ref.watch(databaseProvider));
