// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'heartbeat.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The version this build calls itself; its own provider so a test
/// needs no platform channel.

@ProviderFor(appVersion)
final appVersionProvider = AppVersionProvider._();

/// The version this build calls itself; its own provider so a test
/// needs no platform channel.

final class AppVersionProvider
    extends $FunctionalProvider<AsyncValue<String>, String, FutureOr<String>>
    with $FutureModifier<String>, $FutureProvider<String> {
  /// The version this build calls itself; its own provider so a test
  /// needs no platform channel.
  AppVersionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appVersionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appVersionHash();

  @$internal
  @override
  $FutureProviderElement<String> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String> create(Ref ref) {
    return appVersion(ref);
  }
}

String _$appVersionHash() => r'59b58cc8214f60571dfe517b1f68cfc1aed29718';

@ProviderFor(heartbeat)
final heartbeatProvider = HeartbeatProvider._();

final class HeartbeatProvider
    extends $FunctionalProvider<Heartbeat, Heartbeat, Heartbeat>
    with $Provider<Heartbeat> {
  HeartbeatProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'heartbeatProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$heartbeatHash();

  @$internal
  @override
  $ProviderElement<Heartbeat> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Heartbeat create(Ref ref) {
    return heartbeat(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Heartbeat value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Heartbeat>(value),
    );
  }
}

String _$heartbeatHash() => r'3af7f4261338e578d1f72ffeab4e900bfb1945f0';
