import 'package:harvest/core/domain/harvest_day.dart';
import 'package:meta/meta.dart';

/// When a habit is due. Projects are implicitly due daily; to-dos are
/// due on their planned day — schedules only apply to habits.
@immutable
sealed class Schedule {
  const Schedule();

  factory Schedule.fromJson(Map<String, dynamic> json) =>
      switch (json['type'] as String) {
        DailySchedule.kind => const DailySchedule(),
        WeeklySchedule.kind => WeeklySchedule(
          weekdays: (json['weekdays'] as List<dynamic>).cast<int>().toSet(),
        ),
        IntervalSchedule.kind => IntervalSchedule(
          everyDays: json['everyDays'] as int,
          anchorDay: HarvestDay.parse(json['anchorDay'] as String),
        ),
        TimesPerWeekSchedule.kind => TimesPerWeekSchedule(
          times: json['times'] as int,
        ),
        final other => throw ArgumentError('unknown schedule type: $other'),
      };

  Map<String, dynamic> toJson();

  /// Whether the habit is due on [day].
  ///
  /// [doneDaysThisWeek] is the number of distinct days already completed in
  /// [day]'s week — only the flexible times-per-week schedule needs it.
  bool isDueOn(HarvestDay day, {int doneDaysThisWeek = 0});
}

/// Every single day.
final class DailySchedule extends Schedule {
  const DailySchedule();

  static const kind = 'daily';

  @override
  Map<String, dynamic> toJson() => {'type': kind};

  @override
  bool isDueOn(HarvestDay day, {int doneDaysThisWeek = 0}) => true;

  @override
  bool operator ==(Object other) => other is DailySchedule;

  @override
  int get hashCode => kind.hashCode;
}

/// Fixed days of the week (e.g. Mon/Wed/Fri).
final class WeeklySchedule extends Schedule {
  const WeeklySchedule({required this.weekdays});

  static const kind = 'weekly';

  /// [DateTime.monday]..[DateTime.sunday].
  final Set<int> weekdays;

  @override
  Map<String, dynamic> toJson() => {
    'type': kind,
    'weekdays': weekdays.toList()..sort(),
  };

  @override
  bool isDueOn(HarvestDay day, {int doneDaysThisWeek = 0}) =>
      weekdays.contains(day.weekday);

  @override
  bool operator ==(Object other) =>
      other is WeeklySchedule &&
      other.weekdays.length == weekdays.length &&
      other.weekdays.containsAll(weekdays);

  @override
  int get hashCode => Object.hashAllUnordered(weekdays);
}

/// Every X days, counted from an anchor day.
final class IntervalSchedule extends Schedule {
  const IntervalSchedule({required this.everyDays, required this.anchorDay});

  static const kind = 'interval';

  final int everyDays;
  final HarvestDay anchorDay;

  @override
  Map<String, dynamic> toJson() => {
    'type': kind,
    'everyDays': everyDays,
    'anchorDay': anchorDay.key,
  };

  @override
  bool isDueOn(HarvestDay day, {int doneDaysThisWeek = 0}) {
    final distance = anchorDay.daysUntil(day);
    return distance >= 0 && distance % everyDays == 0;
  }

  @override
  bool operator ==(Object other) =>
      other is IntervalSchedule &&
      other.everyDays == everyDays &&
      other.anchorDay == anchorDay;

  @override
  int get hashCode => Object.hash(everyDays, anchorDay);
}

/// X times per week, on whichever days I pick as the week unfolds.
final class TimesPerWeekSchedule extends Schedule {
  const TimesPerWeekSchedule({required this.times});

  static const kind = 'timesPerWeek';

  final int times;

  @override
  Map<String, dynamic> toJson() => {'type': kind, 'times': times};

  @override
  bool isDueOn(HarvestDay day, {int doneDaysThisWeek = 0}) =>
      doneDaysThisWeek < times;

  @override
  bool operator ==(Object other) =>
      other is TimesPerWeekSchedule && other.times == times;

  @override
  int get hashCode => times.hashCode;
}
