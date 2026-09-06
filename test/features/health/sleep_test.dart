import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/health/domain/sleep.dart';
import 'package:harvest/features/settings/domain/daily_cycle.dart';

/// Phase 4, M4.7. Sleep debt is arithmetic that runs on the worst
/// input imaginable — a number I typed half-awake — so the tests are
/// about the edges: the night nobody logged, the lie-in, the week.
void main() {
  final monday = HarvestDay.parse('2026-09-07');

  /// A night ending on [day] of [hours] slept against an 8-hour target.
  SleepNight night(
    HarvestDay day, {
    required double hours,
    int targetHours = 8,
    int? stars,
  }) {
    final woke = DateTime(day.year, day.month, day.day, 7);
    return SleepNight(
      uuid: 'n-${day.key}',
      day: day,
      fellAsleepAt: woke.subtract(Duration(minutes: (hours * 60).round())),
      wokeAt: woke,
      targetMinutes: targetHours * 60,
      restedStars: stars,
    );
  }

  group('one night', () {
    test('knows how long it was', () {
      expect(
        night(monday, hours: 7.5).slept,
        const Duration(hours: 7, minutes: 30),
      );
    });

    test('short of target is a positive shortfall', () {
      expect(night(monday, hours: 6).shortfallMinutes, 120);
    });

    test('over target is a negative one', () {
      expect(night(monday, hours: 9).shortfallMinutes, -60);
    });

    test('crossing midnight is not a special case', () {
      final woke = DateTime(2026, 9, 7, 6, 30);
      final entry = SleepNight(
        uuid: 'n',
        day: monday,
        fellAsleepAt: DateTime(2026, 9, 6, 23, 15),
        wokeAt: woke,
        targetMinutes: 480,
      );
      expect(entry.sleptMinutes, 7 * 60 + 15);
    });
  });

  group('the debt', () {
    test('is nothing when nothing is logged', () {
      expect(sleepDebtMinutes(const []), 0);
    });

    test('adds up night after night', () {
      final nights = [
        night(monday, hours: 6),
        night(monday.next, hours: 6),
        night(monday.next.next, hours: 7),
      ];
      // Two hours, two hours, one hour.
      expect(sleepDebtMinutes(nights), 300);
    });

    test('is paid down minute for minute', () {
      final nights = [
        night(monday, hours: 6),
        night(monday.next, hours: 9),
      ];
      expect(sleepDebtMinutes(nights), 60);
    });

    test('never goes below zero', () {
      final nights = [
        night(monday, hours: 12),
        night(monday.next, hours: 12),
        night(monday.next.next, hours: 7),
      ];
      // Two enormous nights do not buy credit against the third: sleep
      // is not a bank account.
      expect(sleepDebtMinutes(nights), 60);
    });

    test('ignores nights nobody logged', () {
      // A gap in the middle is unknown, not a failure — the two logged
      // nights are all that counts.
      final nights = [
        night(monday, hours: 6),
        night(monday.addDays(5), hours: 6),
      ];
      expect(sleepDebtMinutes(nights), 240);
    });

    test('only looks back as far as the window', () {
      final nights = [
        for (var i = 0; i < 20; i++) night(monday.addDays(i), hours: 7),
      ];
      // Twenty nights an hour short, a fourteen-night window.
      expect(sleepDebtMinutes(nights), 14 * 60);
    });

    test('reads the same however the nights arrive', () {
      final nights = [
        night(monday.next, hours: 9),
        night(monday, hours: 6),
      ];
      expect(sleepDebtMinutes(nights), 60);
    });

    test('is reported in nights as well as minutes', () {
      final debt = sleepDebt(
        [night(monday, hours: 4)],
        targetMinutes: 480,
      );
      expect(debt.minutes, 240);
      expect(debt.nights, closeTo(0.5, 0.001));
    });

    test('respects the target that night actually had', () {
      // A five-hour target night slept for five hours owes nothing,
      // even though it is short by anyone else's standard.
      expect(
        sleepDebtMinutes([night(monday, hours: 5, targetHours: 5)]),
        0,
      );
    });
  });

  group('the average', () {
    test('is zero with nothing logged', () {
      expect(averageSleep(const []), Duration.zero);
    });

    test('counts only the nights that exist', () {
      final average = averageSleep([
        night(monday, hours: 6),
        night(monday.addDays(4), hours: 8),
      ]);
      expect(average, const Duration(hours: 7));
    });
  });

  group('targets', () {
    const cycle = DailyCycle.fallback;

    test('are the daily cycle when nothing else is said', () {
      const targets = SleepTargets(cycle: cycle);
      expect(targets.forWeekday(DateTime.saturday), cycle);
      expect(targets.targetMinutesFor(monday), 480);
      expect(targets.hasOverrides, isFalse);
    });

    test('a weekday can have a night of its own', () {
      const lieIn = DailyCycle(bedTime: (1, 0), wakeTime: (10, 0));
      const targets = SleepTargets(
        cycle: cycle,
        overrides: {DateTime.sunday: lieIn},
      );
      expect(targets.forWeekday(DateTime.sunday), lieIn);
      expect(targets.forWeekday(DateTime.monday), cycle);
      expect(targets.hasOverrides, isTrue);
    });

    test('the weekday that decides is the morning I wake on', () {
      const sundayLieIn = DailyCycle(bedTime: (1, 0), wakeTime: (10, 0));
      const targets = SleepTargets(
        cycle: cycle,
        overrides: {DateTime.sunday: sundayLieIn},
      );
      final sunday = HarvestDay.parse('2026-09-13');
      expect(sunday.weekday, DateTime.sunday);
      expect(targets.targetMinutesFor(sunday), 9 * 60);
    });
  });

  group('when things happen', () {
    const targets = SleepTargets(cycle: DailyCycle.fallback);

    test('the alarm is the wake time on the morning itself', () {
      expect(alarmFor(monday, targets), DateTime(2026, 9, 7, 7));
    });

    test('bedtime is the evening before, worked back from the alarm', () {
      expect(bedtimeFor(monday, targets), DateTime(2026, 9, 6, 23));
    });

    test('the wind-down comes half an hour before that', () {
      expect(windDownFor(monday, targets), DateTime(2026, 9, 6, 22, 30));
    });

    test('a night that does not cross midnight still works', () {
      const daytime = SleepTargets(
        cycle: DailyCycle(bedTime: (2, 0), wakeTime: (10, 0)),
      );
      expect(bedtimeFor(monday, daytime), DateTime(2026, 9, 7, 2));
    });
  });

  group('storing a weekday night', () {
    test('round-trips through text', () {
      const cycle = DailyCycle(bedTime: (23, 30), wakeTime: (7, 5));
      expect(decodeCycle(encodeCycle(cycle)), cycle);
      expect(encodeCycle(cycle), '23:30-07:05');
    });

    test('nonsense decodes to nothing rather than throwing', () {
      expect(decodeCycle(null), isNull);
      expect(decodeCycle(''), isNull);
      expect(decodeCycle('half past ten'), isNull);
      expect(decodeCycle('25:00-07:00'), isNull);
      expect(decodeCycle('23:00'), isNull);
    });
  });
}
