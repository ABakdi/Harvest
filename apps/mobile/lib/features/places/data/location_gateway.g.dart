// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'location_gateway.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(locationGateway)
final locationGatewayProvider = LocationGatewayProvider._();

final class LocationGatewayProvider
    extends
        $FunctionalProvider<LocationGateway, LocationGateway, LocationGateway>
    with $Provider<LocationGateway> {
  LocationGatewayProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'locationGatewayProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$locationGatewayHash();

  @$internal
  @override
  $ProviderElement<LocationGateway> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  LocationGateway create(Ref ref) {
    return locationGateway(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LocationGateway value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LocationGateway>(value),
    );
  }
}

String _$locationGatewayHash() => r'b320338fca700f80570447bfb139b260a4a7af3e';
