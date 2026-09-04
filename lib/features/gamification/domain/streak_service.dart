import 'dart:convert';
import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/db/database_provider.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/commitments/domain/commitment.dart';
import 'package:harvest/features/commitments/domain/schedule.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

part 'streak_service.g.dart';

/// Coin rewards for global streak milestones.
const streakMilestoneCoins = {7: 50, 30: 200, 100: 1000};

/// Streak Freeze economy: price in coins and the storage cap.
const freezeCost = 100;
const maxFreezesStored = 2;

/// Maintains the global and per-habit streaks (business rules #1 and #4).
///
/// Two entry points keep it correct:
/// - [onCheckIn]/[onUndo] update streaks live as effort is logged.
/// - [reconcile] runs at the 3 AM reset and lazily on app open, judging
///   every completed day exactly once — consuming stored freezes before
///   breaking the global streak. It is idempotent per Harvest Day.
class StreakService {
  StreakService(this._db);

  final HarvestDatabase _db;
  static const _uuid = Uuid();

  static const globalScope = 'global';
  static const goalKey = 'dailyHarvestGoal';
  static const defaultGoal = 3;

  /// Where reconcile left off; public so tests can pin the clock.
  static const lastJudgedKey = 'streak.lastJudgedDay';

  // ------------------------------------------------------------- queries

  Future<int> dailyGoal() async {
    final row = await (_db.select(
      _db.kvSettings,
    )..where((s) => s.key.equals(goalKey))).getSingleOrNull();
    if (row == null) return defaultGoal;
    final value = jsonDecode(row.valueJson);
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? defaultGoal;
  }

  /// Productive actions on [day]: each habit/to-do checked in counts one;
  /// a project counts one once it reached its daily commitment. Effort
  /// on a seed that was archived later still counts — it was real.
  Future<int> productiveActions(HarvestDay day) async {
    final quantity = _db.checkIns.quantity.sum();
    final query = _db.selectOnly(_db.checkIns)
      ..addColumns([_db.checkIns.commitmentUuid, quantity])
      ..where(
        _db.checkIns.harvestDay.equals(day.key) &
            _db.checkIns.deletedAt.isNull(),
      )
      ..groupBy([_db.checkIns.commitmentUuid]);
    final sums = <String, int>{
      for (final row in await query.get())
        row.read(_db.checkIns.commitmentUuid)!: row.read(quantity) ?? 0,
    };
    if (sums.isEmpty) return 0;

    final commitments = await (_db.select(
      _db.commitments,
    )..where((c) => c.uuid.isIn(sums.keys.toList()))).get();

    var actions = 0;
    for (final row in commitments) {
      if (row.type == CommitmentType.project.name) {
        final daily = row.dailyCommitment ?? 0;
        if (daily > 0 && (sums[row.uuid] ?? 0) >= daily) actions++;
      } else {
        actions++;
      }
    }
    return actions;
  }

  // -------------------------------------------------------- live updates

  Future<void> onCheckIn(Commitment commitment, HarvestDay day) async {
    // Individual habit streaks count each completed day.
    if (commitment.type == CommitmentType.habit) {
      final streak = await _row(commitment.uuid);
      if (streak.lastEarnedDay != day.key) {
        await _write(
          scope: commitment.uuid,
          current: streak.current + 1,
          best: _max(streak.best, streak.current + 1),
          lastEarnedDay: day.key,
          freezesStored: streak.freezesStored,
        );
      }
    }
    await _refreshGlobal(day);
  }

  Future<void> onUndo(Commitment commitment, HarvestDay day) async {
    if (commitment.type == CommitmentType.habit) {
      final streak = await _row(commitment.uuid);
      if (streak.lastEarnedDay == day.key) {
        await _write(
          scope: commitment.uuid,
          current: math.max(0, streak.current - 1),
          best: streak.best,
          lastEarnedDay: _earnedBefore(day, streak.current - 1),
          freezesStored: streak.freezesStored,
        );
      }
    }
    await _refreshGlobal(day);
  }

