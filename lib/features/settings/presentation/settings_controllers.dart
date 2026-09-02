import 'package:flutter/material.dart';
import 'package:harvest/core/platform/notifications.dart';
import 'package:harvest/features/gamification/domain/streak_service.dart';
import 'package:harvest/features/planner/domain/notification_planner.dart';
import 'package:harvest/features/settings/data/settings_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'settings_controllers.g.dart';

/// The persisted theme mode; defaults to following the system.
@Riverpod(keepAlive: true)
class ThemeModeSetting extends _$ThemeModeSetting {
  @override
  Stream<ThemeMode> build() =>
      ref.watch(settingsRepositoryProvider).watchString(SettingKeys.themeMode).map(
            (value) => ThemeMode.values.firstWhere(
              (m) => m.name == value,
              orElse: () => ThemeMode.system,
            ),
          );

  Future<void> set(ThemeMode mode) => ref
      .read(settingsRepositoryProvider)
      .setString(SettingKeys.themeMode, mode.name);
}

/// The persisted locale override; `null` means follow the system.
@Riverpod(keepAlive: true)
class LocaleSetting extends _$LocaleSetting {
  static const system = 'system';

  @override
  Stream<Locale?> build() =>
      ref.watch(settingsRepositoryProvider).watchString(SettingKeys.locale).map(
            (value) => value == null || value == system ? null : Locale(value),
          );

  Future<void> set(String languageCodeOrSystem) => ref
      .read(settingsRepositoryProvider)
      .setString(SettingKeys.locale, languageCodeOrSystem);
}

/// The persisted Daily Harvest Goal (minimum productive actions per day).
@Riverpod(keepAlive: true)
class DailyGoalSetting extends _$DailyGoalSetting {
  @override
  Stream<int> build() => ref
      .watch(settingsRepositoryProvider)
      .watchString(StreakService.goalKey)
      .map((value) => int.tryParse(value ?? '') ?? StreakService.defaultGoal);

  Future<void> set(int goal) => ref
      .read(settingsRepositoryProvider)
      .setString(StreakService.goalKey, '$goal');
}

/// Reminder configuration: master switch, times, and the streak nudge.
@Riverpod(keepAlive: true)
class ReminderSettings extends _$ReminderSettings {
  @override
  Stream<({bool enabled, TimeOfDay morning, TimeOfDay evening, bool streakNudge})>
      build() {
    final repo = ref.watch(settingsRepositoryProvider);
    TimeOfDay parse(String? raw, TimeOfDay fallback) {
      final parts = (raw ?? '').split(':');
      if (parts.length != 2) return fallback;
      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      if (hour == null || minute == null) return fallback;
      return TimeOfDay(hour: hour, minute: minute);
    }

    return repo.watchAll(const [
      ReminderKeys.enabled,
      ReminderKeys.morningTime,
      ReminderKeys.eveningTime,
      ReminderKeys.streakNudge,
    ]).map(
      (values) => (
        enabled: values[ReminderKeys.enabled] == 'true',
        morning: parse(
          values[ReminderKeys.morningTime],
          const TimeOfDay(hour: 7, minute: 0),
        ),
        evening: parse(
          values[ReminderKeys.eveningTime],
          const TimeOfDay(hour: 21, minute: 30),
        ),
        streakNudge: values[ReminderKeys.streakNudge] != 'false',
      ),
    );
  }

  Future<bool> setEnabled({required bool enabled}) async {
    var granted = true;
    if (enabled) {
      granted =
          await ref.read(notificationServiceProvider).requestPermission();
    }
    final effective = enabled && granted;
    await ref
        .read(settingsRepositoryProvider)
        .setString(ReminderKeys.enabled, '$effective');
    await ref.read(notificationPlannerProvider).planToday();
    return effective;
  }

  Future<void> setTime(String key, TimeOfDay time) async {
    await ref.read(settingsRepositoryProvider).setString(
          key,
          '${time.hour}:${time.minute.toString().padLeft(2, '0')}',
        );
    await ref.read(notificationPlannerProvider).planToday();
  }

  Future<void> setStreakNudge({required bool enabled}) async {
    await ref
        .read(settingsRepositoryProvider)
        .setString(ReminderKeys.streakNudge, '$enabled');
    await ref.read(notificationPlannerProvider).planToday();
  }
}
