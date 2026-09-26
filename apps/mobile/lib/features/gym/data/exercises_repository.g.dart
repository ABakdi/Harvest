// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'exercises_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(exercisesRepository)
final exercisesRepositoryProvider = ExercisesRepositoryProvider._();

final class ExercisesRepositoryProvider
    extends
        $FunctionalProvider<
          ExercisesRepository,
          ExercisesRepository,
          ExercisesRepository
        >
    with $Provider<ExercisesRepository> {
  ExercisesRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'exercisesRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$exercisesRepositoryHash();

  @$internal
  @override
  $ProviderElement<ExercisesRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ExercisesRepository create(Ref ref) {
    return exercisesRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ExercisesRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ExercisesRepository>(value),
    );
  }
}

String _$exercisesRepositoryHash() =>
    r'5cb1420b7c2a0457f9ad4d84bdfb4030ec2b93a9';

/// Mine and the catalogue's, as one list.
///
/// Everything downstream — a program slot, a session, a personal
/// record — refers to an exercise by id and does not care which side of
/// the line it came from.

@ProviderFor(allExercises)
final allExercisesProvider = AllExercisesProvider._();

/// Mine and the catalogue's, as one list.
///
/// Everything downstream — a program slot, a session, a personal
/// record — refers to an exercise by id and does not care which side of
/// the line it came from.

final class AllExercisesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Exercise>>,
          List<Exercise>,
          FutureOr<List<Exercise>>
        >
    with $FutureModifier<List<Exercise>>, $FutureProvider<List<Exercise>> {
  /// Mine and the catalogue's, as one list.
  ///
  /// Everything downstream — a program slot, a session, a personal
  /// record — refers to an exercise by id and does not care which side of
  /// the line it came from.
  AllExercisesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'allExercisesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$allExercisesHash();

  @$internal
  @override
  $FutureProviderElement<List<Exercise>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Exercise>> create(Ref ref) {
    return allExercises(ref);
  }
}

String _$allExercisesHash() => r'42f05c55b0ef458784874ceddfd3a7cf86410c59';

@ProviderFor(myExercises)
final myExercisesProvider = MyExercisesProvider._();

final class MyExercisesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Exercise>>,
          List<Exercise>,
          Stream<List<Exercise>>
        >
    with $FutureModifier<List<Exercise>>, $StreamProvider<List<Exercise>> {
  MyExercisesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'myExercisesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$myExercisesHash();

  @$internal
  @override
  $StreamProviderElement<List<Exercise>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Exercise>> create(Ref ref) {
    return myExercises(ref);
  }
}

String _$myExercisesHash() => r'161750584adf4a4f8bc460cf2e2135802cc3b4a6';

/// One exercise by id, whichever side it lives on.

@ProviderFor(exerciseById)
final exerciseByIdProvider = ExerciseByIdFamily._();

/// One exercise by id, whichever side it lives on.

final class ExerciseByIdProvider
    extends
        $FunctionalProvider<
          AsyncValue<Exercise?>,
          Exercise?,
          FutureOr<Exercise?>
        >
    with $FutureModifier<Exercise?>, $FutureProvider<Exercise?> {
  /// One exercise by id, whichever side it lives on.
  ExerciseByIdProvider._({
    required ExerciseByIdFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'exerciseByIdProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$exerciseByIdHash();

  @override
  String toString() {
    return r'exerciseByIdProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<Exercise?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<Exercise?> create(Ref ref) {
    final argument = this.argument as String;
    return exerciseById(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ExerciseByIdProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$exerciseByIdHash() => r'e905964052b874abcf4d9437bb2b088fe6e3a860';

/// One exercise by id, whichever side it lives on.

final class ExerciseByIdFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<Exercise?>, String> {
  ExerciseByIdFamily._()
    : super(
        retry: null,
        name: r'exerciseByIdProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// One exercise by id, whichever side it lives on.

  ExerciseByIdProvider call(String id) =>
      ExerciseByIdProvider._(argument: id, from: this);

  @override
  String toString() => r'exerciseByIdProvider';
}
