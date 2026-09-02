// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings_controllers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The persisted theme mode; defaults to following the system.

@ProviderFor(ThemeModeSetting)
final themeModeSettingProvider = ThemeModeSettingProvider._();

/// The persisted theme mode; defaults to following the system.
final class ThemeModeSettingProvider
    extends $StreamNotifierProvider<ThemeModeSetting, ThemeMode> {
  /// The persisted theme mode; defaults to following the system.
  ThemeModeSettingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'themeModeSettingProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$themeModeSettingHash();

  @$internal
  @override
  ThemeModeSetting create() => ThemeModeSetting();
}

String _$themeModeSettingHash() => r'f5fa54b228d51b28f9aaaceec37771744ac74ed6';

/// The persisted theme mode; defaults to following the system.

abstract class _$ThemeModeSetting extends $StreamNotifier<ThemeMode> {
  Stream<ThemeMode> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<ThemeMode>, ThemeMode>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<ThemeMode>, ThemeMode>,
              AsyncValue<ThemeMode>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The persisted locale override; `null` means follow the system.

@ProviderFor(LocaleSetting)
final localeSettingProvider = LocaleSettingProvider._();

/// The persisted locale override; `null` means follow the system.
final class LocaleSettingProvider
    extends $StreamNotifierProvider<LocaleSetting, Locale?> {
  /// The persisted locale override; `null` means follow the system.
  LocaleSettingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'localeSettingProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$localeSettingHash();

  @$internal
  @override
  LocaleSetting create() => LocaleSetting();
}

String _$localeSettingHash() => r'43ac88376254586c78ec9ce27e2f08783dbf2f67';

/// The persisted locale override; `null` means follow the system.

abstract class _$LocaleSetting extends $StreamNotifier<Locale?> {
  Stream<Locale?> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<Locale?>, Locale?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<Locale?>, Locale?>,
              AsyncValue<Locale?>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The persisted Daily Harvest Goal (minimum productive actions per day).

@ProviderFor(DailyGoalSetting)
final dailyGoalSettingProvider = DailyGoalSettingProvider._();

/// The persisted Daily Harvest Goal (minimum productive actions per day).
final class DailyGoalSettingProvider
    extends $StreamNotifierProvider<DailyGoalSetting, int> {
  /// The persisted Daily Harvest Goal (minimum productive actions per day).
  DailyGoalSettingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dailyGoalSettingProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dailyGoalSettingHash();

  @$internal
  @override
  DailyGoalSetting create() => DailyGoalSetting();
}

String _$dailyGoalSettingHash() => r'fc976e06fcb52b64c91a5b7db985b66c60def27a';

/// The persisted Daily Harvest Goal (minimum productive actions per day).

abstract class _$DailyGoalSetting extends $StreamNotifier<int> {
  Stream<int> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<int>, int>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<int>, int>,
              AsyncValue<int>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Reminder configuration: master switch, times, and the streak nudge.

@ProviderFor(ReminderSettings)
final reminderSettingsProvider = ReminderSettingsProvider._();

/// Reminder configuration: master switch, times, and the streak nudge.
final class ReminderSettingsProvider
    extends
        $StreamNotifierProvider<
          ReminderSettings,
          ({
            bool enabled,
            TimeOfDay evening,
            TimeOfDay morning,
            bool streakNudge,
          })
        > {
  /// Reminder configuration: master switch, times, and the streak nudge.
  ReminderSettingsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'reminderSettingsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$reminderSettingsHash();

  @$internal
  @override
  ReminderSettings create() => ReminderSettings();
}

String _$reminderSettingsHash() => r'dd063e5b28b0ae561e0f2492e0f518ef39d00642';

/// Reminder configuration: master switch, times, and the streak nudge.

abstract class _$ReminderSettings
    extends
        $StreamNotifier<
          ({
            bool enabled,
            TimeOfDay evening,
            TimeOfDay morning,
            bool streakNudge,
          })
        > {
  Stream<
    ({bool enabled, TimeOfDay evening, TimeOfDay morning, bool streakNudge})
  >
  build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<
                ({
                  bool enabled,
                  TimeOfDay evening,
                  TimeOfDay morning,
                  bool streakNudge,
                })
              >,
              ({
                bool enabled,
                TimeOfDay evening,
                TimeOfDay morning,
                bool streakNudge,
              })
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<
                  ({
                    bool enabled,
                    TimeOfDay evening,
                    TimeOfDay morning,
                    bool streakNudge,
                  })
                >,
                ({
                  bool enabled,
                  TimeOfDay evening,
                  TimeOfDay morning,
                  bool streakNudge,
                })
              >,
              AsyncValue<
                ({
                  bool enabled,
                  TimeOfDay evening,
                  TimeOfDay morning,
                  bool streakNudge,
                })
              >,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Which of the five looks the app wears.

@ProviderFor(ThemePresetSetting)
final themePresetSettingProvider = ThemePresetSettingProvider._();

/// Which of the five looks the app wears.
final class ThemePresetSettingProvider
    extends $StreamNotifierProvider<ThemePresetSetting, ThemePreset> {
  /// Which of the five looks the app wears.
  ThemePresetSettingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'themePresetSettingProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$themePresetSettingHash();

  @$internal
  @override
  ThemePresetSetting create() => ThemePresetSetting();
}

String _$themePresetSettingHash() =>
    r'60f42aab93eeba7bd425b6b8802a008b1262aec3';

/// Which of the five looks the app wears.

abstract class _$ThemePresetSetting extends $StreamNotifier<ThemePreset> {
  Stream<ThemePreset> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<ThemePreset>, ThemePreset>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<ThemePreset>, ThemePreset>,
              AsyncValue<ThemePreset>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
