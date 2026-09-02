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

/// The four daily micro-quests generated at each 3 AM reset.
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
    Streaks,
    Ledger,
    Quests,
    PomodoroSessions,
    Expenses,
    ExpenseCategories,
    Outbox,
    KvSettings,
  ],
)
class HarvestDatabase extends _$HarvestDatabase {
  HarvestDatabase() : super(_openConnection());

  HarvestDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
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
        },
      );

  static QueryExecutor _openConnection() =>
      driftDatabase(name: 'harvest');
}
