// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'commitments_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(commitmentsRepository)
final commitmentsRepositoryProvider = CommitmentsRepositoryProvider._();

final class CommitmentsRepositoryProvider
    extends
        $FunctionalProvider<
          CommitmentsRepository,
          CommitmentsRepository,
          CommitmentsRepository
        >
    with $Provider<CommitmentsRepository> {
  CommitmentsRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'commitmentsRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$commitmentsRepositoryHash();

  @$internal
  @override
  $ProviderElement<CommitmentsRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CommitmentsRepository create(Ref ref) {
    return commitmentsRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CommitmentsRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CommitmentsRepository>(value),
    );
  }
}

String _$commitmentsRepositoryHash() =>
    r'a2fa530102971b319337e5e0958ee45e07ff086e';
