import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/commitments/domain/schedule.dart';

void main() {
  // 2026-09-02 is a Wednesday.
  final wednesday = HarvestDay.parse('2026-09-02');
  final thursday = HarvestDay.parse('2026-09-03');

  group('DailySchedule', () {
    test('is always due', () {
      expect(const DailySchedule().isDueOn(wednesday), isTrue);
    });
  });

  group('WeeklySchedule', () {
    const schedule = WeeklySchedule(
      weekdays: {DateTime.monday, DateTime.wednesday, DateTime.friday},
    );

    test('due on listed weekdays only', () {
      expect(schedule.isDueOn(wednesday), isTrue);
      expect(schedule.isDueOn(thursday), isFalse);
    });
  });

  group('IntervalSchedule', () {
    final schedule = IntervalSchedule(
      everyDays: 3,
      anchorDay: HarvestDay.parse('2026-09-01'),
    );

    test('due on anchor and every N days after', () {
      expect(schedule.isDueOn(HarvestDay.parse('2026-09-01')), isTrue);
      expect(schedule.isDueOn(HarvestDay.parse('2026-09-04')), isTrue);
      expect(schedule.isDueOn(HarvestDay.parse('2026-09-07')), isTrue);
      expect(schedule.isDueOn(wednesday), isFalse);
    });

    test('never due before the anchor', () {
      expect(schedule.isDueOn(HarvestDay.parse('2026-08-29')), isFalse);
    });
  });

  group('TimesPerWeekSchedule', () {
    const schedule = TimesPerWeekSchedule(times: 3);

    test('due while the weekly count is unmet', () {
      expect(schedule.isDueOn(wednesday), isTrue);
      expect(schedule.isDueOn(wednesday, doneDaysThisWeek: 2), isTrue);
      expect(schedule.isDueOn(wednesday, doneDaysThisWeek: 3), isFalse);
    });
  });

  group('json round-trip', () {
    test('all schedule kinds survive fromJson(toJson)', () {
      final schedules = <Schedule>[
        const DailySchedule(),
        const WeeklySchedule(weekdays: {1, 3, 5}),
        IntervalSchedule(everyDays: 2, anchorDay: wednesday),
        const TimesPerWeekSchedule(times: 4),
      ];
      for (final schedule in schedules) {
        expect(Schedule.fromJson(schedule.toJson()), equals(schedule));
      }
    });
  });

  group('HarvestDay week helpers', () {
    test('weekday and weekStart', () {
      expect(wednesday.weekday, DateTime.wednesday);
      expect(wednesday.weekStart.key, '2026-08-31');
      expect(wednesday.weekStart.weekday, DateTime.monday);
    });
  });
}
