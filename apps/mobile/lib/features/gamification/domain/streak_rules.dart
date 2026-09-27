import 'dart:math' as math;

import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/commitments/domain/schedule.dart';
import 'package:meta/meta.dart';

/// Coin rewards for global streak milestones.
const streakMilestoneCoins = {7: 50, 30: 200, 100: 1000};

/// A `streaks` row, without its key and clock.
@immutable
class StreakState {
  const StreakState({
    required this.current,
    required this.best,
    required this.lastEarnedDay,
    required this.freezesStored,
  });

  final int current;
  final int best;

  /// Harvest Day key of the last day this streak counted, if any.
  final String? lastEarnedDay;
  final int freezesStored;

  @override
  bool operator ==(Object other) =>
      other is StreakState &&
      other.current == current &&
      other.best == best &&
      other.lastEarnedDay == lastEarnedDay &&
      other.freezesStored == freezesStored;

  @override
  int get hashCode => Object.hash(current, best, lastEarnedDay, freezesStored);

  @override
  String toString() =>
      'StreakState($current, best $best, $lastEarnedDay, '
      '$freezesStored freezes)';
}

/// What the live half needs to know about a habit's missed days.
class HabitCalendar {
  const HabitCalendar({required this.schedule, this.pausedDay});

  /// Its schedule; null reads as daily, as the judging does.
  final Schedule? schedule;

  /// The Harvest Day it was paused or archived on: days from then on
  /// are excused, exactly as `_wasActiveOn` excuses them.
  final HarvestDay? pausedDay;
}

/// A milestone already paid: a `streak:N` ledger row and its day.
typedef MilestonePaid = ({String reason, String harvestDay});

/// The live streak rules, the same as `packages/core/src/streak.ts` and
/// read against the same fixture (`streaks.json`).
abstract final class StreakRules {
  /// Closed days between the last earned day and [dayKey] that nothing
  /// counted: 0 when [dayKey] follows it, or when there is no run. A
  /// check-in made on another device before this one judged those days
  /// must not hide them ([[Audit-v3]] Q5-02).
  static int daysMissedBefore(StreakState streak, String dayKey) {
    if (streak.current <= 0 || streak.lastEarnedDay == null) return 0;
    final last = HarvestDay.tryParse(streak.lastEarnedDay);
    if (last == null) return 0;
    return math.max(0, last.daysUntil(HarvestDay.parse(dayKey)) - 1);
  }

  static bool _habitMissedBefore(
    StreakState streak,
    String dayKey,
    HabitCalendar habit,
  ) {
    final gap = daysMissedBefore(streak, dayKey);
    if (gap == 0) return false;
    final schedule = habit.schedule ?? const DailySchedule();
    // A times-a-week habit is judged when its week closes, never here.
    if (schedule is TimesPerWeekSchedule) return false;
    var day = HarvestDay.parse(dayKey).addDays(-gap);
    for (var i = 0; i < gap; i++, day = day.next) {
      final paused = habit.pausedDay;
      if (paused != null && paused.compareTo(day) <= 0) return false;
      if (schedule.isDueOn(day)) return true;
    }
    return false;
  }

  /// A habit checked in on [dayKey]: its own streak counts the day,
  /// once. With [habit], a due day missed since the last earned one
  /// starts the run again at 1 instead of extending it.
  static StreakState? earnHabitDay(
    StreakState streak,
    String dayKey, {
    HabitCalendar? habit,
  }) {
    if (streak.lastEarnedDay == dayKey) return null;
    final current = habit != null && _habitMissedBefore(streak, dayKey, habit)
        ? 1
        : streak.current + 1;
    return StreakState(
      current: current,
      best: math.max(streak.best, current),
      lastEarnedDay: dayKey,
      freezesStored: streak.freezesStored,
    );
  }

  /// A habit's check-in on [dayKey] undone: the day is taken back.
  static StreakState? retractHabitDay(
    StreakState streak,
    String dayKey,
    String previousDayKey,
  ) {
    if (streak.lastEarnedDay != dayKey) return null;
    return StreakState(
      current: math.max(0, streak.current - 1),
      best: streak.best,
      lastEarnedDay: streak.current - 1 > 0 ? previousDayKey : null,
      freezesStored: streak.freezesStored,
    );
  }

  /// Whether `streak:[length]` was already paid in this run. A run that
  /// broke needs more than [length] days to reach the same length
  /// again, so a payment that recent can only be this run's, taken back
  /// by an undo and earned again ([[Audit-v3]] Q5-29).
  static bool _paidThisRun(
    Iterable<MilestonePaid> paid,
    int length,
    String dayKey,
  ) {
    final day = HarvestDay.parse(dayKey);
    final reason = 'streak:$length';
    return paid.any((entry) {
      if (entry.reason != reason) return false;
      final on = HarvestDay.tryParse(entry.harvestDay);
      return on != null && on.daysUntil(day) <= length;
    });
  }

  /// Extends or retracts the global streak on [dayKey] from its
  /// [actions]. Reaching the goal counts the day once and may pay a
  /// milestone, never twice in one run ([paid] holds the ledger's
  /// `streak:` rows); a same-day undo below the goal takes the day back.
  ///
  /// Closed days since the last earned one that no device judged yet
  /// are judged here as the 3 AM reset would: stored freezes cover them
  /// one each, and with too few the run starts again at 1.
  static ({StreakState? next, ({int coins, String reason})? milestone})
  refreshGlobal(
    StreakState streak, {
    required int actions,
    required int goal,
    required String dayKey,
    required String previousDayKey,
    Iterable<MilestonePaid> paid = const [],
  }) {
    if (actions >= goal && streak.lastEarnedDay != dayKey) {
      final missed = daysMissedBefore(streak, dayKey);
      final current = missed <= streak.freezesStored ? streak.current + 1 : 1;
      final coins = streakMilestoneCoins[current];
      return (
        next: StreakState(
          current: current,
          best: math.max(streak.best, current),
          lastEarnedDay: dayKey,
          freezesStored: math.max(0, streak.freezesStored - missed),
        ),
        milestone: coins == null || _paidThisRun(paid, current, dayKey)
            ? null
            : (coins: coins, reason: 'streak:$current'),
      );
    }
    if (actions < goal && streak.lastEarnedDay == dayKey) {
      return (
        next: StreakState(
          current: math.max(0, streak.current - 1),
          best: streak.best,
          lastEarnedDay: streak.current - 1 > 0 ? previousDayKey : null,
          freezesStored: streak.freezesStored,
        ),
        milestone: null,
      );
    }
    return (next: null, milestone: null);
  }
}
