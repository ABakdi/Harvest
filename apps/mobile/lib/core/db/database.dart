import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:harvest/core/db/built_in_lists.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:uuid/uuid.dart';

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

  /// The goal this seed serves, if any ([[Goals]]). A link, not an
  /// owner: archiving either side never touches the other (GL5).
  TextColumn get goalUuid => text().nullable()();

  DateTimeColumn get archivedAt => dateTime().nullable()();

  /// Why this seed was put away — written when it is archived, and the
  /// only thing the archive can tell me later that the title cannot.
  TextColumn get archiveNote => text().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().clientDefault(DateTime.now)();
  DateTimeColumn get updatedAt => dateTime().clientDefault(DateTime.now)();

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
  DateTimeColumn get loggedAt => dateTime().clientDefault(DateTime.now)();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().clientDefault(DateTime.now)();

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
  DateTimeColumn get loggedAt => dateTime().clientDefault(DateTime.now)();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().clientDefault(DateTime.now)();

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
  DateTimeColumn get createdAt => dateTime().clientDefault(DateTime.now)();
  DateTimeColumn get updatedAt => dateTime().clientDefault(DateTime.now)();
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
  DateTimeColumn get createdAt => dateTime().clientDefault(DateTime.now)();
  DateTimeColumn get updatedAt => dateTime().clientDefault(DateTime.now)();
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

  /// The SHA-256 of the file's bytes, once it has been synced.
  ///
  /// A file is named by its own contents on the server, so this is
  /// both the name to fetch it by and the proof that what arrived is
  /// what left ([[Sync-API]]). Null means it has never been uploaded,
  /// which is every file until sync is switched on.
  TextColumn get fileHash => text().nullable()();

  DateTimeColumn get capturedAt => dateTime().clientDefault(DateTime.now)();
  DateTimeColumn get updatedAt => dateTime().clientDefault(DateTime.now)();

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
  DateTimeColumn get updatedAt => dateTime().clientDefault(DateTime.now)();

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
  DateTimeColumn get measuredAt => dateTime().clientDefault(DateTime.now)();
  DateTimeColumn get updatedAt => dateTime().clientDefault(DateTime.now)();
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
  DateTimeColumn get createdAt => dateTime().clientDefault(DateTime.now)();
  DateTimeColumn get updatedAt => dateTime().clientDefault(DateTime.now)();
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
  DateTimeColumn get createdAt => dateTime().clientDefault(DateTime.now)();
  DateTimeColumn get updatedAt => dateTime().clientDefault(DateTime.now)();
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
  DateTimeColumn get updatedAt => dateTime().clientDefault(DateTime.now)();

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
  DateTimeColumn get startedAt => dateTime().clientDefault(DateTime.now)();

  /// Null while the session is still running — which is how an
  /// interrupted workout is found and resumed ([[Gym]] rule Y3).
  DateTimeColumn get endedAt => dateTime().nullable()();
  TextColumn get note => text().nullable()();

  /// Set while the clock is stopped — a phone call, a queue for the
  /// rack. The elapsed time is what was not paused ([[Checkpoint-6]]).
  DateTimeColumn get pausedAt => dateTime().nullable()();

  /// Every pause that has already ended, added up.
  IntColumn get pausedSeconds => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime().clientDefault(DateTime.now)();
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

  /// Why it was skipped, in my own words.
  ///
  /// Separate from [note], because "shoulder still sore" is the reason
  /// I did not do it and the note is what I want to remember about
  /// doing it ([[Gym]], [[Audit-v2]] P3-04).
  TextColumn get skipReason => text().nullable()();
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
  DateTimeColumn get loggedAt => dateTime().clientDefault(DateTime.now)();

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
  DateTimeColumn get updatedAt => dateTime().clientDefault(DateTime.now)();

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
  DateTimeColumn get loggedAt => dateTime().clientDefault(DateTime.now)();

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
  DateTimeColumn get updatedAt => dateTime().clientDefault(DateTime.now)();

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
  DateTimeColumn get loggedAt => dateTime().clientDefault(DateTime.now)();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().clientDefault(DateTime.now)();

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
  DateTimeColumn get loggedAt => dateTime().clientDefault(DateTime.now)();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().clientDefault(DateTime.now)();

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
  DateTimeColumn get createdAt => dateTime().clientDefault(DateTime.now)();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().clientDefault(DateTime.now)();

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
  DateTimeColumn get loggedAt => dateTime().clientDefault(DateTime.now)();
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

  /// When the category was made; the list is ordered by it, so a
  /// restore (which bumps [updatedAt] for sync) keeps its place. Null
  /// only on a row synced from a device that predates the column, which
  /// sorts by [updatedAt] instead.
  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().clientDefault(DateTime.now)();

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
  DateTimeColumn get queuedAt => dateTime().clientDefault(DateTime.now)();
}

