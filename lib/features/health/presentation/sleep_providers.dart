import 'package:harvest/core/app/current_day.dart';
import 'package:harvest/features/health/data/sleep_repository.dart';
import 'package:harvest/features/health/domain/sleep.dart';
import 'package:harvest/features/settings/data/settings_repository.dart';
import 'package:harvest/features/settings/domain/daily_cycle.dart';
import 'package:harvest/features/settings/domain/daily_cycle_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'sleep_providers.g.dart';

/// Settings keys the sleep screens read.
///
/// The targets themselves live in the daily cycle and are **not**
/// duplicated here: sleep reads the hours the app already bends the
/// day around. Only the per-weekday exceptions are stored.
abstract final class SleepKeys {
  static const alarmOn = 'sleep.alarm';
  static const windDownOn = 'sleep.windDown';

  /// `sleep.night.1` … `sleep.night.7`, Monday to Sunday.
  static String night(int weekday) => 'sleep.night.$weekday';

  static const List<String> all = [
    alarmOn,
    windDownOn,
    'sleep.night.1',
    'sleep.night.2',
    'sleep.night.3',
    'sleep.night.4',
    'sleep.night.5',
    'sleep.night.6',
    'sleep.night.7',
  ];
}

@riverpod
Stream<List<SleepNight>> sleepNights(Ref ref) =>
    ref.watch(sleepRepositoryProvider).watchRecent();

/// The night I mean to have, per weekday, over the daily cycle.
@riverpod
Stream<SleepTargets> sleepTargets(Ref ref) {
  final cycle = ref.watch(dailyCycleProvider).value ?? DailyCycle.fallback;
  return ref
      .watch(settingsRepositoryProvider)
      .watchAll(SleepKeys.all)
      .map(
        (values) => SleepTargets(cycle: cycle, overrides: _overrides(values)),
      );
}

/// What is owed, over the last two weeks.
@riverpod
Stream<SleepDebt> sleepDebtNow(Ref ref) {
  final targets = ref.watch(sleepTargetsProvider).value;
  final today = ref.watch(currentHarvestDayProvider);
  return ref
      .watch(sleepRepositoryProvider)
      .watchRecent()
      .map(
        (nights) => sleepDebt(
          nights,
          targetMinutes:
              targets?.targetMinutesFor(today) ??
              DailyCycle.fallback.sleep.inMinutes,
        ),
      );
}

/// Whether last night is still waiting to be written down.
@riverpod
Stream<bool> sleepUnlogged(Ref ref) {
  final today = ref.watch(currentHarvestDayProvider);
  return ref
      .watch(sleepRepositoryProvider)
      .watchRecent()
      .map((nights) => !nights.any((night) => night.day == today));
}

/// Whether the alarm rings at all. Off until it is asked for — an app
/// that appoints itself your alarm clock without being asked is an app
/// you uninstall.
@riverpod
class SleepAlarmOn extends _$SleepAlarmOn {
  @override
  Stream<bool> build() => ref
      .watch(settingsRepositoryProvider)
      .watchAll([SleepKeys.alarmOn])
      .map((values) => values[SleepKeys.alarmOn] == 'true');

  Future<void> set({required bool on}) =>
      ref.read(settingsRepositoryProvider).setString(SleepKeys.alarmOn, '$on');
}

/// Whether anything is said before bedtime.
@riverpod
class SleepWindDownOn extends _$SleepWindDownOn {
  @override
  Stream<bool> build() => ref
      .watch(settingsRepositoryProvider)
      .watchAll([SleepKeys.windDownOn])
      .map((values) => values[SleepKeys.windDownOn] == 'true');

  Future<void> set({required bool on}) => ref
      .read(settingsRepositoryProvider)
      .setString(SleepKeys.windDownOn, '$on');
}

/// One weekday's own night, or none.
@riverpod
class SleepNightOverride extends _$SleepNightOverride {
  @override
  Stream<DailyCycle?> build(int weekday) => ref
      .watch(settingsRepositoryProvider)
      .watchAll([SleepKeys.night(weekday)])
      .map((values) => decodeCycle(values[SleepKeys.night(weekday)]));

  Future<void> set(DailyCycle? cycle) => ref
      .read(settingsRepositoryProvider)
      .setString(
        SleepKeys.night(weekday),
        cycle == null ? '' : encodeCycle(cycle),
      );
}

/// The weekdays that have a night of their own. A weekday with no
/// stored value simply is not in the map, and falls back to the cycle.
Map<int, DailyCycle> _overrides(Map<String, String?> values) {
  final overrides = <int, DailyCycle>{};
  for (var weekday = 1; weekday <= 7; weekday++) {
    final cycle = decodeCycle(values[SleepKeys.night(weekday)]);
    if (cycle != null) overrides[weekday] = cycle;
  }
  return overrides;
}
