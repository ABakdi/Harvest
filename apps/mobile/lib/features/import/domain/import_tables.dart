part of 'import_service.dart';

/// How one sheet merges into one table.
///
/// The importer is this list and one loop over it. It used to be
/// twenty-six hand-written blocks, and the Streaks sheet went missing
/// among them for a whole release ([[Audit-v2-Beta]] B-02, Q2-04);
/// a table that is not in this list is now a sheet the preview
/// visibly ignores, not a silent omission.
class _Table {
  const _Table({
    required this.sheet,
    required this.keyOf,
    required this.localStamps,
    required this.insert,
    this.stampColumn,
    this.accept,
  });

  final String sheet;

  /// The row's identity: a uuid, a scope, a day, a key.
  final String? Function(_Row row) keyOf;

  /// The column that says how new the row is. Null for a child row
  /// that has no timestamp of its own — a target set is not edited, it
  /// is replaced — which is added when missing and otherwise left
  /// alone, the conservative half of the merge rule.
  final String? stampColumn;

  /// Every local row's identity and stamp.
  final Future<Map<String, DateTime>> Function(HarvestDatabase db) localStamps;

  final Future<void> Function(HarvestDatabase db, _Row row) insert;

  /// Rows the archive may not set at all; null accepts every row.
  final bool Function(_Row row)? accept;
}

// ------------------------------------------------------------ helpers

/// On the local clock, the spelling the app writes: an older export
/// spelled some times in UTC with a `Z`.
DateTime? _time(String? value) =>
    value == null || value.isEmpty ? null : DateTime.tryParse(value)?.toLocal();

double? _double(String? value) {
  if (value == null || value.isEmpty) return null;
  return double.tryParse(value);
}

int? _int(String? value) {
  if (value == null || value.isEmpty) return null;
  return int.tryParse(value) ?? double.tryParse(value)?.round();
}

/// A spreadsheet writes booleans half a dozen ways, and a person
/// editing one writes them a seventh. Anything that is not plainly
/// true is false.
bool _bool(String? value) {
  final text = value?.trim().toLowerCase();
  return text == 'true' || text == '1' || text == 'yes';
}

/// The stamp for a child row that has none of its own — always older
/// than anything incoming, so an existing row is never overwritten
/// by one that cannot prove it is newer.
final DateTime _epoch = DateTime.fromMillisecondsSinceEpoch(0);

DateTime _now() => DateTime.now();

String? _uuid(_Row row) => row['Uuid'];

/// Every uuid-keyed table's local stamps, from a column of its own.
Future<Map<String, DateTime>> _stamps<T extends Table, R>(
  HarvestDatabase db,
  TableInfo<T, R> table,
  String Function(R row) key,
  DateTime Function(R row) stamp,
) async => {
  for (final row in await db.select(table).get()) key(row): stamp(row),
};

// ------------------------------------------------------------- tables