  /// Extends or retracts the global streak based on [day]'s actions.
  Future<void> _refreshGlobal(HarvestDay day) async {
    final goal = await dailyGoal();
    final actions = await productiveActions(day);
    final streak = await _row(globalScope);

    if (actions >= goal && streak.lastEarnedDay != day.key) {
      final current = streak.current + 1;
      await _write(
        scope: globalScope,
        current: current,
        best: _max(streak.best, current),
        lastEarnedDay: day.key,
        freezesStored: streak.freezesStored,
      );
      final coins = streakMilestoneCoins[current];
      if (coins != null) await _grantCoins(coins, 'streak:$current', day);
    } else if (actions < goal && streak.lastEarnedDay == day.key) {
      // Same-day undo dropped the day below the goal.
      await _write(
        scope: globalScope,
        current: math.max(0, streak.current - 1),
        best: streak.best,
        lastEarnedDay: _earnedBefore(day, streak.current - 1),
        freezesStored: streak.freezesStored,
      );
    }
  }

  /// After an undo on [day]: a streak that still stands is consecutive,
  /// so its last earned day is the day before; a streak that fell to
  /// zero has no earned day to point at.
  String? _earnedBefore(HarvestDay day, int remaining) =>
      remaining > 0 ? day.previous.key : null;

  /// The current global streak length.
  Future<int> currentGlobal() async => (await _row(globalScope)).current;

  /// Buys one Streak Freeze with coins. Returns false when the balance
  /// is short or the shed is full (max [maxFreezesStored]).
  Future<bool> buyFreeze({HarvestDay? day}) async {
    final today = day ?? HarvestDay.today();
    // Balance and shed are read inside the transaction so two taps
    // cannot both pass the check.
    return _db.transaction(() async {
      final streak = await _row(globalScope);
      if (streak.freezesStored >= maxFreezesStored) return false;

      final sum = _db.ledger.delta.sum();
      final query = _db.selectOnly(_db.ledger)
        ..addColumns([sum])
        ..where(_db.ledger.kind.equals('coin'));
      final balance = (await query.getSingle()).read(sum) ?? 0;
      if (balance < freezeCost) return false;

      await _db
          .into(_db.ledger)
          .insert(
            LedgerCompanion.insert(
              uuid: _uuid.v4(),
              kind: 'coin',
              delta: -freezeCost,
              reason: 'freeze:buy',
              harvestDay: today.key,
            ),
          );
      await _write(
        scope: globalScope,
        current: streak.current,
        best: streak.best,
        lastEarnedDay: streak.lastEarnedDay,
        freezesStored: streak.freezesStored + 1,
      );
      return true;
    });
  }

  // -------------------------------------------------------- reconcile

  /// Judges every completed Harvest Day since the last run: a missed
  /// global goal consumes a stored freeze before breaking the streak,
  /// and a habit missing a due day loses its individual streak.
  Future<void> reconcile({DateTime? now}) async {
    final today = HarvestDay.of(now ?? DateTime.now());
    final yesterday = today.previous;

    final lastJudgedRow = await (_db.select(
      _db.kvSettings,
    )..where((s) => s.key.equals(lastJudgedKey))).getSingleOrNull();

    if (lastJudgedRow == null) {
      // First run: nothing before install day to judge.
      await _setLastJudged(yesterday);
      return;
    }

    final lastJudged = HarvestDay.tryParse(
      jsonDecode(lastJudgedRow.valueJson) as String?,
    );
    var day = (lastJudged ?? yesterday.previous).next;
    if (day.compareTo(today) >= 0) return;

    // A long absence with no effort at all is one verdict, not one per
    // day: every live streak breaks (freezes first), and we jump ahead.
    if (!await _anyCheckInBetween(day, yesterday)) {
      await _breakEverythingIdle(day, yesterday);
      await _setLastJudged(yesterday);
      return;
    }

    final habits = await _habits();
    while (day.compareTo(today) < 0) {
      await _judgeGlobal(day);
      for (final habit in habits) {
        if (!_wasActiveOn(habit, day)) continue;
        await _judgeHabit(habit, day);
      }
      day = day.next;
    }
    await _setLastJudged(yesterday);
  }

