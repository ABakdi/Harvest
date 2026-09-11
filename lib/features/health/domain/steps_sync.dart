import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/health/data/health_repository.dart';
import 'package:harvest/features/health/data/steps_source.dart';
import 'package:harvest/features/health/domain/steps.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'steps_sync.g.dart';

/// How far back a Health Connect read reaches. Thirty days is what the
/// history charts show, and it is also the furthest back Health
/// Connect lets a newly-permitted app look.
const stepsSyncDays = 30;

/// What a sync came to, for the card to react to.
enum StepsSyncOutcome {
  /// The days were written.
  synced,

  /// The source exists but has not been allowed yet. Ask.
  needsPermission,

  /// Nothing on this phone can count steps.
  unavailable,
}

/// Pulls the phone's step count into `step_days`.
///
/// Two paths, one per source, and they could not be more different in
/// shape:
///
/// * **Health Connect** answers "how many steps between these two
///   instants", so each Harvest Day is one question — 3 AM to 3 AM —
///   and the answer is written down as it is. Reboots, other apps,
///   watches: Health Connect's problem, already solved.
/// * **The sensor** answers "how many steps since boot", so the
///   arithmetic in [applyReading] turns a sequence of those into a
///   day's total. Only ever the current day: the sensor has no memory
///   of yesterday.
///
/// Reading is foreground-only and on purpose: the app asks when it is
/// opened and when the Health screen is looked at, and never runs a
/// service to watch the sensor. Steps are a passive number
/// ([[Health]] H3) and passive things do not deserve a battery budget.
class StepsSync {
  const StepsSync(this._repository, this._source);

  final HealthRepository _repository;
  final StepsSource _source;

  Future<StepsSyncOutcome> sync({
    required HarvestDay today,
    required int goal,
    int days = stepsSyncDays,
  }) async {
    final status = await _source.status();
    final outcome = switch (status.backend) {
      StepsBackend.healthConnect => await _fromHealthConnect(today, days),
      StepsBackend.sensor => await _fromSensor(status, today),
      StepsBackend.none => StepsSyncOutcome.unavailable,
    };
    if (outcome == StepsSyncOutcome.synced) {
      await _repository.payStepGoal(today, goal: goal);
    }
    return outcome;
  }

  Future<StepsSyncOutcome> _fromHealthConnect(
    HarvestDay today,
    int days,
  ) async {
    final first = today.addDays(-(days - 1));
    final windows = <StepsWindow>[
      for (var i = 0; i < days; i++)
        (start: first.addDays(i).startsAt, end: first.addDays(i + 1).startsAt),
    ];
    final totals = await _source.totals(windows);
    switch (totals) {
      case StepsDenied():
        return StepsSyncOutcome.needsPermission;
      case StepsCounted(:final totals):
        await _repository.saveStepDays([
          for (final (i, total) in totals.indexed)
            StepDay(day: first.addDays(i), steps: total),
        ]);
        return StepsSyncOutcome.synced;
    }
  }

  Future<StepsSyncOutcome> _fromSensor(
    StepsStatus status,
    HarvestDay today,
  ) async {
    if (!status.granted) return StepsSyncOutcome.needsPermission;
    final counter = await _source.counter();
    // A silent sensor is not a zero: leave the day as it was.
    if (counter == null) return StepsSyncOutcome.synced;

    var day = await _repository.stepsOn(today);
    if (day.lastCounter == null) {
      // A new day starts anchored to where the old one ended, so the
      // steps taken since then land on today rather than vanishing.
      day = startOfDay(
        today,
        counter: await _repository.lastCounterBefore(today),
      );
    }
    await _repository.saveStepDay(applyReading(day, counter));
    return StepsSyncOutcome.synced;
  }
}

@Riverpod(keepAlive: true)
StepsSync stepsSync(Ref ref) => StepsSync(
  ref.watch(healthRepositoryProvider),
  ref.watch(stepsSourceProvider),
);
