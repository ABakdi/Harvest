import 'package:harvest/core/app/current_day.dart';
import 'package:harvest/features/health/data/health_repository.dart';
import 'package:harvest/features/health/data/steps_source.dart';
import 'package:harvest/features/health/domain/body_weight.dart';
import 'package:harvest/features/health/domain/steps.dart';
import 'package:harvest/features/health/domain/steps_sync.dart';
import 'package:harvest/features/settings/data/settings_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'health_providers.g.dart';

/// Settings keys the health screens read.
abstract final class HealthKeys {
  static const unit = 'health.weightUnit';
  static const targetGrams = 'health.targetWeightGrams';
  static const stepGoal = 'health.stepGoal';
  static const strideCm = 'health.strideCm';
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

/// How far one step goes, in centimetres — what turns a count into a
/// distance.
@riverpod
class StrideSetting extends _$StrideSetting {
  @override
  Stream<int> build() => ref
      .watch(settingsRepositoryProvider)
      .watchAll([HealthKeys.strideCm])
      .map(
        (values) =>
            int.tryParse(values[HealthKeys.strideCm] ?? '') ?? defaultStrideCm,
      );

  Future<void> set(int cm) => ref
      .read(settingsRepositoryProvider)
      .setString(HealthKeys.strideCm, '$cm');
}

/// Where the steps stand: which source the phone has, and what the
/// last pull came to.
typedef StepsState = ({StepsStatus status, StepsSyncOutcome outcome});

/// The steps, pulled from the phone.
///
/// Built once and refreshed on purpose — when the Health screen is
/// looked at, when the app comes back to the foreground, and after the
/// permission is granted — rather than watched, because the phone is
/// not going to push a step at the app and polling a sensor is not
/// what a passive number deserves.
@Riverpod(keepAlive: true)
class StepsPull extends _$StepsPull {
  @override
  Future<StepsState> build() => _pull();

  Future<StepsState> _pull() async {
    final source = ref.read(stepsSourceProvider);
    final goal = await ref.read(stepGoalProvider.future);
    final outcome = await ref
        .read(stepsSyncProvider)
        .sync(today: ref.read(currentHarvestDayProvider), goal: goal);
    var status = await source.status();
    // Health Connect only says whether it is allowed by being read.
    if (outcome == StepsSyncOutcome.synced) {
      status = status.copyWith(granted: true);
    }
    return (status: status, outcome: outcome);
  }

  Future<void> refresh() async {
    state = AsyncData(await _pull());
  }

  /// Asks the phone, and pulls straight away if it says yes.
  Future<bool> connect() async {
    final ok = await ref.read(stepsSourceProvider).requestPermission();
    await refresh();
    return ok;
  }
}
