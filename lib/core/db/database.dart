import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

/// Habits, projects and to-dos — the seeds.
@DataClassName('CommitmentRow')
class Commitments extends Table {
  /// Client-generated UUID; will become the server `_id` when sync arrives.
  TextColumn get uuid => text()();

  /// `habit` | `project` | `todo`.
  TextColumn get type => text()();
  TextColumn get title => text()();

  /// Habit schedule rules, JSON-encoded (null for projects/todos).
  TextColumn get scheduleJson => text().nullable()();

  /// Projects only: total units to complete and the daily commitment.
  IntColumn get totalTarget => integer().nullable()();
  IntColumn get dailyCommitment => integer().nullable()();

  /// To-dos only: the Harvest Day this is planned for (yyyy-MM-dd).
  TextColumn get dueDay => text().nullable()();

  /// Habits only: vacation mode — paused habits are neither due nor
  /// judged, and their streak survives the break.
  DateTimeColumn get pausedAt => dateTime().nullable()();

  /// Free-form note shown with the seed.
  TextColumn get note => text().nullable()();

  /// Per-seed reminder time ("HH:mm"), fired on days the seed is due.
  TextColumn get remindAt => text().nullable()();

  /// Accomplish-before day (yyyy-MM-dd); overdue seeds turn urgent.
  TextColumn get deadline => text().nullable()();

  DateTimeColumn get archivedAt => dateTime().nullable()();

  /// Why this seed was put away — written when it is archived, and the
  /// only thing the archive can tell me later that the title cannot.
  TextColumn get archiveNote => text().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {uuid};
}

/// Append-only log of every completed action — the water.
@DataClassName('CheckInRow')
class CheckIns extends Table {
  TextColumn get uuid => text()();
  TextColumn get commitmentUuid => text().references(Commitments, #uuid)();

  /// The Harvest Day this counts for, computed at write time.
  TextColumn get harvestDay => text()();

  /// Units logged: 1 for habits/todos, page/minute counts for projects.
  IntColumn get quantity => integer().withDefault(const Constant(1))();
  DateTimeColumn get loggedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {uuid};
}

/// One note per seed per Harvest Day — the page I stopped on, the set
/// I managed, what to pick up tomorrow. A new day starts a blank one;
/// yesterday's is still there to read.
@DataClassName('SeedNoteRow')
class SeedNotes extends Table {
  TextColumn get uuid => text()();
  TextColumn get commitmentUuid => text().references(Commitments, #uuid)();

  /// The Harvest Day this note belongs to.
  TextColumn get harvestDay => text()();
  TextColumn get body => text()();
  DateTimeColumn get loggedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {uuid};
}

/// A markdown note (phase 3). The body is the truth; everything else
/// about a note is derived from it, including its links.
@DataClassName('NoteRow')
class Notes extends Table {
  TextColumn get uuid => text()();
  TextColumn get title => text()();

  /// Folder path, "" for the root. Slash-separated, created by naming.
  TextColumn get folder => text().withDefault(const Constant(''))();
  TextColumn get body => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {uuid};
}

/// One `[[link]]` found in a note's body, indexed so "what links here"
/// is a query rather than a scan of every note. Rebuildable from the
/// bodies at any time (rule N2).
@DataClassName('NoteLinkRow')
class NoteLinks extends Table {
  TextColumn get uuid => text()();
  TextColumn get fromUuid => text().references(Notes, #uuid)();

  /// The title as written between the brackets.
  TextColumn get toTitle => text()();

  /// The note that title resolves to, null while it does not exist yet.
  TextColumn get toUuid => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {uuid};
}

/// A run of memories — "Gym", "Face" — optionally scheduled, in which
/// case it is a seed on the field (phase 3).
@DataClassName('AlbumRow')
class Albums extends Table {
  TextColumn get uuid => text()();
  TextColumn get name => text()();

  /// Habit-style schedule rules, JSON-encoded. Null means unscheduled:
  /// an album I add to when I feel like it, not a seed.
  TextColumn get scheduleJson => text().nullable()();

