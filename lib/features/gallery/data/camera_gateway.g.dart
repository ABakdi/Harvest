// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'camera_gateway.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(cameraGateway)
final cameraGatewayProvider = CameraGatewayProvider._();

final class CameraGatewayProvider
    extends $FunctionalProvider<CameraGateway, CameraGateway, CameraGateway>
    with $Provider<CameraGateway> {
  CameraGatewayProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'cameraGatewayProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$cameraGatewayHash();

  @$internal
  @override
  $ProviderElement<CameraGateway> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  CameraGateway create(Ref ref) {
    return cameraGateway(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CameraGateway value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CameraGateway>(value),
    );
  }
}

String _$cameraGatewayHash() => r'9d6c762e16934c2369420271fc8de398394005fd';
