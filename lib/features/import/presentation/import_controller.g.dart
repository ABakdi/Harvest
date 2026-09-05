// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'import_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Picks an archive, reads it, shows what it would do, and — only if
/// asked again — does it.
///
/// The two steps are deliberately separate calls: an import that
/// started the moment a file was chosen would be a restore-over by
/// accident, and ADR-007 rule 6 says I get to see it first.

@ProviderFor(ImportController)
final importControllerProvider = ImportControllerProvider._();

/// Picks an archive, reads it, shows what it would do, and — only if
/// asked again — does it.
///
/// The two steps are deliberately separate calls: an import that
/// started the moment a file was chosen would be a restore-over by
/// accident, and ADR-007 rule 6 says I get to see it first.
final class ImportControllerProvider
    extends $NotifierProvider<ImportController, ImportState> {
  /// Picks an archive, reads it, shows what it would do, and — only if
  /// asked again — does it.
  ///
  /// The two steps are deliberately separate calls: an import that
  /// started the moment a file was chosen would be a restore-over by
  /// accident, and ADR-007 rule 6 says I get to see it first.
  ImportControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'importControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$importControllerHash();

  @$internal
  @override
  ImportController create() => ImportController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ImportState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ImportState>(value),
    );
  }
}

String _$importControllerHash() => r'fc93410335466b4c54b94f7a4ffc4ce68fb82264';

/// Picks an archive, reads it, shows what it would do, and — only if
/// asked again — does it.
///
/// The two steps are deliberately separate calls: an import that
/// started the moment a file was chosen would be a restore-over by
/// accident, and ADR-007 rule 6 says I get to see it first.

abstract class _$ImportController extends $Notifier<ImportState> {
  ImportState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<ImportState, ImportState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ImportState, ImportState>,
              ImportState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
