// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pomodoro_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Drives the pomodoro state machine. All timing derives from wall-clock
/// instants persisted by [PomodoroService]; [evaluate] advances the
/// machine across any boundaries that passed while the app was away.

@ProviderFor(PomodoroController)
final pomodoroControllerProvider = PomodoroControllerProvider._();

/// Drives the pomodoro state machine. All timing derives from wall-clock
/// instants persisted by [PomodoroService]; [evaluate] advances the
/// machine across any boundaries that passed while the app was away.
final class PomodoroControllerProvider
    extends $AsyncNotifierProvider<PomodoroController, PomodoroSnapshot?> {
  /// Drives the pomodoro state machine. All timing derives from wall-clock
  /// instants persisted by [PomodoroService]; [evaluate] advances the
  /// machine across any boundaries that passed while the app was away.
  PomodoroControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pomodoroControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pomodoroControllerHash();

  @$internal
  @override
  PomodoroController create() => PomodoroController();
}

String _$pomodoroControllerHash() =>
    r'bcbc6482627da56a9d44c67eaf732433f859e53a';

/// Drives the pomodoro state machine. All timing derives from wall-clock
/// instants persisted by [PomodoroService]; [evaluate] advances the
/// machine across any boundaries that passed while the app was away.

abstract class _$PomodoroController extends $AsyncNotifier<PomodoroSnapshot?> {
  FutureOr<PomodoroSnapshot?> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<PomodoroSnapshot?>, PomodoroSnapshot?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<PomodoroSnapshot?>, PomodoroSnapshot?>,
              AsyncValue<PomodoroSnapshot?>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
