// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_lock.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The clock the grace window is measured against; overridden in tests.

@ProviderFor(lockClock)
final lockClockProvider = LockClockProvider._();

/// The clock the grace window is measured against; overridden in tests.

final class LockClockProvider
    extends
        $FunctionalProvider<
          DateTime Function(),
          DateTime Function(),
          DateTime Function()
        >
    with $Provider<DateTime Function()> {
  /// The clock the grace window is measured against; overridden in tests.
  LockClockProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'lockClockProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$lockClockHash();

  @$internal
  @override
  $ProviderElement<DateTime Function()> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DateTime Function() create(Ref ref) {
    return lockClock(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DateTime Function() value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DateTime Function()>(value),
    );
  }
}

String _$lockClockHash() => r'815126c4f7b7f8f3230a7cea08c8c135d9f212a0';

/// The app lock's phase machine.
///
/// It deliberately knows nothing about widgets or plugins: lifecycle
/// events and the device's answer come in, a phase comes out. That is
/// what makes rules L3, L4 and L6 testable without a real thumb.

@ProviderFor(AppLock)
final appLockProvider = AppLockProvider._();

/// The app lock's phase machine.
///
/// It deliberately knows nothing about widgets or plugins: lifecycle
/// events and the device's answer come in, a phase comes out. That is
/// what makes rules L3, L4 and L6 testable without a real thumb.
final class AppLockProvider extends $NotifierProvider<AppLock, AppLockState> {
  /// The app lock's phase machine.
  ///
  /// It deliberately knows nothing about widgets or plugins: lifecycle
  /// events and the device's answer come in, a phase comes out. That is
  /// what makes rules L3, L4 and L6 testable without a real thumb.
  AppLockProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appLockProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appLockHash();

  @$internal
  @override
  AppLock create() => AppLock();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppLockState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppLockState>(value),
    );
  }
}

String _$appLockHash() => r'cf409c476264188ad039ed7f0f865e8c0bd01ce4';

/// The app lock's phase machine.
///
/// It deliberately knows nothing about widgets or plugins: lifecycle
/// events and the device's answer come in, a phase comes out. That is
/// what makes rules L3, L4 and L6 testable without a real thumb.

abstract class _$AppLock extends $Notifier<AppLockState> {
  AppLockState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AppLockState, AppLockState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AppLockState, AppLockState>,
              AppLockState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