  /// "HH:mm" reminder, on days the album is due.
  TextColumn get remindAt => text().nullable()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {uuid};
}

/// One photo or video in an album, with the Harvest Day it belongs to.
///
/// The file itself lives in the app's own storage; this row points at
/// it. Deleting is a two-step: [deletedAt] puts the memory in the
/// trash and the file stays where it is, and emptying the trash is
/// what actually deletes it (rule G5, revised in [[Checkpoint-5]] —
/// "gone for good" now means gone from the trash, because a picture
/// deleted by a fat thumb was gone for good too).
@DataClassName('MemoryRow')
class Memories extends Table {
  TextColumn get uuid => text()();
  TextColumn get albumUuid => text().references(Albums, #uuid)();
  TextColumn get harvestDay => text()();

  /// Path relative to the gallery directory, so the row survives the
  /// app's storage moving between installs.
  TextColumn get path => text()();

  /// `photo` | `video`.
  TextColumn get kind => text().withDefault(const Constant('photo'))();
  TextColumn get note => text().nullable()();
  DateTimeColumn get capturedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  /// In the trash since. Null is a memory I still have.
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {uuid};
}

/// Current and best streaks; derived state, never synced.
@DataClassName('StreakRow')
class Streaks extends Table {
  /// `global`, or a commitment uuid for individual streaks.
  TextColumn get scope => text()();
  IntColumn get current => integer().withDefault(const Constant(0))();
  IntColumn get best => integer().withDefault(const Constant(0))();
  TextColumn get lastEarnedDay => text().nullable()();
  IntColumn get freezesStored => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {scope};
}

/// XP and coin movements — balances are sums over this, never counters.
class Ledger extends Table {
  TextColumn get uuid => text()();

  /// `xp` | `coin`.
  TextColumn get kind => text()();
  IntColumn get delta => integer()();
  TextColumn get reason => text()();
  TextColumn get harvestDay => text()();
  DateTimeColumn get loggedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {uuid};
}

/// Parked: daily quests were removed from the app pending a redesign;
/// the table stays so old data and sync-readiness survive.
class Quests extends Table {
  TextColumn get uuid => text()();
  TextColumn get harvestDay => text()();
  TextColumn get templateId => text()();
  IntColumn get progress => integer().withDefault(const Constant(0))();
  IntColumn get target => integer()();
  DateTimeColumn get claimedAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {uuid};
}

/// Completed pomodoro sessions.
class PomodoroSessions extends Table {
  TextColumn get uuid => text()();
  TextColumn get commitmentUuid => text().nullable()();
  IntColumn get focusBlocks => integer().withDefault(const Constant(0))();
  TextColumn get harvestDay => text()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {uuid};
}

/// Money out, in minor units — never floats (business rule: finances
/// stay on-device; see the sync strategy's privacy tiers).
@DataClassName('ExpenseRow')
class Expenses extends Table {
  TextColumn get uuid => text()();

  /// Amount in minor units (cents); always positive.
  IntColumn get amountMinor => integer()();

  /// ISO-ish currency code (DZD / USD / EUR).
  TextColumn get currency => text().withDefault(const Constant('DZD'))();

  /// One of the preset category names.
  TextColumn get category => text()();
  TextColumn get note => text().nullable()();
  TextColumn get harvestDay => text()();
  DateTimeColumn get loggedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {uuid};
}

/// Wallet and savings movements (checkpoint round 3): a signed delta
/// per account, so balances are sums and history is the record.
@DataClassName('MoneyTxnRow')
class MoneyTxns extends Table {
  TextColumn get uuid => text()();

  /// 'wallet' | 'savings'.
  TextColumn get account => text()();

  /// Minor units, signed: positive deposits, negative withdrawals.
  IntColumn get deltaMinor => integer()();
  TextColumn get currency => text().withDefault(const Constant('DZD'))();
  TextColumn get note => text().nullable()();

  /// What caused the movement: 'manual' | 'transfer' | 'expense' | 'debt'
  /// (round 4 — the ledger explains every row).
  TextColumn get kind => text().withDefault(const Constant('manual'))();

  /// Context for [kind]: the counterpart account for a transfer, the
  /// category key for an expense, the person for a debt payment.
  TextColumn get reference => text().nullable()();

