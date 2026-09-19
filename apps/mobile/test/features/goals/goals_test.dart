import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/commitments/data/commitments_repository.dart';
import 'package:harvest/features/commitments/domain/check_in_service.dart';
import 'package:harvest/features/commitments/domain/commitment.dart';
import 'package:harvest/features/commitments/domain/schedule.dart';
import 'package:harvest/features/gamification/domain/streak_service.dart';
import 'package:harvest/features/goals/data/goals_repository.dart';
import 'package:harvest/features/goals/domain/goal.dart';

/// Phase 5, M5.2: the goals board ([[Goals]]).
void main() {
  late HarvestDatabase db;
  late GoalsRepository goals;
  late CommitmentsRepository seeds;
  late CheckInService checkIns;

  setUp(() {
    db = HarvestDatabase.forTesting(NativeDatabase.memory());
    goals = GoalsRepository(db);
    seeds = CommitmentsRepository(db);
    checkIns = CheckInService(db, StreakService(db));
  });

  tearDown(() async => db.close());

  Future<GoalView> view(String uuid) async =>
      (await goals.watchOne(uuid).first)!;

  Future<int> goalXp() async {
    final rows = await db.select(db.ledger).get();
    return rows
        .where((row) => row.reason.startsWith('goal'))
        .fold<int>(0, (sum, row) => sum + row.delta);
  }

  group('progress (GL2)', () {
    test('is ticked over all, needs and steps alike', () async {
      final goal = await goals.create(title: 'Half marathon');
      expect((await view(goal.uuid)).progress, isNull);

      final shoes = await goals.addItem(
        goal.uuid,
        body: 'Running shoes',
        kind: GoalItemKind.need,
      );
      await goals.addItem(goal.uuid, body: 'Run 10 km');
      await goals.addItem(goal.uuid, body: 'Run 15 km');
      await goals.addItem(goal.uuid, body: 'Sign up');
      await goals.setDone(shoes.uuid, done: true);

      final v = await view(goal.uuid);
      expect(v.progress, 0.25);
      expect(v.needs.map((i) => i.body), ['Running shoes']);
      expect(v.steps.map((i) => i.body), ['Run 10 km', 'Run 15 km', 'Sign up']);
      expect(v.next?.body, 'Run 10 km');
      expect(v.complete, isFalse);
    });

    test('a deleted item stops counting, and comes back with undo', () async {
      final goal = await goals.create(title: 'Car');
      final a = await goals.addItem(goal.uuid, body: 'Save 1000');
      await goals.addItem(goal.uuid, body: 'Test drive');
      await goals.setDone(a.uuid, done: true);
      await goals.deleteItem(a.uuid);
      expect((await view(goal.uuid)).progress, 0);
      await goals.restoreItem(a.uuid);
      expect((await view(goal.uuid)).progress, 0.5);
    });
  });

  group('achieving (GL4)', () {
    test('pays +50 once, reopening takes it back, again pays again', () async {
      final goal = await goals.create(title: 'Calligraphy');
      await goals.achieve(goal.uuid);
      await goals.achieve(goal.uuid);
      expect(await goalXp(), goalAchievedXp);
      expect((await view(goal.uuid)).goal.status, GoalStatus.achieved);

      await goals.reopen(goal.uuid);
      expect(await goalXp(), 0);
      expect((await view(goal.uuid)).goal.status, GoalStatus.active);

      await goals.achieve(goal.uuid);
      expect(await goalXp(), goalAchievedXp);
    });

    test('dropping costs nothing and can be picked up again', () async {
      final goal = await goals.create(title: 'Violin');
      await goals.drop(goal.uuid, note: 'not now');
      final dropped = await view(goal.uuid);
      expect(dropped.goal.status, GoalStatus.dropped);
      expect(dropped.goal.statusNote, 'not now');
      expect(await goalXp(), 0);
      await goals.reopen(goal.uuid);
      expect((await view(goal.uuid)).goal.status, GoalStatus.active);
      expect(await goalXp(), 0);
    });
  });

  group('a planted to-do (GL3)', () {
    test('ticks its item on check-in, and un-ticks it on undo', () async {
      final goal = await goals.create(title: 'Half marathon');
      final item = await goals.addItem(goal.uuid, body: 'Sign up');
      final todo = await seeds.create(
        type: CommitmentType.todo,
        title: 'Sign up',
        dueDay: HarvestDay.today(),
        goalUuid: goal.uuid,
      );
      await goals.linkItem(item.uuid, todo.uuid);

      await checkIns.checkIn(todo);
      expect((await view(goal.uuid)).items.single.isDone, isTrue);

      await checkIns.undoToday(todo);
      expect((await view(goal.uuid)).items.single.isDone, isFalse);
    });

    test('a habit never ticks its item', () async {
      final goal = await goals.create(title: 'Fit');
      final item = await goals.addItem(
        goal.uuid,
        body: 'Run three times a week',
      );
      final habit = await seeds.create(
        type: CommitmentType.habit,
        title: 'Run',
        schedule: const DailySchedule(),
        goalUuid: goal.uuid,
      );
      await goals.linkItem(item.uuid, habit.uuid);
      await checkIns.checkIn(habit);
      expect((await view(goal.uuid)).items.single.isDone, isFalse);
    });
  });

  group('linked, not owned (GL5, GL7)', () {
    test('archiving a seed leaves its goal and item alone', () async {
      final goal = await goals.create(title: 'Car');
      final item = await goals.addItem(goal.uuid, body: 'Save');
      final todo = await seeds.create(
        type: CommitmentType.todo,
        title: 'Save',
        dueDay: HarvestDay.today(),
        goalUuid: goal.uuid,
      );
      await goals.linkItem(item.uuid, todo.uuid);
      await seeds.archive(todo.uuid);
      final v = await view(goal.uuid);
      expect(v.items.single.commitmentUuid, todo.uuid);
      expect(v.goal.status, GoalStatus.active);
    });

    test(
      'deleting a goal takes its items; undo brings back only those',
      () async {
        final goal = await goals.create(title: 'Car');
        final early = await goals.addItem(goal.uuid, body: 'Gone before');
        await goals.addItem(goal.uuid, body: 'Kept');
        await goals.deleteItem(
          early.uuid,
          at: DateTime.now().subtract(const Duration(hours: 1)),
        );

        await goals.delete(goal.uuid);
        expect(await goals.watchOne(goal.uuid).first, isNull);
        expect(await goals.watchAll().first, isEmpty);

        await goals.restore(goal.uuid);
        final v = await view(goal.uuid);
        expect(v.items.map((i) => i.body), ['Kept']);

        final seed = await seeds.create(
          type: CommitmentType.todo,
          title: 'x',
          dueDay: HarvestDay.today(),
          goalUuid: goal.uuid,
        );
        await goals.delete(goal.uuid);
        final still = await (db.select(
          db.commitments,
        )..where((c) => c.uuid.equals(seed.uuid))).getSingle();
        expect(still.goalUuid, goal.uuid);
        expect(still.deletedAt, isNull);
      },
    );
  });

  test('every goal write reaches the outbox', () async {
    final goal = await goals.create(title: 'Car');
    final item = await goals.addItem(goal.uuid, body: 'Save');
    await goals.setDone(item.uuid, done: true);
    await goals.achieve(goal.uuid);
    final tables = (await db.select(db.outbox).get()).map((r) => r.targetTable);
    expect(tables, containsAll(['goals', 'goal_items', 'ledger']));
  });
}
