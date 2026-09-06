import 'package:drift/drift.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/db/database_provider.dart';
import 'package:harvest/features/export/domain/harvest_workbook.dart';
import 'package:harvest/features/gallery/data/gallery_storage.dart';
import 'package:harvest/features/import/domain/archive_reader.dart';
import 'package:harvest/features/notes/data/notes_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'import_service.g.dart';

/// What an import would do to one table.
typedef ImportCount = ({int added, int updated, int unchanged});

/// What an import would do, in full, before anything is written.
typedef ImportPreview = ({
  Map<String, ImportCount> tables,

  /// Files in the archive, and how many are not on this phone yet.
  int files,
  int newFiles,
});

/// A totals row for the preview, so a screen does not have to add up.
ImportCount totalOf(ImportPreview preview) {
  var added = 0;
  var updated = 0;
  var unchanged = 0;
  for (final count in preview.tables.values) {
    added += count.added;
    updated += count.updated;
    unchanged += count.unchanged;
  }
  return (added: added, updated: updated, unchanged: unchanged);
}

/// Merges a Harvest archive back into the database.
///
/// Three rules, all from ADR-007 and none of them negotiable:
///
/// * **Merge by uuid.** A row already here is updated only when the
///   incoming copy is newer.
/// * **Nothing local is deleted for being missing.** An archive is a
///   second copy, not an authority.
/// * **Previewed first.** [preview] and [apply] read the same archive
///   the same way, so what was shown is what happens.
class ImportService {
  ImportService(this._db, this._storage);

  final HarvestDatabase _db;
  final GalleryStorage _storage;

  /// What [bundle] would change, without changing it.
  Future<ImportPreview> preview(ArchiveBundle bundle) =>
      _run(bundle, write: false);

  /// Carries the merge out. Every table is its own transaction, so a
  /// failure part-way leaves whole tables rather than half of one.
  Future<ImportPreview> apply(ArchiveBundle bundle) async {
    final result = await _run(bundle, write: true);
    // The link index is derived from the bodies (rule N2), so it is
    // rebuilt rather than imported.
    await NotesRepository(_db).reindexAll();
    return result;
  }

