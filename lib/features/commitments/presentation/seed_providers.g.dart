// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'seed_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(archivedCommitments)
final archivedCommitmentsProvider = ArchivedCommitmentsProvider._();

final class ArchivedCommitmentsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Commitment>>,
          List<Commitment>,
          Stream<List<Commitment>>
        >
    with $FutureModifier<List<Commitment>>, $StreamProvider<List<Commitment>> {
  ArchivedCommitmentsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'archivedCommitmentsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$archivedCommitmentsHash();

  @$internal
  @override
  $StreamProviderElement<List<Commitment>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Commitment>> create(Ref ref) {
    return archivedCommitments(ref);
  }
}

String _$archivedCommitmentsHash() =>
    r'8dc12030ecca7015a02dff4100a918c28624a4a4';

@ProviderFor(seed)
final seedProvider = SeedFamily._();

final class SeedProvider
    extends
        $FunctionalProvider<
          AsyncValue<Commitment?>,
          Commitment?,
          Stream<Commitment?>
        >
    with $FutureModifier<Commitment?>, $StreamProvider<Commitment?> {
  SeedProvider._({
    required SeedFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'seedProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$seedHash();

  @override
  String toString() {
    return r'seedProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<Commitment?> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<Commitment?> create(Ref ref) {
    final argument = this.argument as String;
    return seed(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is SeedProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$seedHash() => r'08f6b7e84dfc98b663cc8e4d7b497370826ba08f';

final class SeedFamily extends $Family
    with $FunctionalFamilyOverride<Stream<Commitment?>, String> {
  SeedFamily._()
    : super(
        retry: null,
        name: r'seedProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  SeedProvider call(String uuid) => SeedProvider._(argument: uuid, from: this);

  @override
  String toString() => r'seedProvider';
}

@ProviderFor(seedNotes)
final seedNotesProvider = SeedNotesFamily._();

final class SeedNotesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<SeedNote>>,
          List<SeedNote>,
          Stream<List<SeedNote>>
        >
    with $FutureModifier<List<SeedNote>>, $StreamProvider<List<SeedNote>> {
  SeedNotesProvider._({
    required SeedNotesFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'seedNotesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$seedNotesHash();

  @override
  String toString() {
    return r'seedNotesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<SeedNote>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<SeedNote>> create(Ref ref) {
    final argument = this.argument as String;
    return seedNotes(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is SeedNotesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$seedNotesHash() => r'bf8c29c3e868ae04d5bf1432dd9467dc4fe5cdce';

final class SeedNotesFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<SeedNote>>, String> {
  SeedNotesFamily._()
    : super(
        retry: null,
        name: r'seedNotesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  SeedNotesProvider call(String uuid) =>
      SeedNotesProvider._(argument: uuid, from: this);

  @override
  String toString() => r'seedNotesProvider';
}

@ProviderFor(seedHistory)
final seedHistoryProvider = SeedHistoryFamily._();

final class SeedHistoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<({HarvestDay day, DateTime loggedAt, int quantity})>>,
          List<({HarvestDay day, DateTime loggedAt, int quantity})>,
          Stream<List<({HarvestDay day, DateTime loggedAt, int quantity})>>
        >
    with
        $FutureModifier<
          List<({HarvestDay day, DateTime loggedAt, int quantity})>
        >,
        $StreamProvider<
          List<({HarvestDay day, DateTime loggedAt, int quantity})>
        > {
  SeedHistoryProvider._({
    required SeedHistoryFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'seedHistoryProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$seedHistoryHash();

  @override
  String toString() {
    return r'seedHistoryProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<
    List<({HarvestDay day, DateTime loggedAt, int quantity})>
  >
  $createElement($ProviderPointer pointer) => $StreamProviderElement(pointer);

  @override
  Stream<List<({HarvestDay day, DateTime loggedAt, int quantity})>> create(
    Ref ref,
  ) {
    final argument = this.argument as String;
    return seedHistory(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is SeedHistoryProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$seedHistoryHash() => r'20e7a4c82f6e83312da8f7bedaaa5435df369f21';

final class SeedHistoryFamily extends $Family
    with
        $FunctionalFamilyOverride<
          Stream<List<({HarvestDay day, DateTime loggedAt, int quantity})>>,
          String
        > {
  SeedHistoryFamily._()
    : super(
        retry: null,
        name: r'seedHistoryProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  SeedHistoryProvider call(String uuid) =>
      SeedHistoryProvider._(argument: uuid, from: this);

  @override
  String toString() => r'seedHistoryProvider';
}

/// The seed's whole story, newest day first: every day it was watered
/// and every day it was written about, merged into one timeline.

@ProviderFor(seedTimeline)
final seedTimelineProvider = SeedTimelineFamily._();

/// The seed's whole story, newest day first: every day it was watered
/// and every day it was written about, merged into one timeline.

final class SeedTimelineProvider
    extends $FunctionalProvider<List<SeedDay>, List<SeedDay>, List<SeedDay>>
    with $Provider<List<SeedDay>> {
  /// The seed's whole story, newest day first: every day it was watered
  /// and every day it was written about, merged into one timeline.
  SeedTimelineProvider._({
    required SeedTimelineFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'seedTimelineProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$seedTimelineHash();

  @override
  String toString() {
    return r'seedTimelineProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<List<SeedDay>> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  List<SeedDay> create(Ref ref) {
    final argument = this.argument as String;
    return seedTimeline(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<SeedDay> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<SeedDay>>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is SeedTimelineProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$seedTimelineHash() => r'206b36d7c495a7b4229219be2353f4a4c9d268f1';

/// The seed's whole story, newest day first: every day it was watered
/// and every day it was written about, merged into one timeline.

final class SeedTimelineFamily extends $Family
    with $FunctionalFamilyOverride<List<SeedDay>, String> {
  SeedTimelineFamily._()
    : super(
        retry: null,
        name: r'seedTimelineProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The seed's whole story, newest day first: every day it was watered
  /// and every day it was written about, merged into one timeline.

  SeedTimelineProvider call(String uuid) =>
      SeedTimelineProvider._(argument: uuid, from: this);

  @override
  String toString() => r'seedTimelineProvider';
}
