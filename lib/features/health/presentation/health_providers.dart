import 'package:harvest/core/app/current_day.dart';
import 'package:harvest/features/health/data/health_repository.dart';
import 'package:harvest/features/health/domain/body_weight.dart';
import 'package:harvest/features/health/domain/steps.dart';
import 'package:harvest/features/settings/data/settings_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'health_providers.g.dart';

/// Settings keys the health screens read.
abstract final class HealthKeys {
  static const unit = 'health.weightUnit';
  static const targetGrams = 'health.targetWeightGrams';
  static const stepGoal = 'health.stepGoal';
  static const trendDays = 'health.trendDays';
}

@riverpod
Stream<List<BodyWeight>> bodyWeights(Ref ref) =>
    ref.watch(healthRepositoryProvider).watchWeights();

@riverpod
Stream<List<StepDay>> recentSteps(Ref ref, int days) =>
    ref.watch(healthRepositoryProvider).watchSteps(days: days);

@riverpod
Stream<StepDay?> stepsToday(Ref ref) => ref
    .watch(healthRepositoryProvider)
    .watchStepsOn(ref.watch(currentHarvestDayProvider));

/// Kilograms or pounds — a display choice, stored as a name.
@riverpod
class WeightUnitSetting extends _$WeightUnitSetting {
  @override
  Stream<WeightUnit> build() => ref
      .watch(settingsRepositoryProvider)
      .watchAll([HealthKeys.unit])
      .map((values) => WeightUnit.fromName(values[HealthKeys.unit]));

  Future<void> set(WeightUnit unit) => ref
      .read(settingsRepositoryProvider)
      .setString(HealthKeys.unit, unit.name);
}

/// An optional line to aim at. Null until one is set.
@riverpod
class TargetWeight extends _$TargetWeight {
  @override
  Stream<int?> build() => ref
      .watch(settingsRepositoryProvider)
      .watchAll([HealthKeys.targetGrams])
      .map((values) => int.tryParse(values[HealthKeys.targetGrams] ?? ''));

  Future<void> set(int? grams) => ref
      .read(settingsRepositoryProvider)
      .setString(HealthKeys.targetGrams, grams?.toString() ?? '');
}

/// How far back the summary sentence reads. Mine to change.
@riverpod
class TrendDays extends _$TrendDays {
  @override
  Stream<int> build() => ref
      .watch(settingsRepositoryProvider)
      .watchAll([HealthKeys.trendDays])
      .map((values) => int.tryParse(values[HealthKeys.trendDays] ?? '') ?? 30);

  Future<void> set(int days) => ref
      .read(settingsRepositoryProvider)
      .setString(HealthKeys.trendDays, '$days');
}

/// The daily step goal. Zero means none has been asked for, and the
/// number is shown before a goal ever is ([[Health]]).
@riverpod
class StepGoal extends _$StepGoal {
  @override
  Stream<int> build() => ref
      .watch(settingsRepositoryProvider)
      .watchAll([HealthKeys.stepGoal])
      .map((values) => int.tryParse(values[HealthKeys.stepGoal] ?? '') ?? 0);

  Future<void> set(int steps) => ref
      .read(settingsRepositoryProvider)
      .setString(HealthKeys.stepGoal, '$steps');
}
