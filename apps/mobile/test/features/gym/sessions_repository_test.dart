import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/features/gym/data/programs_repository.dart';
import 'package:harvest/features/gym/data/sessions_repository.dart';
import 'package:harvest/features/gym/domain/program.dart';
import 'package:harvest/features/gym/domain/session.dart';

/// Phase 4, M4.5. The session is the one place in this app where the
/// user is holding something heavy, so the tests are about the two
/// things that would actually cost me a workout: a set that was not
/// written, and a session that could not be picked back up.
void main() {
  late HarvestDatabase db;
  late ProgramsRepository programs;
  late SessionsRepository sessions;

  setUp(() {
    db = HarvestDatabase.forTesting(NativeDatabase.memory());
    programs = ProgramsRepository(db);
    sessions = SessionsRepository(db);
  });

  tearDown(() async => db.close());

  /// A day of one exercise: 100 kg × 5, then 100 kg × 3.
  Future<({Program program, ProgramDay day})> aDay({
    String exerciseId = '0025',
    List<int> reps = const [5, 3],
  }) async {
    final program = await programs.createProgram(name: 'nSuns');
    final day = await programs.addDay(program.uuid, name: 'Day 1');
    final slot = await programs.addSlot(
      day.uuid,
      exerciseId: exerciseId,
      restSeconds: 180,
    );
    for (final count in reps) {
      await programs.addTargetSet(
        slot.uuid,
        reps: count,
        weightGrams: 100 * gramsPerKg,
      );
    }
    final fresh = (await programs.once(program.uuid))!;
    return (program: fresh, day: fresh.days.single);
  }

  group('starting', () {
    test('copies the day in, with the weights already filled', () async {
      final made = await aDay();
      final session = await sessions.start(
        day: made.day,
        programUuid: made.program.uuid,
        title: 'Day 1',
      );

      final exercise = session.exercises.single;
      expect(exercise.exerciseId, '0025');
      expect(exercise.restSeconds, 180);
      expect(exercise.sets, hasLength(2));
      // The whole point of prefilling: a set that goes to plan is one
      // tap, because the numbers are already there.
      expect(exercise.sets.first.weightGrams, 100 * gramsPerKg);
      expect(exercise.sets.first.reps, 5);
      expect(exercise.sets.every((set) => !set.done), isTrue);
      expect(session.doneSets, 0);
      expect(session.totalSets, 2);
    });

    test('resolves percentages against the training max', () async {
      final program = await programs.createProgram(name: 'nSuns');
      final day = await programs.addDay(program.uuid, name: 'Day 1');
      final slot = await programs.addSlot(day.uuid, exerciseId: '0025');
      await programs.addTargetSet(slot.uuid, reps: 5, percentTenths: 825);
      await programs.setTrainingMax(
        programUuid: program.uuid,
        exerciseId: '0025',
        grams: 100 * gramsPerKg,
      );

      final fresh = (await programs.once(program.uuid))!;
      final session = await sessions.start(
        day: fresh.days.single,
        programUuid: program.uuid,
        title: 'Day 1',
        trainingMaxes: await programs.trainingMaxesOnce(program.uuid),
      );

      // 82.5% of 100 kg, rounded to the 0.25 kg I actually own.
      expect(session.exercises.single.sets.single.weightGrams, 82500);
    });

    test('keeps what was asked, even after the program changes', () async {
      final made = await aDay();
      final session = await sessions.start(
        day: made.day,
        programUuid: made.program.uuid,
        title: 'Day 1',
      );
      await programs.removeDay(made.day.uuid);

      final again = await sessions.once(session.uuid);
      expect(again!.exercises.single.sets, hasLength(2));
    });
  });

  group('resuming', () {
    test('the running session survives the app being killed', () async {
      final made = await aDay();
      final started = await sessions.start(
        day: made.day,
        programUuid: made.program.uuid,
        title: 'Day 1',
      );
      await sessions.logSet(
        started.exercises.single.sets.first.uuid,
        weightGrams: 100 * gramsPerKg,
        reps: 5,
      );

      // A fresh repository over the same file is what a relaunch is.
      final afterRelaunch = await SessionsRepository(db).runningOnce();
      expect(afterRelaunch, isNotNull);
      expect(afterRelaunch!.uuid, started.uuid);
      expect(afterRelaunch.doneSets, 1);
      expect(afterRelaunch.running, isTrue);
    });

    test('a finished session is not offered again', () async {
      final made = await aDay();
      final started = await sessions.start(
        day: made.day,
        programUuid: made.program.uuid,
        title: 'Day 1',
      );
      await sessions.finish(started.uuid);

      expect(await sessions.runningOnce(), isNull);
      expect(await sessions.finishedOnce(), hasLength(1));
    });

    test('a discarded session leaves nothing behind', () async {
      final made = await aDay();
      final started = await sessions.start(
        day: made.day,
        programUuid: made.program.uuid,
        title: 'Day 1',
      );
      await sessions.discard(started.uuid);

      expect(await sessions.runningOnce(), isNull);
      expect(await sessions.finishedOnce(), isEmpty);
      expect(await sessions.once(started.uuid), isNull);
    });
  });

  group('logging', () {
    test('a ticked set is written there and then', () async {
      final made = await aDay();
      final started = await sessions.start(
        day: made.day,
        programUuid: made.program.uuid,
        title: 'Day 1',
      );
      await sessions.logSet(
        started.exercises.single.sets.first.uuid,
        weightGrams: 102500,
        reps: 4,
      );

      final set = (await sessions.once(
        started.uuid,
      ))!.exercises.single.sets.first;
      expect(set.done, isTrue);
      expect(set.weightGrams, 102500);
      expect(set.reps, 4);
      expect(set.loggedAt, isNotNull);
    });

    test('unticking gives the set back without losing the numbers', () async {
      final made = await aDay();
      final started = await sessions.start(
        day: made.day,
        programUuid: made.program.uuid,
        title: 'Day 1',
      );
      final uuid = started.exercises.single.sets.first.uuid;
      await sessions.logSet(uuid, weightGrams: 102500, reps: 4);
      await sessions.logSet(uuid, weightGrams: 102500, reps: 4, done: false);

      final set = (await sessions.once(
        started.uuid,
      ))!.exercises.single.sets.first;
      expect(set.done, isFalse);
      expect(set.weightGrams, 102500);
    });

    test('a swap keeps what was planned, so I can see the swap', () async {
      final made = await aDay();
      final started = await sessions.start(
        day: made.day,
        programUuid: made.program.uuid,
        title: 'Day 1',
      );
      await sessions.replaceExercise(
        started.exercises.single.uuid,
        exerciseId: '0033',
      );

      final exercise = (await sessions.once(started.uuid))!.exercises.single;
      expect(exercise.exerciseId, '0033');
      expect(exercise.plannedExerciseId, '0025');
      expect(exercise.replaced, isTrue);
    });

    test('a skipped exercise keeps its sets, undone', () async {
      final made = await aDay();
      final started = await sessions.start(
        day: made.day,
        programUuid: made.program.uuid,
        title: 'Day 1',
      );
      await sessions.skipExercise(
        started.exercises.single.uuid,
        skipped: true,
      );

      final exercise = (await sessions.once(started.uuid))!.exercises.single;
      expect(exercise.skipped, isTrue);
      expect(exercise.sets, hasLength(2));
    });
  });

  group('records', () {
    test('are nothing until a set is actually logged', () async {
      final made = await aDay();
      await sessions.start(
        day: made.day,
        programUuid: made.program.uuid,
        title: 'Day 1',
      );
      expect(await sessions.records('0025'), noRecords);
    });

    test('an unticked set counts for nothing', () async {
      final made = await aDay();
      final started = await sessions.start(
        day: made.day,
        programUuid: made.program.uuid,
        title: 'Day 1',
      );
      final uuid = started.exercises.single.sets.first.uuid;
      await sessions.logSet(uuid, weightGrams: 140 * gramsPerKg, reps: 1);
      expect((await sessions.records('0025')).heaviest?.weightGrams, 140000);

      await sessions.logSet(
        uuid,
        weightGrams: 140 * gramsPerKg,
        reps: 1,
        done: false,
      );
      // Taking the tick back takes the record back: the record is a
      // reading of what is logged, never a number kept on the side.
      expect(await sessions.records('0025'), noRecords);
    });

    test('heaviest and best estimate can be different sets', () async {
      final made = await aDay();
      final started = await sessions.start(
        day: made.day,
        programUuid: made.program.uuid,
        title: 'Day 1',
      );
      final sets = started.exercises.single.sets;
      // 140 × 1 is heavier; 120 × 5 estimates higher (140 vs 140... )
      await sessions.logSet(
        sets[0].uuid,
        weightGrams: 140 * gramsPerKg,
        reps: 1,
      );
      await sessions.logSet(
        sets[1].uuid,
        weightGrams: 130 * gramsPerKg,
        reps: 5,
      );

      final records = await sessions.records('0025');
      expect(records.heaviest?.weightGrams, 140 * gramsPerKg);
      expect(records.bestSet?.reps, 5);
    });

    test('are per exercise, not per session', () async {
      final first = await aDay();
      final a = await sessions.start(
        day: first.day,
        programUuid: first.program.uuid,
        title: 'Day 1',
      );
      await sessions.logSet(
        a.exercises.single.sets.first.uuid,
        weightGrams: 140 * gramsPerKg,
        reps: 1,
      );
      await sessions.finish(a.uuid);

      expect((await sessions.records('0025')).heaviest, isNotNull);
      expect(await sessions.records('0033'), noRecords);
    });
  });

  group('last time', () {
    test('is the most recent session that logged the exercise', () async {
      final made = await aDay();
      final first = await sessions.start(
        day: made.day,
        programUuid: made.program.uuid,
        title: 'Day 1',
      );
      await sessions.logSet(
        first.exercises.single.sets.first.uuid,
        weightGrams: 100 * gramsPerKg,
        reps: 5,
      );
      await sessions.finish(first.uuid);

      final second = await sessions.start(
        day: made.day,
        programUuid: made.program.uuid,
        title: 'Day 1',
      );
      await sessions.logSet(
        second.exercises.single.sets.first.uuid,
        weightGrams: 105 * gramsPerKg,
        reps: 5,
      );
      await sessions.finish(second.uuid);

      final last = await sessions.lastTime('0025');
      expect(last.single.weightGrams, 105 * gramsPerKg);
    });

    test('is empty for an exercise I have never done', () async {
      expect(await sessions.lastTime('9999'), isEmpty);
    });
  });
}