  /// The row this movement belongs to — the expense uuid for a
  /// wallet-funded expense, the debt payment uuid for a debt. Editing
  /// or deleting that row carries the movement with it (schema v8).
  TextColumn get linkUuid => text().nullable()();
  TextColumn get harvestDay => text()();
  DateTimeColumn get loggedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {uuid};
}

/// Money owed to someone — amount, no interest, optional pay-off day
/// and a daily reminder until settled.
@DataClassName('DebtRow')
class Debts extends Table {
  TextColumn get uuid => text()();
  TextColumn get person => text()();
  IntColumn get amountMinor => integer()();
  TextColumn get currency => text().withDefault(const Constant('DZD'))();
  TextColumn get payOffBy => text().nullable()();

  /// "HH:mm" daily reminder time; a default applies when unset.
  TextColumn get remindAt => text().nullable()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get settledAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {uuid};
}

/// Partial pay-offs against a debt.
@DataClassName('DebtPaymentRow')
class DebtPayments extends Table {
  TextColumn get uuid => text()();
  TextColumn get debtUuid => text().references(Debts, #uuid)();
  IntColumn get amountMinor => integer()();
  TextColumn get harvestDay => text()();
  DateTimeColumn get loggedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {uuid};
}

/// User-created expense categories layered on top of the presets.
@DataClassName('ExpenseCategoryRow')
class ExpenseCategories extends Table {
  TextColumn get uuid => text()();

  /// Display name; doubles as the key stored on expenses.
  TextColumn get name => text()();

  /// Icon key resolved through the app's icon map.
  TextColumn get icon => text()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {uuid};
}

/// Change log for the future sync client — appended on every local write.
class Outbox extends Table {
  IntColumn get seq => integer().autoIncrement()();
  TextColumn get targetTable => text()();
  TextColumn get rowUuid => text()();

  /// `insert` | `update` | `delete`.
  TextColumn get op => text()();
  DateTimeColumn get queuedAt => dateTime().withDefault(currentDateAndTime)();
}

/// Simple key-value store for app settings (theme, locale, goal, times).
class KvSettings extends Table {
  TextColumn get key => text()();
  TextColumn get valueJson => text()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

@DriftDatabase(
  tables: [
    Commitments,
    CheckIns,
    SeedNotes,
    Notes,
    NoteLinks,
    Albums,
    Memories,
    Streaks,
    Ledger,
    Quests,
    PomodoroSessions,
    Expenses,
    ExpenseCategories,
    MoneyTxns,
    Debts,
    DebtPayments,
    Outbox,
    KvSettings,
  ],
)
class HarvestDatabase extends _$HarvestDatabase {
  HarvestDatabase() : super(_openConnection());

  HarvestDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 11;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      // A table created in this run already carries the newest
      // columns; later addColumn steps must skip it.
      final expensesJustCreated = from < 2;
      final moneyTxnsJustCreated = from < 6;
      final memoriesJustCreated = from < 10;
      if (from < 2) {
        await m.createTable(expenses);
      }
      if (from < 3) {
        await m.addColumn(commitments, commitments.pausedAt);
      }
      if (from < 4) {
        await m.addColumn(commitments, commitments.note);
        await m.addColumn(commitments, commitments.remindAt);
        await m.addColumn(commitments, commitments.deadline);
        await m.createTable(expenseCategories);
      }
      if (from < 5 && !expensesJustCreated) {
        await m.addColumn(expenses, expenses.currency);
      }
      if (from < 6) {
        await m.createTable(moneyTxns);
        await m.createTable(debts);
        await m.createTable(debtPayments);
      }
      if (from < 7 && !moneyTxnsJustCreated) {
        await m.addColumn(moneyTxns, moneyTxns.kind);
        await m.addColumn(moneyTxns, moneyTxns.reference);
      }
      if (from < 8 && !moneyTxnsJustCreated) {
        await m.addColumn(moneyTxns, moneyTxns.linkUuid);
      }
      if (from < 9) {
        await m.addColumn(commitments, commitments.archiveNote);
        await m.createTable(seedNotes);
      }
      if (from < 10) {
        await m.createTable(notes);
        await m.createTable(noteLinks);
        await m.createTable(albums);
        await m.createTable(memories);
      }
      if (from < 11 && !memoriesJustCreated) {
        await m.addColumn(memories, memories.deletedAt);
      }
    },
  );

  static QueryExecutor _openConnection() => driftDatabase(name: 'harvest');
}
