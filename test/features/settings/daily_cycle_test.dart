import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/features/commitments/data/commitments_repository.dart';
import 'package:harvest/features/commitments/domain/commitment.dart';
import 'package:harvest/features/commitments/domain/schedule.dart';
import 'package:harvest/features/settings/domain/daily_cycle.dart';
import 'package:harvest/features/settings/domain/daily_cycle_service.dart';

/// Checkpoint C4-5: the app bends to whatever hours I keep.
void main() {
  group('the night itself', () {
    test('a plain night is measured end to end', () {
      const cycle = DailyCycle.fallback;
      expect(cycle.sleep, const Duration(hours: 8));
      expect(cycle.meetsRecommendation, isTrue);
      expect(cycle.isShort, isFalse);
    });

    test('a night that does not cross midnight is still a night', () {
      // Asleep at 3 AM, up at 11 — a perfectly ordinary night shift.
      const cycle = DailyCycle(bedTime: (3, 0), wakeTime: (11, 0));
      expect(cycle.sleep, const Duration(hours: 8));
    });

    test('four hours is flagged, and not refused', () {
      const cycle = DailyCycle(bedTime: (2, 0), wakeTime: (6, 0));
      expect(cycle.sleep, const Duration(hours: 4));
      expect(cycle.isShort, isTrue);
    });

    test('the window covers the night and not the morning', () {
      const cycle = DailyCycle.fallback;
      expect(cycle.covers((23, 30)), isTrue);
      expect(cycle.covers((3, 0)), isTrue);
      expect(cycle.covers((6, 59)), isTrue);
      // The wake minute is already morning: a reminder for the moment I
      // get up is not one that wakes me.
      expect(cycle.covers((7, 0)), isFalse);
      expect(cycle.covers((22, 59)), isFalse);
    });

    test('a night inside one day covers only that stretch', () {
      const cycle = DailyCycle(bedTime: (3, 0), wakeTime: (11, 0));
      expect(cycle.covers((5, 0)), isTrue);
      expect(cycle.covers((23, 0)), isFalse);
      expect(cycle.covers((2, 59)), isFalse);
    });
  });

  group('keeping the distance from waking', () {
    const from = DailyCycle.fallback;

    test('a reminder moves by exactly what the wake time moved', () {
      const to = DailyCycle(bedTime: (1, 0), wakeTime: (9, 0));
      // 9 AM was two hours after waking; it still is.
      expect(from.afterWaking((9, 0)), const Duration(hours: 2));
      expect(from.shiftedWith(to, (9, 0)), (11, 0));
      expect(to.afterWaking((11, 0)), const Duration(hours: 2));
    });

    test('it wraps around midnight rather than falling off the day', () {
      const to = DailyCycle(bedTime: (17, 0), wakeTime: (1, 0));
      expect(from.shiftedWith(to, (2, 0)), (20, 0));
    });

    test('an earlier wake time pulls reminders back with it', () {
      const to = DailyCycle(bedTime: (21, 30), wakeTime: (5, 30));
      expect(from.shiftedWith(to, (18, 0)), (16, 30));
    });

    test('nothing moves when the wake time does not', () {
      const to = DailyCycle(bedTime: (0, 30), wakeTime: (7, 0));
      expect(from.shiftedWith(to, (18, 0)), (18, 0));
    });
  });

  group('what a new night would swallow', () {
    late HarvestDatabase db;
    late CommitmentsRepository repo;
    late DailyCycleService service;

    const from = DailyCycle.fallback;

    setUp(() {
      db = HarvestDatabase.forTesting(NativeDatabase.memory());
      repo = CommitmentsRepository(db);
      service = DailyCycleService(db);
    });

    tearDown(() => db.close());

    Future<void> seed(String title, String? remindAt) => repo
        .create(
          type: CommitmentType.habit,
          title: title,
          schedule: const DailySchedule(),
          remindAt: remindAt,
          createdAt: DateTime(2026),
        )
        .then((_) {});

    test('only the reminders inside the new night are listed', () async {
      await seed('Morning pages', '07:30');
      await seed('Gym', '18:00');
      await seed('No reminder', null);

      // Moving to a 1 AM–9 AM night buries the 07:30 one.
      const to = DailyCycle(bedTime: (1, 0), wakeTime: (9, 0));
      final clashes = await service.clashes(from: from, to: to);

      expect(clashes.map((c) => c.title), ['Morning pages']);
      expect(clashes.single.at, (7, 30));
      expect(clashes.single.movedTo, (9, 30));
    });

    test('an unsettled debt reminder counts too', () async {
      await db.customStatement(
        'insert into debts (uuid, person, amount_minor, currency, '
        'remind_at, created_at, updated_at) '
        "values ('d1', 'Sam', 5000, 'DZD', '02:00', 0, 0)",
      );
      const to = DailyCycle(bedTime: (1, 0), wakeTime: (9, 0));
      final clashes = await service.clashes(from: from, to: to);
      expect(clashes.single.kind, 'debt');
      expect(clashes.single.movedTo, (4, 0));
    });

    test('shifting writes the new times and nothing else', () async {
      await seed('Morning pages', '07:30');
      const to = DailyCycle(bedTime: (1, 0), wakeTime: (9, 0));

      final clashes = await service.clashes(from: from, to: to);
      await service.shift(clashes);

      final seeds = await repo.activeOnce();
      expect(seeds.single.remindAt, '09:30');
      expect(seeds.single.title, 'Morning pages');
    });

    test('the cycle round-trips through settings', () async {
      const cycle = DailyCycle(bedTime: (2, 15), wakeTime: (10, 45));
      await service.write(cycle);
      expect(await service.read(), cycle);
    });

    test('an unset cycle is the ordinary one', () async {
      expect(await service.read(), DailyCycle.fallback);
    });
  });
}
