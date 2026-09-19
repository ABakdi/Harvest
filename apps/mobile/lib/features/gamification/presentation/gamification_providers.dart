import 'package:harvest/core/app/current_day.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/gamification/data/gamification_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'gamification_providers.g.dart';

/// How far back the activity heat-map looks.
const activityWindow = Duration(days: 182);

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

@riverpod
Stream<Map<String, int>> dailyActivity(Ref ref) {
  final today = ref.watch(currentHarvestDayProvider);
  return ref
      .watch(gamificationRepositoryProvider)
      .watchDailyActivity(today.addDays(-activityWindow.inDays).weekStart);
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
