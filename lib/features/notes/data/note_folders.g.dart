// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'note_folders.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(DeclaredFolders)
final declaredFoldersProvider = DeclaredFoldersProvider._();

final class DeclaredFoldersProvider
    extends $StreamNotifierProvider<DeclaredFolders, List<String>> {
  DeclaredFoldersProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'declaredFoldersProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$declaredFoldersHash();

  @$internal
  @override
  DeclaredFolders create() => DeclaredFolders();
}

String _$declaredFoldersHash() => r'bd30d9ad26e754d220a106dd4ed7fb958f10fd38';

abstract class _$DeclaredFolders extends $StreamNotifier<List<String>> {
  Stream<List<String>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<String>>, List<String>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<String>>, List<String>>,
              AsyncValue<List<String>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Every folder the sidebar shows: the ones holding notes, the ones I
/// made and have not filled, and every parent of both.
///
/// It watches both sources rather than reading one inside the other's
/// stream — a folder made a second ago has no notes in it yet, and that
/// is precisely the folder that has to appear.

@ProviderFor(noteFolderTree)
final noteFolderTreeProvider = NoteFolderTreeProvider._();

/// Every folder the sidebar shows: the ones holding notes, the ones I
/// made and have not filled, and every parent of both.
///
/// It watches both sources rather than reading one inside the other's
/// stream — a folder made a second ago has no notes in it yet, and that
/// is precisely the folder that has to appear.

final class NoteFolderTreeProvider
    extends $FunctionalProvider<List<String>, List<String>, List<String>>
    with $Provider<List<String>> {
  /// Every folder the sidebar shows: the ones holding notes, the ones I
  /// made and have not filled, and every parent of both.
  ///
  /// It watches both sources rather than reading one inside the other's
  /// stream — a folder made a second ago has no notes in it yet, and that
  /// is precisely the folder that has to appear.
  NoteFolderTreeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'noteFolderTreeProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$noteFolderTreeHash();

  @$internal
  @override
  $ProviderElement<List<String>> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  List<String> create(Ref ref) {
    return noteFolderTree(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<String> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<String>>(value),
    );
  }
}

String _$noteFolderTreeHash() => r'a65795aaeae1e26c5e692dbd1a2caa4ffe9e060a';
