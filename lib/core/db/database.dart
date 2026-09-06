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

// ---------------------------------------------------------------- health

/// One Harvest Day's step total (phase 4).
///
/// The phone's step counter counts since boot and resets to zero when
/// the phone reboots, so a raw reading is useless on its own. This
/// stores the day's running total plus the last raw reading it was
/// computed from: a reading lower than the last one means a reboot
/// happened, and the day carries on from where it was rather than
/// starting again or going negative ([[Health]] H2).
@DataClassName('StepDayRow')
class StepDays extends Table {
  TextColumn get harvestDay => text()();
  IntColumn get steps => integer().withDefault(const Constant(0))();

  /// The sensor's own since-boot count at the last sync. Null before
  /// the first reading of the day.
  IntColumn get lastCounter => integer().nullable()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {harvestDay};
}

/// A body weight, in **grams** (phase 4).
///
/// Integer, for the reason money is stored in minor units: a weight is
/// not a float. Kilograms and pounds are a display choice made at the
/// edge ([[Health]] H4).
@DataClassName('BodyWeightRow')
class BodyWeights extends Table {
  TextColumn get uuid => text()();
  IntColumn get grams => integer()();
  TextColumn get harvestDay => text()();
  TextColumn get note => text().nullable()();

  /// More than one a day is allowed — morning and evening are
  /// different facts.
  DateTimeColumn get measuredAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {uuid};
}

// ------------------------------------------------------------------ gym

/// An exercise I added myself (phase 4).
///
/// The 1,324-exercise catalogue is a bundled asset, not a table
/// ([[ADR-008-Exercise-Catalogue]]) — it is not my data. These are:
/// they migrate, they export, they sync.
@DataClassName('ExerciseRow')
class Exercises extends Table {
  TextColumn get uuid => text()();
  TextColumn get name => text()();
  TextColumn get bodyPart => text().nullable()();
  TextColumn get equipment => text().nullable()();
  TextColumn get target => text().nullable()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {uuid};
}

/// A routine I wrote: nSuns 5/3/1, Push Pull Legs (phase 4).
@DataClassName('ProgramRow')
class Programs extends Table {
  TextColumn get uuid => text()();
  TextColumn get name => text()();
  TextColumn get note => text().nullable()();

  /// Null for a program that is just a list of days; a number for one
  /// that cycles over N weeks.
  IntColumn get weeks => integer().nullable()();

  /// The habit this program is: finishing a session checks it in
  /// ([[Gym]] rule Y4). Null until it is bound to one.
  TextColumn get commitmentUuid => text().nullable()();

  /// The album the pictures go to, if I took the offer.
  TextColumn get albumUuid => text().nullable()();

