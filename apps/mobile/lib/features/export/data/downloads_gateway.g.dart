// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'downloads_gateway.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(downloadsGateway)
final downloadsGatewayProvider = DownloadsGatewayProvider._();

final class DownloadsGatewayProvider
    extends
        $FunctionalProvider<
          DownloadsGateway,
          DownloadsGateway,
          DownloadsGateway
        >
    with $Provider<DownloadsGateway> {
  DownloadsGatewayProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'downloadsGatewayProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$downloadsGatewayHash();

  @$internal
  @override
  $ProviderElement<DownloadsGateway> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DownloadsGateway create(Ref ref) {
    return downloadsGateway(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DownloadsGateway value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DownloadsGateway>(value),
    );
  }
}

String _$downloadsGatewayHash() => r'736066d9e56ed21939503d873b0dd54c0b49350e';
