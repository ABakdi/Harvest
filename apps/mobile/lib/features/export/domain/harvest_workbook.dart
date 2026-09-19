import 'package:harvest/features/export/domain/workbook.dart';

/// Everything the workbook is built from, one list per table.
///
/// Plain rows, already flattened by the repository — the layout below
/// is the only place that knows what a column means, and it never
/// touches Drift.
typedef ExportData = ({
  DateTime generatedAt,
  List<List<Object?>> seeds,
  List<List<Object?>> checkIns,
  List<List<Object?>> seedNotes,
  List<List<Object?>> expenses,
  List<List<Object?>> money,
  List<List<Object?>> debts,
  List<List<Object?>> debtPayments,
  List<List<Object?>> focus,
  List<List<Object?>> ledger,
  List<List<Object?>> streaks,
  List<List<Object?>> settings,
  List<List<Object?>> notes,
  List<List<Object?>> albums,
  List<List<Object?>> memories,
  List<List<Object?>> steps,
  List<List<Object?>> weights,
  List<List<Object?>> sleep,
  List<List<Object?>> exercises,
  List<List<Object?>> programs,
  List<List<Object?>> programDays,
  List<List<Object?>> programSlots,
  List<List<Object?>> targetSets,
  List<List<Object?>> trainingMaxes,
  List<List<Object?>> sessions,
  List<List<Object?>> sessionExercises,
  List<List<Object?>> sets,
});

/// Everything the zip is written from: the rows, and the files the
/// rows point at (ADR-007).
typedef ArchiveContents = ({
  ExportData data,

  /// One `.md` per live note, at the path its row names.
  List<({String path, String body})> notes,

  /// One picture or clip, at the path its row names, read back out of
  /// the gallery directory by [storedPath].
  List<({String path, String storedPath})> memories,
});

/// Sheet names are part of the file's contract with a future sync, so
/// they are constants rather than literals scattered through formulas.
abstract final class SheetNames {
  static const summary = 'Summary';
  static const seeds = 'Seeds';
  static const checkIns = 'CheckIns';
  static const seedNotes = 'SeedNotes';
  static const expenses = 'Expenses';
  static const money = 'Money';
  static const debts = 'Debts';
  static const debtPayments = 'DebtPayments';
  static const focus = 'Focus';
  static const ledger = 'Ledger';
  static const streaks = 'Streaks';
  static const settings = 'Settings';
  static const notes = 'Notes';
  static const albums = 'Albums';
  static const memories = 'Memories';
  static const steps = 'Steps';
  static const weights = 'Weights';
  static const sleep = 'Sleep';

  /// Only the exercises I wrote. The 1324 in the bundled catalogue are
  /// not mine and do not belong in my archive.
  static const exercises = 'Exercises';
  static const programs = 'Programs';
  static const programDays = 'ProgramDays';
  static const programSlots = 'ProgramSlots';
  static const targetSets = 'TargetSets';
  static const trainingMaxes = 'TrainingMaxes';
  static const sessions = 'Sessions';
  static const sessionExercises = 'SessionExercises';
  static const sets = 'Sets';
}

/// Minor units to major, as a live formula rather than a Dart division
/// (rule X4): the integer stays the truth, the decimal stays derived.
String _major(String minorHeader) => '={$minorHeader}{row}/100';

/// Looks a seed's title up from its uuid, so the log sheets read like
/// something a person wrote instead of a column of uuids.
const _seedTitle =
    '=IFERROR(VLOOKUP({CommitmentUuid}{row},'
    '${SheetNames.seeds}!\$A:\$C,3,FALSE),"")';

/// The same trick for an album, so the Memories sheet reads as names
/// rather than a column of uuids.
const _albumName =
    '=IFERROR(VLOOKUP({AlbumUuid}{row},'
    '${SheetNames.albums}!\$A:\$B,2,FALSE),"")';

