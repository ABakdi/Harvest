import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/db/database_provider.dart';
import 'package:harvest/features/export/domain/harvest_workbook.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'export_repository.g.dart';

/// Reads the whole database into flat rows for the workbook.
///
/// It goes to the tables directly rather than through the feature
/// repositories on purpose: those filter to what a screen should show —
/// active, undeleted, most recent — and an export that quietly drops
/// rows is not a backup (rule X7).
class ExportRepository {
  ExportRepository(this._db);

  final HarvestDatabase _db;

  /// Timestamps go out as ISO-8601 text: unambiguous, sorts correctly,
  /// and no spreadsheet has to guess at a serial date.
  static String? _at(DateTime? value) => value?.toIso8601String();

  Future<ExportData> read({DateTime? generatedAt}) async {
    final seeds = await _db.select(_db.commitments).get();
    final checkIns = await _db.select(_db.checkIns).get();
    final expenses = await _db.select(_db.expenses).get();
    final money = await _db.select(_db.moneyTxns).get();
    final debts = await _db.select(_db.debts).get();
    final payments = await _db.select(_db.debtPayments).get();
    final focus = await _db.select(_db.pomodoroSessions).get();
    final ledger = await _db.select(_db.ledger).get();
    final streaks = await _db.select(_db.streaks).get();
    final settings = await _db.select(_db.kvSettings).get();

    return (
      generatedAt: generatedAt ?? DateTime.now(),
      seeds: [
        for (final row in seeds)
          [
            row.uuid,
            row.type,
            row.title,
            row.scheduleJson,
            row.totalTarget,
            row.dailyCommitment,
            row.dueDay,
            row.note,
            row.remindAt,
            row.deadline,
            _at(row.pausedAt),
            _at(row.archivedAt),
            _at(row.deletedAt),
            _at(row.createdAt),
            _at(row.updatedAt),
          ],
      ],
      checkIns: [
        for (final row in checkIns)
          [
            row.uuid,
            row.commitmentUuid,
            row.harvestDay,
            row.quantity,
            _at(row.loggedAt),
            _at(row.deletedAt),
          ],
      ],
      expenses: [
        for (final row in expenses)
          [
            row.uuid,
            row.harvestDay,
            row.category,
            row.currency,
            row.amountMinor,
            row.note,
            _at(row.loggedAt),
            _at(row.deletedAt),
          ],
      ],
      money: [
        for (final row in money)
          [
            row.uuid,
            row.harvestDay,
            row.account,
            row.kind,
            row.reference,
            row.currency,
            row.deltaMinor,
            row.note,
            row.linkUuid,
            _at(row.loggedAt),
            _at(row.deletedAt),
          ],
      ],
      debts: [
        for (final row in debts)
          [
            row.uuid,
            row.person,
            row.currency,
            row.amountMinor,
            row.payOffBy,
            row.remindAt,
            row.note,
            _at(row.settledAt),
            _at(row.createdAt),
            _at(row.deletedAt),
            _at(row.updatedAt),
          ],
      ],
      debtPayments: [
        for (final row in payments)
          [
            row.uuid,
            row.debtUuid,
            row.harvestDay,
            row.amountMinor,
            _at(row.loggedAt),
            _at(row.deletedAt),
          ],
      ],
      focus: [
        for (final row in focus)
          [
            row.uuid,
            row.commitmentUuid,
            row.harvestDay,
            row.focusBlocks,
            _at(row.startedAt),
            _at(row.endedAt),
          ],
      ],
      ledger: [
        for (final row in ledger)
          [
            row.uuid,
            row.kind,
            row.delta,
            row.reason,
            row.harvestDay,
            _at(row.loggedAt),
          ],
      ],
      streaks: [
        for (final row in streaks)
          [
            row.scope,
            row.current,
            row.best,
            row.lastEarnedDay,
            row.freezesStored,
            _at(row.updatedAt),
          ],
      ],
      settings: [
        for (final row in settings)
          [row.key, row.valueJson, _at(row.updatedAt)],
      ],
    );
  }
}

@Riverpod(keepAlive: true)
ExportRepository exportRepository(Ref ref) =>
    ExportRepository(ref.watch(databaseProvider));
