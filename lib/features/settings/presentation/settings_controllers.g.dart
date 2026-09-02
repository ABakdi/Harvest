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
