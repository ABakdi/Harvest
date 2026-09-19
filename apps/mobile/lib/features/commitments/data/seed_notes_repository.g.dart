// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'seed_notes_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(seedNotesRepository)
final seedNotesRepositoryProvider = SeedNotesRepositoryProvider._();

final class SeedNotesRepositoryProvider
    extends
        $FunctionalProvider<
          SeedNotesRepository,
          SeedNotesRepository,
          SeedNotesRepository
        >
    with $Provider<SeedNotesRepository> {
  SeedNotesRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'seedNotesRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$seedNotesRepositoryHash();

  @$internal
  @override
  $ProviderElement<SeedNotesRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SeedNotesRepository create(Ref ref) {
    return seedNotesRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SeedNotesRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SeedNotesRepository>(value),
    );
  }
}

String _$seedNotesRepositoryHash() =>
    r'71b21d980da72b8475941a84e53b6e02aa4ac445';
