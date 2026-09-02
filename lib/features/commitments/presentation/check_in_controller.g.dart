// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'check_in_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(CheckInController)
final checkInControllerProvider = CheckInControllerProvider._();

final class CheckInControllerProvider
    extends $AsyncNotifierProvider<CheckInController, void> {
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
}

String _$checkInControllerHash() => r'b78eef38e0c8edd63ac9eef3bc036fefd811a317';

abstract class _$CheckInController extends $AsyncNotifier<void> {
  FutureOr<void> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<void>, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<void>, void>,
              AsyncValue<void>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(CommitmentEditor)
final commitmentEditorProvider = CommitmentEditorProvider._();

final class CommitmentEditorProvider
    extends $AsyncNotifierProvider<CommitmentEditor, void> {
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
}

String _$commitmentEditorHash() => r'3d7820f9feb3802e703c424534af84678b7ad906';

abstract class _$CommitmentEditor extends $AsyncNotifier<void> {
  FutureOr<void> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<void>, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<void>, void>,
              AsyncValue<void>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
