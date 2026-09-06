import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/db/database_provider.dart';
import 'package:harvest/features/export/domain/archive_layout.dart';
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

  /// The workbook rows alone — the file tree is [readArchive].
  Future<ExportData> read({DateTime? generatedAt}) async =>
      (await readArchive(generatedAt: generatedAt)).data;

  /// Everything the archive is written from, in one pass.
  ///
  /// The rows and the files have to be computed together: the sheet
  /// says where each file went, and the names are only unique once
  /// the collisions have been resolved (ADR-007 rule 4).
  Future<ArchiveContents> readArchive({DateTime? generatedAt}) async {
    final seeds = await _db.select(_db.commitments).get();
    final checkIns = await _db.select(_db.checkIns).get();
    final seedNotes = await _db.select(_db.seedNotes).get();
    final expenses = await _db.select(_db.expenses).get();
    final money = await _db.select(_db.moneyTxns).get();
    final debts = await _db.select(_db.debts).get();
    final payments = await _db.select(_db.debtPayments).get();
    final focus = await _db.select(_db.pomodoroSessions).get();
    final ledger = await _db.select(_db.ledger).get();
    final streaks = await _db.select(_db.streaks).get();
    final settings = await _db.select(_db.kvSettings).get();
    final noteRows = await _db.select(_db.notes).get();
    final albumRows = await _db.select(_db.albums).get();
    final memoryRows = await _db.select(_db.memories).get();

    final taken = <String>{};
    final noteFiles = <({String path, String body})>[];
    final noteRowsOut = <List<Object?>>[];
    for (final row in noteRows) {
      final path = notePath(
        title: row.title,
        folder: row.folder,
        taken: taken,
      );
      // A deleted note keeps its row so the merge can see it, but it
      // does not get a file — the vault is what I still have.
      if (row.deletedAt == null) {
        noteFiles.add((path: path, body: row.body));
      }
      noteRowsOut.add([
        row.uuid,
        row.title,
        row.folder,
        if (row.deletedAt == null) path else null,
        row.body,
        _at(row.createdAt),
        _at(row.updatedAt),
        _at(row.deletedAt),
      ]);
    }

    final albumNames = {for (final row in albumRows) row.uuid: row.name};
    final memoryFiles = <({String path, String storedPath})>[];
    final memoryRowsOut = <List<Object?>>[];
    for (final row in memoryRows) {
      // A memory in the trash keeps its row and its file: the archive
      // carries the trash as it stands, so an import does not quietly
      // resurrect what I threw away.
      final path = memoryPath(
        albumName: albumNames[row.albumUuid] ?? 'Album',
        day: row.harvestDay,
        storedPath: row.path,
        taken: taken,
      );
      memoryFiles.add((path: path, storedPath: row.path));
      memoryRowsOut.add([
        row.uuid,
        row.albumUuid,
        row.harvestDay,
        path,
        row.path,
        row.kind,
        row.note,
        _at(row.capturedAt),
        _at(row.updatedAt),
        _at(row.deletedAt),
      ]);
    }

    final data = (
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
            row.archiveNote,
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
      seedNotes: [
        for (final row in seedNotes)
          [
            row.uuid,
            row.commitmentUuid,
            row.harvestDay,
            row.body,
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
      notes: noteRowsOut,
      albums: [
        for (final row in albumRows)
          [
            row.uuid,
            row.name,
            albumFolder(row.name),
            row.scheduleJson,
            row.remindAt,
            row.note,
            _at(row.createdAt),
            _at(row.updatedAt),
            _at(row.deletedAt),
          ],
      ],
      memories: memoryRowsOut,
    );

    return (data: data, notes: noteFiles, memories: memoryFiles);
  }
}

@Riverpod(keepAlive: true)
ExportRepository exportRepository(Ref ref) =>
    ExportRepository(ref.watch(databaseProvider));
