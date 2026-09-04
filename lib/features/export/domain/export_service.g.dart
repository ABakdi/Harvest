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

String _$exportServiceHash() => r'1caaad39f620d015399e56ce25eb14ba7eeac5e9';

/// Runs one export at a time and reports where it got to.

@ProviderFor(ExportController)
final exportControllerProvider = ExportControllerProvider._();

/// Runs one export at a time and reports where it got to.
final class ExportControllerProvider
    extends $NotifierProvider<ExportController, ExportStatus> {
  /// Runs one export at a time and reports where it got to.
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

String _$exportControllerHash() => r'96ff229ddd5907cf34fa37366ad3217f8739a8b6';

/// Runs one export at a time and reports where it got to.

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
