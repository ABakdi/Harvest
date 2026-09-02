import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/commitments/domain/check_in_service.dart';
import 'package:harvest/features/commitments/domain/commitment.dart';
import 'package:harvest/features/commitments/domain/schedule.dart';
import 'package:harvest/features/gamification/domain/streak_service.dart';

void main() {
  late HarvestDatabase db;
  late CheckInService service;
  final day = HarvestDay.parse('2026-09-02');

  final habit = Commitment(
    uuid: 'habit-1',
    type: CommitmentType.habit,
    title: 'Exercise',
    createdAt: DateTime(2026),
    schedule: const DailySchedule(),
  );

  final project = Commitment(
    uuid: 'project-1',
    type: CommitmentType.project,
    title: 'Read a book',
    createdAt: DateTime(2026),
    totalTarget: 300,
    dailyCommitment: 10,
  );

  setUp(() {
    db = HarvestDatabase.forTesting(NativeDatabase.memory());
    service = CheckInService(db, StreakService(db));
  });

  tearDown(() => db.close());

  Future<int> xpTotal() async {
    final sum = db.ledger.delta.sum();
    final query = db.selectOnly(db.ledger)..addColumns([sum]);
    return (await query.getSingle()).read(sum) ?? 0;
  }

  group('habit check-ins', () {
    test('first check-in succeeds and earns 10 XP', () async {
      final result = await service.checkIn(habit, day: day);
      expect(result, isA<CheckInSuccess>());
      expect((result as CheckInSuccess).xpEarned, Xp.habitOrTodo);
      expect(await xpTotal(), Xp.habitOrTodo);
    });

    test('second check-in the same day is a no-op', () async {
      await service.checkIn(habit, day: day);
      final second = await service.checkIn(habit, day: day);
      expect(second, isA<CheckInCapped>());
      expect((second as CheckInCapped).quantityLogged, 0);
      expect(await xpTotal(), Xp.habitOrTodo);
    });

    test('a new day allows a new check-in', () async {
      await service.checkIn(habit, day: day);
      final next = await service.checkIn(habit, day: day.next);
      expect(next, isA<CheckInSuccess>());
    });
  });

  group('project check-ins and the 2x over-log cap', () {
    test('logging units earns 2 XP per unit', () async {
      final result = await service.checkIn(project, quantity: 10, day: day);
      expect(result, isA<CheckInSuccess>());
      expect(
        (result as CheckInSuccess).xpEarned,
        10 * Xp.perProjectUnit,
      );
    });

    test('a single oversized log is clamped to 2x the daily commitment',
        () async {
      final result = await service.checkIn(project, quantity: 50, day: day);
      expect(result, isA<CheckInCapped>());
      expect((result as CheckInCapped).quantityLogged, 20);
    });

    test('cumulative logs cannot exceed the cap either', () async {
      await service.checkIn(project, quantity: 15, day: day);
      final second = await service.checkIn(project, quantity: 15, day: day);
      expect(second, isA<CheckInCapped>());
      expect((second as CheckInCapped).quantityLogged, 5);

      final third = await service.checkIn(project, day: day);
      expect(third, isA<CheckInCapped>());
      expect((third as CheckInCapped).quantityLogged, 0);
    });
  });

  group('undo', () {
    test("removes the day's check-ins and their XP", () async {
      await service.checkIn(habit, day: day);
      expect(await xpTotal(), Xp.habitOrTodo);

      await service.undoToday(habit, day: day);
      expect(await xpTotal(), 0);

      final rows = await db.select(db.checkIns).get();
      expect(rows, isEmpty);
    });

    test('appends delete operations to the outbox', () async {
      await service.checkIn(habit, day: day);
      await service.undoToday(habit, day: day);
      final ops = await db.select(db.outbox).get();
      expect(ops.map((o) => o.op), containsAll(['insert', 'delete']));
    });
  });
}