  /// Vacation mode and archiving only excuse the days after they were
  /// switched on — pausing after a miss does not rewrite the miss. A
  /// day that ended before the habit existed is not its day either.
  bool _wasActiveOn(CommitmentRow habit, HarvestDay day) {
    final dayEnd = day.next.startsAt;
    if (HarvestDay.of(habit.createdAt).compareTo(day) > 0) return false;
    final pausedBefore =
        habit.pausedAt != null && habit.pausedAt!.isBefore(dayEnd);
    final archivedBefore =
        habit.archivedAt != null && habit.archivedAt!.isBefore(dayEnd);
    return !pausedBefore && !archivedBefore;
  }

  Future<bool> _anyCheckInBetween(HarvestDay from, HarvestDay to) async {
    final row =
        await (_db.select(_db.checkIns)
              ..where(
                (c) =>
                    c.harvestDay.isBiggerOrEqualValue(from.key) &
                    c.harvestDay.isSmallerOrEqualValue(to.key) &
                    c.deletedAt.isNull(),
              )
              ..limit(1))
            .getSingleOrNull();
    return row != null;
  }

  /// Idle days from [from] to [to]: the global streak spends its freezes
  /// one per day, then breaks; every habit due at least once breaks.
  Future<void> _breakEverythingIdle(HarvestDay from, HarvestDay to) async {
    var day = from;
    while (day.compareTo(to) <= 0) {
      await _judgeGlobal(day);
      day = day.next;
    }
    for (final habit in await _habits()) {
      final schedule = _scheduleOf(habit);
      if (schedule == null) continue;
      var d = from;
      while (d.compareTo(to) <= 0) {
        if (_wasActiveOn(habit, d) && schedule.isDueOn(d)) {
          final streak = await _row(habit.uuid);
          if (streak.current > 0) await _breakStreak(habit.uuid, streak);
          break;
        }
        d = d.next;
      }
    }
  }

  Future<void> _judgeGlobal(HarvestDay day) async {
    final streak = await _row(globalScope);
    if (streak.lastEarnedDay != null &&
        HarvestDay.parse(streak.lastEarnedDay!).compareTo(day) >= 0) {
      return; // already earned live
    }
    final goal = await dailyGoal();
    final actions = await productiveActions(day);
    if (actions >= goal) {
      final current = streak.current + 1;
      await _write(
        scope: globalScope,
        current: current,
        best: _max(streak.best, current),
        lastEarnedDay: day.key,
        freezesStored: streak.freezesStored,
      );
    } else if (streak.current > 0 && streak.freezesStored > 0) {
      // Business rule #4: a stored freeze shields the streak.
      await _write(
        scope: globalScope,
        current: streak.current,
        best: streak.best,
        lastEarnedDay: day.key,
        freezesStored: streak.freezesStored - 1,
      );
    } else if (streak.current > 0) {
      await _write(
        scope: globalScope,
        current: 0,
        best: streak.best,
        lastEarnedDay: streak.lastEarnedDay,
        freezesStored: streak.freezesStored,
      );
    }
  }

  Schedule? _scheduleOf(CommitmentRow habit) {
    if (habit.scheduleJson == null) return const DailySchedule();
    try {
      return Schedule.fromJson(
        jsonDecode(habit.scheduleJson!) as Map<String, dynamic>,
      );
    } on Object {
      return null; // an unreadable schedule is never judged
    }
  }

