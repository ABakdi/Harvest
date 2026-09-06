import 'package:harvest/core/domain/harvest_day.dart';
import 'package:meta/meta.dart';

/// One Harvest Day's steps.
@immutable
class StepDay {
  const StepDay({
    required this.day,
    required this.steps,
    this.lastCounter,
  });

  final HarvestDay day;
  final int steps;

  /// The sensor's own since-boot reading when this total was last
  /// updated. Null before the first reading of the day.
  final int? lastCounter;
}

/// What one sensor reading does to a day's total.
///
/// Android's `TYPE_STEP_COUNTER` counts **since the phone booted**, so
/// a reading is not a step count — it is a running total that resets
/// to zero without warning. The whole job is turning a sequence of
/// those into daily figures that never go backwards and never invent
/// steps.
///
/// Three cases, and the third is the one everybody gets wrong:
///
/// * **First reading of a day** — nothing to compare against, so it
///   adds nothing. It only records where the counter was, and the next
///   reading measures from there. A day therefore starts at whatever
///   the previous reading left it, which is the correct answer.
/// * **Counter went up** — the difference is real steps. Add it.
/// * **Counter went *down*** — the phone rebooted. There is no way to
///   know how many steps happened before it went off, so the honest
///   answer is to count from zero again and lose them, rather than
///   adding the new reading wholesale and inventing a few thousand.
///   The day keeps everything it had.
StepDay applyReading(StepDay current, int counter) {
  final last = current.lastCounter;
  if (last == null || counter < last) {
    // A first reading, or a reboot: re-anchor without changing the
    // total. Steps taken between the reboot and this reading are lost,
    // and losing them is better than guessing them.
    return StepDay(
      day: current.day,
      steps: current.steps,
      lastCounter: counter,
    );
  }
  return StepDay(
    day: current.day,
    steps: current.steps + (counter - last),
    lastCounter: counter,
  );
}

/// The rolling total to carry into a new day.
///
/// Crossing 3 AM does not reset the sensor, so the new day starts at
/// zero steps but anchored to the counter the old day ended on.
StepDay startOfDay(HarvestDay day, {int? counter}) =>
    StepDay(day: day, steps: 0, lastCounter: counter);

/// Averages over a run of days, ignoring days with no reading at all.
///
/// A day the phone was off is not a zero-step day, and averaging it in
/// as one would quietly libel the week.
int? averageSteps(Iterable<StepDay> days) {
  final counted = days.where((day) => day.steps > 0).toList();
  if (counted.isEmpty) return null;
  return counted.fold<int>(0, (sum, day) => sum + day.steps) ~/ counted.length;
}
