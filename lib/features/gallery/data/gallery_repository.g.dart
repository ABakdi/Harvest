// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gallery_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(galleryRepository)
final galleryRepositoryProvider = GalleryRepositoryProvider._();

final class GalleryRepositoryProvider
    extends
        $FunctionalProvider<
          GalleryRepository,
          GalleryRepository,
          GalleryRepository
        >
    with $Provider<GalleryRepository> {
  GalleryRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'galleryRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$galleryRepositoryHash();

  @$internal
  @override
  $ProviderElement<GalleryRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  GalleryRepository create(Ref ref) {
    return galleryRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GalleryRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GalleryRepository>(value),
    );
  }
}

String _$galleryRepositoryHash() => r'0f640974986a4aa7a2fe245ad3f16738664926ad';
