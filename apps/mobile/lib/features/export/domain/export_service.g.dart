// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'export_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(exportService)
final exportServiceProvider = ExportServiceProvider._();

final class ExportServiceProvider
    extends $FunctionalProvider<ExportService, ExportService, ExportService>
    with $Provider<ExportService> {
  ExportServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'exportServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$exportServiceHash();

  @$internal
  @override
  $ProviderElement<ExportService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ExportService create(Ref ref) {
    return exportService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ExportService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ExportService>(value),
    );
  }
}

String _$exportServiceHash() => r'801ec16f6fa37bf1475f2dcf766acf603e799cc2';

/// Runs one export at a time and reports where it got to.
///
/// The archive is now slow enough to need both halves of this: a count
/// that moves, and a way to stop it. A cancelled export has written
/// nothing anywhere.

@ProviderFor(ExportController)
final exportControllerProvider = ExportControllerProvider._();

/// Runs one export at a time and reports where it got to.
///
/// The archive is now slow enough to need both halves of this: a count
/// that moves, and a way to stop it. A cancelled export has written
/// nothing anywhere.
final class ExportControllerProvider
    extends $NotifierProvider<ExportController, ExportStatus> {
  /// Runs one export at a time and reports where it got to.
  ///
  /// The archive is now slow enough to need both halves of this: a count
  /// that moves, and a way to stop it. A cancelled export has written
  /// nothing anywhere.
  ExportControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'exportControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$exportControllerHash();

  @$internal
  @override
  ExportController create() => ExportController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ExportStatus value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ExportStatus>(value),
    );
  }
}

String _$exportControllerHash() => r'af48f862be52b449adc0890b81f512f67718b822';

/// Runs one export at a time and reports where it got to.
///
/// The archive is now slow enough to need both halves of this: a count
/// that moves, and a way to stop it. A cancelled export has written
/// nothing anywhere.

abstract class _$ExportController extends $Notifier<ExportStatus> {
  ExportStatus build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<ExportStatus, ExportStatus>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ExportStatus, ExportStatus>,
              ExportStatus,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
