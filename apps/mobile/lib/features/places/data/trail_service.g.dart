// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'trail_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(trailService)
final trailServiceProvider = TrailServiceProvider._();

final class TrailServiceProvider
    extends $FunctionalProvider<TrailService, TrailService, TrailService>
    with $Provider<TrailService> {
  TrailServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'trailServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$trailServiceHash();

  @$internal
  @override
  $ProviderElement<TrailService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  TrailService create(Ref ref) {
    return trailService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TrailService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TrailService>(value),
    );
  }
}

String _$trailServiceHash() => r'df86d0f5bf543e054deb67f230ba766a9db1b97a';
