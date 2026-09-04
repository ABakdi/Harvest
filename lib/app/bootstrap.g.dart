// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bootstrap.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The last startup step that failed, as a short description — shown
/// quietly in Settings so a broken row never fails silently.

@ProviderFor(BootstrapStatus)
final bootstrapStatusProvider = BootstrapStatusProvider._();

/// The last startup step that failed, as a short description — shown
/// quietly in Settings so a broken row never fails silently.
final class BootstrapStatusProvider
    extends $NotifierProvider<BootstrapStatus, String?> {
  /// The last startup step that failed, as a short description — shown
  /// quietly in Settings so a broken row never fails silently.
  BootstrapStatusProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'bootstrapStatusProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$bootstrapStatusHash();

  @$internal
  @override
  BootstrapStatus create() => BootstrapStatus();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$bootstrapStatusHash() => r'b8f1b1c419fc9b4aca46ec080540f456dad26294';

/// The last startup step that failed, as a short description — shown
/// quietly in Settings so a broken row never fails silently.

abstract class _$BootstrapStatus extends $Notifier<String?> {
  String? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<String?, String?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String?, String?>,
              String?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Startup work: the lazy, idempotent day reconciliation that backs up
/// the 3 AM background job (business rule #1), today's reminders, and
/// housekeeping. Each step is isolated — one bad row must not take the
/// others down.

@ProviderFor(appBootstrap)
final appBootstrapProvider = AppBootstrapProvider._();

/// Startup work: the lazy, idempotent day reconciliation that backs up
/// the 3 AM background job (business rule #1), today's reminders, and
/// housekeeping. Each step is isolated — one bad row must not take the
/// others down.

final class AppBootstrapProvider
    extends $FunctionalProvider<AsyncValue<void>, void, FutureOr<void>>
    with $FutureModifier<void>, $FutureProvider<void> {
  /// Startup work: the lazy, idempotent day reconciliation that backs up
  /// the 3 AM background job (business rule #1), today's reminders, and
  /// housekeeping. Each step is isolated — one bad row must not take the
  /// others down.
  AppBootstrapProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appBootstrapProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appBootstrapHash();

  @$internal
  @override
  $FutureProviderElement<void> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<void> create(Ref ref) {
    return appBootstrap(ref);
  }
}

String _$appBootstrapHash() => r'5f3245c6aa0f59d22bf451cc7eb9bc3867d210bb';
