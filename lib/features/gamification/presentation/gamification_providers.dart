import 'package:harvest/core/app/current_day.dart';
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

@riverpod
Stream<int> weeklyXp(Ref ref) => ref
    .watch(gamificationRepositoryProvider)
    .watchXpSince(ref.watch(currentHarvestDayProvider).weekStart);
