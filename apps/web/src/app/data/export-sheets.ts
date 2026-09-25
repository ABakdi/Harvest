import { ExportSheet, Formula, type CellValue, type DerivedColumn } from './archive-xlsx';

/**
 * The workbook's layout: one sheet per table plus a Summary whose every
 * number is a formula over the others ([[ADR-006-Export-Format]]).
 *
 * A port of the phone's `harvest_workbook.dart`. The sheet names, the
 * headers and their order are the file's contract with the phone's
 * importer and with every archive already out there, so they are kept
 * exactly as the phone writes them.
 */

export const SheetNames = {
  summary: 'Summary',
  seeds: 'Seeds',
  checkIns: 'CheckIns',
  seedNotes: 'SeedNotes',
  goals: 'Goals',
  goalItems: 'GoalItems',
  wishlist: 'Wishlist',
  expenses: 'Expenses',
  /** The categories I made myself; the presets are the app's. */
  categories: 'Categories',
  money: 'Money',
  debts: 'Debts',
  debtPayments: 'DebtPayments',
  focus: 'Focus',
  ledger: 'Ledger',
  streaks: 'Streaks',
  settings: 'Settings',
  notes: 'Notes',
  noteAttachments: 'NoteAttachments',
  albums: 'Albums',
  memories: 'Memories',
  steps: 'Steps',
  weights: 'Weights',
  sleep: 'Sleep',
  /** Only the exercises I wrote; the catalogue is not mine to carry. */
  exercises: 'Exercises',
  programs: 'Programs',
  programDays: 'ProgramDays',
  programSlots: 'ProgramSlots',
  targetSets: 'TargetSets',
  trainingMaxes: 'TrainingMaxes',
  sessions: 'Sessions',
  sessionExercises: 'SessionExercises',
  sets: 'Sets',
  // Places: private-tier ([[Places]] PL6), and in the archive all the
  // same, because a backup that leaves out a table is not a backup.
  savedPlaces: 'SavedPlaces',
  locationPoints: 'LocationPoints',
  geotags: 'Geotags',
} as const;

export type SheetKey = Exclude<keyof typeof SheetNames, 'summary'>;

