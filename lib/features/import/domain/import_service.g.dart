// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'import_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(importService)
final importServiceProvider = ImportServiceProvider._();

final class ImportServiceProvider
    extends $FunctionalProvider<ImportService, ImportService, ImportService>
    with $Provider<ImportService> {
  ImportServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'importServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$importServiceHash();

  @$internal
  @override
  $ProviderElement<ImportService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ImportService create(Ref ref) {
    return importService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ImportService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ImportService>(value),
    );
  }
}

String _$importServiceHash() => r'3428833856b2d1035cebadd15151039e4af8b6ac';