/// Lays out the whole workbook: one sheet per table, plus a Summary
/// whose every number is a formula over the others.
List<ExportSheet> harvestSheets(ExportData data) {
  final seeds = ExportSheet(
    name: SheetNames.seeds,
    headers: const [
      'Uuid',
      'Type',
      'Title',
      'Schedule',
      'TotalTarget',
      'DailyCommitment',
      'DueDay',
      'Note',
      'RemindAt',
      'Deadline',
      'PausedAt',
      'ArchivedAt',
      'ArchiveNote',
      'DeletedAt',
      'CreatedAt',
      'UpdatedAt',
    ],
    rows: data.seeds,
  );

  final checkIns = ExportSheet(
    name: SheetNames.checkIns,
    headers: const [
      'Uuid',
      'CommitmentUuid',
      'HarvestDay',
      'Quantity',
      'LoggedAt',
      'UpdatedAt',
      'DeletedAt',
    ],
    rows: data.checkIns,
    derived: const [(header: 'Seed', template: _seedTitle)],
  );

  final seedNotes = ExportSheet(
    name: SheetNames.seedNotes,
    headers: const [
      'Uuid',
      'CommitmentUuid',
      'HarvestDay',
      'Body',
      'LoggedAt',
      'UpdatedAt',
      'DeletedAt',
    ],
    rows: data.seedNotes,
    derived: const [(header: 'Seed', template: _seedTitle)],
  );

  final expenses = ExportSheet(
    name: SheetNames.expenses,
    headers: const [
      'Uuid',
      'HarvestDay',
      'Category',
      'Currency',
      'AmountMinor',
      'Note',
      'LoggedAt',
      'UpdatedAt',
      'DeletedAt',
    ],
    rows: data.expenses,
    derived: [(header: 'Amount', template: _major('AmountMinor'))],
  );

  final money = ExportSheet(
    name: SheetNames.money,
    headers: const [
      'Uuid',
      'HarvestDay',
      'Account',
      'Kind',
      'Reference',
      'Currency',
      'DeltaMinor',
      'Note',
      'LinkUuid',
      'LoggedAt',
      'UpdatedAt',
      'DeletedAt',
    ],
    rows: data.money,
    derived: [(header: 'Delta', template: _major('DeltaMinor'))],
  );

  final debtPayments = ExportSheet(
    name: SheetNames.debtPayments,
    headers: const [
      'Uuid',
      'DebtUuid',
      'HarvestDay',
      'AmountMinor',
      'LoggedAt',
      'DeletedAt',
    ],
    rows: data.debtPayments,
    derived: [(header: 'Amount', template: _major('AmountMinor'))],
  );

  final debts = ExportSheet(
    name: SheetNames.debts,
    headers: const [
      'Uuid',
      'Person',
      'Currency',
      'AmountMinor',
      'PayOffBy',
      'RemindAt',
      'Note',
      'SettledAt',
      'CreatedAt',
      'DeletedAt',
      'UpdatedAt',
    ],
    rows: data.debts,
    derived: [
      (header: 'Amount', template: _major('AmountMinor')),
      (
        header: 'Paid',
        template:
            '=SUMIFS(${SheetNames.debtPayments}!'
            '${debtPayments.column('AmountMinor')}:'
            '${debtPayments.column('AmountMinor')},'
            '${SheetNames.debtPayments}!'
            '${debtPayments.column('DebtUuid')}:'
            '${debtPayments.column('DebtUuid')},{Uuid}{row},'
            '${SheetNames.debtPayments}!'
            '${debtPayments.column('DeletedAt')}:'
            '${debtPayments.column('DeletedAt')},"")/100',
      ),
      (header: 'Remaining', template: '={Amount}{row}-{Paid}{row}'),
    ],
  );

  final focus = ExportSheet(
    name: SheetNames.focus,
    headers: const [
      'Uuid',
      'CommitmentUuid',
      'HarvestDay',
      'FocusBlocks',
      'StartedAt',
      'EndedAt',
    ],
    rows: data.focus,
    derived: const [(header: 'Seed', template: _seedTitle)],
  );

  final ledger = ExportSheet(
    name: SheetNames.ledger,
    headers: const [
      'Uuid',
      'Kind',
      'Delta',
      'Reason',
      'HarvestDay',
      'LoggedAt',
    ],
    rows: data.ledger,
  );

  final streaks = ExportSheet(
    name: SheetNames.streaks,
    headers: const [
      'Scope',
      'Current',
      'Best',
      'LastEarnedDay',
      'FreezesStored',
      'UpdatedAt',
    ],
    rows: data.streaks,
  );

  final settings = ExportSheet(
    name: SheetNames.settings,
    headers: const ['Key', 'Value', 'UpdatedAt'],
    rows: data.settings,
  );

  // The three file-backed sheets (ADR-007). `File` holds the path
  // inside the zip, so the tree is browsable and the sheet is its
  // index: the real title lives here, the filename is a sanitised
  // version of it.
  final notes = ExportSheet(
    name: SheetNames.notes,
    headers: const [
      'Uuid',
      'Title',
      'Folder',
      'File',
      'Body',
      'CreatedAt',
      'UpdatedAt',
      'DeletedAt',
    ],
    rows: data.notes,
  );

  final albums = ExportSheet(
    name: SheetNames.albums,
    headers: const [
      'Uuid',
      'Name',
      'Folder',
      'ScheduleJson',
      'RemindAt',
      'Note',
      'CreatedAt',
      'UpdatedAt',
      'DeletedAt',
    ],
    rows: data.albums,
  );

  final memories = ExportSheet(
    name: SheetNames.memories,
    headers: const [
      'Uuid',
      'AlbumUuid',
      'HarvestDay',
      'File',
      'StoredPath',
      'Kind',
      'Note',
      'CapturedAt',
      'UpdatedAt',
      'DeletedAt',
    ],
    rows: data.memories,
    derived: const [(header: 'Album', template: _albumName)],
  );

  // ------------------------------------------------------------ body
  //
  // Weights and barbell loads are grams and stay grams, for the same
  // reason money stays minor units (rule X4): the integer is the truth
  // and the kilogram is a formula away.

  final steps = ExportSheet(
    name: SheetNames.steps,
    headers: const [
      'HarvestDay',
      'Steps',
      'LastCounter',
      'UpdatedAt',
    ],
    rows: data.steps,
  );

  final weights = ExportSheet(
    name: SheetNames.weights,
    headers: const [
      'Uuid',
      'HarvestDay',
      'Grams',
      'Note',
      'MeasuredAt',
      'UpdatedAt',
      'DeletedAt',
    ],
    rows: data.weights,
    derived: const [(header: 'Kg', template: '={Grams}{row}/1000')],
  );

  final sleep = ExportSheet(
    name: SheetNames.sleep,
    headers: const [
      'Uuid',
      'HarvestDay',
      'FellAsleepAt',
      'WokeAt',
      'TargetMinutes',
      'RestedStars',
      'Note',
      'CreatedAt',
      'UpdatedAt',
      'DeletedAt',
    ],
    rows: data.sleep,
  );

  final exercises = ExportSheet(
    name: SheetNames.exercises,
    headers: const [
      'Uuid',
      'Name',
      'BodyPart',
      'Equipment',
      'Target',
      'Note',
      'CreatedAt',
      'UpdatedAt',
      'DeletedAt',
    ],
    rows: data.exercises,
  );

  final programs = ExportSheet(
    name: SheetNames.programs,
    headers: const [
      'Uuid',
      'Name',
      'Note',
      'Weeks',
      'CommitmentUuid',
      'AlbumUuid',
      'PhotoPrompt',
      'CreatedAt',
      'UpdatedAt',
      'DeletedAt',
    ],
    rows: data.programs,
    derived: const [(header: 'Seed', template: _seedTitle)],
  );

  final programDays = ExportSheet(
    name: SheetNames.programDays,
    headers: const ['Uuid', 'ProgramUuid', 'Name', 'Position', 'Week'],
    rows: data.programDays,
  );

  final programSlots = ExportSheet(
    name: SheetNames.programSlots,
    headers: const [
      'Uuid',
      'DayUuid',
      'ExerciseId',
      'Position',
      'RestSeconds',
      'BarGrams',
      'Note',
    ],
    rows: data.programSlots,
  );

  final targetSets = ExportSheet(
    name: SheetNames.targetSets,
    headers: const [
      'Uuid',
      'SlotUuid',
      'Position',
      'Reps',
      'WeightGrams',
      'PercentTenths',
      'OpenEnded',
    ],
    rows: data.targetSets,
  );

  final trainingMaxes = ExportSheet(
    name: SheetNames.trainingMaxes,
    headers: const [
      'ProgramUuid',
      'ExerciseId',
      'Grams',
      'UpdatedAt',
    ],
    rows: data.trainingMaxes,
    derived: const [(header: 'Kg', template: '={Grams}{row}/1000')],
  );

  final sessions = ExportSheet(
    name: SheetNames.sessions,
    headers: const [
      'Uuid',
      'ProgramUuid',
      'DayUuid',
      'Title',
      'HarvestDay',
      'Note',
      'StartedAt',
      'EndedAt',
      'PausedAt',
      'PausedSeconds',
      'UpdatedAt',
      'DeletedAt',
    ],
    rows: data.sessions,
  );

  final sessionExercises = ExportSheet(
    name: SheetNames.sessionExercises,
    headers: const [
      'Uuid',
      'SessionUuid',
      'Position',
      'ExerciseId',
      'PlannedExerciseId',
      'SlotUuid',
      'Skipped',
      'Note',
      'RestSeconds',
      'BarGrams',
    ],
    rows: data.sessionExercises,
  );

  final sets = ExportSheet(
    name: SheetNames.sets,
    headers: const [
      'Uuid',
      'SessionExerciseUuid',
      'Position',
      'WeightGrams',
      'Reps',
      'Done',
      'TargetLabel',
      'OpenEnded',
      'LoggedAt',
    ],
    rows: data.sets,
    derived: const [
      (header: 'Kg', template: '={WeightGrams}{row}/1000'),
      // Volume the way a lifter means it, live off the two columns
      // beside it — edit a rep count and the number follows.
      (
        header: 'VolumeKg',
        template: '={WeightGrams}{row}*{Reps}{row}/1000',
      ),
    ],
  );

  final sheets = [
    seeds,
    checkIns,
    seedNotes,
    expenses,
    money,
    debts,
    debtPayments,
    focus,
    ledger,
    streaks,
    settings,
    notes,
    albums,
    memories,
    steps,
    weights,
    sleep,
    exercises,
    programs,
    programDays,
    programSlots,
    targetSets,
    trainingMaxes,
    sessions,
    sessionExercises,
    sets,
  ];

  return [
    _summary(
      data,
      sheets: sheets,
      expenses: expenses,
      money: money,
      debts: debts,
      ledger: ledger,
    ),
    ...sheets,
  ];
}

