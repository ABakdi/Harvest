import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/commitments/domain/commitment.dart';
import 'package:harvest/features/commitments/domain/due.dart';

/// A live check-in, as the calendar reads it.
typedef CalendarCheckIn = ({
  String commitmentUuid,
  String harvestDay,
  int quantity,
});

/// One thing a calendar day lists: a seed due, or its deadline.
typedef CalendarEntry = ({Commitment commitment, bool deadline, bool done});

/// The seeds a calendar day lists, in the seeds' order, each with
/// whether it was done. The same rule as `calendarEntries` in
/// `packages/core`, held to `fixtures/calendar.json` ([[Audit-v3]]
/// G5-12):
/// - a habit on the days it is due. A times-a-week habit counts only
///   the days before the cell in its week, so meeting the quota on
///   Wednesday takes it off Thursday to Sunday, never off Monday to
///   Wednesday; done is a check-in that day;
/// - a to-do on the day it was planned for, done once it was ever
///   checked in, a day late included;
/// - a project never (it is due every day), but its deadline shows;
/// - a deadline on its day, done when the project reached its target
///   (a to-do: once done; a habit: checked in that day).
/// Archived seeds are left out; [checkIns] are the live ones.
List<CalendarEntry> calendarEntries(
  Iterable<Commitment> seeds,
  Iterable<CalendarCheckIn> checkIns,
  HarvestDay day,
) {
  final weekStart = day.weekStart.key;
  final onDay = <String>{};
  final daysBefore = <String, Set<String>>{};
  final logged = <String, int>{};
  for (final row in checkIns) {
    logged[row.commitmentUuid] =
        (logged[row.commitmentUuid] ?? 0) + row.quantity;
    if (row.harvestDay == day.key) onDay.add(row.commitmentUuid);
    if (row.harvestDay.compareTo(weekStart) >= 0 &&
        row.harvestDay.compareTo(day.key) < 0) {
      daysBefore.putIfAbsent(row.commitmentUuid, () => {}).add(row.harvestDay);
    }
  }

  final entries = <CalendarEntry>[];
  for (final seed in seeds) {
    if (seed.archivedAt != null) continue;
    final ever = logged[seed.uuid] ?? 0;
    switch (seed.type) {
      case CommitmentType.habit:
        final doneDays = daysBefore[seed.uuid]?.length ?? 0;
        if (isDueOn(seed, day, doneDaysThisWeek: doneDays)) {
          entries.add((
            commitment: seed,
            deadline: false,
            done: onDay.contains(seed.uuid),
          ));
        }
      case CommitmentType.todo:
        if (seed.dueDay == day) {
          entries.add((commitment: seed, deadline: false, done: ever > 0));
        }
      case CommitmentType.project:
        break;
    }
    if (seed.deadline == day) {
      final done = switch (seed.type) {
        CommitmentType.project => ever > 0 && ever >= (seed.totalTarget ?? 0),
        CommitmentType.todo => ever > 0,
        CommitmentType.habit => onDay.contains(seed.uuid),
      };
      entries.add((commitment: seed, deadline: true, done: done));
    }
  }
  return entries;
}
