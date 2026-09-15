import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/features/gym/data/programs_repository.dart';
import 'package:harvest/features/gym/domain/program.dart';

/// Phase 4, M4.4. A program lives in four tables and is read as one
/// object, which is where the interesting failure is: a stream that
/// watches only the top table looks fine until you add an exercise to
/// a day and the screen does not change.
///
/// That happened. These are the tests that would have caught it.
void main() {
  late HarvestDatabase db;
  late ProgramsRepository repository;

  setUp(() {
    db = HarvestDatabase.forTesting(NativeDatabase.memory());
    repository = ProgramsRepository(db);
  });

  tearDown(() async => db.close());

  group('the program stream', () {
    test('emits once immediately, before anything changes', () async {
      await repository.createProgram(name: 'nSuns');
      expect(await repository.watchAll().first, hasLength(1));
    });

    test('fires when a day is added', () async {
      final program = await repository.createProgram(name: 'nSuns');
      final arrived = expectLater(
        repository.watchAll(),
        emitsThrough(
          predicate<List<Program>>((all) => all.single.days.length == 1),
        ),
      );
      await repository.addDay(program.uuid, name: 'Day 1');
      await arrived;
    });

    test('fires when an exercise is added to a day', () async {
      final program = await repository.createProgram(name: 'nSuns');
      final day = await repository.addDay(program.uuid, name: 'Day 1');
      final arrived = expectLater(
        repository.watchOne(program.uuid),
        emitsThrough(
          predicate<Program?>((p) => p!.days.single.slots.length == 1),
        ),
      );
      await repository.addSlot(day.uuid, exerciseId: '0001');
      await arrived;
    });

    test('fires when a set is added to an exercise', () async {
      final program = await repository.createProgram(name: 'nSuns');
      final day = await repository.addDay(program.uuid, name: 'Day 1');
      final slot = await repository.addSlot(day.uuid, exerciseId: '0001');
      final arrived = expectLater(
        repository.watchOne(program.uuid),
        emitsThrough(predicate<Program?>((p) => p!.days.single.totalSets == 1)),
      );
      await repository.addTargetSet(slot.uuid, reps: 5, percentTenths: 750);
      await arrived;
    });
  });

  group('reading a program whole', () {
    test('brings back days, slots and sets in order', () async {
      final program = await repository.createProgram(name: 'nSuns');
      final day = await repository.addDay(program.uuid, name: 'Day 4');
      final slot = await repository.addSlot(
        day.uuid,
        exerciseId: 'deadlift',
        restSeconds: 180,
      );
      await repository.addTargetSet(slot.uuid, reps: 5, percentTenths: 750);
      await repository.addTargetSet(slot.uuid, reps: 3, percentTenths: 850);
      await repository.addTargetSet(
        slot.uuid,
        reps: 1,
        percentTenths: 950,
        openEnded: true,
      );

      final read = (await repository.once(program.uuid))!;
      final sets = read.days.single.slots.single.sets;
      expect(read.days.single.name, 'Day 4');
      expect(read.days.single.slots.single.restSeconds, 180);
      expect(sets.map((s) => s.percentTenths), [750, 850, 950]);
      expect(sets.map((s) => s.position), [0, 1, 2]);
      expect(sets.last.openEnded, isTrue);
    });

    test('a new slot defaults to a 20 kg bar', () async {
      final program = await repository.createProgram(name: 'p');
      final day = await repository.addDay(program.uuid, name: 'd');
      await repository.addSlot(day.uuid, exerciseId: '0001');
      final read = (await repository.once(program.uuid))!;
      expect(read.days.single.slots.single.barGrams, defaultBarGrams);
    });
  });

  group('duplicating a day', () {
    test('copies its exercises and their sets, not just its name', () async {
      final program = await repository.createProgram(name: 'nSuns');
      final day = await repository.addDay(program.uuid, name: 'Day 1');
      final slot = await repository.addSlot(day.uuid, exerciseId: 'squat');
      await repository.addTargetSet(slot.uuid, reps: 5, percentTenths: 750);

      final full = (await repository.once(program.uuid))!.days.single;
      await repository.duplicateDay(full, name: 'Day 2');

      final read = (await repository.once(program.uuid))!;
      expect(read.days.map((d) => d.name), ['Day 1', 'Day 2']);
      expect(read.days.last.slots.single.exerciseId, 'squat');
      expect(read.days.last.slots.single.sets.single.percentTenths, 750);
      // A copy, not a share: editing one must not edit the other.
      expect(
        read.days.last.slots.single.uuid,
        isNot(read.days.first.slots.single.uuid),
      );
    });
  });

  group('training maxes', () {
    test('are per program and per exercise', () async {
      final a = await repository.createProgram(name: 'A');
      final b = await repository.createProgram(name: 'B');
      await repository.setTrainingMax(
        programUuid: a.uuid,
        exerciseId: 'squat',
        grams: 140000,
      );
      await repository.setTrainingMax(
        programUuid: b.uuid,
        exerciseId: 'squat',
        grams: 100000,
      );

      expect(await repository.trainingMaxesOnce(a.uuid), {'squat': 140000});
      expect(await repository.trainingMaxesOnce(b.uuid), {'squat': 100000});
    });

    test('bumping one replaces it rather than adding a second', () async {
      final program = await repository.createProgram(name: 'A');
      await repository.setTrainingMax(
        programUuid: program.uuid,
        exerciseId: 'squat',
        grams: 140000,
      );
      await repository.setTrainingMax(
        programUuid: program.uuid,
        exerciseId: 'squat',
        grams: 142500,
      );
      expect(await repository.trainingMaxesOnce(program.uuid), {
        'squat': 142500,
      });
    });
  });

  group('deleting', () {
    test('a program hides it without touching finished sessions', () async {
      final program = await repository.createProgram(name: 'A');
      await repository.deleteProgram(program.uuid);
      expect(await repository.watchAll().first, isEmpty);
      // The row is still there, soft-deleted, so a session that points
      // at it can still name what it was.
      expect(await db.select(db.programs).get(), hasLength(1));
    });

    test('a day takes its slots and sets with it', () async {
      final program = await repository.createProgram(name: 'A');
      final day = await repository.addDay(program.uuid, name: 'd');
      final slot = await repository.addSlot(day.uuid, exerciseId: '0001');
      await repository.addTargetSet(slot.uuid, reps: 5);

      await repository.removeDay(day.uuid);

      expect(await db.select(db.programDays).get(), isEmpty);
      expect(await db.select(db.programSlots).get(), isEmpty);
      expect(await db.select(db.targetSets).get(), isEmpty);
    });
  });
}