  Future<ImportPreview> _run(
    ArchiveBundle bundle, {
    required bool write,
  }) async {
    final tables = <String, ImportCount>{};

    // Parents before children: an album before its memories, a seed
    // before its check-ins, or a foreign key refuses the row.
    tables[SheetNames.seeds] = await _mergeRows(
      rows: bundle.sheet(SheetNames.seeds),
      write: write,
      localStamps: {
        for (final row in await _db.select(_db.commitments).get())
          row.uuid: row.updatedAt,
      },
      stampOf: (row) => _time(row['UpdatedAt']),
      keyOf: (row) => row['Uuid'],
      insert: (row) => _db
          .into(_db.commitments)
          .insertOnConflictUpdate(
            CommitmentsCompanion.insert(
              uuid: row['Uuid']!,
              type: row['Type'] ?? 'habit',
              title: row['Title'] ?? '',
              scheduleJson: Value(row['Schedule']),
              totalTarget: Value(_int(row['TotalTarget'])),
              dailyCommitment: Value(_int(row['DailyCommitment'])),
              dueDay: Value(row['DueDay']),
              note: Value(row['Note']),
              remindAt: Value(row['RemindAt']),
              deadline: Value(row['Deadline']),
              pausedAt: Value(_time(row['PausedAt'])),
              archivedAt: Value(_time(row['ArchivedAt'])),
              archiveNote: Value(row['ArchiveNote']),
              deletedAt: Value(_time(row['DeletedAt'])),
              createdAt: Value(_time(row['CreatedAt']) ?? DateTime.now()),
              updatedAt: Value(_time(row['UpdatedAt']) ?? DateTime.now()),
            ),
          ),
    );

    tables[SheetNames.checkIns] = await _mergeRows(
      rows: bundle.sheet(SheetNames.checkIns),
      write: write,
      localStamps: {
        for (final row in await _db.select(_db.checkIns).get())
          row.uuid: row.loggedAt,
      },
      stampOf: (row) => _time(row['LoggedAt']),
      keyOf: (row) => row['Uuid'],
      insert: (row) => _db
          .into(_db.checkIns)
          .insertOnConflictUpdate(
            CheckInsCompanion.insert(
              uuid: row['Uuid']!,
              commitmentUuid: row['CommitmentUuid'] ?? '',
              harvestDay: row['HarvestDay'] ?? '',
              quantity: Value(_int(row['Quantity']) ?? 1),
              loggedAt: Value(_time(row['LoggedAt']) ?? DateTime.now()),
              deletedAt: Value(_time(row['DeletedAt'])),
            ),
          ),
    );

    tables[SheetNames.seedNotes] = await _mergeRows(
      rows: bundle.sheet(SheetNames.seedNotes),
      write: write,
      localStamps: {
        for (final row in await _db.select(_db.seedNotes).get())
          row.uuid: row.loggedAt,
      },
      stampOf: (row) => _time(row['LoggedAt']),
      keyOf: (row) => row['Uuid'],
      insert: (row) => _db
          .into(_db.seedNotes)
          .insertOnConflictUpdate(
            SeedNotesCompanion.insert(
              uuid: row['Uuid']!,
              commitmentUuid: row['CommitmentUuid'] ?? '',
              harvestDay: row['HarvestDay'] ?? '',
              body: row['Body'] ?? '',
              loggedAt: Value(_time(row['LoggedAt']) ?? DateTime.now()),
              deletedAt: Value(_time(row['DeletedAt'])),
            ),
          ),
    );

    tables[SheetNames.expenses] = await _mergeRows(
      rows: bundle.sheet(SheetNames.expenses),
      write: write,
      localStamps: {
        for (final row in await _db.select(_db.expenses).get())
          row.uuid: row.loggedAt,
      },
      stampOf: (row) => _time(row['LoggedAt']),
      keyOf: (row) => row['Uuid'],
      insert: (row) => _db
          .into(_db.expenses)
          .insertOnConflictUpdate(
            ExpensesCompanion.insert(
              uuid: row['Uuid']!,
              harvestDay: row['HarvestDay'] ?? '',
              category: row['Category'] ?? '',
              currency: Value(row['Currency'] ?? 'DZD'),
              amountMinor: _int(row['AmountMinor']) ?? 0,
              note: Value(row['Note']),
              loggedAt: Value(_time(row['LoggedAt']) ?? DateTime.now()),
              deletedAt: Value(_time(row['DeletedAt'])),
            ),
          ),
    );

    tables[SheetNames.money] = await _mergeRows(
      rows: bundle.sheet(SheetNames.money),
      write: write,
      localStamps: {
        for (final row in await _db.select(_db.moneyTxns).get())
          row.uuid: row.loggedAt,
      },
      stampOf: (row) => _time(row['LoggedAt']),
      keyOf: (row) => row['Uuid'],
      insert: (row) => _db
          .into(_db.moneyTxns)
          .insertOnConflictUpdate(
            MoneyTxnsCompanion.insert(
              uuid: row['Uuid']!,
              harvestDay: row['HarvestDay'] ?? '',
              account: row['Account'] ?? '',
              kind: Value(row['Kind'] ?? 'manual'),
              reference: Value(row['Reference']),
              currency: Value(row['Currency'] ?? 'DZD'),
              deltaMinor: _int(row['DeltaMinor']) ?? 0,
              note: Value(row['Note']),
              linkUuid: Value(row['LinkUuid']),
              loggedAt: Value(_time(row['LoggedAt']) ?? DateTime.now()),
              deletedAt: Value(_time(row['DeletedAt'])),
            ),
          ),
    );

    tables[SheetNames.debts] = await _mergeRows(
      rows: bundle.sheet(SheetNames.debts),
      write: write,
      localStamps: {
        for (final row in await _db.select(_db.debts).get())
          row.uuid: row.updatedAt,
      },
      stampOf: (row) => _time(row['UpdatedAt']),
      keyOf: (row) => row['Uuid'],
      insert: (row) => _db
          .into(_db.debts)
          .insertOnConflictUpdate(
            DebtsCompanion.insert(
              uuid: row['Uuid']!,
              person: row['Person'] ?? '',
              currency: Value(row['Currency'] ?? 'DZD'),
              amountMinor: _int(row['AmountMinor']) ?? 0,
              payOffBy: Value(row['PayOffBy']),
              remindAt: Value(row['RemindAt']),
              note: Value(row['Note']),
              settledAt: Value(_time(row['SettledAt'])),
              createdAt: Value(_time(row['CreatedAt']) ?? DateTime.now()),
              deletedAt: Value(_time(row['DeletedAt'])),
              updatedAt: Value(_time(row['UpdatedAt']) ?? DateTime.now()),
            ),
          ),
    );

    tables[SheetNames.debtPayments] = await _mergeRows(
      rows: bundle.sheet(SheetNames.debtPayments),
      write: write,
      localStamps: {
        for (final row in await _db.select(_db.debtPayments).get())
          row.uuid: row.loggedAt,
      },
      stampOf: (row) => _time(row['LoggedAt']),
      keyOf: (row) => row['Uuid'],
      insert: (row) => _db
          .into(_db.debtPayments)
          .insertOnConflictUpdate(
            DebtPaymentsCompanion.insert(
              uuid: row['Uuid']!,
              debtUuid: row['DebtUuid'] ?? '',
              harvestDay: row['HarvestDay'] ?? '',
              amountMinor: _int(row['AmountMinor']) ?? 0,
              loggedAt: Value(_time(row['LoggedAt']) ?? DateTime.now()),
              deletedAt: Value(_time(row['DeletedAt'])),
            ),
          ),
    );

    tables[SheetNames.focus] = await _mergeRows(
      rows: bundle.sheet(SheetNames.focus),
      write: write,
      localStamps: {
        for (final row in await _db.select(_db.pomodoroSessions).get())
          row.uuid: row.startedAt,
      },
      stampOf: (row) => _time(row['StartedAt']),
      keyOf: (row) => row['Uuid'],
      insert: (row) => _db
          .into(_db.pomodoroSessions)
          .insertOnConflictUpdate(
            PomodoroSessionsCompanion.insert(
              uuid: row['Uuid']!,
              commitmentUuid: Value(row['CommitmentUuid']),
              harvestDay: row['HarvestDay'] ?? '',
              focusBlocks: Value(_int(row['FocusBlocks']) ?? 0),
              startedAt: _time(row['StartedAt']) ?? DateTime.now(),
              endedAt: Value(_time(row['EndedAt'])),
            ),
          ),
    );

    tables[SheetNames.ledger] = await _mergeRows(
      rows: bundle.sheet(SheetNames.ledger),
      write: write,
      localStamps: {
        for (final row in await _db.select(_db.ledger).get())
          row.uuid: row.loggedAt,
      },
      stampOf: (row) => _time(row['LoggedAt']),
      keyOf: (row) => row['Uuid'],
      insert: (row) => _db
          .into(_db.ledger)
          .insertOnConflictUpdate(
            LedgerCompanion.insert(
              uuid: row['Uuid']!,
              kind: row['Kind'] ?? 'xp',
              delta: _int(row['Delta']) ?? 0,
              reason: row['Reason'] ?? '',
              harvestDay: row['HarvestDay'] ?? '',
              loggedAt: Value(_time(row['LoggedAt']) ?? DateTime.now()),
            ),
          ),
    );

    tables[SheetNames.notes] = await _mergeRows(
      rows: bundle.sheet(SheetNames.notes),
      write: write,
      localStamps: {
        for (final row in await _db.select(_db.notes).get())
          row.uuid: row.updatedAt,
      },
      stampOf: (row) => _time(row['UpdatedAt']),
      keyOf: (row) => row['Uuid'],
      insert: (row) => _db
          .into(_db.notes)
          .insertOnConflictUpdate(
            NotesCompanion.insert(
              uuid: row['Uuid']!,
              title: row['Title'] ?? '',
              folder: Value(row['Folder'] ?? ''),
              // The `.md` in the zip wins over the cell: someone may
              // have edited the vault in a text editor, and rule N4
              // says that has to survive.
              body: Value(
                bundle.noteBody(row['File'] ?? '') ?? row['Body'] ?? '',
              ),
              createdAt: Value(_time(row['CreatedAt']) ?? DateTime.now()),
              updatedAt: Value(_time(row['UpdatedAt']) ?? DateTime.now()),
              deletedAt: Value(_time(row['DeletedAt'])),
            ),
          ),
    );

    tables[SheetNames.albums] = await _mergeRows(
      rows: bundle.sheet(SheetNames.albums),
      write: write,
      localStamps: {
        for (final row in await _db.select(_db.albums).get())
          row.uuid: row.updatedAt,
      },
      stampOf: (row) => _time(row['UpdatedAt']),
      keyOf: (row) => row['Uuid'],
      insert: (row) => _db
          .into(_db.albums)
          .insertOnConflictUpdate(
            AlbumsCompanion.insert(
              uuid: row['Uuid']!,
              name: row['Name'] ?? '',
              scheduleJson: Value(row['ScheduleJson']),
              remindAt: Value(row['RemindAt']),
              note: Value(row['Note']),
              createdAt: Value(_time(row['CreatedAt']) ?? DateTime.now()),
              updatedAt: Value(_time(row['UpdatedAt']) ?? DateTime.now()),
              deletedAt: Value(_time(row['DeletedAt'])),
            ),
          ),
    );

    // Memories carry a file each, so they are merged by hand: the
    // picture has to land in storage before the row can point at it.
    final memoryResult = await _mergeMemories(bundle, write: write);
    tables[SheetNames.memories] = memoryResult.count;

    // ------------------------------------------------------------ body
    //
    // Parents before children, so a half-applied import leaves rows
    // that still point at something. Several of the child tables carry
    // no timestamp of their own — a target set is not edited, it is
    // replaced — so they are added when missing and otherwise left
    // alone, which is the conservative half of the merge rule.

    tables[SheetNames.steps] = await _mergeRows(
      rows: bundle.sheet(SheetNames.steps),
      write: write,
      localStamps: {
        for (final row in await _db.select(_db.stepDays).get())
          row.harvestDay: row.updatedAt,
      },
      stampOf: (row) => _time(row['UpdatedAt']),
      keyOf: (row) => row['HarvestDay'],
      insert: (row) => _db
          .into(_db.stepDays)
          .insertOnConflictUpdate(
            StepDaysCompanion.insert(
              harvestDay: row['HarvestDay']!,
              steps: Value(_int(row['Steps']) ?? 0),
              lastCounter: Value(_int(row['LastCounter'])),
              updatedAt: Value(_time(row['UpdatedAt']) ?? DateTime.now()),
            ),
          ),
    );

    tables[SheetNames.weights] = await _mergeRows(
      rows: bundle.sheet(SheetNames.weights),
      write: write,
      localStamps: {
        for (final row in await _db.select(_db.bodyWeights).get())
          row.uuid: row.measuredAt,
      },
      stampOf: (row) => _time(row['MeasuredAt']),
      keyOf: (row) => row['Uuid'],
      insert: (row) => _db
          .into(_db.bodyWeights)
          .insertOnConflictUpdate(
            BodyWeightsCompanion.insert(
              uuid: row['Uuid']!,
              harvestDay: row['HarvestDay'] ?? '',
              grams: _int(row['Grams']) ?? 0,
              note: Value(row['Note']),
              measuredAt: Value(_time(row['MeasuredAt']) ?? DateTime.now()),
              deletedAt: Value(_time(row['DeletedAt'])),
            ),
          ),
    );

    tables[SheetNames.sleep] = await _mergeRows(
      rows: bundle.sheet(SheetNames.sleep),
      write: write,
      localStamps: {
        for (final row in await _db.select(_db.sleepSessions).get())
          row.uuid: row.updatedAt,
      },
      stampOf: (row) => _time(row['UpdatedAt']),
      keyOf: (row) => row['Uuid'],
      insert: (row) => _db
          .into(_db.sleepSessions)
          .insertOnConflictUpdate(
            SleepSessionsCompanion.insert(
              uuid: row['Uuid']!,
              harvestDay: row['HarvestDay'] ?? '',
              fellAsleepAt: _time(row['FellAsleepAt']) ?? DateTime.now(),
              wokeAt: _time(row['WokeAt']) ?? DateTime.now(),
              targetMinutes: _int(row['TargetMinutes']) ?? 0,
              restedStars: Value(_int(row['RestedStars'])),
              note: Value(row['Note']),
              createdAt: Value(_time(row['CreatedAt']) ?? DateTime.now()),
              updatedAt: Value(_time(row['UpdatedAt']) ?? DateTime.now()),
              deletedAt: Value(_time(row['DeletedAt'])),
            ),
          ),
    );

    tables[SheetNames.exercises] = await _mergeRows(
      rows: bundle.sheet(SheetNames.exercises),
      write: write,
      localStamps: {
        for (final row in await _db.select(_db.exercises).get())
          row.uuid: row.updatedAt,
      },
      stampOf: (row) => _time(row['UpdatedAt']),
      keyOf: (row) => row['Uuid'],
      insert: (row) => _db
          .into(_db.exercises)
          .insertOnConflictUpdate(
            ExercisesCompanion.insert(
              uuid: row['Uuid']!,
              name: row['Name'] ?? '',
              bodyPart: Value(row['BodyPart']),
              equipment: Value(row['Equipment']),
              target: Value(row['Target']),
              note: Value(row['Note']),
              createdAt: Value(_time(row['CreatedAt']) ?? DateTime.now()),
              updatedAt: Value(_time(row['UpdatedAt']) ?? DateTime.now()),
              deletedAt: Value(_time(row['DeletedAt'])),
            ),
          ),
    );

    tables[SheetNames.programs] = await _mergeRows(
      rows: bundle.sheet(SheetNames.programs),
      write: write,
      localStamps: {
        for (final row in await _db.select(_db.programs).get())
          row.uuid: row.updatedAt,
      },
      stampOf: (row) => _time(row['UpdatedAt']),
      keyOf: (row) => row['Uuid'],
      insert: (row) => _db
          .into(_db.programs)
          .insertOnConflictUpdate(
            ProgramsCompanion.insert(
              uuid: row['Uuid']!,
              name: row['Name'] ?? '',
              note: Value(row['Note']),
              weeks: Value(_int(row['Weeks'])),
              commitmentUuid: Value(row['CommitmentUuid']),
              albumUuid: Value(row['AlbumUuid']),
              photoPrompt: Value(row['PhotoPrompt'] ?? 'after'),
              createdAt: Value(_time(row['CreatedAt']) ?? DateTime.now()),
              updatedAt: Value(_time(row['UpdatedAt']) ?? DateTime.now()),
              deletedAt: Value(_time(row['DeletedAt'])),
            ),
          ),
    );

    tables[SheetNames.programDays] = await _mergeRows(
      rows: bundle.sheet(SheetNames.programDays),
      write: write,
      localStamps: {
        for (final row in await _db.select(_db.programDays).get())
          row.uuid: _epoch,
      },
      stampOf: (_) => null,
      keyOf: (row) => row['Uuid'],
      insert: (row) => _db
          .into(_db.programDays)
          .insertOnConflictUpdate(
            ProgramDaysCompanion.insert(
              uuid: row['Uuid']!,
              programUuid: row['ProgramUuid'] ?? '',
              name: row['Name'] ?? '',
              position: _int(row['Position']) ?? 0,
              week: Value(_int(row['Week'])),
            ),
          ),
    );

    tables[SheetNames.programSlots] = await _mergeRows(
      rows: bundle.sheet(SheetNames.programSlots),
      write: write,
      localStamps: {
        for (final row in await _db.select(_db.programSlots).get())
          row.uuid: _epoch,
      },
      stampOf: (_) => null,
      keyOf: (row) => row['Uuid'],
      insert: (row) => _db
          .into(_db.programSlots)
          .insertOnConflictUpdate(
            ProgramSlotsCompanion.insert(
              uuid: row['Uuid']!,
              dayUuid: row['DayUuid'] ?? '',
              exerciseId: row['ExerciseId'] ?? '',
              position: _int(row['Position']) ?? 0,
              restSeconds: Value(_int(row['RestSeconds'])),
              barGrams: Value(_int(row['BarGrams']) ?? 20000),
              note: Value(row['Note']),
            ),
          ),
    );

    tables[SheetNames.targetSets] = await _mergeRows(
      rows: bundle.sheet(SheetNames.targetSets),
      write: write,
      localStamps: {
        for (final row in await _db.select(_db.targetSets).get())
          row.uuid: _epoch,
      },
      stampOf: (_) => null,
      keyOf: (row) => row['Uuid'],
      insert: (row) => _db
          .into(_db.targetSets)
          .insertOnConflictUpdate(
            TargetSetsCompanion.insert(
              uuid: row['Uuid']!,
              slotUuid: row['SlotUuid'] ?? '',
              position: _int(row['Position']) ?? 0,
              reps: Value(_int(row['Reps'])),
              weightGrams: Value(_int(row['WeightGrams'])),
              percentTenths: Value(_int(row['PercentTenths'])),
              openEnded: Value(_bool(row['OpenEnded'])),
            ),
          ),
    );

    tables[SheetNames.trainingMaxes] = await _mergeRows(
      rows: bundle.sheet(SheetNames.trainingMaxes),
      write: write,
      localStamps: {
        for (final row in await _db.select(_db.trainingMaxes).get())
          '${row.programUuid}/${row.exerciseId}': row.updatedAt,
      },
      stampOf: (row) => _time(row['UpdatedAt']),
      keyOf: (row) => row['ProgramUuid'] == null || row['ExerciseId'] == null
          ? null
          : '${row['ProgramUuid']}/${row['ExerciseId']}',
      insert: (row) => _db
          .into(_db.trainingMaxes)
          .insertOnConflictUpdate(
            TrainingMaxesCompanion.insert(
              programUuid: row['ProgramUuid']!,
              exerciseId: row['ExerciseId']!,
              grams: _int(row['Grams']) ?? 0,
              updatedAt: Value(_time(row['UpdatedAt']) ?? DateTime.now()),
            ),
          ),
    );

    tables[SheetNames.sessions] = await _mergeRows(
      rows: bundle.sheet(SheetNames.sessions),
      write: write,
      localStamps: {
        for (final row in await _db.select(_db.workoutSessions).get())
          row.uuid: row.startedAt,
      },
      stampOf: (row) => _time(row['StartedAt']),
      keyOf: (row) => row['Uuid'],
      insert: (row) => _db
          .into(_db.workoutSessions)
          .insertOnConflictUpdate(
            WorkoutSessionsCompanion.insert(
              uuid: row['Uuid']!,
              programUuid: Value(row['ProgramUuid']),
              dayUuid: Value(row['DayUuid']),
              title: Value(row['Title']),
              harvestDay: row['HarvestDay'] ?? '',
              note: Value(row['Note']),
              startedAt: Value(_time(row['StartedAt']) ?? DateTime.now()),
              endedAt: Value(_time(row['EndedAt'])),
              deletedAt: Value(_time(row['DeletedAt'])),
            ),
          ),
    );

    tables[SheetNames.sessionExercises] = await _mergeRows(
      rows: bundle.sheet(SheetNames.sessionExercises),
      write: write,
      localStamps: {
        for (final row in await _db.select(_db.sessionExercises).get())
          row.uuid: _epoch,
      },
      stampOf: (_) => null,
      keyOf: (row) => row['Uuid'],
      insert: (row) => _db
          .into(_db.sessionExercises)
          .insertOnConflictUpdate(
            SessionExercisesCompanion.insert(
              uuid: row['Uuid']!,
              sessionUuid: row['SessionUuid'] ?? '',
              position: _int(row['Position']) ?? 0,
              exerciseId: row['ExerciseId'] ?? '',
              plannedExerciseId: Value(row['PlannedExerciseId']),
              slotUuid: Value(row['SlotUuid']),
              skipped: Value(_bool(row['Skipped'])),
              note: Value(row['Note']),
              restSeconds: Value(_int(row['RestSeconds'])),
              barGrams: Value(_int(row['BarGrams']) ?? 20000),
            ),
          ),
    );

    tables[SheetNames.sets] = await _mergeRows(
      rows: bundle.sheet(SheetNames.sets),
      write: write,
      localStamps: {
        for (final row in await _db.select(_db.workoutSets).get())
          row.uuid: row.loggedAt,
      },
      stampOf: (row) => _time(row['LoggedAt']),
      keyOf: (row) => row['Uuid'],
      insert: (row) => _db
          .into(_db.workoutSets)
          .insertOnConflictUpdate(
            WorkoutSetsCompanion.insert(
              uuid: row['Uuid']!,
              sessionExerciseUuid: row['SessionExerciseUuid'] ?? '',
              position: _int(row['Position']) ?? 0,
              weightGrams: Value(_int(row['WeightGrams']) ?? 0),
              reps: Value(_int(row['Reps']) ?? 0),
              done: Value(_bool(row['Done'])),
              targetLabel: Value(row['TargetLabel']),
              openEnded: Value(_bool(row['OpenEnded'])),
              loggedAt: Value(_time(row['LoggedAt']) ?? DateTime.now()),
            ),
          ),
    );

    tables[SheetNames.settings] = await _mergeRows(
      rows: bundle.sheet(SheetNames.settings),
      write: write,
      localStamps: {
        for (final row in await _db.select(_db.kvSettings).get())
          row.key: row.updatedAt,
      },
      stampOf: (row) => _time(row['UpdatedAt']),
      keyOf: (row) => row['Key'],
      insert: (row) => _db
          .into(_db.kvSettings)
          .insertOnConflictUpdate(
            KvSettingsCompanion.insert(
              key: row['Key']!,
              valueJson: row['Value'] ?? '',
              updatedAt: Value(_time(row['UpdatedAt']) ?? DateTime.now()),
            ),
          ),
    );

    return (
      tables: tables,
      files: bundle.files.length,
      newFiles: memoryResult.newFiles,
    );
  }

