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
/// Reads happen when the app is opened, when the Health screen is
/// looked at — and once at 3 AM, from the day-reset job, so a day
/// closes with its final count whether or not the app was opened that
/// evening ([[Checkpoint-8]]). No service watches the sensor: steps
/// are a passive number ([[Health]] H3) and passive things do not
/// deserve a battery budget.
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
      // Yesterday's goal may have been met after the last pull; the
      // ledger takes it once and never again, so asking is free.
      await _repository.payStepGoal(today.previous, goal: goal);
    }
    return outcome;
  }

  /// The 3 AM pull: closes [ended], the day that just finished, and
  /// pays its goal.
  ///
  /// Health Connect keeps its own history, so for it this is the
  /// ordinary pull a day later. The sensor has no memory: the steps
  /// since its last reading belong to the day that ended, and the new
  /// day starts anchored where this reading leaves the counter.
  Future<StepsSyncOutcome> closeDay({
    required HarvestDay ended,
    required int goal,
    int days = stepsSyncDays,
  }) async {
    final status = await _source.status();
    final outcome = switch (status.backend) {
      StepsBackend.healthConnect => await _fromHealthConnect(ended.next, days),
      StepsBackend.sensor => await _sensorAtDayEnd(status, ended),
      StepsBackend.none => StepsSyncOutcome.unavailable,
    };
    if (outcome == StepsSyncOutcome.synced) {
      await _repository.payStepGoal(ended, goal: goal);
    }
    return outcome;
  }

  Future<StepsSyncOutcome> _sensorAtDayEnd(
    StepsStatus status,
    HarvestDay ended,
  ) async {
    if (!status.granted) return StepsSyncOutcome.needsPermission;
    final counter = await _source.counter();
    if (counter == null) return StepsSyncOutcome.synced;

    var day = await _repository.stepsOn(ended);
    if (day.lastCounter == null) {
      day = startOfDay(
        ended,
        counter: await _repository.lastCounterBefore(ended),
      );
    }
    final closed = applyReading(day, counter);
    final next = await _repository.stepsOn(ended.next);
    await _repository.saveStepDays([
      closed,
      // Only anchor a day nothing has written yet: a pull that beat
      // the job to it already knows where the counter stands.
      if (next.lastCounter == null) startOfDay(ended.next, counter: counter),
    ]);
    return StepsSyncOutcome.synced;
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
