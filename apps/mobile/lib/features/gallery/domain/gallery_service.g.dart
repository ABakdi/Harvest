// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gallery_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(galleryService)
final galleryServiceProvider = GalleryServiceProvider._();

final class GalleryServiceProvider
    extends $FunctionalProvider<GalleryService, GalleryService, GalleryService>
    with $Provider<GalleryService> {
  GalleryServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'galleryServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$galleryServiceHash();

  @$internal
  @override
  $ProviderElement<GalleryService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  GalleryService create(Ref ref) {
    return galleryService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GalleryService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GalleryService>(value),
    );
  }
}

String _$galleryServiceHash() => r'030e4c2267a6299094a8dc44b3695de489214e8c';