  /// Merge one sheet. Counts what it would do whether or not [write].
  Future<ImportCount> _mergeRows({
    required SheetRows rows,
    required bool write,
    required Map<String, DateTime> localStamps,
    required DateTime? Function(Map<String, String>) stampOf,
    required String? Function(Map<String, String>) keyOf,
    required Future<void> Function(Map<String, String>) insert,
  }) async {
    var added = 0;
    var updated = 0;
    var unchanged = 0;
    final pending = <Map<String, String>>[];

    for (final row in rows) {
      final key = keyOf(row);
      if (key == null || key.isEmpty) continue;
      final local = localStamps[key];
      if (local == null) {
        added++;
        pending.add(row);
        continue;
      }
      final incoming = stampOf(row);
      // Same timestamp is not newer: an archive taken from this phone
      // and put straight back must be a no-op.
      if (incoming != null && incoming.isAfter(local)) {
        updated++;
        pending.add(row);
      } else {
        unchanged++;
      }
    }

    if (write && pending.isNotEmpty) {
      await _db.transaction(() async {
        for (final row in pending) {
          await insert(row);
        }
      });
    }
    return (added: added, updated: updated, unchanged: unchanged);
  }

  /// Memories, and the files behind them.
  Future<({ImportCount count, int newFiles})> _mergeMemories(
    ArchiveBundle bundle, {
    required bool write,
  }) async {
    final local = {
      for (final row in await _db.select(_db.memories).get())
        row.uuid: row.updatedAt,
    };

    var added = 0;
    var updated = 0;
    var unchanged = 0;
    var newFiles = 0;
    final pending = <(Map<String, String>, Uint8List?)>[];

    for (final row in bundle.sheet(SheetNames.memories)) {
      final uuid = row['Uuid'];
      if (uuid == null || uuid.isEmpty) continue;
      final bytes = bundle.files[row['File'] ?? ''];
      final at = local[uuid];
      if (at == null) {
        added++;
        if (bytes != null) newFiles++;
        pending.add((row, bytes));
        continue;
      }
      final incoming = _time(row['UpdatedAt']);
      if (incoming != null && incoming.isAfter(at)) {
        updated++;
        pending.add((row, bytes));
      } else {
        unchanged++;
      }
    }

    if (write) {
      // The files land first, then the rows that point at them, and
      // the rows go in together. A failure part-way can leave a file
      // nothing references — an orphan, which costs space and nothing
      // else — but never a row pointing at a picture that is not there.
      final written = <(Map<String, String>, String)>[];
      for (final (row, bytes) in pending) {
        var path = row['StoredPath'] ?? '';
        if (bytes != null && path.isNotEmpty) {
          // Restoring the file at the path the row already names is
          // what makes an archive taken from this phone and put back
          // a no-op rather than a second copy of everything.
          path = await _storage.write(bytes, path);
        }
        written.add((row, path));
      }
      await _db.transaction(() async {
        for (final (row, path) in written) {
          await _db
              .into(_db.memories)
              .insertOnConflictUpdate(
                MemoriesCompanion.insert(
                  uuid: row['Uuid']!,
                  albumUuid: row['AlbumUuid'] ?? '',
                  harvestDay: row['HarvestDay'] ?? '',
                  path: path,
                  kind: Value(row['Kind'] ?? 'photo'),
                  note: Value(row['Note']),
                  capturedAt: Value(_time(row['CapturedAt']) ?? DateTime.now()),
                  updatedAt: Value(_time(row['UpdatedAt']) ?? DateTime.now()),
                  deletedAt: Value(_time(row['DeletedAt'])),
                ),
              );
        }
      });
    }

    return (
      count: (added: added, updated: updated, unchanged: unchanged),
      newFiles: newFiles,
    );
  }

  static DateTime? _time(String? value) =>
      value == null || value.isEmpty ? null : DateTime.tryParse(value);

  static int? _int(String? value) {
    if (value == null || value.isEmpty) return null;
    return int.tryParse(value) ?? double.tryParse(value)?.round();
  }

  /// A spreadsheet writes booleans half a dozen ways, and a person
  /// editing one writes them a seventh. Anything that is not plainly
  /// true is false.
  static bool _bool(String? value) {
    final text = value?.trim().toLowerCase();
    return text == 'true' || text == '1' || text == 'yes';
  }

  /// The stamp for a child row that has none of its own — always older
  /// than anything incoming, so an existing row is never overwritten
  /// by one that cannot prove it is newer.
  static final DateTime _epoch = DateTime.fromMillisecondsSinceEpoch(0);
}

@Riverpod(keepAlive: true)
ImportService importService(Ref ref) => ImportService(
  ref.watch(databaseProvider),
  ref.watch(galleryStorageProvider),
);