/// Simple key-value store for app settings (theme, locale, goal, times).
class KvSettings extends Table {
  TextColumn get key => text()();
  TextColumn get valueJson => text()();
  DateTimeColumn get updatedAt => dateTime().clientDefault(DateTime.now)();

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
  DateTimeColumn get createdAt => dateTime().clientDefault(DateTime.now)();
  DateTimeColumn get updatedAt => dateTime().clientDefault(DateTime.now)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {uuid};
}

/// Something I am working toward, with a list of what it takes
/// ([[Goals]]). No streak, no schedule: its seeds are what get judged.
@DataClassName('GoalRow')
class Goals extends Table {
  TextColumn get uuid => text()();
  TextColumn get title => text()();

  /// Why I want it. Free text, shown at the top of the goal.
  TextColumn get why => text().withDefault(const Constant(''))();

  /// Optional target Harvest Day (yyyy-MM-dd).
  TextColumn get targetDay => text().nullable()();

  /// `active` | `achieved` | `dropped`.
  TextColumn get status => text().withDefault(const Constant('active'))();

  /// Why it was dropped, or a line on how it was achieved.
  TextColumn get statusNote => text().nullable()();
  DateTimeColumn get achievedAt => dateTime().nullable()();

  /// Order on the board.
  IntColumn get position => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().clientDefault(DateTime.now)();
  DateTimeColumn get updatedAt => dateTime().clientDefault(DateTime.now)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {uuid};
}

/// One line of what a goal takes: a `need` (to have or know) or a
/// `step` (to do). Ticked by hand, or by the to-do it was planted as.
@DataClassName('GoalItemRow')
class GoalItems extends Table {
  TextColumn get uuid => text()();
  TextColumn get goalUuid => text().references(Goals, #uuid)();

  /// `need` | `step`.
  TextColumn get kind => text().withDefault(const Constant('step'))();
  TextColumn get body => text()();
  TextColumn get note => text().nullable()();

  /// Ticked when set; the time it was ticked.
  DateTimeColumn get doneAt => dateTime().nullable()();
  IntColumn get position => integer().withDefault(const Constant(0))();

  /// The seed this item was planted as, if it was.
  TextColumn get commitmentUuid => text().nullable()();

  /// For a subtask, the item it belongs to; null for a top-level item
  /// ([[Goals]] GL8, schema v24). One level deep: a parent never has a
  /// parent of its own.
  TextColumn get parentUuid => text().nullable()();
  DateTimeColumn get createdAt => dateTime().clientDefault(DateTime.now)();
  DateTimeColumn get updatedAt => dateTime().clientDefault(DateTime.now)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {uuid};
}

/// One list of things I have not got to yet ([[Lists]]): what to buy,
/// what to read, whatever I think of next. A new list is a row here,
/// never a new table (L1).
@DataClassName('ListRow')
class Lists extends Table {
  TextColumn get uuid => text()();
  TextColumn get name => text()();

  /// `plain` | `shopping` | `media` — which fields its items carry (L2).
  TextColumn get kind => text().withDefault(const Constant('plain'))();

  /// An icon's key; null shows the kind's own.
  TextColumn get icon => text().nullable()();

  /// Order among the lists.
  IntColumn get position => integer().withDefault(const Constant(0))();