/// Sheet by sheet, parents first. A stamp column of `UpdatedAt` is
/// used wherever the table has one — a soft delete writes
/// `updated_at` and never `logged_at`, so stamping on the latter let
/// a deletion lose every merge ([[Audit-v2-Beta]] B-05).
final List<_Table> _tables = [
  _Table(
    sheet: SheetNames.seeds,
    keyOf: _uuid,
    stampColumn: 'UpdatedAt',
    localStamps: (db) =>
        _stamps(db, db.commitments, (r) => r.uuid, (r) => r.updatedAt),
    insert: (db, row) => db
        .into(db.commitments)
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
            goalUuid: Value(row['GoalUuid']),
            pausedAt: Value(_time(row['PausedAt'])),
            archivedAt: Value(_time(row['ArchivedAt'])),
            archiveNote: Value(row['ArchiveNote']),
            deletedAt: Value(_time(row['DeletedAt'])),
            createdAt: Value(_time(row['CreatedAt']) ?? _now()),
            updatedAt: Value(_time(row['UpdatedAt']) ?? _now()),
          ),
        ),
  ),
  _Table(
    sheet: SheetNames.goals,
    keyOf: _uuid,
    stampColumn: 'UpdatedAt',
    localStamps: (db) =>
        _stamps(db, db.goals, (r) => r.uuid, (r) => r.updatedAt),
    insert: (db, row) => db
        .into(db.goals)
        .insertOnConflictUpdate(
          GoalsCompanion.insert(
            uuid: row['Uuid']!,
            title: row['Title'] ?? '',
            why: Value(row['Why'] ?? ''),
            targetDay: Value(row['TargetDay']),
            status: Value(row['Status'] ?? 'active'),
            statusNote: Value(row['StatusNote']),
            achievedAt: Value(_time(row['AchievedAt'])),
            position: Value(_int(row['Position']) ?? 0),
            createdAt: Value(_time(row['CreatedAt']) ?? _now()),
            updatedAt: Value(_time(row['UpdatedAt']) ?? _now()),
            deletedAt: Value(_time(row['DeletedAt'])),
          ),
        ),
  ),
  _Table(
    sheet: SheetNames.goalItems,
    keyOf: _uuid,
    stampColumn: 'UpdatedAt',
    localStamps: (db) =>
        _stamps(db, db.goalItems, (r) => r.uuid, (r) => r.updatedAt),
    insert: (db, row) => db
        .into(db.goalItems)
        .insertOnConflictUpdate(
          GoalItemsCompanion.insert(
            uuid: row['Uuid']!,
            goalUuid: row['GoalUuid'] ?? '',
            kind: Value(row['Kind'] ?? 'step'),
            body: row['Body'] ?? '',
            note: Value(row['Note']),
            doneAt: Value(_time(row['DoneAt'])),
            position: Value(_int(row['Position']) ?? 0),
            commitmentUuid: Value(row['CommitmentUuid']),
            // Absent before v24: every item is top-level.
            parentUuid: Value(row['ParentUuid']),
            createdAt: Value(_time(row['CreatedAt']) ?? _now()),
            updatedAt: Value(_time(row['UpdatedAt']) ?? _now()),
            deletedAt: Value(_time(row['DeletedAt'])),
          ),
        ),
  ),
  _Table(
    sheet: SheetNames.lists,
    keyOf: _uuid,
    stampColumn: 'UpdatedAt',
    localStamps: (db) =>
        _stamps(db, db.lists, (r) => r.uuid, (r) => r.updatedAt),
    insert: (db, row) => db
        .into(db.lists)
        .insertOnConflictUpdate(
          ListsCompanion.insert(
            uuid: row['Uuid']!,
            name: row['Name'] ?? '',
            kind: Value(row['Kind'] ?? 'plain'),
            icon: Value(row['Icon']),
            position: Value(_int(row['Position']) ?? 0),
            builtIn: Value(row['BuiltIn']),
            createdAt: Value(_time(row['CreatedAt']) ?? _now()),
            updatedAt: Value(_time(row['UpdatedAt']) ?? _now()),
            deletedAt: Value(_time(row['DeletedAt'])),
          ),
        ),
  ),
  _Table(
    sheet: SheetNames.wishlist,
    keyOf: _uuid,
    stampColumn: 'UpdatedAt',
    localStamps: (db) =>
        _stamps(db, db.wishlistItems, (r) => r.uuid, (r) => r.updatedAt),
    insert: (db, row) => db
        .into(db.wishlistItems)
        .insertOnConflictUpdate(
          WishlistItemsCompanion.insert(
            uuid: row['Uuid']!,
            list: Value(row['List'] ?? 'buy'),
            // An archive from before lists has no ListUuid; its List
            // names the shopping list, as a pulled row's would.
            listUuid: Value(
              row['ListUuid'] ?? listUuidOfItem(list: row['List'] ?? 'buy'),
            ),
            title: row['Title'] ?? '',
            priceMinor: Value(_int(row['PriceMinor'])),
            currency: Value(row['Currency'] ?? 'DZD'),
            note: Value(row['Note']),
            targetDay: Value(row['TargetDay']),
            mediaType: Value(row['MediaType']),
            link: Value(row['Link']),
            creator: Value(row['Creator']),
            startedAt: Value(_time(row['StartedAt'])),
            rating: Value(switch (_int(row['Rating'])) {
              final stars? when stars >= 1 && stars <= 5 => stars,
              _ => null,
            }),
            seedUuid: Value(row['SeedUuid']),
            noteUuid: Value(row['NoteUuid']),
            boughtAt: Value(_time(row['BoughtAt'])),
            position: Value(_int(row['Position']) ?? 0),
            createdAt: Value(_time(row['CreatedAt']) ?? _now()),
            updatedAt: Value(_time(row['UpdatedAt']) ?? _now()),
            deletedAt: Value(_time(row['DeletedAt'])),
          ),
        ),
  ),
  _Table(
    sheet: SheetNames.checkIns,
    keyOf: _uuid,
    stampColumn: 'UpdatedAt',
    localStamps: (db) =>
        _stamps(db, db.checkIns, (r) => r.uuid, (r) => r.updatedAt),
    insert: (db, row) => db
        .into(db.checkIns)
        .insertOnConflictUpdate(
          CheckInsCompanion.insert(
            uuid: row['Uuid']!,
            commitmentUuid: row['CommitmentUuid'] ?? '',
            harvestDay: row['HarvestDay'] ?? '',
            quantity: Value(_int(row['Quantity']) ?? 1),
            loggedAt: Value(_time(row['LoggedAt']) ?? _now()),
            // An archive from before the column existed carries no
            // UpdatedAt; the row is then as new as it was logged.
            updatedAt: Value(
              _time(row['UpdatedAt']) ?? _time(row['LoggedAt']) ?? _now(),
            ),
            deletedAt: Value(_time(row['DeletedAt'])),
          ),
        ),
  ),
  _Table(
    sheet: SheetNames.seedNotes,
    keyOf: _uuid,
    stampColumn: 'UpdatedAt',
    localStamps: (db) =>
        _stamps(db, db.seedNotes, (r) => r.uuid, (r) => r.updatedAt),
    insert: (db, row) => db
        .into(db.seedNotes)
        .insertOnConflictUpdate(
          SeedNotesCompanion.insert(
            uuid: row['Uuid']!,
            commitmentUuid: row['CommitmentUuid'] ?? '',
            harvestDay: row['HarvestDay'] ?? '',
            body: row['Body'] ?? '',
            loggedAt: Value(_time(row['LoggedAt']) ?? _now()),
            updatedAt: Value(
              _time(row['UpdatedAt']) ?? _time(row['LoggedAt']) ?? _now(),
            ),
            deletedAt: Value(_time(row['DeletedAt'])),
          ),
        ),
  ),
  _Table(
    sheet: SheetNames.expenses,
    keyOf: _uuid,
    stampColumn: 'UpdatedAt',
    localStamps: (db) =>
        _stamps(db, db.expenses, (r) => r.uuid, (r) => r.updatedAt),
    insert: (db, row) => db
        .into(db.expenses)
        .insertOnConflictUpdate(
          ExpensesCompanion.insert(
            uuid: row['Uuid']!,
            harvestDay: row['HarvestDay'] ?? '',
            category: row['Category'] ?? '',
            currency: Value(row['Currency'] ?? 'DZD'),
            amountMinor: _int(row['AmountMinor']) ?? 0,
            note: Value(row['Note']),
            loggedAt: Value(_time(row['LoggedAt']) ?? _now()),
            updatedAt: Value(
              _time(row['UpdatedAt']) ?? _time(row['LoggedAt']) ?? _now(),
            ),
            deletedAt: Value(_time(row['DeletedAt'])),
          ),
        ),
  ),
  // The categories I made, so a restored phone has a name and an icon
  // for every key its expenses use ([[Audit-v2]] Q3-02).
  _Table(
    sheet: SheetNames.categories,
    keyOf: _uuid,
    stampColumn: 'UpdatedAt',
    localStamps: (db) => _stamps(
      db,
      db.expenseCategories,
      (r) => r.uuid,
      (r) => r.updatedAt,
    ),
    insert: (db, row) => db
        .into(db.expenseCategories)
        .insertOnConflictUpdate(
          ExpenseCategoriesCompanion.insert(
            uuid: row['Uuid']!,
            name: row['Name'] ?? '',
            icon: row['Icon'] ?? '',
            // Missing from an archive made before v21; the list then
            // orders it by UpdatedAt, as it always had.
            createdAt: Value(_time(row['CreatedAt'])),
            updatedAt: Value(_time(row['UpdatedAt']) ?? _now()),
            deletedAt: Value(_time(row['DeletedAt'])),
          ),
        ),
  ),
  _Table(
    sheet: SheetNames.money,
    keyOf: _uuid,
    stampColumn: 'UpdatedAt',
    localStamps: (db) =>
        _stamps(db, db.moneyTxns, (r) => r.uuid, (r) => r.updatedAt),
    insert: (db, row) => db
        .into(db.moneyTxns)
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
            loggedAt: Value(_time(row['LoggedAt']) ?? _now()),
            updatedAt: Value(
              _time(row['UpdatedAt']) ?? _time(row['LoggedAt']) ?? _now(),
            ),
            deletedAt: Value(_time(row['DeletedAt'])),
          ),
        ),
  ),
  _Table(
    sheet: SheetNames.debts,
    keyOf: _uuid,
    stampColumn: 'UpdatedAt',
    localStamps: (db) =>
        _stamps(db, db.debts, (r) => r.uuid, (r) => r.updatedAt),
    insert: (db, row) => db
        .into(db.debts)
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
            createdAt: Value(_time(row['CreatedAt']) ?? _now()),
            deletedAt: Value(_time(row['DeletedAt'])),
            updatedAt: Value(_time(row['UpdatedAt']) ?? _now()),
          ),
        ),
  ),
  _Table(
    sheet: SheetNames.debtPayments,
    keyOf: _uuid,
    stampColumn: 'LoggedAt',
    localStamps: (db) =>
        _stamps(db, db.debtPayments, (r) => r.uuid, (r) => r.loggedAt),
    insert: (db, row) => db
        .into(db.debtPayments)
        .insertOnConflictUpdate(
          DebtPaymentsCompanion.insert(
            uuid: row['Uuid']!,
            debtUuid: row['DebtUuid'] ?? '',
            harvestDay: row['HarvestDay'] ?? '',
            amountMinor: _int(row['AmountMinor']) ?? 0,
            loggedAt: Value(_time(row['LoggedAt']) ?? _now()),
            deletedAt: Value(_time(row['DeletedAt'])),
          ),
        ),
  ),
  _Table(
    sheet: SheetNames.focus,
    keyOf: _uuid,
    stampColumn: 'StartedAt',
    localStamps: (db) =>
        _stamps(db, db.pomodoroSessions, (r) => r.uuid, (r) => r.startedAt),
    insert: (db, row) => db
        .into(db.pomodoroSessions)
        .insertOnConflictUpdate(
          PomodoroSessionsCompanion.insert(
            uuid: row['Uuid']!,
            commitmentUuid: Value(row['CommitmentUuid']),
            harvestDay: row['HarvestDay'] ?? '',
            focusBlocks: Value(_int(row['FocusBlocks']) ?? 0),
            startedAt: _time(row['StartedAt']) ?? _now(),
            endedAt: Value(_time(row['EndedAt'])),
          ),
        ),
  ),
  _Table(
    sheet: SheetNames.ledger,
    keyOf: _uuid,
    stampColumn: 'LoggedAt',
    localStamps: (db) =>
        _stamps(db, db.ledger, (r) => r.uuid, (r) => r.loggedAt),
    insert: (db, row) => db
        .into(db.ledger)
        .insertOnConflictUpdate(
          LedgerCompanion.insert(
            uuid: row['Uuid']!,
            kind: row['Kind'] ?? 'xp',
            delta: _int(row['Delta']) ?? 0,
            reason: row['Reason'] ?? '',
            harvestDay: row['HarvestDay'] ?? '',
            loggedAt: Value(_time(row['LoggedAt']) ?? _now()),
          ),
        ),
  ),
  // The streak rows: derived state, but derived from history this
  // phone may not have, so they come across like everything else
  // and the newer copy wins ([[Audit-v2-Beta]] B-02).
  _Table(
    sheet: SheetNames.streaks,
    keyOf: (row) => row['Scope'],
    stampColumn: 'UpdatedAt',
    localStamps: (db) =>
        _stamps(db, db.streaks, (r) => r.scope, (r) => r.updatedAt),
    insert: (db, row) => db
        .into(db.streaks)
        .insertOnConflictUpdate(
          StreaksCompanion.insert(
            scope: row['Scope']!,
            current: Value(_int(row['Current']) ?? 0),
            best: Value(_int(row['Best']) ?? 0),
            lastEarnedDay: Value(row['LastEarnedDay']),
            freezesStored: Value(_int(row['FreezesStored']) ?? 0),
            updatedAt: Value(_time(row['UpdatedAt']) ?? _now()),
          ),
        ),
  ),
  _Table(
    sheet: SheetNames.notes,
    keyOf: _uuid,
    stampColumn: 'UpdatedAt',
    localStamps: (db) =>
        _stamps(db, db.notes, (r) => r.uuid, (r) => r.updatedAt),
    insert: (db, row) => db
        .into(db.notes)
        .insertOnConflictUpdate(
          NotesCompanion.insert(
            uuid: row['Uuid']!,
            title: row['Title'] ?? '',
            folder: Value(row['Folder'] ?? ''),
            // The `.md` in the zip wins over the cell: someone may
            // have edited the vault in a text editor, and rule N4
            // says that has to survive. `_bodies` is filled per run.
            body: Value(
              ImportService._bodies[row['File'] ?? ''] ?? row['Body'] ?? '',
            ),
            createdAt: Value(_time(row['CreatedAt']) ?? _now()),
            updatedAt: Value(_time(row['UpdatedAt']) ?? _now()),
            deletedAt: Value(_time(row['DeletedAt'])),
          ),
        ),
  ),
  _Table(
    sheet: SheetNames.albums,
    keyOf: _uuid,
    stampColumn: 'UpdatedAt',
    localStamps: (db) =>
        _stamps(db, db.albums, (r) => r.uuid, (r) => r.updatedAt),
    insert: (db, row) => db
        .into(db.albums)
        .insertOnConflictUpdate(
          AlbumsCompanion.insert(
            uuid: row['Uuid']!,
            name: row['Name'] ?? '',
            scheduleJson: Value(row['ScheduleJson']),
            remindAt: Value(row['RemindAt']),
            note: Value(row['Note']),
            createdAt: Value(_time(row['CreatedAt']) ?? _now()),
            updatedAt: Value(_time(row['UpdatedAt']) ?? _now()),
            deletedAt: Value(_time(row['DeletedAt'])),
          ),
        ),
  ),
  // (Recordings are merged by hand right after the notes, and
  // memories right after the albums: see _mergeAll.)
  _Table(
    sheet: SheetNames.steps,
    keyOf: (row) => row['HarvestDay'],
    stampColumn: 'UpdatedAt',
    localStamps: (db) =>
        _stamps(db, db.stepDays, (r) => r.harvestDay, (r) => r.updatedAt),
    insert: (db, row) => db
        .into(db.stepDays)
        .insertOnConflictUpdate(
          StepDaysCompanion.insert(
            harvestDay: row['HarvestDay']!,
            steps: Value(_int(row['Steps']) ?? 0),
            lastCounter: Value(_int(row['LastCounter'])),
            updatedAt: Value(_time(row['UpdatedAt']) ?? _now()),
          ),
        ),
  ),
  _Table(
    sheet: SheetNames.weights,
    keyOf: _uuid,
    stampColumn: 'UpdatedAt',
    localStamps: (db) =>
        _stamps(db, db.bodyWeights, (r) => r.uuid, (r) => r.updatedAt),
    insert: (db, row) => db
        .into(db.bodyWeights)
        .insertOnConflictUpdate(
          BodyWeightsCompanion.insert(
            uuid: row['Uuid']!,
            harvestDay: row['HarvestDay'] ?? '',
            grams: _int(row['Grams']) ?? 0,
            note: Value(row['Note']),
            measuredAt: Value(_time(row['MeasuredAt']) ?? _now()),
            updatedAt: Value(
              _time(row['UpdatedAt']) ?? _time(row['MeasuredAt']) ?? _now(),
            ),
            deletedAt: Value(_time(row['DeletedAt'])),
          ),
        ),
  ),
  _Table(
    sheet: SheetNames.sleep,
    keyOf: _uuid,
    stampColumn: 'UpdatedAt',
    localStamps: (db) =>
        _stamps(db, db.sleepSessions, (r) => r.uuid, (r) => r.updatedAt),
    insert: (db, row) => db
        .into(db.sleepSessions)
        .insertOnConflictUpdate(
          SleepSessionsCompanion.insert(
            uuid: row['Uuid']!,
            harvestDay: row['HarvestDay'] ?? '',
            fellAsleepAt: _time(row['FellAsleepAt']) ?? _now(),
            wokeAt: _time(row['WokeAt']) ?? _now(),
            targetMinutes: _int(row['TargetMinutes']) ?? 0,
            restedStars: Value(_int(row['RestedStars'])),
            note: Value(row['Note']),
            createdAt: Value(_time(row['CreatedAt']) ?? _now()),
            updatedAt: Value(_time(row['UpdatedAt']) ?? _now()),
            deletedAt: Value(_time(row['DeletedAt'])),
          ),
        ),
  ),
  _Table(
    sheet: SheetNames.exercises,
    keyOf: _uuid,
    stampColumn: 'UpdatedAt',
    localStamps: (db) =>
        _stamps(db, db.exercises, (r) => r.uuid, (r) => r.updatedAt),
    insert: (db, row) => db
        .into(db.exercises)
        .insertOnConflictUpdate(
          ExercisesCompanion.insert(
            uuid: row['Uuid']!,
            name: row['Name'] ?? '',
            bodyPart: Value(row['BodyPart']),
            equipment: Value(row['Equipment']),
            target: Value(row['Target']),
            note: Value(row['Note']),
            createdAt: Value(_time(row['CreatedAt']) ?? _now()),
            updatedAt: Value(_time(row['UpdatedAt']) ?? _now()),
            deletedAt: Value(_time(row['DeletedAt'])),
          ),
        ),
  ),
  _Table(
    sheet: SheetNames.programs,
    keyOf: _uuid,
    stampColumn: 'UpdatedAt',
    localStamps: (db) =>
        _stamps(db, db.programs, (r) => r.uuid, (r) => r.updatedAt),
    insert: (db, row) => db
        .into(db.programs)
        .insertOnConflictUpdate(
          ProgramsCompanion.insert(
            uuid: row['Uuid']!,
            name: row['Name'] ?? '',
            note: Value(row['Note']),
            weeks: Value(_int(row['Weeks'])),
            commitmentUuid: Value(row['CommitmentUuid']),
            albumUuid: Value(row['AlbumUuid']),
            photoPrompt: Value(row['PhotoPrompt'] ?? 'after'),
            createdAt: Value(_time(row['CreatedAt']) ?? _now()),
            updatedAt: Value(_time(row['UpdatedAt']) ?? _now()),
            deletedAt: Value(_time(row['DeletedAt'])),
          ),
        ),
  ),
  _Table(
    sheet: SheetNames.programDays,
    keyOf: _uuid,
    localStamps: (db) =>
        _stamps(db, db.programDays, (r) => r.uuid, (_) => _epoch),
    insert: (db, row) => db
        .into(db.programDays)
        .insertOnConflictUpdate(
          ProgramDaysCompanion.insert(
            uuid: row['Uuid']!,
            programUuid: row['ProgramUuid'] ?? '',
            name: row['Name'] ?? '',
            position: _int(row['Position']) ?? 0,
            week: Value(_int(row['Week'])),
            // Older archives have no column: keep what is here.
            accessories: row.containsKey('Accessories')
                ? Value(row['Accessories'])
                : const Value.absent(),
          ),
        ),
  ),
  _Table(
    sheet: SheetNames.programSlots,
    keyOf: _uuid,
    localStamps: (db) =>
        _stamps(db, db.programSlots, (r) => r.uuid, (_) => _epoch),
    insert: (db, row) => db
        .into(db.programSlots)
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
  ),
  _Table(
    sheet: SheetNames.targetSets,
    keyOf: _uuid,
    localStamps: (db) =>
        _stamps(db, db.targetSets, (r) => r.uuid, (_) => _epoch),
    insert: (db, row) => db
        .into(db.targetSets)
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
  ),
  _Table(
    sheet: SheetNames.trainingMaxes,
    keyOf: (row) => row['ProgramUuid'] == null || row['ExerciseId'] == null
        ? null
        : '${row['ProgramUuid']}/${row['ExerciseId']}',
    stampColumn: 'UpdatedAt',
    localStamps: (db) => _stamps(
      db,
      db.trainingMaxes,
      (r) => '${r.programUuid}/${r.exerciseId}',
      (r) => r.updatedAt,
    ),
    insert: (db, row) => db
        .into(db.trainingMaxes)
        .insertOnConflictUpdate(
          TrainingMaxesCompanion.insert(
            programUuid: row['ProgramUuid']!,
            exerciseId: row['ExerciseId']!,
            grams: _int(row['Grams']) ?? 0,
            updatedAt: Value(_time(row['UpdatedAt']) ?? _now()),
          ),
        ),
  ),
  _Table(
    sheet: SheetNames.sessions,
    keyOf: _uuid,
    stampColumn: 'UpdatedAt',
    localStamps: (db) =>
        _stamps(db, db.workoutSessions, (r) => r.uuid, (r) => r.updatedAt),
    insert: (db, row) => db
        .into(db.workoutSessions)
        .insertOnConflictUpdate(
          WorkoutSessionsCompanion.insert(
            uuid: row['Uuid']!,
            programUuid: Value(row['ProgramUuid']),
            dayUuid: Value(row['DayUuid']),
            title: Value(row['Title']),
            harvestDay: row['HarvestDay'] ?? '',
            note: Value(row['Note']),
            startedAt: Value(_time(row['StartedAt']) ?? _now()),
            endedAt: Value(_time(row['EndedAt'])),
            pausedAt: Value(_time(row['PausedAt'])),
            pausedSeconds: Value(_int(row['PausedSeconds']) ?? 0),
            updatedAt: Value(
              _time(row['UpdatedAt']) ?? _time(row['StartedAt']) ?? _now(),
            ),
            deletedAt: Value(_time(row['DeletedAt'])),
          ),
        ),
  ),
  _Table(
    sheet: SheetNames.sessionExercises,
    keyOf: _uuid,
    localStamps: (db) =>
        _stamps(db, db.sessionExercises, (r) => r.uuid, (_) => _epoch),
    insert: (db, row) => db
        .into(db.sessionExercises)
        .insertOnConflictUpdate(
          SessionExercisesCompanion.insert(
            uuid: row['Uuid']!,
            sessionUuid: row['SessionUuid'] ?? '',
            position: _int(row['Position']) ?? 0,
            exerciseId: row['ExerciseId'] ?? '',
            plannedExerciseId: Value(row['PlannedExerciseId']),
            slotUuid: Value(row['SlotUuid']),
            skipped: Value(_bool(row['Skipped'])),
            skipReason: Value(row['SkipReason']),
            note: Value(row['Note']),
            restSeconds: Value(_int(row['RestSeconds'])),
            barGrams: Value(_int(row['BarGrams']) ?? 20000),
          ),
        ),
  ),
  _Table(
    sheet: SheetNames.sets,
    keyOf: _uuid,
    stampColumn: 'LoggedAt',
    localStamps: (db) =>
        _stamps(db, db.workoutSets, (r) => r.uuid, (r) => r.loggedAt),
    insert: (db, row) => db
        .into(db.workoutSets)
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
            loggedAt: Value(_time(row['LoggedAt']) ?? _now()),
          ),
        ),
  ),
  _Table(
    sheet: SheetNames.settings,
    keyOf: (row) => row['Key'],
    stampColumn: 'UpdatedAt',
    accept: (row) => isImportableSetting(row['Key'] ?? ''),
    localStamps: (db) =>
        _stamps(db, db.kvSettings, (r) => r.key, (r) => r.updatedAt),
    insert: (db, row) => db
        .into(db.kvSettings)
        .insertOnConflictUpdate(
          KvSettingsCompanion.insert(
            key: row['Key']!,
            valueJson: row['Value'] ?? '',
            updatedAt: Value(_time(row['UpdatedAt']) ?? _now()),
          ),
        ),
  ),
  // Places. A point without both coordinates is not a point, so a
  // blank cell reads as 0,0 rather than failing the table; the
  // archive I wrote never has one. A place's notes came later (v20):
  // an older archive has no column, which reads as no notes.
  _Table(
    sheet: SheetNames.savedPlaces,
    keyOf: _uuid,
    stampColumn: 'UpdatedAt',
    localStamps: (db) =>
        _stamps(db, db.savedPlaces, (r) => r.uuid, (r) => r.updatedAt),
    insert: (db, row) => db
        .into(db.savedPlaces)
        .insertOnConflictUpdate(
          SavedPlacesCompanion.insert(
            uuid: row['Uuid']!,
            name: row['Name'] ?? '',
            latitude: _double(row['Latitude']) ?? 0,
            longitude: _double(row['Longitude']) ?? 0,
            radiusM: Value(_double(row['RadiusM']) ?? 100),
            notes: Value(row['Notes']),
            createdAt: Value(_time(row['CreatedAt']) ?? _now()),
            updatedAt: Value(_time(row['UpdatedAt']) ?? _now()),
            deletedAt: Value(_time(row['DeletedAt'])),
          ),
        ),
  ),
  _Table(
    sheet: SheetNames.locationPoints,
    keyOf: _uuid,
    stampColumn: 'UpdatedAt',
    localStamps: (db) =>
        _stamps(db, db.locationPoints, (r) => r.uuid, (r) => r.updatedAt),
    insert: (db, row) => db
        .into(db.locationPoints)
        .insertOnConflictUpdate(
          LocationPointsCompanion.insert(
            uuid: row['Uuid']!,
            harvestDay: row['HarvestDay'] ?? '',
            recordedAt: _time(row['RecordedAt']) ?? _now(),
            latitude: _double(row['Latitude']) ?? 0,
            longitude: _double(row['Longitude']) ?? 0,
            accuracyM: Value(_double(row['AccuracyM'])),
            speedMps: Value(_double(row['SpeedMps'])),
            altitudeM: Value(_double(row['AltitudeM'])),
            updatedAt: Value(
              _time(row['UpdatedAt']) ?? _time(row['RecordedAt']) ?? _now(),
            ),
            deletedAt: Value(_time(row['DeletedAt'])),
          ),
        ),
  ),
  _Table(
    sheet: SheetNames.geotags,
    keyOf: _uuid,
    stampColumn: 'UpdatedAt',
    localStamps: (db) =>
        _stamps(db, db.geotags, (r) => r.uuid, (r) => r.updatedAt),
    insert: (db, row) => db
        .into(db.geotags)
        .insertOnConflictUpdate(
          GeotagsCompanion.insert(
            uuid: row['Uuid']!,
            targetTable: row['TargetTable'] ?? '',
            targetUuid: row['TargetUuid'] ?? '',
            harvestDay: row['HarvestDay'] ?? '',
            at: _time(row['At']) ?? _now(),
            latitude: Value(_double(row['Latitude'])),
            longitude: Value(_double(row['Longitude'])),
            accuracyM: Value(_double(row['AccuracyM'])),
            state: Value(row['State'] ?? 'pending'),
            updatedAt: Value(_time(row['UpdatedAt']) ?? _now()),
            deletedAt: Value(_time(row['DeletedAt'])),
          ),
        ),
  ),
];
