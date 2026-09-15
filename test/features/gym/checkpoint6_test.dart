import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/gym/data/programs_repository.dart';
import 'package:harvest/features/gym/data/sessions_repository.dart';
import 'package:harvest/features/gym/domain/exercise.dart';
import 'package:harvest/features/gym/domain/session.dart';

/// Checkpoint 6: the clock that pauses, the days that go round, and
/// which exercises have a bar at all.
void main() {
  group('the session clock', () {
    final start = DateTime(2026, 9, 11, 18);

    WorkoutSession at({
      DateTime? pausedAt,
      int pausedSeconds = 0,
      DateTime? endedAt,
    }) => WorkoutSession(
      uuid: 's',
      day: HarvestDay.parse('2026-09-11'),
      startedAt: start,
      pausedAt: pausedAt,
      pausedSeconds: pausedSeconds,
      endedAt: endedAt,
    );

    test('runs from the start', () {
      expect(
        at().elapsedAt(start.add(const Duration(minutes: 10))),
        const Duration(minutes: 10),
      );
    });

    test('stops at the pause', () {
      final paused = at(pausedAt: start.add(const Duration(minutes: 10)));
      expect(paused.paused, isTrue);
      expect(
        paused.elapsedAt(start.add(const Duration(minutes: 30))),
        const Duration(minutes: 10),
        reason: 'twenty minutes on the phone were not training',
      );
    });

    test('takes the pauses that ended off the total', () {
      final resumed = at(pausedSeconds: 5 * 60);
      expect(
        resumed.elapsedAt(start.add(const Duration(minutes: 30))),
        const Duration(minutes: 25),
      );
    });

    test('never goes negative', () {
      expect(at(pausedSeconds: 600).elapsedAt(start), Duration.zero);
    });
  });

  group('pause and resume on the repository', () {
    late HarvestDatabase db;
    late ProgramsRepository programs;
    late SessionsRepository sessions;

    setUp(() {
      db = HarvestDatabase.forTesting(NativeDatabase.memory());
      programs = ProgramsRepository(db);
      sessions = SessionsRepository(db);
    });

    tearDown(() async => db.close());

    test('a paused session is still the running one, and resumes', () async {
      final program = await programs.createProgram(name: 'PPL');
      final day = await programs.addDay(program.uuid, name: 'Push');
      final session = await sessions.start(
        day: day,
        programUuid: program.uuid,
        title: day.name,
      );

      await sessions.pause(session.uuid);
      final paused = (await sessions.runningOnce())!;
      expect(paused.uuid, session.uuid);
      expect(paused.paused, isTrue);

      await sessions.resume(session.uuid);
      final resumed = (await sessions.once(session.uuid))!;
      expect(resumed.paused, isFalse);
      expect(resumed.pausedSeconds, greaterThanOrEqualTo(0));

      // Pausing twice, or resuming what is not paused, is a no-op.
      await sessions.resume(session.uuid);
      await sessions.pause(session.uuid);
      await sessions.pause(session.uuid);
      expect((await sessions.once(session.uuid))!.paused, isTrue);
    });

    test('finishing while paused ends at the pause', () async {
      final program = await programs.createProgram(name: 'PPL');
      final day = await programs.addDay(program.uuid, name: 'Push');
      final session = await sessions.start(
        day: day,
        programUuid: program.uuid,
        title: day.name,
      );
      await sessions.pause(session.uuid);
      final pausedAt = (await sessions.once(session.uuid))!.pausedAt!;
      await sessions.finish(session.uuid);
      final done = (await sessions.once(session.uuid))!;
      expect(done.running, isFalse);
      expect(done.paused, isFalse);
      expect(done.endedAt, pausedAt);
    });
  });

  group('the next day', () {
    late HarvestDatabase db;
    late ProgramsRepository programs;
    late SessionsRepository sessions;

    setUp(() {
      db = HarvestDatabase.forTesting(NativeDatabase.memory());
      programs = ProgramsRepository(db);
      sessions = SessionsRepository(db);
    });

    tearDown(() async => db.close());

    Future<void> finishDay(String programUuid, String dayUuid) async {
      final program = (await programs.once(programUuid))!;
      final day = program.days.firstWhere((d) => d.uuid == dayUuid);
      final session = await sessions.start(
        day: day,
        programUuid: programUuid,
        title: day.name,
      );
      await sessions.finish(session.uuid);
    }

    test('starts at the top, goes round, and wraps', () async {
      final program = await programs.createProgram(name: 'nSuns');
      final d1 = await programs.addDay(program.uuid, name: 'Day 1');
      final d2 = await programs.addDay(program.uuid, name: 'Day 2');
      final d3 = await programs.addDay(program.uuid, name: 'Day 3');

      Future<String?> next() async =>
          (await sessions.nextDay((await programs.once(program.uuid))!))?.name;

      expect(await next(), 'Day 1');
      await finishDay(program.uuid, d1.uuid);
      expect(await next(), 'Day 2');
      await finishDay(program.uuid, d2.uuid);
      expect(await next(), 'Day 3');
      await finishDay(program.uuid, d3.uuid);
      expect(await next(), 'Day 1', reason: 'the loop closes');
    });

    test('a day picked out of turn moves the pointer from there', () async {
      final program = await programs.createProgram(name: 'nSuns');
      await programs.addDay(program.uuid, name: 'Day 1');
      await programs.addDay(program.uuid, name: 'Day 2');
      final d3 = await programs.addDay(program.uuid, name: 'Day 3');
      await finishDay(program.uuid, d3.uuid);
      final next = await sessions.nextDay((await programs.once(program.uuid))!);
      expect(next?.name, 'Day 1');
    });

    test('a discarded session does not count as done', () async {
      final program = await programs.createProgram(name: 'nSuns');
      final d1 = await programs.addDay(program.uuid, name: 'Day 1');
      await programs.addDay(program.uuid, name: 'Day 2');
      final session = await sessions.start(
        day: d1,
        programUuid: program.uuid,
        title: d1.name,
      );
      await sessions.discard(session.uuid);
      final next = await sessions.nextDay((await programs.once(program.uuid))!);
      expect(next?.name, 'Day 1');
    });

    test('a program with no days has no next day', () async {
      final program = await programs.createProgram(name: 'Empty');
      expect(await sessions.nextDay(program), isNull);
    });
  });

  group('every gym write lands in the outbox (Audit 2, Q2-03)', () {
    late HarvestDatabase db;
    late ProgramsRepository programs;
    late SessionsRepository sessions;

    setUp(() {
      db = HarvestDatabase.forTesting(NativeDatabase.memory());
      programs = ProgramsRepository(db);
      sessions = SessionsRepository(db);
    });

    tearDown(() async => db.close());

    Future<Set<String>> tables() async => {
      for (final row in await db.select(db.outbox).get()) row.targetTable,
    };

    test("a program's days, slots, sets and maxes", () async {
      final program = await programs.createProgram(name: 'PPL');
      final day = await programs.addDay(program.uuid, name: 'Push');
      final slot = await programs.addSlot(day.uuid, exerciseId: '0025');
      await programs.addTargetSet(slot.uuid, reps: 5, weightGrams: 80000);
      await programs.setTrainingMax(
        programUuid: program.uuid,
        exerciseId: '0025',
        grams: 100000,
      );
      expect(
        await tables(),
        containsAll([
          'programs',
          'program_days',
          'program_slots',
          'target_sets',
          'training_maxes',
        ]),
      );
    });

    test("a session's exercises and sets, and what happens to them", () async {
      final program = await programs.createProgram(name: 'PPL');
      final day = await programs.addDay(program.uuid, name: 'Push');
      final slot = await programs.addSlot(day.uuid, exerciseId: '0025');
      await programs.addTargetSet(slot.uuid, reps: 5, weightGrams: 80000);
      final session = await sessions.start(
        day: (await programs.once(program.uuid))!.days.single,
        programUuid: program.uuid,
        title: 'Push',
      );
      final exercise = session.exercises.single;
      await sessions.skipExercise(exercise.uuid, skipped: true);
      await sessions.addSet(exercise.uuid);
      await sessions.logSet(
        exercise.sets.first.uuid,
        weightGrams: 80000,
        reps: 5,
      );
      final rows = await db.select(db.outbox).get();
      expect(
        rows.where((r) => r.targetTable == 'session_exercises').length,
        greaterThanOrEqualTo(2),
        reason: 'the insert and the skip',
      );
      expect(
        rows.where((r) => r.targetTable == 'workout_sets').length,
        greaterThanOrEqualTo(3),
        reason: 'the copied target, the added set, the tick',
      );
    });
  });

  group('which exercises have a bar', () {
    Exercise gear(String? equipment, {String name = 'Row'}) =>
        Exercise(id: 'x', name: name, equipment: equipment);

    test('the five bar kinds in the catalogue do', () {
      for (final kind in barEquipment) {
        expect(gear(kind).usesBar, isTrue, reason: kind);
      }
    });

    test('dumbbells, cables and body weight do not', () {
      expect(gear('dumbbell').usesBar, isFalse);
      expect(gear('cable').usesBar, isFalse);
      expect(gear('body weight').usesBar, isFalse);
      expect(gear(null).usesBar, isFalse);
    });

    test('my own exercise counts if it says barbell anywhere', () {
      expect(gear(null, name: 'Barbell hip thrust').usesBar, isTrue);
      expect(gear('Olympic Barbell').usesBar, isTrue);
      expect(gear('bands', name: 'Face pull').usesBar, isFalse);
    });
  });
}
