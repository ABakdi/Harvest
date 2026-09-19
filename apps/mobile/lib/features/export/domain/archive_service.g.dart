// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'archive_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(archiveService)
final archiveServiceProvider = ArchiveServiceProvider._();

final class ArchiveServiceProvider
    extends $FunctionalProvider<ArchiveService, ArchiveService, ArchiveService>
    with $Provider<ArchiveService> {
  ArchiveServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'archiveServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$archiveServiceHash();

  @$internal
  @override
  $ProviderElement<ArchiveService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ArchiveService create(Ref ref) {
    return archiveService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ArchiveService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ArchiveService>(value),
    );
  }
}

String _$archiveServiceHash() => r'33082ef18fe31fe2044ea87f09de0cc15db67446';
