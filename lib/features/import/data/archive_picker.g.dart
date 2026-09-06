// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'archive_picker.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(archivePicker)
final archivePickerProvider = ArchivePickerProvider._();

final class ArchivePickerProvider
    extends $FunctionalProvider<ArchivePicker, ArchivePicker, ArchivePicker>
    with $Provider<ArchivePicker> {
  ArchivePickerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'archivePickerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$archivePickerHash();

  @$internal
  @override
  $ProviderElement<ArchivePicker> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ArchivePicker create(Ref ref) {
    return archivePicker(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ArchivePicker value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ArchivePicker>(value),
    );
  }
}

String _$archivePickerHash() => r'5a35ae13eea8572671e9b78b1d4bea197953f242';
