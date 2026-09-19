// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'exercise_media.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(exerciseMedia)
final exerciseMediaProvider = ExerciseMediaProvider._();

final class ExerciseMediaProvider
    extends $FunctionalProvider<ExerciseMedia, ExerciseMedia, ExerciseMedia>
    with $Provider<ExerciseMedia> {
  ExerciseMediaProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'exerciseMediaProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$exerciseMediaHash();

  @$internal
  @override
  $ProviderElement<ExerciseMedia> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ExerciseMedia create(Ref ref) {
    return exerciseMedia(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ExerciseMedia value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ExerciseMedia>(value),
    );
  }
}

String _$exerciseMediaHash() => r'c3418bbdd8f83c75cbccad58f4687468c71c710f';
