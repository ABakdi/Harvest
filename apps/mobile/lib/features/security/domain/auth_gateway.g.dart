// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_gateway.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(authGateway)
final authGatewayProvider = AuthGatewayProvider._();

final class AuthGatewayProvider
    extends $FunctionalProvider<AuthGateway, AuthGateway, AuthGateway>
    with $Provider<AuthGateway> {
  AuthGatewayProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'authGatewayProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$authGatewayHash();

  @$internal
  @override
  $ProviderElement<AuthGateway> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AuthGateway create(Ref ref) {
    return authGateway(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AuthGateway value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AuthGateway>(value),
    );
  }
}

String _$authGatewayHash() => r'2db65d12a90886345f10696b3b94e61508952b92';
