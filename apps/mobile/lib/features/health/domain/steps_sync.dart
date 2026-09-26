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

  /// The read was allowed and failed: keep what is there, try again
  /// on the next pull.
  failed,
}

/// How long after 3 AM a sensor reading still belongs to the day that
/// ended. Later than this, the steps in the counter are as likely to be
/// this morning's as last night's, and guessing is how a day gets
/// counted twice ([[Audit-v2]] B3-01).
const sensorCloseWindow = Duration(hours: 3);

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
      await _payUnpaid(today, goal: goal, days: days);
    }
    return outcome;
  }

  /// Pays every day a pull can see and the ledger has not paid (H9:
  /// "whichever pull sees it first"). A day the 3 AM job could not
  /// read, followed by a weekend without an open, is still paid on
  /// Monday ([[Audit-v2]] B3-02).
  ///
  /// The walk starts after the last day ever paid, so a goal set today
  /// does not pay a month of history back. A phone that has never paid
  /// looks at today and yesterday only, which is what it always did.
  Future<void> _payUnpaid(
    HarvestDay today, {
    required int goal,
    required int days,
  }) async {
    if (goal <= 0) return;
    final oldest = today.addDays(-(days - 1));
    final lastPaid = await _repository.lastPaidStepDay();
    var day = lastPaid == null ? today.previous : lastPaid.next;
    if (day.compareTo(oldest) < 0) day = oldest;
    for (; day.compareTo(today) <= 0; day = day.next) {
      await _repository.payStepGoal(day, goal: goal);
    }
  }

  /// The 3 AM pull: closes [ended], the day that just finished, and
  /// pays its goal.
  ///
  /// Health Connect keeps its own history, so for it this is the
  /// ordinary pull a day later. The sensor has no memory: the steps
  /// since its last reading belong to the day that ended, and the new
  /// day starts anchored where this reading leaves the counter.
  ///
  /// [now] is when the job actually runs, which WorkManager decides:
  /// Doze defers it by hours and a DST change moves it by one.
  Future<StepsSyncOutcome> closeDay({
    required HarvestDay ended,
    required int goal,
    DateTime? now,
    int days = stepsSyncDays,
  }) async {
    final status = await _source.status();
    final outcome = switch (status.backend) {
      StepsBackend.healthConnect => await _fromHealthConnect(ended.next, days),
      StepsBackend.sensor => await _sensorAtDayEnd(
        status,
        ended,
        now ?? DateTime.now(),
      ),
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
    DateTime now,
  ) async {
    if (!status.granted) return StepsSyncOutcome.needsPermission;

    // The reading is only ended's to take when two things are true:
    // it is still the small hours after ended closed, and nothing has
    // read the new day yet. Otherwise the steps in the counter may
    // already belong to — or already be counted on — the new day, and
    // the ended day keeps what it had. On most phones the question is
    // moot: Android does not deliver sensor events to a background
    // app, the reading comes back null, and the evening's steps are
    // written down on the next open ([[Health]] H9).
    final closedAt = ended.next.startsAt;
    final fresh =
        !now.isBefore(closedAt) &&
        now.isBefore(closedAt.add(sensorCloseWindow));
    if (!fresh) return StepsSyncOutcome.synced;
    final next = await _repository.stepsOn(ended.next);
    if (next.lastCounter != null) return StepsSyncOutcome.synced;

    final counter = await _source.counter();
    if (counter == null) return StepsSyncOutcome.synced;

    var day = await _repository.stepsOn(ended);
    if (day.lastCounter == null) {
      day = startOfDay(
        ended,
        counter: await _repository.lastCounterBefore(ended),
      );
    }
    await _repository.saveStepDays([
      applyReading(day, counter),
      startOfDay(ended.next, counter: counter),
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
      case StepsUnreadable():
        return StepsSyncOutcome.failed;
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
