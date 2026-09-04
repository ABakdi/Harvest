// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'check_in_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Check-ins from the UI. The state is the in-flight write: the field
/// disables taps while it is loading and shows the error when it fails.

@ProviderFor(CheckInController)
final checkInControllerProvider = CheckInControllerProvider._();

/// Check-ins from the UI. The state is the in-flight write: the field
/// disables taps while it is loading and shows the error when it fails.
final class CheckInControllerProvider
    extends $NotifierProvider<CheckInController, AsyncValue<void>> {
  /// Check-ins from the UI. The state is the in-flight write: the field
  /// disables taps while it is loading and shows the error when it fails.
  CheckInControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'checkInControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$checkInControllerHash();

  @$internal
  @override
  CheckInController create() => CheckInController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<void> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<void>>(value),
    );
  }
}

String _$checkInControllerHash() => r'a32976edfe4a6d563d2c4bf774f17898e0cf6f2d';

/// Check-ins from the UI. The state is the in-flight write: the field
/// disables taps while it is loading and shows the error when it fails.

abstract class _$CheckInController extends $Notifier<AsyncValue<void>> {
  AsyncValue<void> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<void>, AsyncValue<void>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<void>, AsyncValue<void>>,
              AsyncValue<void>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Creates, edits, pauses and archives seeds. Every write replans the
/// reminders; a newly set reminder time asks the OS once for permission.

@ProviderFor(CommitmentEditor)
final commitmentEditorProvider = CommitmentEditorProvider._();

/// Creates, edits, pauses and archives seeds. Every write replans the
/// reminders; a newly set reminder time asks the OS once for permission.
final class CommitmentEditorProvider
    extends $NotifierProvider<CommitmentEditor, AsyncValue<void>> {
  /// Creates, edits, pauses and archives seeds. Every write replans the
  /// reminders; a newly set reminder time asks the OS once for permission.
  CommitmentEditorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'commitmentEditorProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$commitmentEditorHash();

  @$internal
  @override
  CommitmentEditor create() => CommitmentEditor();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<void> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<void>>(value),
    );
  }
}

String _$commitmentEditorHash() => r'5f046424eb3a127fceaac8cd81a9e95ad2c69adb';

/// Creates, edits, pauses and archives seeds. Every write replans the
/// reminders; a newly set reminder time asks the OS once for permission.

abstract class _$CommitmentEditor extends $Notifier<AsyncValue<void>> {
  AsyncValue<void> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<void>, AsyncValue<void>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<void>, AsyncValue<void>>,
              AsyncValue<void>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
