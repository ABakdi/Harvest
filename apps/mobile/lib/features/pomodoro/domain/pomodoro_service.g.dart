// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pomodoro_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(pomodoroService)
final pomodoroServiceProvider = PomodoroServiceProvider._();

final class PomodoroServiceProvider
    extends
        $FunctionalProvider<PomodoroService, PomodoroService, PomodoroService>
    with $Provider<PomodoroService> {
  PomodoroServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pomodoroServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pomodoroServiceHash();

  @$internal
  @override
  $ProviderElement<PomodoroService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PomodoroService create(Ref ref) {
    return pomodoroService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PomodoroService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PomodoroService>(value),
    );
  }
}

String _$pomodoroServiceHash() => r'd0774f63a12f17090969b2cf30fc262ba2418ab7';

/// The live timer configuration, persisted in settings.

@ProviderFor(PomodoroConfigSetting)
final pomodoroConfigSettingProvider = PomodoroConfigSettingProvider._();

/// The live timer configuration, persisted in settings.
final class PomodoroConfigSettingProvider
    extends $StreamNotifierProvider<PomodoroConfigSetting, PomodoroConfig> {
  /// The live timer configuration, persisted in settings.
  PomodoroConfigSettingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pomodoroConfigSettingProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pomodoroConfigSettingHash();

  @$internal
  @override
  PomodoroConfigSetting create() => PomodoroConfigSetting();
}

String _$pomodoroConfigSettingHash() =>
    r'bd90fe583466996105dfaab5c767794d839e6deb';

/// The live timer configuration, persisted in settings.

abstract class _$PomodoroConfigSetting extends $StreamNotifier<PomodoroConfig> {
  Stream<PomodoroConfig> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<PomodoroConfig>, PomodoroConfig>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<PomodoroConfig>, PomodoroConfig>,
              AsyncValue<PomodoroConfig>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
