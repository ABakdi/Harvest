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
    final stepRows = await _db.select(_db.stepDays).get();
    final weightRows = await _db.select(_db.bodyWeights).get();
    final sleepRows = await _db.select(_db.sleepSessions).get();
    final exerciseRows = await _db.select(_db.exercises).get();
    final programRows = await _db.select(_db.programs).get();
    final dayRows = await _db.select(_db.programDays).get();
    final slotRows = await _db.select(_db.programSlots).get();
    final targetRows = await _db.select(_db.targetSets).get();
    final maxRows = await _db.select(_db.trainingMaxes).get();
    final sessionRows = await _db.select(_db.workoutSessions).get();
    final sessionExerciseRows = await _db.select(_db.sessionExercises).get();
    final setRows = await _db.select(_db.workoutSets).get();

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
            _at(row.updatedAt),
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
            _at(row.updatedAt),
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
            _at(row.updatedAt),
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
            _at(row.updatedAt),
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
      steps: [
        for (final row in stepRows)
          [
            row.harvestDay,
            row.steps,
            row.lastCounter,
            _at(row.updatedAt),
          ],
      ],
      weights: [
        for (final row in weightRows)
          [
            row.uuid,
            row.harvestDay,
            row.grams,
            row.note,
            _at(row.measuredAt),
            _at(row.updatedAt),
            _at(row.deletedAt),
          ],
      ],
      sleep: [
        for (final row in sleepRows)
          [
            row.uuid,
            row.harvestDay,
            _at(row.fellAsleepAt),
            _at(row.wokeAt),
            row.targetMinutes,
            row.restedStars,
            row.note,
            _at(row.createdAt),
            _at(row.updatedAt),
            _at(row.deletedAt),
          ],
      ],
      exercises: [
        for (final row in exerciseRows)
          [
            row.uuid,
            row.name,
            row.bodyPart,
            row.equipment,
            row.target,
            row.note,
            _at(row.createdAt),
            _at(row.updatedAt),
            _at(row.deletedAt),
          ],
      ],
      programs: [
        for (final row in programRows)
          [
            row.uuid,
            row.name,
            row.note,
            row.weeks,
            row.commitmentUuid,
            row.albumUuid,
            row.photoPrompt,
            _at(row.createdAt),
            _at(row.updatedAt),
            _at(row.deletedAt),
          ],
      ],
      programDays: [
        for (final row in dayRows)
          [row.uuid, row.programUuid, row.name, row.position, row.week],
      ],
      programSlots: [
        for (final row in slotRows)
          [
            row.uuid,
            row.dayUuid,
            row.exerciseId,
            row.position,
            row.restSeconds,
            row.barGrams,
            row.note,
          ],
      ],
      targetSets: [
        for (final row in targetRows)
          [
            row.uuid,
            row.slotUuid,
            row.position,
            row.reps,
            row.weightGrams,
            row.percentTenths,
            row.openEnded,
          ],
      ],
      trainingMaxes: [
        for (final row in maxRows)
          [
            row.programUuid,
            row.exerciseId,
            row.grams,
            _at(row.updatedAt),
          ],
      ],
      sessions: [
        for (final row in sessionRows)
          [
            row.uuid,
            row.programUuid,
            row.dayUuid,
            row.title,
            row.harvestDay,
            row.note,
            _at(row.startedAt),
            _at(row.endedAt),
            _at(row.pausedAt),
            row.pausedSeconds,
            _at(row.updatedAt),
            _at(row.deletedAt),
          ],
      ],
      sessionExercises: [
        for (final row in sessionExerciseRows)
          [
            row.uuid,
            row.sessionUuid,
            row.position,
            row.exerciseId,
            row.plannedExerciseId,
            row.slotUuid,
            row.skipped,
            row.note,
            row.restSeconds,
            row.barGrams,
          ],
      ],
      sets: [
        for (final row in setRows)
          [
            row.uuid,
            row.sessionExerciseUuid,
            row.position,
            row.weightGrams,
            row.reps,
            row.done,
            row.targetLabel,
            row.openEnded,
            _at(row.loggedAt),
          ],
      ],
    );

    return (data: data, notes: noteFiles, memories: memoryFiles);
  }
}

@Riverpod(keepAlive: true)
ExportRepository exportRepository(Ref ref) =>
    ExportRepository(ref.watch(databaseProvider));