  /// `after` | `before` | `never` — when the picture is asked for.
  TextColumn get photoPrompt => text().withDefault(const Constant('after'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {uuid};
}

/// One session's worth of a program: "Week 1 · Day 4", or "Push".
@DataClassName('ProgramDayRow')
class ProgramDays extends Table {
  TextColumn get uuid => text()();
  TextColumn get programUuid => text().references(Programs, #uuid)();
  TextColumn get name => text()();
  IntColumn get position => integer()();

  /// Which week of the cycle, for a program that has them.
  IntColumn get week => integer().nullable()();

  /// Free text: "Back, Abs". A note, not a prescription.
  TextColumn get accessories => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {uuid};
}

/// One exercise in a day, in order, with what it asks for.
@DataClassName('ProgramSlotRow')
class ProgramSlots extends Table {
  TextColumn get uuid => text()();
  TextColumn get dayUuid => text().references(ProgramDays, #uuid)();

  /// A catalogue id ("0001") or the uuid of one of my own exercises.
  TextColumn get exerciseId => text()();
  IntColumn get position => integer()();
  IntColumn get restSeconds => integer().nullable()();

  /// What the bar itself weighs. 20 kg unless told otherwise, because
  /// that is right nearly always ([[Gym]]).
  IntColumn get barGrams => integer().withDefault(const Constant(20000))();
  TextColumn get note => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {uuid};
}

/// What I am *meant* to do: reps, and a weight or a percentage.
@DataClassName('TargetSetRow')
class TargetSets extends Table {
  TextColumn get uuid => text()();
  TextColumn get slotUuid => text().references(ProgramSlots, #uuid)();
  IntColumn get position => integer()();

  /// Null on an open set — "as many as I can".
  IntColumn get reps => integer().nullable()();

  /// Exactly one of these two carries the load.
  IntColumn get weightGrams => integer().nullable()();

  /// Percent of the exercise's training max, ×10 so 82.5% is 825.
  IntColumn get percentTenths => integer().nullable()();

  /// `1+` / AMRAP — the set that decides whether the weight goes up.
  BoolColumn get openEnded => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {uuid};
}

/// The number a program's percentages are of, per exercise.
@DataClassName('TrainingMaxRow')
class TrainingMaxes extends Table {
  TextColumn get programUuid => text().references(Programs, #uuid)();
  TextColumn get exerciseId => text()();
  IntColumn get grams => integer()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {programUuid, exerciseId};
}

/// One day of a program, actually done.
@DataClassName('WorkoutSessionRow')
class WorkoutSessions extends Table {
  TextColumn get uuid => text()();
  TextColumn get programUuid => text().nullable()();
  TextColumn get dayUuid => text().nullable()();

  /// Kept as text so a session survives its program being deleted.
  TextColumn get title => text().nullable()();
  TextColumn get harvestDay => text()();
  DateTimeColumn get startedAt => dateTime().withDefault(currentDateAndTime)();

  /// Null while the session is still running — which is how an
  /// interrupted workout is found and resumed ([[Gym]] rule Y3).
  DateTimeColumn get endedAt => dateTime().nullable()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {uuid};
}

/// One exercise inside a session, as it actually went.
///
/// Separate from the sets because a skip and a swap are facts about
/// the exercise, not about any set — and history has to be able to say
/// what the day was *meant* to be ([[Gym]] rule Y7).
@DataClassName('SessionExerciseRow')
class SessionExercises extends Table {
  TextColumn get uuid => text()();
  TextColumn get sessionUuid => text().references(WorkoutSessions, #uuid)();
  IntColumn get position => integer()();

  /// What I actually did.
  TextColumn get exerciseId => text()();

  /// What the program asked for, when that is not the same thing.
  TextColumn get plannedExerciseId => text().nullable()();
  TextColumn get slotUuid => text().nullable()();
  BoolColumn get skipped => boolean().withDefault(const Constant(false))();
  TextColumn get note => text().nullable()();
  IntColumn get restSeconds => integer().nullable()();
  IntColumn get barGrams => integer().withDefault(const Constant(20000))();

  @override
  Set<Column<Object>> get primaryKey => {uuid};
}

/// The row that matters: weight, reps, ticked.
///
/// Written the moment it is ticked, never at the end of the session.
@DataClassName('WorkoutSetRow')
class WorkoutSets extends Table {
  TextColumn get uuid => text()();
  TextColumn get sessionExerciseUuid =>
      text().references(SessionExercises, #uuid)();
  IntColumn get position => integer()();
  IntColumn get weightGrams => integer().withDefault(const Constant(0))();
  IntColumn get reps => integer().withDefault(const Constant(0))();
  BoolColumn get done => boolean().withDefault(const Constant(false))();

  /// What this set was asked to be, kept so "did I hit the target?" is
  /// answerable a year later without the program still existing.
  TextColumn get targetLabel => text().nullable()();
  BoolColumn get openEnded => boolean().withDefault(const Constant(false))();
  DateTimeColumn get loggedAt => dateTime().withDefault(currentDateAndTime)();

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

/// One night, as reported the morning after.
///
/// The app does not watch anyone sleep: both ends are times I said. The
/// target is frozen into the row for the same reason a workout set
/// keeps its target — moving my bedtime must not rewrite last month's
/// debt ([[Health]]).
@DataClassName('SleepSessionRow')
class SleepSessions extends Table {
  TextColumn get uuid => text()();

  /// The Harvest Day I woke up on: a night is filed under its morning,
  /// because that is the day it decides how I feel.
  TextColumn get harvestDay => text()();

  DateTimeColumn get fellAsleepAt => dateTime()();
  DateTimeColumn get wokeAt => dateTime()();

  /// What the night was meant to be, in minutes, as of that night.
  IntColumn get targetMinutes => integer()();

  /// 1-5. Null is a legitimate answer at 6 AM.
  IntColumn get restedStars => integer().nullable()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {uuid};
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
    StepDays,
    BodyWeights,
    Exercises,
    Programs,
    ProgramDays,
    ProgramSlots,
    TargetSets,
    TrainingMaxes,
    WorkoutSessions,
    SessionExercises,
    WorkoutSets,
    SleepSessions,
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
  int get schemaVersion => 13;

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
      // Phase 4 lands as one migration rather than five: the tables
      // are inert until the feature is switched on, and one upgrade is
      // kinder to a phone than five.
      if (from < 12) {
        await m.createTable(stepDays);
        await m.createTable(bodyWeights);
        await m.createTable(exercises);
        await m.createTable(programs);
        await m.createTable(programDays);
        await m.createTable(programSlots);
        await m.createTable(targetSets);
        await m.createTable(trainingMaxes);
        await m.createTable(workoutSessions);
        await m.createTable(sessionExercises);
        await m.createTable(workoutSets);
      }
      if (from < 13) {
        await m.createTable(sleepSessions);
      }
    },
  );

  static QueryExecutor _openConnection() => driftDatabase(name: 'harvest');
}
