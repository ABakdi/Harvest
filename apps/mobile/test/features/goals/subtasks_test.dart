import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/commitments/data/commitments_repository.dart';
import 'package:harvest/features/commitments/domain/check_in_service.dart';
import 'package:harvest/features/commitments/domain/commitment.dart';
import 'package:harvest/features/gamification/domain/streak_service.dart';
import 'package:harvest/features/goals/data/goals_repository.dart';
import 'package:harvest/features/goals/domain/goal.dart';

/// M6.13: tasks hold subtasks, one level deep ([[Goals]] GL2, GL7, GL8).
void main() {
  late HarvestDatabase db;
  late GoalsRepository goals;

  setUp(() {
    db = HarvestDatabase.forTesting(NativeDatabase.memory());
    goals = GoalsRepository(db);
  });

  tearDown(() async => db.close());

  Future<GoalView> view(String uuid) async =>
      (await goals.watchOne(uuid).first)!;

  Future<GoalItemRow> row(String uuid) => (db.select(
    db.goalItems,
  )..where((i) => i.uuid.equals(uuid))).getSingle();

  /// A goal with one task, "Run a 10 km race", broken into three.
  Future<(Goal, GoalItem, List<GoalItem>)> race() async {
    final goal = await goals.create(title: 'Half marathon');
    final task = await goals.addItem(goal.uuid, body: 'Run a 10 km race');
    final subtasks = [
      for (final body in ['Find a race', 'Register', 'Run it'])
        await goals.addSubtask(task.uuid, body: body),
    ];
    return (goal, task, subtasks);
  }

  group('adding (GL8)', () {
    test('a subtask sits under its task, in order, with its kind', () async {
      final goal = await goals.create(title: 'Half marathon');
      final plan = await goals.addItem(
        goal.uuid,
        body: 'A training plan',
        kind: GoalItemKind.need,
      );
      // Asked for as a step, it still takes its parent's kind.
      final pick = await goals.addItem(
        goal.uuid,
        body: 'Pick one',
        parentUuid: plan.uuid,
      );
      final print = await goals.addSubtask(plan.uuid, body: 'Print it');

      expect(pick.kind, GoalItemKind.need);
      expect([pick.position, print.position], [0, 1]);
      final v = await view(goal.uuid);
      expect(v.needs.map((i) => i.body), ['A training plan']);
      expect(v.steps, isEmpty);
      expect(v.subtasksOf(plan.uuid).map((i) => i.body), [
        'Pick one',
        'Print it',
      ]);
      // Top-level positions are not disturbed by subtasks.
      final next = await goals.addItem(
        goal.uuid,
        body: 'Shoes',
        kind: GoalItemKind.need,
      );
      expect(next.position, 1);
    });

    test('is one level deep: a subtask never has one', () async {
      final (_, _, subtasks) = await race();
      expect(
        () => goals.addSubtask(subtasks.first.uuid, body: 'Deeper'),
        throwsArgumentError,
      );
    });

    test('an open subtask reopens a done parent', () async {
      final goal = await goals.create(title: 'Car');
      final task = await goals.addItem(goal.uuid, body: 'Test drive');
      await goals.setDone(task.uuid, done: true);
      await goals.addSubtask(task.uuid, body: 'Book it');
      expect((await row(task.uuid)).doneAt, isNull);
      expect((await view(goal.uuid)).isDone(task), isFalse);
    });
  });

  group("a parent's tick (GL8)", () {
    test('is drawn from its subtasks, stored as the latest of theirs', () async {
      final (goal, task, subtasks) = await race();
      await goals.setDone(
        subtasks[0].uuid,
        done: true,
        at: DateTime(2026, 9, 20, 10),
      );
      await goals.setDone(
        subtasks[2].uuid,
        done: true,
        at: DateTime(2026, 9, 22, 10),
      );
      expect((await row(task.uuid)).doneAt, isNull);
      expect((await view(goal.uuid)).isDone(task), isFalse);

      await goals.setDone(
        subtasks[1].uuid,
        done: true,
        at: DateTime(2026, 9, 21, 10),
      );
      expect(
        (await row(task.uuid)).doneAt!.isAtSameMomentAs(
          DateTime(2026, 9, 22, 10),
        ),
        isTrue,
      );
      expect((await view(goal.uuid)).isDone(task), isTrue);

      await goals.setDone(subtasks[1].uuid, done: false);
      expect((await row(task.uuid)).doneAt, isNull);
    });

    test('ticking the parent ticks every subtask, and un-ticks them', () async {
      final (goal, task, subtasks) = await race();
      await goals.setDone(subtasks[0].uuid, done: true);
      final at = DateTime(2026, 9, 25, 9);
      await goals.setDone(task.uuid, done: true, at: at);
      var v = await view(goal.uuid);
      expect(v.subtasksOf(task.uuid).every((s) => s.isDone), isTrue);
      expect(v.isDone(task), isTrue);
      expect((await row(task.uuid)).doneAt, isNotNull);

      await goals.setDone(task.uuid, done: false);
      v = await view(goal.uuid);
      expect(v.subtasksOf(task.uuid).any((s) => s.isDone), isFalse);
      expect((await row(task.uuid)).doneAt, isNull);
    });

    test('is written to the outbox with the subtasks', () async {
      final (_, task, subtasks) = await race();
      await db.delete(db.outbox).go();
      await goals.setDone(task.uuid, done: true);
      final queued = {
        for (final r in await db.select(db.outbox).get()) r.rowUuid,
      };
      expect(queued, containsAll([task.uuid, ...subtasks.map((s) => s.uuid)]));
    });

    test('a deleted open subtask no longer holds the parent back', () async {
      final (_, task, subtasks) = await race();
      await goals.setDone(subtasks[0].uuid, done: true);
      await goals.setDone(subtasks[1].uuid, done: true);
      await goals.deleteItem(subtasks[2].uuid);
      expect((await row(task.uuid)).doneAt, isNotNull);
      await goals.restoreItem(subtasks[2].uuid);
      expect((await row(task.uuid)).doneAt, isNull);
    });
  });

  group('progress (GL2)', () {
    test('counts subtasks in place of their parent', () async {
      final (goal, task, subtasks) = await race();
      final shoes = await goals.addItem(
        goal.uuid,
        body: 'Shoes',
        kind: GoalItemKind.need,
      );
      await goals.setDone(shoes.uuid, done: true);
      await goals.setDone(subtasks[0].uuid, done: true);
      final v = await view(goal.uuid);
      // Shoes and one of three: two of four, not one of two.
      expect(goalTally(v.items), (done: 2, total: 4));
      expect(v.progress, 0.5);
      expect(v.complete, isFalse);

      await goals.setDone(task.uuid, done: true);
      expect((await view(goal.uuid)).complete, isTrue);
    });

    test("the next step is the first open task's first open subtask", () async {
      final (goal, task, subtasks) = await race();
      await goals.addItem(goal.uuid, body: 'Run the half');
      expect((await view(goal.uuid)).next?.body, 'Find a race');
      await goals.setDone(subtasks[0].uuid, done: true);
      expect((await view(goal.uuid)).next?.body, 'Register');
      await goals.reorderItems([subtasks[2].uuid, subtasks[1].uuid]);
      expect((await view(goal.uuid)).next?.body, 'Run it');
      await goals.setDone(task.uuid, done: true);
      expect((await view(goal.uuid)).next?.body, 'Run the half');
    });
  });

  group('deleting (GL7)', () {
    test('a task takes its subtasks, and undo brings back only those', () async {
      final (goal, task, subtasks) = await race();
      final early = DateTime.now().subtract(const Duration(hours: 1));
      await goals.deleteItem(subtasks[0].uuid, at: early);

      await goals.deleteItem(task.uuid);
      var v = await view(goal.uuid);
      expect(v.items, isEmpty);
      expect(
        (await row(subtasks[1].uuid)).deletedAt,
        (await row(task.uuid)).deletedAt,
      );

      await goals.restoreItem(task.uuid);
      v = await view(goal.uuid);
      expect(v.subtasksOf(task.uuid).map((s) => s.body), ['Register', 'Run it']);
      expect((await row(subtasks[0].uuid)).deletedAt, isNotNull);
    });

    test('a goal deleted with subtasks comes back with them', () async {
      final (goal, task, _) = await race();
      await goals.delete(goal.uuid);
      await goals.restore(goal.uuid);
      expect((await view(goal.uuid)).subtasksOf(task.uuid), hasLength(3));
    });
  });

  group('lifting and moving (GL8)', () {
    test('a subtask lifted becomes a task of its own, at the foot', () async {
      final (goal, task, subtasks) = await race();
      await goals.addItem(goal.uuid, body: 'Run the half');
      await goals.setDone(subtasks[0].uuid, done: true);
      await goals.setDone(subtasks[1].uuid, done: true);

      await goals.liftItem(subtasks[2].uuid);
      final v = await view(goal.uuid);
      expect(v.steps.map((i) => i.body), [
        'Run a 10 km race',
        'Run the half',
        'Run it',
      ]);
      expect(v.subtasksOf(task.uuid), hasLength(2));
      // What it left behind is all ticked now.
      expect((await row(task.uuid)).doneAt, isNotNull);
    });

    test('a task without subtasks moves under another, taking its kind', () async {
      final goal = await goals.create(title: 'Half marathon');
      final plan = await goals.addItem(
        goal.uuid,
        body: 'A training plan',
        kind: GoalItemKind.need,
      );
      final print = await goals.addItem(goal.uuid, body: 'Print it');
      await goals.moveUnder(print.uuid, plan.uuid);

      final v = await view(goal.uuid);
      expect(v.steps, isEmpty);
      final moved = v.subtasksOf(plan.uuid).single;
      expect(moved.kind, GoalItemKind.need);
      expect(moved.parentUuid, plan.uuid);
    });

    test('a task with subtasks, or a subtask, cannot be moved under', () async {
      final (goal, task, subtasks) = await race();
      final other = await goals.addItem(goal.uuid, body: 'Run the half');
      expect(() => goals.moveUnder(task.uuid, other.uuid), throwsArgumentError);
      expect(
        () => goals.moveUnder(other.uuid, subtasks[0].uuid),
        throwsArgumentError,
      );
      expect(() => goals.moveUnder(other.uuid, other.uuid), throwsArgumentError);
    });
  });

  group('a planted subtask (GL3)', () {
    test('its to-do ticks it, and can complete the parent', () async {
      final seeds = CommitmentsRepository(db);
      final checkIns = CheckInService(db, StreakService(db));
      final (goal, task, subtasks) = await race();
      await goals.setDone(subtasks[0].uuid, done: true);
      await goals.setDone(subtasks[1].uuid, done: true);
      final todo = await seeds.create(
        type: CommitmentType.todo,
        title: 'Run it',
        dueDay: HarvestDay.today(),
        goalUuid: goal.uuid,
      );
      await goals.linkItem(subtasks[2].uuid, todo.uuid);

      await checkIns.checkIn(todo);
      var v = await view(goal.uuid);
      expect(v.isDone(task), isTrue);
      expect((await row(task.uuid)).doneAt, isNotNull);
      expect(v.complete, isTrue);

      await checkIns.undoToday(todo);
      v = await view(goal.uuid);
      expect(v.isDone(task), isFalse);
      expect((await row(task.uuid)).doneAt, isNull);
      expect(
        v.subtasksOf(task.uuid).where((s) => s.isDone).map((s) => s.body),
        ['Find a race', 'Register'],
      );
    });
  });
}
