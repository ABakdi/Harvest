import 'package:harvest/core/app/current_day.dart';
import 'package:harvest/core/db/database_provider.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/gamification/data/gamification_repository.dart';
import 'package:harvest/features/gamification/domain/day_activity.dart';
import 'package:harvest/features/gamification/domain/streak_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'gamification_providers.g.dart';

@riverpod
Stream<int> xpTotal(Ref ref) =>
    ref.watch(gamificationRepositoryProvider).watchXpTotal();

@riverpod
Stream<({int current, int best, int freezes})> globalStreak(Ref ref) =>
    ref.watch(gamificationRepositoryProvider).watchGlobalStreak();

@riverpod
Stream<int> coinTotal(Ref ref) =>
    ref.watch(gamificationRepositoryProvider).watchCoinTotal();

@riverpod
Stream<int> checkInCount(Ref ref) =>
    ref.watch(gamificationRepositoryProvider).watchCheckInCount();

/// The heat-map's squares over [activityWindow]: each day's productive
/// actions, by the rule the web draws its map with (G5-11).
@riverpod
Stream<Map<String, int>> heatActivity(Ref ref) {
  final window = activityWindow(ref.watch(currentHarvestDayProvider));
  return ref
      .watch(gamificationRepositoryProvider)
      .watchHeatActivity(window.start, window.end);
}

/// Distinct seeds checked in per day: the weekly report's count.
@riverpod
Stream<Map<String, int>> dailyActivity(Ref ref) {
  final today = ref.watch(currentHarvestDayProvider);
  return ref
      .watch(gamificationRepositoryProvider)
      .watchDailyActivity(activityWindow(today).start);
}

@riverpod
Stream<Map<String, ({int current, int best})>> commitmentStreaks(Ref ref) =>
    ref.watch(gamificationRepositoryProvider).watchCommitmentStreaks();

/// The Harvest Days the current global streak is made of.
///
/// A streak is a run, and the engine already records both ends of it:
/// the day it was last earned and how many days long it is. Counting
/// back from one by the other is the whole set — including the days a
/// freeze covered, which are part of the streak whether or not anything
/// was logged on them.
@riverpod
Set<HarvestDay> streakDays(Ref ref) {
  final streak = ref.watch(globalStreakProvider).value;
  final last = ref.watch(lastEarnedDayProvider).value;
  if (streak == null || last == null || streak.current <= 0) return const {};
  return {
    for (var i = 0; i < streak.current; i++) last.addDays(-i),
  };
}

/// The last day the global streak was earned; null before the first.
@riverpod
Stream<HarvestDay?> lastEarnedDay(Ref ref) =>
    ref.watch(gamificationRepositoryProvider).watchLastEarnedDay();

@riverpod
Stream<int> weeklyXp(Ref ref) => ref
    .watch(gamificationRepositoryProvider)
    .watchXpSince(ref.watch(currentHarvestDayProvider).weekStart);

/// Today's productive actions, the count the Daily Harvest Goal is
/// judged by: what the Field shows as "1 of 3" so a streak at 0 says
/// why ([[Audit-v3]] U6-03). Re-counted when a check-in, a seed or a
/// scheduled album's picture changes.
@riverpod
Stream<int> todayActions(Ref ref) {
  final day = ref.watch(currentHarvestDayProvider);
  final db = ref.watch(databaseProvider);
  final streaks = ref.watch(streakServiceProvider);
  return db
      .customSelect(
        'SELECT 1',
        readsFrom: {db.checkIns, db.commitments, db.memories, db.albums},
      )
      .watch()
      .asyncMap((_) => streaks.productiveActions(day));
}