/** Stored-value headers per sheet, in the phone's order. */
export const sheetHeaders: Record<SheetKey, readonly string[]> = {
  seeds: [
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
    'GoalUuid',
    'PausedAt',
    'ArchivedAt',
    'ArchiveNote',
    'DeletedAt',
    'CreatedAt',
    'UpdatedAt',
  ],
  checkIns: ['Uuid', 'CommitmentUuid', 'HarvestDay', 'Quantity', 'LoggedAt', 'UpdatedAt', 'DeletedAt'],
  seedNotes: ['Uuid', 'CommitmentUuid', 'HarvestDay', 'Body', 'LoggedAt', 'UpdatedAt', 'DeletedAt'],
  goals: ['Uuid', 'Title', 'Why', 'TargetDay', 'Status', 'StatusNote', 'AchievedAt', 'Position', 'CreatedAt', 'UpdatedAt', 'DeletedAt'],
  goalItems: ['Uuid', 'GoalUuid', 'Kind', 'Body', 'Note', 'DoneAt', 'Position', 'CommitmentUuid', 'CreatedAt', 'UpdatedAt', 'DeletedAt'],
  wishlist: [
    'Uuid',
    'List',
    'Title',
    'PriceMinor',
    'Currency',
    'Note',
    'TargetDay',
    'BoughtAt',
    'Position',
    'CreatedAt',
    'UpdatedAt',
    'DeletedAt',
  ],
  expenses: ['Uuid', 'HarvestDay', 'Category', 'Currency', 'AmountMinor', 'Note', 'LoggedAt', 'UpdatedAt', 'DeletedAt'],
  categories: ['Uuid', 'Name', 'Icon', 'CreatedAt', 'UpdatedAt', 'DeletedAt'],
  money: [
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
  debts: ['Uuid', 'Person', 'Currency', 'AmountMinor', 'PayOffBy', 'RemindAt', 'Note', 'SettledAt', 'CreatedAt', 'DeletedAt', 'UpdatedAt'],
  debtPayments: ['Uuid', 'DebtUuid', 'HarvestDay', 'AmountMinor', 'LoggedAt', 'DeletedAt'],
  focus: ['Uuid', 'CommitmentUuid', 'HarvestDay', 'FocusBlocks', 'StartedAt', 'EndedAt'],
  ledger: ['Uuid', 'Kind', 'Delta', 'Reason', 'HarvestDay', 'LoggedAt'],
  streaks: ['Scope', 'Current', 'Best', 'LastEarnedDay', 'FreezesStored', 'UpdatedAt'],
  settings: ['Key', 'Value', 'UpdatedAt'],
  // The file-backed sheets (ADR-007): `File` is the path inside the zip,
  // so the sheet is the index of a browsable tree.
  notes: ['Uuid', 'Title', 'Folder', 'File', 'Body', 'CreatedAt', 'UpdatedAt', 'DeletedAt'],
  noteAttachments: [
    'Uuid',
    'NoteUuid',
    'Kind',
    'FileName',
    'File',
    'StoredPath',
    'DurationMs',
    'SizeBytes',
    'FileHash',
    'CreatedAt',
    'UpdatedAt',
    'DeletedAt',
  ],
  albums: ['Uuid', 'Name', 'Folder', 'ScheduleJson', 'RemindAt', 'Note', 'CreatedAt', 'UpdatedAt', 'DeletedAt'],
  memories: ['Uuid', 'AlbumUuid', 'HarvestDay', 'File', 'StoredPath', 'Kind', 'Note', 'FileHash', 'CapturedAt', 'UpdatedAt', 'DeletedAt'],
  // Grams stay grams, as money stays minor units (rule X4).
  steps: ['HarvestDay', 'Steps', 'LastCounter', 'UpdatedAt'],
  weights: ['Uuid', 'HarvestDay', 'Grams', 'Note', 'MeasuredAt', 'UpdatedAt', 'DeletedAt'],
  sleep: ['Uuid', 'HarvestDay', 'FellAsleepAt', 'WokeAt', 'TargetMinutes', 'RestedStars', 'Note', 'CreatedAt', 'UpdatedAt', 'DeletedAt'],
  exercises: ['Uuid', 'Name', 'BodyPart', 'Equipment', 'Target', 'Note', 'CreatedAt', 'UpdatedAt', 'DeletedAt'],
  programs: ['Uuid', 'Name', 'Note', 'Weeks', 'CommitmentUuid', 'AlbumUuid', 'PhotoPrompt', 'CreatedAt', 'UpdatedAt', 'DeletedAt'],
  programDays: ['Uuid', 'ProgramUuid', 'Name', 'Position', 'Week', 'Accessories'],
  programSlots: ['Uuid', 'DayUuid', 'ExerciseId', 'Position', 'RestSeconds', 'BarGrams', 'Note'],
  targetSets: ['Uuid', 'SlotUuid', 'Position', 'Reps', 'WeightGrams', 'PercentTenths', 'OpenEnded'],
  trainingMaxes: ['ProgramUuid', 'ExerciseId', 'Grams', 'UpdatedAt'],
  sessions: [
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
  sessionExercises: [
    'Uuid',
    'SessionUuid',
    'Position',
    'ExerciseId',
    'PlannedExerciseId',
    'SlotUuid',
    'Skipped',
    'SkipReason',
    'Note',
    'RestSeconds',
    'BarGrams',
  ],
  sets: ['Uuid', 'SessionExerciseUuid', 'Position', 'WeightGrams', 'Reps', 'Done', 'TargetLabel', 'OpenEnded', 'LoggedAt'],
  // Coordinates are plain decimal degrees and metres.
  savedPlaces: ['Uuid', 'Name', 'Latitude', 'Longitude', 'RadiusM', 'Notes', 'CreatedAt', 'UpdatedAt', 'DeletedAt'],
  locationPoints: ['Uuid', 'HarvestDay', 'RecordedAt', 'Latitude', 'Longitude', 'AccuracyM', 'SpeedMps', 'AltitudeM', 'UpdatedAt', 'DeletedAt'],
  geotags: ['Uuid', 'TargetTable', 'TargetUuid', 'HarvestDay', 'At', 'Latitude', 'Longitude', 'AccuracyM', 'State', 'UpdatedAt', 'DeletedAt'],
};

/** The sheets in the phone's order, after the Summary. */
export const sheetOrder: readonly SheetKey[] = [
  'seeds',
  'checkIns',
  'seedNotes',
  'goals',
  'goalItems',
  'wishlist',
  'expenses',
  'categories',
  'money',
  'debts',
  'debtPayments',
  'focus',
  'ledger',
  'streaks',
  'settings',
  'notes',
  'noteAttachments',
  'albums',
  'memories',
  'steps',
  'weights',
  'sleep',
  'exercises',
  'programs',
  'programDays',
  'programSlots',
  'targetSets',
  'trainingMaxes',
  'sessions',
  'sessionExercises',
  'sets',
  'savedPlaces',
  'locationPoints',
  'geotags',
];

/** Every table's rows, flattened in the order of [sheetHeaders]. */
export type ExportData = { generatedAt: string } & Record<SheetKey, CellValue[][]>;

/** Minor units to major, as a live formula (rule X4). */
const major = (minorHeader: string) => `={${minorHeader}}{row}/100`;

const seedTitle = `=IFERROR(VLOOKUP({CommitmentUuid}{row},${SheetNames.seeds}!$A:$C,3,FALSE),"")`;
const albumName = `=IFERROR(VLOOKUP({AlbumUuid}{row},${SheetNames.albums}!$A:$B,2,FALSE),"")`;
const goalTitle = `=IFERROR(VLOOKUP({GoalUuid}{row},${SheetNames.goals}!$A:$B,2,FALSE),"")`;
const noteTitle = `=IFERROR(VLOOKUP({NoteUuid}{row},${SheetNames.notes}!$A:$B,2,FALSE),"")`;

function sheet(key: SheetKey, rows: CellValue[][], derived: DerivedColumn[] = []): ExportSheet {
  return new ExportSheet({ name: SheetNames[key], headers: sheetHeaders[key], rows, derived });
}

/** Lays out the whole workbook: the Summary, then one sheet per table. */
export function harvestSheets(data: ExportData): ExportSheet[] {
  const debtPayments = sheet('debtPayments', data.debtPayments, [{ header: 'Amount', template: major('AmountMinor') }]);
  const paid = debtPayments.column('AmountMinor');
  const debtOf = debtPayments.column('DebtUuid');
  const paymentDeleted = debtPayments.column('DeletedAt');
  const built: Record<SheetKey, ExportSheet> = {
    seeds: sheet('seeds', data.seeds),
    checkIns: sheet('checkIns', data.checkIns, [{ header: 'Seed', template: seedTitle }]),
    seedNotes: sheet('seedNotes', data.seedNotes, [{ header: 'Seed', template: seedTitle }]),
    goals: sheet('goals', data.goals),
    goalItems: sheet('goalItems', data.goalItems, [{ header: 'Goal', template: goalTitle }]),
    wishlist: sheet('wishlist', data.wishlist),
    expenses: sheet('expenses', data.expenses, [{ header: 'Amount', template: major('AmountMinor') }]),
    categories: sheet('categories', data.categories),
    money: sheet('money', data.money, [{ header: 'Delta', template: major('DeltaMinor') }]),
    debts: sheet('debts', data.debts, [
      { header: 'Amount', template: major('AmountMinor') },
      {
        header: 'Paid',
        template:
          `=SUMIFS(${SheetNames.debtPayments}!${paid}:${paid},` +
          `${SheetNames.debtPayments}!${debtOf}:${debtOf},{Uuid}{row},` +
          `${SheetNames.debtPayments}!${paymentDeleted}:${paymentDeleted},"")/100`,
      },
      { header: 'Remaining', template: '={Amount}{row}-{Paid}{row}' },
    ]),
    debtPayments,
    focus: sheet('focus', data.focus, [{ header: 'Seed', template: seedTitle }]),
    ledger: sheet('ledger', data.ledger),
    streaks: sheet('streaks', data.streaks),
    settings: sheet('settings', data.settings),
    notes: sheet('notes', data.notes),
    noteAttachments: sheet('noteAttachments', data.noteAttachments, [{ header: 'Note', template: noteTitle }]),
    albums: sheet('albums', data.albums),
    memories: sheet('memories', data.memories, [{ header: 'Album', template: albumName }]),
    steps: sheet('steps', data.steps),
    weights: sheet('weights', data.weights, [{ header: 'Kg', template: '={Grams}{row}/1000' }]),
    sleep: sheet('sleep', data.sleep),
    exercises: sheet('exercises', data.exercises),
    programs: sheet('programs', data.programs, [{ header: 'Seed', template: seedTitle }]),
    programDays: sheet('programDays', data.programDays),
    programSlots: sheet('programSlots', data.programSlots),
    targetSets: sheet('targetSets', data.targetSets),
    trainingMaxes: sheet('trainingMaxes', data.trainingMaxes, [{ header: 'Kg', template: '={Grams}{row}/1000' }]),
    sessions: sheet('sessions', data.sessions),
    sessionExercises: sheet('sessionExercises', data.sessionExercises),
    sets: sheet('sets', data.sets, [
      { header: 'Kg', template: '={WeightGrams}{row}/1000' },
      // Volume the way a lifter means it, live off the two columns beside it.
      { header: 'VolumeKg', template: '={WeightGrams}{row}*{Reps}{row}/1000' },
    ]),
    savedPlaces: sheet('savedPlaces', data.savedPlaces),
    locationPoints: sheet('locationPoints', data.locationPoints),
    geotags: sheet('geotags', data.geotags),
  };
  const sheets = sheetOrder.map((key) => built[key]);
  return [summary(data, sheets, built), ...sheets];
}

/** Counts the rows of [sheet] live, so a deleted spreadsheet row drops out. */
function countOf(sheet: ExportSheet): string {
  const column = sheet.column(sheet.headers[0]!);
  return `=COUNTA(${sheet.name}!${column}:${column})-1`;
}

/** `Sheet!X:X` for one of a sheet's columns. */
function range(sheet: ExportSheet, header: string): string {
  const column = sheet.column(header);
  return `${sheet.name}!${column}:${column}`;
}

/** Sums [value] where [match] equals column A of the row, skipping the deleted. */
function sumBy(sheet: ExportSheet, value: string, match: string, and?: [string, string]): string {
  const extra = and ? `,${range(sheet, and[0])},"${and[1]}"` : '';
  return `=SUMIFS(${range(sheet, value)},${range(sheet, match)},$A{row}${extra},${range(sheet, 'DeletedAt')},"")/100`;
}

/** Sorted distinct non-empty values, so the breakdowns keep their order. */
function distinct(values: Iterable<CellValue | undefined>): string[] {
  const seen = new Set<string>();
  for (const value of values) if (typeof value === 'string' && value !== '') seen.add(value);
  return [...seen].sort((a, b) => (a < b ? -1 : a > b ? 1 : 0));
}

/** The all-formula overview (rule X3): editing a row moves the totals. */
function summary(data: ExportData, sheets: ExportSheet[], built: Record<SheetKey, ExportSheet>): ExportSheet {
  const { expenses, money, debts, ledger } = built;
  const rows: CellValue[][] = [
    ['Harvest export'],
    ['Generated', data.generatedAt],
    [],
    ['Rows', 'Count'],
    ...sheets.map((each) => [each.name, new Formula(countOf(each))]),
    [],
    ['Totals', 'Value'],
    // The ledger is append-only and has no DeletedAt.
    ['XP', new Formula(`=SUMIFS(${range(ledger, 'Delta')},${range(ledger, 'Kind')},"xp")`)],
    ['Coins', new Formula(`=SUMIFS(${range(ledger, 'Delta')},${range(ledger, 'Kind')},"coin")`)],
  ];

  const currencies = distinct([
    ...expenses.rows.map((row) => row[3]),
    ...money.rows.map((row) => row[5]),
    ...debts.rows.map((row) => row[2]),
  ]);
  if (currencies.length > 0) {
    rows.push([], ['Currency', 'Wallet', 'Savings', 'Spent', 'Owed']);
    for (const currency of currencies) {
      rows.push([
        currency,
        new Formula(sumBy(money, 'DeltaMinor', 'Currency', ['Account', 'wallet'])),
        new Formula(sumBy(money, 'DeltaMinor', 'Currency', ['Account', 'savings'])),
        new Formula(sumBy(expenses, 'AmountMinor', 'Currency')),
        // Remaining is itself a formula, so what is owed stays live.
        new Formula(
          `=SUMIFS(${range(debts, 'Remaining')},${range(debts, 'Currency')},$A{row},` +
            `${range(debts, 'SettledAt')},"",${range(debts, 'DeletedAt')},"")`,
        ),
      ]);
    }
  }

  const categories = distinct(expenses.rows.map((row) => row[2]));
  if (categories.length > 0) {
    rows.push([], ['Category', 'Spent']);
    for (const category of categories) rows.push([category, new Formula(sumBy(expenses, 'AmountMinor', 'Category'))]);
  }

  const months = distinct(expenses.rows.map((row) => (typeof row[1] === 'string' ? row[1].slice(0, 7) : null)));
  if (months.length > 0) {
    // SUMIFS cannot match a prefix; SUMPRODUCT over a range bounded
    // exactly at the last row can.
    const day = expenses.column('HarvestDay');
    const amount = expenses.column('AmountMinor');
    const deleted = expenses.column('DeletedAt');
    const last = expenses.lastRow;
    rows.push([], ['Month', 'Spent']);
    for (const month of months) {
      rows.push([
        month,
        new Formula(
          `=SUMPRODUCT((LEFT(${expenses.name}!$${day}$2:$${day}$${last},7)=$A{row})` +
            `*(${expenses.name}!$${deleted}$2:$${deleted}$${last}="")` +
            `*${expenses.name}!$${amount}$2:$${amount}$${last})/100`,
        ),
      ]);
    }
  }

  const width = 5;
  return new ExportSheet({
    name: SheetNames.summary,
    hasHeaderRow: false,
    headers: ['A', 'B', 'C', 'D', 'E'],
    rows: rows.map((row) => [...row, ...Array<CellValue>(width - row.length).fill(null)]),
  });
}
