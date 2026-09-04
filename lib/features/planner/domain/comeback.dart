import 'package:harvest/core/domain/harvest_day.dart';

/// The rungs of the comeback ladder — how long I have been away when
/// each nudge fires.
///
/// The app is a streak app, and a streak app that goes quiet the moment
/// you stop using it has given up on the one job it had. This is the
/// gentle-to-urgent escalation of the reminder spec applied to absence
/// rather than to a single task: one day, three days, a week, a
/// fortnight, a month, two months — and never more than one on any day.
enum ComebackRung {
  day1(1),
  day3(3),
  week1(7),
  week2(14),
  month1(30),
  month2(60);

  const ComebackRung(this.missedDays);

  /// Full Harvest Days gone by with nothing logged.
  final int missedDays;
}

/// The day each rung fires, given the last day I actually did something.
///
/// A rung fires the morning *after* its run of missed days is complete:
/// the day-1 nudge lands two days after the last check-in, because the
/// day in between was the one I missed and the day before that I was
/// still here.
Map<ComebackRung, HarvestDay> comebackDays(HarvestDay lastActive) => {
  for (final rung in ComebackRung.values)
    rung: lastActive.addDays(rung.missedDays + 1),
};

/// The rung due on [day], if any — what today's nudge should say.
ComebackRung? rungOn(HarvestDay lastActive, HarvestDay day) {
  for (final entry in comebackDays(lastActive).entries) {
    if (entry.value == day) return entry.key;
  }
  return null;
}

/// How often the last rung repeats once the ladder has run out.
const comebackHeartbeat = 30;

/// The rungs still ahead of [today], with the day each lands on. Rungs
/// already behind us are gone: a nudge for a day that has passed is
/// noise, and the ladder is rebuilt from scratch on every plan anyway.
///
/// Past the last rung the ladder does not go silent — it settles into a
/// monthly heartbeat. Someone who put the phone down in March should
/// still hear from their field in June; the alternative is an app that
/// quietly deletes itself from your life, which is the exact failure
/// this whole feature exists to prevent.
List<(ComebackRung, HarvestDay)> upcomingComebacks(
  HarvestDay lastActive,
  HarvestDay today,
) {
  final days = comebackDays(lastActive);
  final upcoming = [
    for (final entry in days.entries)
      if (entry.value.compareTo(today) >= 0) (entry.key, entry.value),
  ];
  final last = days[ComebackRung.values.last]!;
  if (last.compareTo(today) < 0) {
    upcoming.add((ComebackRung.values.last, today.addDays(comebackHeartbeat)));
  }
  return upcoming;
}