/// Counts the rows of [sheet] live, so a row deleted in the spreadsheet
/// drops out of the count too.
String _countOf(ExportSheet sheet) {
  final column = sheet.column(sheet.headers.first);
  return '=COUNTA(${sheet.name}!$column:$column)-1';
}

/// `Sheet!X:X` for one of a sheet's columns.
String _range(ExportSheet sheet, String header) {
  final column = sheet.column(header);
  return '${sheet.name}!$column:$column';
}

/// Sums [value] on [sheet] where [match] equals the label in column A of
/// the summary row, skipping rows that were soft-deleted.
String _sumBy(
  ExportSheet sheet, {
  required String value,
  required String match,
  (String, String)? and,
}) {
  final extra = and == null ? '' : ',${_range(sheet, and.$1)},"${and.$2}"';
  return '=SUMIFS(${_range(sheet, value)},${_range(sheet, match)},\$A{row}'
      '$extra,${_range(sheet, 'DeletedAt')},"")/100';
}

/// The all-formula overview (rule X3): nothing on this sheet is a
/// number I computed in Dart, so editing a row moves the totals.
ExportSheet _summary(
  ExportData data, {
  required List<ExportSheet> sheets,
  required ExportSheet expenses,
  required ExportSheet money,
  required ExportSheet debts,
  required ExportSheet ledger,
}) {
  final rows = <List<Object?>>[
    ['Harvest export'],
    ['Generated', data.generatedAt.toIso8601String()],
    [],
    ['Rows', 'Count'],
    for (final sheet in sheets) [sheet.name, Formula(_countOf(sheet))],
    [],
    ['Totals', 'Value'],
    // The ledger is append-only and has no DeletedAt, so these two do
    // not go through the shared helper.
    [
      'XP',
      Formula(
        '=SUMIFS(${_range(ledger, 'Delta')},${_range(ledger, 'Kind')},"xp")',
      ),
    ],
    [
      'Coins',
      Formula(
        '=SUMIFS(${_range(ledger, 'Delta')},${_range(ledger, 'Kind')},"coin")',
      ),
    ],
  ];

  final currencies = _distinct([
    ...expenses.rows.map((row) => row[3]),
    ...money.rows.map((row) => row[5]),
    ...debts.rows.map((row) => row[2]),
  ]);
  if (currencies.isNotEmpty) {
    rows
      ..add([])
      ..add(['Currency', 'Wallet', 'Savings', 'Spent', 'Owed']);
    for (final currency in currencies) {
      rows.add([
        currency,
        Formula(
          _sumBy(
            money,
            value: 'DeltaMinor',
            match: 'Currency',
            and: ('Account', 'wallet'),
          ),
        ),
        Formula(
          _sumBy(
            money,
            value: 'DeltaMinor',
            match: 'Currency',
            and: ('Account', 'savings'),
          ),
        ),
        Formula(_sumBy(expenses, value: 'AmountMinor', match: 'Currency')),
        // Remaining is itself a formula column, so what is owed stays
        // live as payments are logged.
        Formula(
          '=SUMIFS(${_range(debts, 'Remaining')},'
          '${_range(debts, 'Currency')},\$A{row},'
          '${_range(debts, 'SettledAt')},"",'
          '${_range(debts, 'DeletedAt')},"")',
        ),
      ]);
    }
  }

  final categories = _distinct(expenses.rows.map((row) => row[2]));
  if (categories.isNotEmpty) {
    rows
      ..add([])
      ..add(['Category', 'Spent']);
    for (final category in categories) {
      rows.add([
        category,
        Formula(_sumBy(expenses, value: 'AmountMinor', match: 'Category')),
      ]);
    }
  }

  final months = _distinct(
    expenses.rows.map((row) => (row[1] as String?)?.substring(0, 7)),
  );
  if (months.isNotEmpty) {
    // SUMIFS cannot match a prefix, so the month rows use SUMPRODUCT
    // over a range bounded at the last row — bounded exactly, because
    // an open-ended one multiplies out over the whole column.
    final day = expenses.column('HarvestDay');
    final amount = expenses.column('AmountMinor');
    final deleted = expenses.column('DeletedAt');
    final last = expenses.lastRow;
    rows
      ..add([])
      ..add(['Month', 'Spent']);
    for (final month in months) {
      rows.add([
        month,
        Formula(
          '=SUMPRODUCT((LEFT(${expenses.name}!\$$day\$2:\$$day\$$last,7)'
          '=\$A{row})*(${expenses.name}!\$$deleted\$2:\$$deleted\$$last="")'
          '*${expenses.name}!\$$amount\$2:\$$amount\$$last)/100',
        ),
      ]);
    }
  }

  const width = 5;
  return ExportSheet(
    name: SheetNames.summary,
    // A layout, not a table: the blocks label themselves in column A.
    hasHeaderRow: false,
    headers: const ['A', 'B', 'C', 'D', 'E'],
    rows: [
      for (final row in rows)
        [...row, ...List.filled(width - row.length, null)],
    ],
  );
}

/// Sorted distinct non-empty values, so the breakdowns come out in the
/// same order every export instead of following insertion order.
List<String> _distinct(Iterable<Object?> values) =>
    values
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