  /// `buy` | `wish` | `read` | `watch` for the four every device has,
  /// under fixed ids; null for a list I made. A built-in list is never
  /// deleted (L10).
  TextColumn get builtIn => text().nullable()();
  DateTimeColumn get createdAt => dateTime().clientDefault(DateTime.now)();
  DateTimeColumn get updatedAt => dateTime().clientDefault(DateTime.now)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {uuid};
}

/// One item of one list ([[Lists]]). The table kept the Wishlist's
/// name, so beta devices and archives keep working; it holds every
/// list's items now. An estimate is a plan, not money (L3): nothing
/// here moves a wallet.
@DataClassName('WishlistItemRow')
class WishlistItems extends Table {
  TextColumn get uuid => text()();

  /// `buy` | `wish`: which of the Wishlist's two lists, from before
  /// lists. Still written — `buy` for *To buy*, `wish` for every other
  /// list — for clients that only know this column.
  TextColumn get list => text().withDefault(const Constant('buy'))();

  /// The list it belongs to — the truth since v23. Null on a row from a
  /// client that only knows [list], which then names the list.
  TextColumn get listUuid => text().nullable()();
  TextColumn get title => text()();

  /// Estimated price in minor units; null while the thing has no number.
  IntColumn get priceMinor => integer().nullable()();
  TextColumn get currency => text().withDefault(const Constant('DZD'))();
  TextColumn get note => text().nullable()();

  /// Planned purchase Harvest Day (yyyy-MM-dd) — a plan, not a
  /// commitment: nothing reads it to judge or remind.
  TextColumn get targetDay => text().nullable()();

  /// Media items: `book` | `article` | `show` | `film` | `video` |
  /// `podcast` | `other`.
  TextColumn get mediaType => text().nullable()();

  /// A link I saved; nothing fetches it (L9).
  TextColumn get link => text().nullable()();

  /// The author or creator.
  TextColumn get creator => text().nullable()();

  /// When I started it: a media item in progress.
  DateTimeColumn get startedAt => dateTime().nullable()();

  /// 1–5, given when finished.
  IntColumn get rating => integer().nullable()();

  /// The seed it was planted as, and the note written about it.
  TextColumn get seedUuid => text().nullable()();
  TextColumn get noteUuid => text().nullable()();

  /// Done, for every kind: bought, finished or ticked. Done items fold
  /// under the open ones.
  DateTimeColumn get boughtAt => dateTime().nullable()();