  Future<void> _judgeHabit(CommitmentRow habit, HarvestDay day) async {
    final schedule = _scheduleOf(habit);
    if (schedule == null) return;
    final streak = await _row(habit.uuid);
    final earned =
        streak.lastEarnedDay != null &&
        HarvestDay.parse(streak.lastEarnedDay!).compareTo(day) >= 0;

    if (schedule is TimesPerWeekSchedule) {
      // Flexible habits are judged when their week closes.
      if (day.weekday != DateTime.sunday || streak.current == 0) return;
      final done = await _doneDaysInWeek(habit.uuid, day.weekStart);
      if (done < schedule.times) {
        await _breakStreak(habit.uuid, streak);
      }
      return;
    }

    if (!earned &&
        streak.current > 0 &&
        schedule.isDueOn(day) &&
        !await _checkedOn(habit.uuid, day)) {
      await _breakStreak(habit.uuid, streak);
    }
  }

  // --------------------------------------------------------- internals

  /// Every habit on record; whether a given day counts is decided per
  /// day by [_wasActiveOn].
  Future<List<CommitmentRow>> _habits() =>
      (_db.select(_db.commitments)..where(
            (c) =>
                c.type.equals(CommitmentType.habit.name) & c.deletedAt.isNull(),
          ))
          .get();

  Future<bool> _checkedOn(String uuid, HarvestDay day) async {
    final row =
        await (_db.select(_db.checkIns)
              ..where(
                (c) =>
                    c.commitmentUuid.equals(uuid) &
                    c.harvestDay.equals(day.key) &
                    c.deletedAt.isNull(),
              )
              ..limit(1))
            .getSingleOrNull();
    return row != null;
  }

  Future<int> _doneDaysInWeek(String uuid, HarvestDay weekStart) async {
    final days = weekStart.weekDays.map((d) => d.key).toList();
    final query = _db.selectOnly(_db.checkIns, distinct: true)
      ..addColumns([_db.checkIns.harvestDay])
      ..where(
        _db.checkIns.commitmentUuid.equals(uuid) &
            _db.checkIns.harvestDay.isIn(days) &
            _db.checkIns.deletedAt.isNull(),
      );
    return (await query.get()).length;
  }

  Future<void> _breakStreak(String scope, StreakRow streak) => _write(
    scope: scope,
    current: 0,
    best: streak.best,
    lastEarnedDay: streak.lastEarnedDay,
    freezesStored: streak.freezesStored,
  );

  Future<StreakRow> _row(String scope) async {
    final row = await (_db.select(
      _db.streaks,
    )..where((s) => s.scope.equals(scope))).getSingleOrNull();
    return row ??
        StreakRow(
          scope: scope,
          current: 0,
          best: 0,
          freezesStored: 0,
          updatedAt: DateTime.now(),
        );
  }

  Future<void> _write({
    required String scope,
    required int current,
    required int best,
    required String? lastEarnedDay,
    required int freezesStored,
  }) => _db
      .into(_db.streaks)
      .insertOnConflictUpdate(
        StreaksCompanion.insert(
          scope: scope,
          current: Value(current),
          best: Value(best),
          lastEarnedDay: Value(lastEarnedDay),
          freezesStored: Value(freezesStored),
          updatedAt: Value(DateTime.now()),
        ),
      );

  Future<void> _grantCoins(int amount, String reason, HarvestDay day) => _db
      .into(_db.ledger)
      .insert(
        LedgerCompanion.insert(
          uuid: _uuid.v4(),
          kind: 'coin',
          delta: amount,
          reason: reason,
          harvestDay: day.key,
        ),
      );

  Future<void> _setLastJudged(HarvestDay day) => _db
      .into(_db.kvSettings)
      .insertOnConflictUpdate(
        KvSettingsCompanion.insert(
          key: lastJudgedKey,
          valueJson: jsonEncode(day.key),
          updatedAt: Value(DateTime.now()),
        ),
      );

  int _max(int a, int b) => a > b ? a : b;
}

@Riverpod(keepAlive: true)
StreakService streakService(Ref ref) =>
    StreakService(ref.watch(databaseProvider));
