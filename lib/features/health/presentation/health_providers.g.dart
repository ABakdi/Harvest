// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'health_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(bodyWeights)
final bodyWeightsProvider = BodyWeightsProvider._();

final class BodyWeightsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<BodyWeight>>,
          List<BodyWeight>,
          Stream<List<BodyWeight>>
        >
    with $FutureModifier<List<BodyWeight>>, $StreamProvider<List<BodyWeight>> {
  BodyWeightsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'bodyWeightsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$bodyWeightsHash();

  @$internal
  @override
  $StreamProviderElement<List<BodyWeight>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<BodyWeight>> create(Ref ref) {
    return bodyWeights(ref);
  }
}

String _$bodyWeightsHash() => r'ef9185e163fdde22d7c82ee9d95f45481559c1c4';

@ProviderFor(recentSteps)
final recentStepsProvider = RecentStepsFamily._();

final class RecentStepsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<StepDay>>,
          List<StepDay>,
          Stream<List<StepDay>>
        >
    with $FutureModifier<List<StepDay>>, $StreamProvider<List<StepDay>> {
  RecentStepsProvider._({
    required RecentStepsFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'recentStepsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$recentStepsHash();

  @override
  String toString() {
    return r'recentStepsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<StepDay>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<StepDay>> create(Ref ref) {
    final argument = this.argument as int;
    return recentSteps(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is RecentStepsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$recentStepsHash() => r'e50a663a46f709063c978cc2e29be6335be9b3b4';

final class RecentStepsFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<StepDay>>, int> {
  RecentStepsFamily._()
    : super(
        retry: null,
        name: r'recentStepsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  RecentStepsProvider call(int days) =>
      RecentStepsProvider._(argument: days, from: this);

  @override
  String toString() => r'recentStepsProvider';
}

@ProviderFor(stepsToday)
final stepsTodayProvider = StepsTodayProvider._();

final class StepsTodayProvider
    extends
        $FunctionalProvider<AsyncValue<StepDay?>, StepDay?, Stream<StepDay?>>
    with $FutureModifier<StepDay?>, $StreamProvider<StepDay?> {
  StepsTodayProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'stepsTodayProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$stepsTodayHash();

  @$internal
  @override
  $StreamProviderElement<StepDay?> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<StepDay?> create(Ref ref) {
    return stepsToday(ref);
  }
}

String _$stepsTodayHash() => r'0e5a57f5b8b7ccef6bd1a3daf126b244f5982ea0';

/// Kilograms or pounds — a display choice, stored as a name.

@ProviderFor(WeightUnitSetting)
final weightUnitSettingProvider = WeightUnitSettingProvider._();

/// Kilograms or pounds — a display choice, stored as a name.
final class WeightUnitSettingProvider
    extends $StreamNotifierProvider<WeightUnitSetting, WeightUnit> {
  /// Kilograms or pounds — a display choice, stored as a name.
  WeightUnitSettingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'weightUnitSettingProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$weightUnitSettingHash();

  @$internal
  @override
  WeightUnitSetting create() => WeightUnitSetting();
}

String _$weightUnitSettingHash() => r'fca9819d7ef8962d6c57f47c89ebd8bd486eb686';

/// Kilograms or pounds — a display choice, stored as a name.

abstract class _$WeightUnitSetting extends $StreamNotifier<WeightUnit> {
  Stream<WeightUnit> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<WeightUnit>, WeightUnit>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<WeightUnit>, WeightUnit>,
              AsyncValue<WeightUnit>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// An optional line to aim at. Null until one is set.

@ProviderFor(TargetWeight)
final targetWeightProvider = TargetWeightProvider._();

/// An optional line to aim at. Null until one is set.
final class TargetWeightProvider
    extends $StreamNotifierProvider<TargetWeight, int?> {
  /// An optional line to aim at. Null until one is set.
  TargetWeightProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'targetWeightProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$targetWeightHash();

  @$internal
  @override
  TargetWeight create() => TargetWeight();
}

String _$targetWeightHash() => r'3263e533a2ae4311618b03478dba5008512e55ee';

/// An optional line to aim at. Null until one is set.

abstract class _$TargetWeight extends $StreamNotifier<int?> {
  Stream<int?> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<int?>, int?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<int?>, int?>,
              AsyncValue<int?>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// How far back the summary sentence reads. Mine to change.

@ProviderFor(TrendDays)
final trendDaysProvider = TrendDaysProvider._();

/// How far back the summary sentence reads. Mine to change.
final class TrendDaysProvider extends $StreamNotifierProvider<TrendDays, int> {
  /// How far back the summary sentence reads. Mine to change.
  TrendDaysProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'trendDaysProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$trendDaysHash();

  @$internal
  @override
  TrendDays create() => TrendDays();
}

String _$trendDaysHash() => r'198b18277734c4df4c0b4e748afccb253ac34e12';

/// How far back the summary sentence reads. Mine to change.

abstract class _$TrendDays extends $StreamNotifier<int> {
  Stream<int> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<int>, int>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<int>, int>,
              AsyncValue<int>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The daily step goal. Zero means none has been asked for, and the
/// number is shown before a goal ever is ([[Health]]).

@ProviderFor(StepGoal)
final stepGoalProvider = StepGoalProvider._();

/// The daily step goal. Zero means none has been asked for, and the
/// number is shown before a goal ever is ([[Health]]).
final class StepGoalProvider extends $StreamNotifierProvider<StepGoal, int> {
  /// The daily step goal. Zero means none has been asked for, and the
  /// number is shown before a goal ever is ([[Health]]).
  StepGoalProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'stepGoalProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$stepGoalHash();

  @$internal
  @override
  StepGoal create() => StepGoal();
}

String _$stepGoalHash() => r'53070cdc613c77e9821d9a88fe44e31b82b1ff7c';

/// The daily step goal. Zero means none has been asked for, and the
/// number is shown before a goal ever is ([[Health]]).

abstract class _$StepGoal extends $StreamNotifier<int> {
  Stream<int> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<int>, int>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<int>, int>,
              AsyncValue<int>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