  /// Order within one list.
  IntColumn get position => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().clientDefault(DateTime.now)();
  DateTimeColumn get updatedAt => dateTime().clientDefault(DateTime.now)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {uuid};
}

/// One point of the trail ([[Places]]). Append-only (PL4): a day's
/// trail can be deleted whole, a point is never moved.
@DataClassName('LocationPointRow')
@TableIndex(name: 'location_points_day', columns: {#harvestDay})
class LocationPoints extends Table {
  TextColumn get uuid => text()();
  TextColumn get harvestDay => text()();
  DateTimeColumn get recordedAt => dateTime()();
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();
  RealColumn get accuracyM => real().nullable()();
  RealColumn get speedMps => real().nullable()();
  RealColumn get altitudeM => real().nullable()();
  DateTimeColumn get updatedAt => dateTime().clientDefault(DateTime.now)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {uuid};
}

/// Where I was when a row was written ([[Places]] PL2): one geotag per
/// insert into an action table, resolved after the fact.
@DataClassName('GeotagRow')
@TableIndex(name: 'geotags_target', columns: {#targetTable, #targetUuid})
@TableIndex(name: 'geotags_day', columns: {#harvestDay})
class Geotags extends Table {
  TextColumn get uuid => text()();
  TextColumn get targetTable => text()();
  TextColumn get targetUuid => text()();
  TextColumn get harvestDay => text()();

  /// When the action happened — not when the fix arrived.
  DateTimeColumn get at => dateTime()();
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();
  RealColumn get accuracyM => real().nullable()();

  /// `pending` | `fixed` | `unavailable`.
  TextColumn get state => text().withDefault(const Constant('pending'))();
  DateTimeColumn get updatedAt => dateTime().clientDefault(DateTime.now)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {uuid};
}

/// A stay I gave a name ("Home", "Gym"), and the circle it covers.
@DataClassName('SavedPlaceRow')
class SavedPlaces extends Table {
  TextColumn get uuid => text()();
  TextColumn get name => text()();
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();
  RealColumn get radiusM => real().withDefault(const Constant(100))();

  /// Whatever I want to remember about this place.
  TextColumn get notes => text().nullable()();

  DateTimeColumn get createdAt => dateTime().clientDefault(DateTime.now)();
  DateTimeColumn get updatedAt => dateTime().clientDefault(DateTime.now)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {uuid};
}

/// A file that belongs to a note — a recording — embedded in its body
/// as `![[fileName]]` ([[Notes]] N7).
@DataClassName('NoteAttachmentRow')
class NoteAttachments extends Table {
  TextColumn get uuid => text()();
  TextColumn get noteUuid => text().references(Notes, #uuid)();

  /// `audio`.
  TextColumn get kind => text().withDefault(const Constant('audio'))();

  /// The name the body embeds; unique, so an embed resolves to one file.
  TextColumn get fileName => text().unique()();

  /// Relative to the attachments directory.
  TextColumn get storedPath => text()();
  IntColumn get durationMs => integer().nullable()();
  IntColumn get sizeBytes => integer().withDefault(const Constant(0))();

  /// The SHA-256 of the file's bytes, once it has been synced.
  ///
  /// A file is named by its own contents on the server, so this is
  /// both the name to fetch it by and the proof that what arrived is
  /// what left ([[Sync-API]]). Null means it has never been uploaded,
  /// which is every file until sync is switched on.
  TextColumn get fileHash => text().nullable()();

  DateTimeColumn get createdAt => dateTime().clientDefault(DateTime.now)();
  DateTimeColumn get updatedAt => dateTime().clientDefault(DateTime.now)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {uuid};
}

/// The tables whose inserts are *things I did*, and so get a geotag
/// when Places is on ([[Places]] PL2). A new feature joins by being
/// added here.
const actionTables = {
  'commitments',
  'check_ins',
  'seed_notes',
  'notes',
  'note_attachments',
  'memories',
  'albums',
  'expenses',
  'money_txns',
  'debts',
  'debt_payments',
  'body_weights',
  'sleep_sessions',
  'workout_sessions',
  'goals',
  'goal_items',
};

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
    Goals,
    GoalItems,
    Lists,
    WishlistItems,
    LocationPoints,
    Geotags,
    SavedPlaces,
    NoteAttachments,
  ],
)
class HarvestDatabase extends _$HarvestDatabase {
  HarvestDatabase() : super(_openConnection());

  HarvestDatabase.forTesting(super.e);

  /// Dates are stored as ISO-8601 text, not unix seconds.
  ///
  /// Seconds were enough while the phone was the only writer. Sync gave
  /// the same row a second writer with a millisecond clock, and two
  /// edits inside one second tie — the loser's push comes back stale
  /// and the two devices disagree until the row is touched again
  /// ([[Sync-API]], [[Phase-6-Sync-Accounts-and-Web]] M6.8). Text keeps
  /// microseconds, so a tie needs two edits inside one microsecond.
  @override
  DriftDatabaseOptions get options =>
      const DriftDatabaseOptions(storeDateTimeAsText: true);

  @override
  int get schemaVersion => 24;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await seedBuiltInLists();
    },
    onUpgrade: (m, from, to) async {
      // A table created in this run already carries the newest
      // columns; later addColumn steps must skip it.
      final expensesJustCreated = from < 2;
      final moneyTxnsJustCreated = from < 6;
      final memoriesJustCreated = from < 10;
      final sessionsJustCreated = from < 12;
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
      if (from < 14 && !sessionsJustCreated) {
        await m.addColumn(workoutSessions, workoutSessions.pausedAt);
        await m.addColumn(workoutSessions, workoutSessions.pausedSeconds);
      }
      // Phase 5 in one step, as phase 4 was: goals, places and voice.
      if (from < 15) {
        await m.addColumn(commitments, commitments.goalUuid);
        await m.createTable(goals);
        await m.createTable(goalItems);
        await m.createTable(locationPoints);
        await m.createTable(geotags);
        await m.createTable(savedPlaces);
        await m.createTable(noteAttachments);
        await m.createIndex(locationPointsDay);
        await m.createIndex(geotagsTarget);
        await m.createIndex(geotagsDay);
      }
      if (from < 16 && !sessionsJustCreated) {
        await m.addColumn(sessionExercises, sessionExercises.skipReason);
      }
      // The files themselves start unsynced, so every hash starts null
      // and is filled in by the first sync that carries the file.
      if (from < 17) {
        if (!memoriesJustCreated) await m.addColumn(memories, memories.fileHash);
        if (from >= 15) {
          await m.addColumn(noteAttachments, noteAttachments.fileHash);
        }
      }
      // Saved places take a note: what I want to remember about a spot
      // ([[Places]]). Existing rows keep a null note, which the editors
      // treat as empty. A box created earlier in this same run (from
      // < 15) is built with the current definition and already carries
      // the column. From 15 to 17 the column must exist *before* the
      // date rewrite below, because that rewrite rebuilds the table
      // from the current definition and would otherwise read a column
      // that is not there yet.
      if (from >= 15 && from < 20) {
        await m.addColumn(savedPlaces, savedPlaces.notes);
      }
      // Categories remember when they were made, so a restored one keeps
      // its place in the list ([[Finances]]). The last edit is the best
      // guess an existing row has, and it keeps today's order. Same
      // ordering rule as above: before the rewrite, which then converts
      // the copied value along with the one it came from.
      if (from >= 4 && from < 21) {
        await m.addColumn(expenseCategories, expenseCategories.createdAt);
        await customStatement(
          'UPDATE expense_categories SET created_at = updated_at',
        );
      }
      // Subtasks ([[Goals]] GL8, M6.13): an item may belong to another
      // item. Every existing item stays top-level, so the column starts
      // null and nothing is rewritten. Same ordering rule as above: a
      // box created in this run (from < 15) already has it, and from 15
      // it is added before the v18 and v22 rebuilds, which copy the
      // table into its current definition.
      if (from >= 15 && from < 24) {
        await m.addColumn(goalItems, goalItems.parentUuid);
      }
      // Every date becomes text, keeping the instant it already held.
      // A table created earlier in this same run is empty and converts
      // to nothing, which costs a statement and no data.
      if (from < 18) {
        await customStatement('PRAGMA foreign_keys = OFF');
        for (final table in allTables) {
          // Tables created later in this run (v19+) do not exist yet;
          // theirs are already text.
          if (table.actualTableName == wishlistItems.actualTableName ||
              table.actualTableName == lists.actualTableName) {
            continue;
          }
          await _datesToText(m, table);
        }
        await customStatement('PRAGMA foreign_keys = ON');
      }
      // The wishlist: one new table ([[Wishlist]]), inert until the tab
      // is built on it, so exactly one step.
      if (from < 19) {
        await m.createTable(wishlistItems);
      }
      // A stamp now comes from the phone's clock, not sqlite's: the SQL
      // default wrote UTC with no zone, which read back as a UTC clock
      // and put every default-stamped time an hour early in Algiers.
      // Dropping a column default means rebuilding the table; then
      // every date that is not already in the app's own spelling is
      // rewritten, keeping its instant.
      // Lists' item columns ([[Lists]]). A wishlist created earlier in
      // this run (from < 19) already has them; from 19 they are added
      // before the v22 rebuild below, which copies each table into its
      // current definition and would otherwise read columns that are not
      // there yet.
      if (from >= 19 && from < 23) {
        await m.addColumn(wishlistItems, wishlistItems.listUuid);
        await m.addColumn(wishlistItems, wishlistItems.mediaType);
        await m.addColumn(wishlistItems, wishlistItems.link);
        await m.addColumn(wishlistItems, wishlistItems.creator);
        await m.addColumn(wishlistItems, wishlistItems.startedAt);
        await m.addColumn(wishlistItems, wishlistItems.rating);
        await m.addColumn(wishlistItems, wishlistItems.seedUuid);
        await m.addColumn(wishlistItems, wishlistItems.noteUuid);
      }
      if (from < 22) {
        await customStatement('PRAGMA foreign_keys = OFF');
        for (final table in allTables) {
          // `lists` arrives in v23, below, already in today's spelling.
          if (table.actualTableName == lists.actualTableName) continue;
          final stamped = table.$columns.any(
            (c) => c.type == DriftSqlType.dateTime && c.clientDefault != null,
          );
          if (stamped) {
            await m.alterTable(TableMigration(table));
          }
          await _datesToLocal(table);
        }
        await customStatement('PRAGMA foreign_keys = ON');
      }
      // Lists ([[Lists]], M6.12): the Wishlist's two lists become two
      // of four built-in ones, under ids every device agrees on, and
      // each item is told which list it is in. Someone who had items
      // keeps seeing them: the feature starts on for them, and off, as
      // every feature does, for everyone else.
      if (from < 23) {
        await m.createTable(lists);
        await seedBuiltInLists();
        await customStatement(
          'UPDATE wishlist_items SET list_uuid = '
          "CASE list WHEN 'buy' THEN ? ELSE ? END WHERE list_uuid IS NULL",
          [BuiltInList.buy.uuid, BuiltInList.wish.uuid],
        );
        final items = await customSelect(
          'SELECT COUNT(*) AS n FROM wishlist_items WHERE deleted_at IS NULL',
        ).getSingle();
        if (items.read<int>('n') > 0) {
          // `FeatureKeys.lists`, and a preference like any other, so it
          // is queued for the other devices too.
          await into(kvSettings).insert(
            KvSettingsCompanion.insert(
              key: 'features.lists',
              valueJson: '"true"',
            ),
            mode: InsertMode.insertOrIgnore,
          );
          await into(outbox).insert(
            OutboxCompanion.insert(
              targetTable: 'kv_settings',
              rowUuid: 'features.lists',
              op: 'update',
            ),
          );
        }
      }
    },
  );

  /// Makes the four built-in lists that are missing ([[Lists]] L10),
  /// and leaves the ones that are there — renamed, reordered — as they
  /// are. Their ids are fixed and their stamp is old, so the same rows
  /// made on another device merge into these instead of beside them;
  /// nothing is queued, since every device makes them itself.
  Future<void> seedBuiltInLists() async {
    final stamp = builtInListsStampedAt.toLocal();
    await batch((b) {
      for (final list in BuiltInList.values) {
        b.insert(
          lists,
          ListsCompanion.insert(
            uuid: list.uuid,
            name: list.defaultName,
            kind: Value(list.kind),
            position: Value(list.position),
            builtIn: Value(list.name),
            createdAt: Value(stamp),
            updatedAt: Value(stamp),
          ),
          mode: InsertMode.insertOrIgnore,
        );
      }
    });
  }

  /// Rewrites one table's UTC dates in the spelling the app writes: the
  /// local clock with its offset, `2026-09-25T16:21:00.000 +01:00`.
  ///
  /// Two spellings are UTC. sqlite's own clock — the old column
  /// default, and the v18 rewrite — writes `2026-09-25 15:21:00`; a
  /// pulled row wrote a `Z`. Both read back as a UTC `DateTime`, whose
  /// clock is the wrong one to show. A date that already carries an
  /// offset was written by the app and is left as it is.
  Future<void> _datesToLocal(TableInfo<Table, Object?> table) async {
    final name = table.actualTableName;
    for (final column in table.$columns) {
      if (column.type != DriftSqlType.dateTime) continue;
      final col = '"${column.name}"';
      final rows = await customSelect(
        'SELECT rowid AS r, $col AS v FROM "$name" '
        "WHERE typeof($col) = 'text' AND ($col GLOB '*Z' OR $col GLOB "
        "'[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9] "
        "[0-9][0-9]:[0-9][0-9]:[0-9][0-9]')",
      ).get();
      if (rows.isEmpty) continue;
      await batch((b) {
        for (final row in rows) {
          b.customStatement('UPDATE "$name" SET $col = ? WHERE rowid = ?', [
            typeMapping.mapToSqlVariable(
              readUtcText(row.read<String>('v')).toLocal(),
            ),
            row.read<int>('r'),
          ]);
        }
      });
    }
  }

  /// Rewrites one table's date columns from unix seconds to text.
  ///
  /// `datetime(col, 'unixepoch')` is sqlite's own conversion, so the
  /// instant is the one that was stored; only its spelling changes.
  static Future<void> _datesToText(
    Migrator m,
    TableInfo<Table, Object?> table,
  ) async {
    final transformer = <GeneratedColumn<Object>, Expression<Object>>{};
    for (final column in table.$columns) {
      if (column.type == DriftSqlType.dateTime) {
        transformer[column] = DateTimeExpressions.fromUnixEpoch(
          column.dartCast<int>(),
        );
      }
    }
    if (transformer.isEmpty) return;
    await m.alterTable(
      TableMigration(table, columnTransformer: transformer),
    );
  }

  static QueryExecutor _openConnection() => driftDatabase(name: 'harvest');

  /// Whether an insert into an action table also writes a pending
  /// geotag ([[Places]] PL2). Set from the `features.places` setting by
  /// the app; a background isolate's database leaves it off.
  bool geotagging = false;

  /// Appends one change-log row for the sync client ([[Sync-Strategy]]).
  /// Every repository used to carry its own copy of this insert; now
  /// they call this ([[Audit-v2-Beta]] Q2-06).
  ///
  /// It is also the one place every action passes through, so it is
  /// where an action gets its place: an insert into an [actionTables]
  /// table leaves a pending geotag for the filler to resolve.
  Future<void> logChange(String table, String rowUuid, String op) async {
    await into(
      outbox,
    ).insert(
      OutboxCompanion.insert(targetTable: table, rowUuid: rowUuid, op: op),
    );
    if (geotagging && op == 'insert' && actionTables.contains(table)) {
      final now = DateTime.now();
      final tag = geotagUuid(table, rowUuid);
      await into(geotags).insert(
        GeotagsCompanion.insert(
          uuid: tag,
          targetTable: table,
          targetUuid: rowUuid,
          harvestDay: harvestDayKeyOf(now),
          at: now,
        ),
        mode: InsertMode.insertOrIgnore,
      );
      await into(outbox).insert(
        OutboxCompanion.insert(
          targetTable: 'geotags',
          rowUuid: tag,
          op: 'insert',
        ),
      );
    }
  }

  /// Keeps the change log to its newest [keep] rows.
  ///
  /// The log is an increment, never the only copy: a device's first sync
  /// sends a full snapshot of every table ([[Sync-API]]), so rows that
  /// piled up before any account existed can go without losing a
  /// thing. This is the cap [[ADR-005-Local-First-Sync]] promised.
  Future<int> capOutbox({int keep = 50000}) async {
    final newest =
        await (selectOnly(
              outbox,
            )..addColumns([outbox.seq.max()]))
            .map((row) => row.read(outbox.seq.max()))
            .getSingleOrNull();
    if (newest == null || newest <= keep) return 0;
    return (delete(
      outbox,
    )..where((row) => row.seq.isSmallerOrEqualValue(newest - keep))).go();
  }

  /// One XP or coin movement, with its change-log row. The ledger is
  /// history that syncs ([[Sync-Strategy]]), so no service inserts
  /// into it any other way ([[Audit-v2]] Q3-01).
  Future<void> insertLedger(LedgerCompanion entry) async {
    await into(ledger).insert(entry);
    await logChange('ledger', entry.uuid.value, 'insert');
  }
}

/// A geotag's id is derived from what it tags, so the same action can
/// never be tagged twice — not by a retry, not by an import.
String geotagUuid(String table, String rowUuid) =>
    const Uuid().v5(Namespace.url.value, 'harvest:geotag:$table:$rowUuid');

String harvestDayKeyOf(DateTime moment) => HarvestDay.of(moment).key;

/// The instant a stored date names, read as drift reads it: an offset
/// or a `Z` says which clock it is, and a date with neither is
/// sqlite's clock, which is UTC — never the local clock
/// [DateTime.parse] would assume for it.
DateTime readUtcText(String text) {
  final zoned =
      text.endsWith('Z') || RegExp(r' ?[-+]\d\d(:?\d\d)?$').hasMatch(text);
  return DateTime.parse(zoned ? text : '${text}Z');
}
