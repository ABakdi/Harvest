// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rates_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ratesService)
final ratesServiceProvider = RatesServiceProvider._();

final class RatesServiceProvider
    extends $FunctionalProvider<RatesService, RatesService, RatesService>
    with $Provider<RatesService> {
  RatesServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'ratesServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$ratesServiceHash();

  @$internal
  @override
  $ProviderElement<RatesService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  RatesService create(Ref ref) {
    return ratesService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RatesService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RatesService>(value),
    );
  }
}

String _$ratesServiceHash() => r'8893f22936b37ae0212b9eb513397c0da70f10bb';
