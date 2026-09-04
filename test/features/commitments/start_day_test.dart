import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/commitments/domain/commitment.dart';
import 'package:harvest/features/commitments/domain/due.dart';
import 'package:harvest/features/commitments/domain/schedule.dart';

/// Checkpoint C3-2: a seed planted today is due from today forward.
///
/// The calendar used to run every habit's schedule over the whole month
/// it was showing, so a habit created this morning appeared on days that
/// had already happened — a history it never had.
void main() {
  final planted = HarvestDay.parse('2026-09-10');

  Commitment habit({Schedule schedule = const DailySchedule()}) => Commitment(
    uuid: 'h',
    type: CommitmentType.habit,
    title: 'Exercise',
    createdAt: planted.startsAt.add(const Duration(hours: 9)),
    schedule: schedule,
  );

  test('a seed starts on the Harvest Day it was planted', () {
    expect(habit().startDay, planted);
  });

  test('a seed planted at 1 AM belongs to the day before', () {
    final night = Commitment(
      uuid: 'h',
      type: CommitmentType.habit,
      title: 'Exercise',
      createdAt: DateTime(2026, 9, 10, 1),
      schedule: const DailySchedule(),
    );
    expect(night.startDay, HarvestDay.parse('2026-09-09'));
  });

  test('a daily habit is not due on any day before it existed', () {
    expect(isDueOn(habit(), planted.previous), isFalse);
    expect(isDueOn(habit(), planted.addDays(-30)), isFalse);
    expect(isDueOn(habit(), planted), isTrue);
    expect(isDueOn(habit(), planted.next), isTrue);
  });

  test('a weekly habit is not due on matching weekdays in the past', () {
    // The 10th is a Thursday; the schedule includes Thursdays.
    final weekly = habit(
      schedule: const WeeklySchedule(weekdays: {DateTime.thursday}),
    );
    expect(isDueOn(weekly, planted.addDays(-7)), isFalse);
    expect(isDueOn(weekly, planted), isTrue);
    expect(isDueOn(weekly, planted.addDays(7)), isTrue);
  });

  test('a project is not due before it was started', () {
    final project = Commitment(
      uuid: 'p',
      type: CommitmentType.project,
      title: 'Read',
      createdAt: planted.startsAt,
      totalTarget: 300,
      dailyCommitment: 10,
    );
    expect(isDueOn(project, planted.previous), isFalse);
    expect(isDueOn(project, planted), isTrue);
  });
}
