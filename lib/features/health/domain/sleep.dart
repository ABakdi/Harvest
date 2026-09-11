import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/settings/domain/daily_cycle.dart';
import 'package:meta/meta.dart';

/// One night, as I reported it the morning after.
///
/// Both ends are times I say, not times the phone guessed: this app
/// does not watch me sleep. The target is **copied in** rather than
/// looked up later, for the same reason a session copies its targets —
/// changing my bedtime in March must not rewrite February's debt.
@immutable
class SleepNight {
  const SleepNight({
    required this.uuid,
    required this.day,
    required this.fellAsleepAt,
    required this.wokeAt,
    required this.targetMinutes,
    this.restedStars,
    this.note,
  });

  final String uuid;

  /// The Harvest Day I **woke up** on. A night is filed under its
  /// morning, because that is the day it decides how I feel.
  final HarvestDay day;

  final DateTime fellAsleepAt;
  final DateTime wokeAt;

  /// What the night was supposed to be, in minutes, as of that night.
  final int targetMinutes;

  /// 1–5, or null when I could not be bothered to say — which is
  /// itself a legitimate answer at 6 AM.
  final int? restedStars;
  final String? note;

  Duration get slept => wokeAt.difference(fellAsleepAt);
  int get sleptMinutes => slept.inMinutes;

  /// Short of target, in minutes. Negative is a surplus.
  int get shortfallMinutes => targetMinutes - sleptMinutes;
}

/// What writing the night down is worth ([[Gamification]]).
///
/// Paid for logging, not for sleeping: the app has no opinion on how
/// long I slept and every reason to want me to write it down.
const int sleepXp = 15;

/// How far back the debt looks. Two weeks: long enough for a bad run to
/// show, short enough that a bad month in the spring is not still being
/// held against me in the summer.
const int debtWindowNights = 14;

/// The running balance, minute for minute.
///
/// Every night short adds its shortfall; every long night pays it
/// down. The balance never goes below zero, because a twelve-hour
/// Sunday clears what I owe and does not put me in credit — sleep is
/// not a bank account, and pretending otherwise would let one lie-in
/// excuse the week after it.
///
/// The window is **calendar** nights, ending on [upTo] (today, or the
/// latest night logged when nobody says): the last fourteen mornings,
/// whether or not I wrote them down. Nights with nothing logged count
/// for nothing at all — an unlogged night is unknown, not a failure —
/// but they do still pass. The first cut took the fourteen most recent
/// *logged* nights, so a night from March could still weigh on July
/// for someone who logs once a week ([[Audit-v2-Beta]] B-09, N-06).
int sleepDebtMinutes(
  Iterable<SleepNight> nights, {
  int window = debtWindowNights,
  HarvestDay? upTo,
}) {
  final sorted = nights.toList()..sort((a, b) => a.day.compareTo(b.day));
  if (sorted.isEmpty) return 0;
  final end = upTo ?? sorted.last.day;
  final start = end.addDays(-(window - 1));
  final considered = sorted.where(
    (night) => night.day.compareTo(start) >= 0 && night.day.compareTo(end) <= 0,
  );

  var balance = 0;
  for (final night in considered) {
    balance += night.shortfallMinutes;
    if (balance < 0) balance = 0;
  }
  return balance;
}

/// What the debt gauge shows: how much is owed, and out of how much.
///
/// The denominator is one full night's target, so the gauge reads "how
/// many nights behind am I" rather than an unbounded number of minutes.
typedef SleepDebt = ({int minutes, double nights});

SleepDebt sleepDebt(
  Iterable<SleepNight> nights, {
  required int targetMinutes,
  int window = debtWindowNights,
  HarvestDay? upTo,
}) {
  final minutes = sleepDebtMinutes(nights, window: window, upTo: upTo);
  return (
    minutes: minutes,
    nights: targetMinutes <= 0 ? 0 : minutes / targetMinutes,
  );
}

/// The average of what was actually slept, over the logged nights only.
Duration averageSleep(Iterable<SleepNight> nights) {
  final logged = nights.toList();
  if (logged.isEmpty) return Duration.zero;
  final total = logged.fold(0, (sum, night) => sum + night.sleptMinutes);
  return Duration(minutes: total ~/ logged.length);
}

/// The night I mean to have on a given weekday.
///
/// The daily cycle is the answer for most days; a weekday with its own
/// answer overrides it. Saturday is a different night from Tuesday for
/// nearly everyone, and a target that pretends otherwise is a target
/// that gets ignored.
@immutable
class SleepTargets {
  const SleepTargets({required this.cycle, this.overrides = const {}});

  final DailyCycle cycle;

  /// Weekday (`DateTime.monday`..`DateTime.sunday`) to its own night.
  final Map<int, DailyCycle> overrides;

  DailyCycle forWeekday(int weekday) => overrides[weekday] ?? cycle;

  /// The night that ends on [day] — so the bedtime is the evening
  /// *before*, and the weekday that decides it is the morning's.
  DailyCycle forMorning(HarvestDay day) => forWeekday(day.weekday);

  int targetMinutesFor(HarvestDay day) => forMorning(day).sleep.inMinutes;

  bool get hasOverrides => overrides.isNotEmpty;
}

/// `23:30` from a stored override, and back.
///
/// Kept as text because it is a setting, and a setting that is legible
/// in the archive is worth two that are not.
String encodeCycle(DailyCycle cycle) =>
    '${_hhmm(cycle.bedTime)}-${_hhmm(cycle.wakeTime)}';

DailyCycle? decodeCycle(String? value) {
  if (value == null || value.isEmpty) return null;
  final parts = value.split('-');
  if (parts.length != 2) return null;
  final bed = _parse(parts.first);
  final wake = _parse(parts.last);
  if (bed == null || wake == null) return null;
  return DailyCycle(bedTime: bed, wakeTime: wake);
}

String _hhmm((int, int) time) =>
    '${time.$1.toString().padLeft(2, '0')}:'
    '${time.$2.toString().padLeft(2, '0')}';

(int, int)? _parse(String value) {
  final bits = value.split(':');
  if (bits.length != 2) return null;
  final hour = int.tryParse(bits.first);
  final minute = int.tryParse(bits.last);
  if (hour == null || minute == null) return null;
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
  return (hour, minute);
}

/// When the alarm should ring for the morning of [day].
DateTime alarmFor(HarvestDay day, SleepTargets targets) {
  final wake = targets.forMorning(day).wakeTime;
  return DateTime(day.year, day.month, day.day, wake.$1, wake.$2);
}

/// How long before the target bedtime the wind-down is said.
///
/// Half an hour: long enough to finish what I am doing, short enough
/// that it is still about tonight.
const windDown = Duration(minutes: 30);

/// When to be in bed, for the night that ends on [day].
///
/// Worked back from the alarm rather than stored separately, so it
/// wraps midnight without anyone having to think about it: waking at
/// 7 AM after eight hours means half past eleven the evening before.
DateTime bedtimeFor(HarvestDay day, SleepTargets targets) =>
    alarmFor(day, targets).subtract(targets.forMorning(day).sleep);

/// When to say it, for the night that ends on [day].
DateTime windDownFor(HarvestDay day, SleepTargets targets) =>
    bedtimeFor(day, targets).subtract(windDown);
