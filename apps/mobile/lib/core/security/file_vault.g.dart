// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'file_vault.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(fileVault)
final fileVaultProvider = FileVaultProvider._();

final class FileVaultProvider
    extends $FunctionalProvider<FileVault, FileVault, FileVault>
    with $Provider<FileVault> {
  FileVaultProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'fileVaultProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$fileVaultHash();

  @$internal
  @override
  $ProviderElement<FileVault> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  FileVault create(Ref ref) {
    return fileVault(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FileVault value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FileVault>(value),
    );
  }
}

String _$fileVaultHash() => r'f84b7c2ee1ebfe97806bce8f5deb9c6f9557f985';
