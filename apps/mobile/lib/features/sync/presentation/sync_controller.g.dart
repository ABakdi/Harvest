// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// When sync runs ([[Sync-API]]: order of a sync): on resume, two
/// seconds after the last local write, and every fifteen minutes while
/// the app is open — and never more than once at a time, which the
/// service itself guarantees.

@ProviderFor(SyncController)
final syncControllerProvider = SyncControllerProvider._();

/// When sync runs ([[Sync-API]]: order of a sync): on resume, two
/// seconds after the last local write, and every fifteen minutes while
/// the app is open — and never more than once at a time, which the
/// service itself guarantees.
final class SyncControllerProvider
    extends $NotifierProvider<SyncController, SyncStatus> {
  /// When sync runs ([[Sync-API]]: order of a sync): on resume, two
  /// seconds after the last local write, and every fifteen minutes while
  /// the app is open — and never more than once at a time, which the
  /// service itself guarantees.
  SyncControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'syncControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$syncControllerHash();

  @$internal
  @override
  SyncController create() => SyncController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SyncStatus value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SyncStatus>(value),
    );
  }
}

String _$syncControllerHash() => r'ff7aaffd1ce8b1b44efbfc6f3e36b392d6e8851f';

/// When sync runs ([[Sync-API]]: order of a sync): on resume, two
/// seconds after the last local write, and every fifteen minutes while
/// the app is open — and never more than once at a time, which the
/// service itself guarantees.

abstract class _$SyncController extends $Notifier<SyncStatus> {
  SyncStatus build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<SyncStatus, SyncStatus>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SyncStatus, SyncStatus>,
              SyncStatus,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
