// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'programs_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(programsRepository)
final programsRepositoryProvider = ProgramsRepositoryProvider._();

final class ProgramsRepositoryProvider
    extends
        $FunctionalProvider<
          ProgramsRepository,
          ProgramsRepository,
          ProgramsRepository
        >
    with $Provider<ProgramsRepository> {
  ProgramsRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'programsRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$programsRepositoryHash();

  @$internal
  @override
  $ProviderElement<ProgramsRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ProgramsRepository create(Ref ref) {
    return programsRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ProgramsRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ProgramsRepository>(value),
    );
  }
}

String _$programsRepositoryHash() =>
    r'ab74bf18fb3a9285ef2b42aae9ca521b0278dd76';

@ProviderFor(programs)
final programsProvider = ProgramsProvider._();

final class ProgramsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Program>>,
          List<Program>,
          Stream<List<Program>>
        >
    with $FutureModifier<List<Program>>, $StreamProvider<List<Program>> {
  ProgramsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'programsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$programsHash();

  @$internal
  @override
  $StreamProviderElement<List<Program>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Program>> create(Ref ref) {
    return programs(ref);
  }
}

String _$programsHash() => r'8582e8ca280a3335a7d1f8426e369303ed8b9a97';

@ProviderFor(program)
final programProvider = ProgramFamily._();

final class ProgramProvider
    extends
        $FunctionalProvider<AsyncValue<Program?>, Program?, Stream<Program?>>
    with $FutureModifier<Program?>, $StreamProvider<Program?> {
  ProgramProvider._({
    required ProgramFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'programProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$programHash();

  @override
  String toString() {
    return r'programProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<Program?> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<Program?> create(Ref ref) {
    final argument = this.argument as String;
    return program(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ProgramProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$programHash() => r'c67ed4aabac02936659cef905df2cbd49e8cd2ae';

final class ProgramFamily extends $Family
    with $FunctionalFamilyOverride<Stream<Program?>, String> {
  ProgramFamily._()
    : super(
        retry: null,
        name: r'programProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ProgramProvider call(String uuid) =>
      ProgramProvider._(argument: uuid, from: this);

  @override
  String toString() => r'programProvider';
}

@ProviderFor(trainingMaxes)
final trainingMaxesProvider = TrainingMaxesFamily._();

final class TrainingMaxesProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, int>>,
          Map<String, int>,
          Stream<Map<String, int>>
        >
    with $FutureModifier<Map<String, int>>, $StreamProvider<Map<String, int>> {
  TrainingMaxesProvider._({
    required TrainingMaxesFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'trainingMaxesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$trainingMaxesHash();

  @override
  String toString() {
    return r'trainingMaxesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<Map<String, int>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<Map<String, int>> create(Ref ref) {
    final argument = this.argument as String;
    return trainingMaxes(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is TrainingMaxesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$trainingMaxesHash() => r'e01d3720a1772feaea746b216ca4013637df2c3d';

final class TrainingMaxesFamily extends $Family
    with $FunctionalFamilyOverride<Stream<Map<String, int>>, String> {
  TrainingMaxesFamily._()
    : super(
        retry: null,
        name: r'trainingMaxesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  TrainingMaxesProvider call(String programUuid) =>
      TrainingMaxesProvider._(argument: programUuid, from: this);

  @override
  String toString() => r'trainingMaxesProvider';
}
