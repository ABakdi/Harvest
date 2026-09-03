import 'package:flutter/material.dart';
import 'package:harvest/core/platform/notifications.dart';
import 'package:harvest/core/ui/tokens.dart';
import 'package:harvest/features/gamification/domain/streak_service.dart';
import 'package:harvest/features/planner/domain/notification_planner.dart';
import 'package:harvest/features/settings/data/settings_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'settings_controllers.g.dart';

/// The persisted theme mode; defaults to following the system.
@Riverpod(keepAlive: true)
class ThemeModeSetting extends _$ThemeModeSetting {
  @override
  Stream<ThemeMode> build() => ref
      .watch(settingsRepositoryProvider)
      .watchString(SettingKeys.themeMode)
      .map(
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
  Stream<Locale?> build() => ref
      .watch(settingsRepositoryProvider)
      .watchString(SettingKeys.locale)
      .map(
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

  Future<void> set(int goal) =>
      ref.read(settingsRepositoryProvider).setInt(StreakService.goalKey, goal);
}

/// Everything the Reminders section shows.
typedef ReminderConfig = ({
  bool enabled,
  TimeOfDay morning,
  TimeOfDay evening,
  TimeOfDay expense,
  bool streakNudge,
});

TimeOfDay _time((int, int) hm) => TimeOfDay(hour: hm.$1, minute: hm.$2);

/// Reminder configuration: master switch, the ritual times, and the
/// streak nudge. Every change replans today's reminders.
@Riverpod(keepAlive: true)
class ReminderSettings extends _$ReminderSettings {
  @override
  Stream<ReminderConfig> build() {
    final repo = ref.watch(settingsRepositoryProvider);
    TimeOfDay parse(String? raw, (int, int) fallback) =>
        _time(SettingsRepository.parseTime(raw) ?? fallback);

    return repo
        .watchAll(const [
          ReminderKeys.enabled,
          ReminderKeys.morningTime,
          ReminderKeys.eveningTime,
          ReminderKeys.expenseTime,
          ReminderKeys.streakNudge,
        ])
        .map(
          (values) => (
            enabled: values[ReminderKeys.enabled] == 'true',
            morning: parse(
              values[ReminderKeys.morningTime],
              ReminderDefaults.morning,
            ),
            evening: parse(
              values[ReminderKeys.eveningTime],
              ReminderDefaults.evening,
            ),
            expense: parse(
              values[ReminderKeys.expenseTime],
              ReminderDefaults.expense,
            ),
            streakNudge: values[ReminderKeys.streakNudge] != 'false',
          ),
        );
  }

  /// Turns the rituals on (asking the OS first) or off. Returns what the
  /// OS answered so the screen can explain a refusal.
  Future<ReminderPermission> setEnabled({required bool enabled}) async {
    var permission = ReminderPermission.granted;
    if (enabled) {
      permission = await ref
          .read(notificationServiceProvider)
          .requestPermissionStatus();
    }
    final effective = enabled && permission == ReminderPermission.granted;
    await ref
        .read(settingsRepositoryProvider)
        .setBool(ReminderKeys.enabled, value: effective);
    await ref.read(notificationPlannerProvider).planToday();
    return permission;
  }

  Future<void> setTime(String key, TimeOfDay time) async {
    await ref
        .read(settingsRepositoryProvider)
        .setTime(key, time.hour, time.minute);
    await ref.read(notificationPlannerProvider).planToday();
  }

  Future<void> setStreakNudge({required bool enabled}) async {
    await ref
        .read(settingsRepositoryProvider)
        .setBool(ReminderKeys.streakNudge, value: enabled);
    await ref.read(notificationPlannerProvider).planToday();
  }
}

/// Which of the five looks the app wears.
@Riverpod(keepAlive: true)
class ThemePresetSetting extends _$ThemePresetSetting {
  static const key = 'themePreset';

  @override
  Stream<ThemePreset> build() => ref
      .watch(settingsRepositoryProvider)
      .watchString(key)
      .map(
        (value) => ThemePreset.values.firstWhere(
          (p) => p.name == value,
          orElse: () => ThemePreset.harvest,
        ),
      );

  Future<void> set(ThemePreset preset) =>
      ref.read(settingsRepositoryProvider).setString(key, preset.name);
}
