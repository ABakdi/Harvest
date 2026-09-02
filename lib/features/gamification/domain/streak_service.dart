import 'dart:convert';

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
  static const _lastJudgedKey = 'streak.lastJudgedDay';

  // ------------------------------------------------------------- queries

  Future<int> dailyGoal() async {
    final row = await (_db.select(_db.kvSettings)
          ..where((s) => s.key.equals(goalKey)))
        .getSingleOrNull();
    if (row == null) return defaultGoal;
    final value = jsonDecode(row.valueJson);
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? defaultGoal;
  }

  /// Productive actions on [day]: each habit/to-do checked in counts one;
  /// a project counts one once it reached its daily commitment.
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

    final commitments = await (_db.select(_db.commitments)
          ..where((c) => c.uuid.isIn(sums.keys.toList())))
        .get();

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
          current: (streak.current - 1).clamp(0, 1 << 31),
          best: streak.best,
          lastEarnedDay: day.previous.key,
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
        current: (streak.current - 1).clamp(0, 1 << 31),
        best: streak.best,
        lastEarnedDay: day.previous.key,
        freezesStored: streak.freezesStored,
      );
    }
  }

  /// Buys one Streak Freeze with coins. Returns false when the balance
  /// is short or the shed is full (max [maxFreezesStored]).
  Future<bool> buyFreeze({HarvestDay? day}) async {
    final today = day ?? HarvestDay.today();
    final streak = await _row(globalScope);
    if (streak.freezesStored >= maxFreezesStored) return false;

    final sum = _db.ledger.delta.sum();
    final query = _db.selectOnly(_db.ledger)
      ..addColumns([sum])
      ..where(_db.ledger.kind.equals('coin'));
    final balance = (await query.getSingle()).read(sum) ?? 0;
    if (balance < freezeCost) return false;

    await _db.transaction(() async {
      await _db.into(_db.ledger).insert(
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
    });
    return true;
  }

  // -------------------------------------------------------- reconcile

  /// Judges every completed Harvest Day since the last run: a missed
  /// global goal consumes a stored freeze before breaking the streak,
  /// and a habit missing a due day loses its individual streak.
  Future<void> reconcile({DateTime? now}) async {
    final today = HarvestDay.of(now ?? DateTime.now());
    final yesterday = today.previous;

    final lastJudgedRow = await (_db.select(_db.kvSettings)
          ..where((s) => s.key.equals(_lastJudgedKey)))
        .getSingleOrNull();

    if (lastJudgedRow == null) {
      // First run: nothing before install day to judge.
      await _setLastJudged(yesterday);
      return;
    }

    var day =
        HarvestDay.parse(jsonDecode(lastJudgedRow.valueJson) as String).next;
    if (day.compareTo(today) >= 0) return;

    final habits = await _activeHabits();

    while (day.compareTo(today) < 0) {
      await _judgeGlobal(day);
      for (final habit in habits) {
        await _judgeHabit(habit, day);
      }
      day = day.next;
    }
    await _setLastJudged(yesterday);
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

  Future<void> _judgeHabit(CommitmentRow habit, HarvestDay day) async {
    final schedule = Schedule.fromJson(
      jsonDecode(habit.scheduleJson!) as Map<String, dynamic>,
    );
    final streak = await _row(habit.uuid);
    final earned = streak.lastEarnedDay != null &&
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

  Future<List<CommitmentRow>> _activeHabits() => (_db.select(_db.commitments)
        ..where(
          (c) =>
              c.type.equals(CommitmentType.habit.name) &
              c.archivedAt.isNull() &
              c.deletedAt.isNull(),
        ))
      .get();

  Future<bool> _checkedOn(String uuid, HarvestDay day) async {
    final row = await (_db.select(_db.checkIns)
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
    final days = <String>[];
    var d = weekStart;
    for (var i = 0; i < 7; i++) {
      days.add(d.key);
      d = d.next;
    }
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
    final row = await (_db.select(_db.streaks)
          ..where((s) => s.scope.equals(scope)))
        .getSingleOrNull();
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
  }) =>
      _db.into(_db.streaks).insertOnConflictUpdate(
            StreaksCompanion.insert(
              scope: scope,
              current: Value(current),
              best: Value(best),
              lastEarnedDay: Value(lastEarnedDay),
              freezesStored: Value(freezesStored),
              updatedAt: Value(DateTime.now()),
            ),
          );

  Future<void> _grantCoins(int amount, String reason, HarvestDay day) =>
      _db.into(_db.ledger).insert(
            LedgerCompanion.insert(
              uuid: _uuid.v4(),
              kind: 'coin',
              delta: amount,
              reason: reason,
              harvestDay: day.key,
            ),
          );

  Future<void> _setLastJudged(HarvestDay day) =>
      _db.into(_db.kvSettings).insertOnConflictUpdate(
            KvSettingsCompanion.insert(
              key: _lastJudgedKey,
              valueJson: jsonEncode(day.key),
              updatedAt: Value(DateTime.now()),
            ),
          );

  int _max(int a, int b) => a > b ? a : b;
}

@Riverpod(keepAlive: true)
StreakService streakService(Ref ref) =>
    StreakService(ref.watch(databaseProvider));
