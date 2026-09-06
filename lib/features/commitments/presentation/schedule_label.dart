import 'package:flutter/widgets.dart';
import 'package:harvest/core/ui/format.dart';
import 'package:harvest/features/commitments/domain/schedule.dart';
import 'package:harvest/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

/// What a schedule asks of me, in a few words.
///
/// Shared because a scheduled album is a seed and has to say the same
/// thing a habit says — one wording, one place to change it.
String scheduleLabel(
  BuildContext context,
  AppLocalizations l10n,
  Schedule? schedule,
) => switch (schedule) {
  WeeklySchedule(:final weekdays) => weekdayNames(context, weekdays),
  IntervalSchedule(:final everyDays) => l10n.scheduleEveryDays(everyDays),
  TimesPerWeekSchedule(:final times) =>
    l10n.scheduleTimesShort(times, 0).split(' · ').first,
  DailySchedule() || null => l10n.scheduleDailyShort,
};

String weekdayNames(BuildContext context, Set<int> weekdays) {
  final names = DateFormat.E(localeTag(context)).dateSymbols.SHORTWEEKDAYS;
  final sorted = weekdays.toList()..sort();
  // intl lists Sunday first; weekdays are ISO (Monday = 1).
  return sorted.map((d) => names[d % 7]).join(' · ');
}
