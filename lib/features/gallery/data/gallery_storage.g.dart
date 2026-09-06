// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gallery_storage.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(galleryStorage)
final galleryStorageProvider = GalleryStorageProvider._();

final class GalleryStorageProvider
    extends $FunctionalProvider<GalleryStorage, GalleryStorage, GalleryStorage>
    with $Provider<GalleryStorage> {
  GalleryStorageProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'galleryStorageProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$galleryStorageHash();

  @$internal
  @override
  $ProviderElement<GalleryStorage> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  GalleryStorage create(Ref ref) {
    return galleryStorage(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GalleryStorage value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GalleryStorage>(value),
    );
  }
}

String _$galleryStorageHash() => r'3f3e3c50cef91c569071fe719f41ec032671fba0';
