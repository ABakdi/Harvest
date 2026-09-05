// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'daily_cycle_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(dailyCycleService)
final dailyCycleServiceProvider = DailyCycleServiceProvider._();

final class DailyCycleServiceProvider
    extends
        $FunctionalProvider<
          DailyCycleService,
          DailyCycleService,
          DailyCycleService
        >
    with $Provider<DailyCycleService> {
  DailyCycleServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dailyCycleServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dailyCycleServiceHash();

  @$internal
  @override
  $ProviderElement<DailyCycleService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DailyCycleService create(Ref ref) {
    return dailyCycleService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DailyCycleService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DailyCycleService>(value),
    );
  }
}

String _$dailyCycleServiceHash() => r'd51e0645b2cbfbda4895683b6fd6333e009c657c';

/// The cycle as the settings screen sees it, live.

@ProviderFor(dailyCycle)
final dailyCycleProvider = DailyCycleProvider._();

/// The cycle as the settings screen sees it, live.

final class DailyCycleProvider
    extends
        $FunctionalProvider<
          AsyncValue<DailyCycle>,
          DailyCycle,
          Stream<DailyCycle>
        >
    with $FutureModifier<DailyCycle>, $StreamProvider<DailyCycle> {
  /// The cycle as the settings screen sees it, live.
  DailyCycleProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dailyCycleProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dailyCycleHash();

  @$internal
  @override
  $StreamProviderElement<DailyCycle> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<DailyCycle> create(Ref ref) {
    return dailyCycle(ref);
  }
}

String _$dailyCycleHash() => r'8ffa33d032fba997e6c4184c5c7c2e9cb30771f7';
