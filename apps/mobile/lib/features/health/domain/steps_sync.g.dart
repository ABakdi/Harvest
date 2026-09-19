// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'steps_sync.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(stepsSync)
final stepsSyncProvider = StepsSyncProvider._();

final class StepsSyncProvider
    extends $FunctionalProvider<StepsSync, StepsSync, StepsSync>
    with $Provider<StepsSync> {
  StepsSyncProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'stepsSyncProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$stepsSyncHash();

  @$internal
  @override
  $ProviderElement<StepsSync> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  StepsSync create(Ref ref) {
    return stepsSync(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(StepsSync value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<StepsSync>(value),
    );
  }
}

String _$stepsSyncHash() => r'283e77044bd7e23530dcd015f568dd5c1928267b';
