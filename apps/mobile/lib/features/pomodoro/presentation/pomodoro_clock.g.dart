// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pomodoro_clock.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// One shared second hand for every timer widget. Only widgets that
/// watch it rebuild, and they only watch it while a session runs.

@ProviderFor(pomodoroClock)
final pomodoroClockProvider = PomodoroClockProvider._();

/// One shared second hand for every timer widget. Only widgets that
/// watch it rebuild, and they only watch it while a session runs.

final class PomodoroClockProvider
    extends
        $FunctionalProvider<AsyncValue<DateTime>, DateTime, Stream<DateTime>>
    with $FutureModifier<DateTime>, $StreamProvider<DateTime> {
  /// One shared second hand for every timer widget. Only widgets that
  /// watch it rebuild, and they only watch it while a session runs.
  PomodoroClockProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pomodoroClockProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pomodoroClockHash();

  @$internal
  @override
  $StreamProviderElement<DateTime> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<DateTime> create(Ref ref) {
    return pomodoroClock(ref);
  }
}

String _$pomodoroClockHash() => r'6f2fcf889a3e42875512a98616640d08269cb44a';
