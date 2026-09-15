// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'exercise_catalogue.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(exerciseCatalogue)
final exerciseCatalogueProvider = ExerciseCatalogueProvider._();

final class ExerciseCatalogueProvider
    extends
        $FunctionalProvider<
          AsyncValue<ExerciseCatalogue>,
          ExerciseCatalogue,
          FutureOr<ExerciseCatalogue>
        >
    with
        $FutureModifier<ExerciseCatalogue>,
        $FutureProvider<ExerciseCatalogue> {
  ExerciseCatalogueProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'exerciseCatalogueProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$exerciseCatalogueHash();

  @$internal
  @override
  $FutureProviderElement<ExerciseCatalogue> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ExerciseCatalogue> create(Ref ref) {
    return exerciseCatalogue(ref);
  }
}

String _$exerciseCatalogueHash() => r'715ddf7e7445718d81dcf14ff6fcf1c6c5e6dcda';
