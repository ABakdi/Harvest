// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'steps_source.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(stepsSource)
final stepsSourceProvider = StepsSourceProvider._();

final class StepsSourceProvider
    extends $FunctionalProvider<StepsSource, StepsSource, StepsSource>
    with $Provider<StepsSource> {
  StepsSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'stepsSourceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$stepsSourceHash();

  @$internal
  @override
  $ProviderElement<StepsSource> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  StepsSource create(Ref ref) {
    return stepsSource(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(StepsSource value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<StepsSource>(value),
    );
  }
}

String _$stepsSourceHash() => r'0750adcf0612638de5eeeb49baf3321c865ed4a3';
