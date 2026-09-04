// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'home_widget_gateway.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(homeWidgetGateway)
final homeWidgetGatewayProvider = HomeWidgetGatewayProvider._();

final class HomeWidgetGatewayProvider
    extends
        $FunctionalProvider<
          HomeWidgetGateway,
          HomeWidgetGateway,
          HomeWidgetGateway
        >
    with $Provider<HomeWidgetGateway> {
  HomeWidgetGatewayProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'homeWidgetGatewayProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$homeWidgetGatewayHash();

  @$internal
  @override
  $ProviderElement<HomeWidgetGateway> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  HomeWidgetGateway create(Ref ref) {
    return homeWidgetGateway(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(HomeWidgetGateway value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<HomeWidgetGateway>(value),
    );
  }
}

String _$homeWidgetGatewayHash() => r'09011d0c253a66ee2fe0b806a70dd70c3fd73eb1';
