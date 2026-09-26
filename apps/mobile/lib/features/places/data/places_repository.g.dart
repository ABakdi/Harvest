// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'places_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(placesRepository)
final placesRepositoryProvider = PlacesRepositoryProvider._();

final class PlacesRepositoryProvider
    extends
        $FunctionalProvider<
          PlacesRepository,
          PlacesRepository,
          PlacesRepository
        >
    with $Provider<PlacesRepository> {
  PlacesRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'placesRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$placesRepositoryHash();

  @$internal
  @override
  $ProviderElement<PlacesRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PlacesRepository create(Ref ref) {
    return placesRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PlacesRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PlacesRepository>(value),
    );
  }
}

String _$placesRepositoryHash() => r'2f34c288de628dedb3640d92abaf2ad11967769d';
