import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/commitments/data/commitments_repository.dart';
import 'package:harvest/features/commitments/domain/check_in_service.dart';
import 'package:harvest/features/commitments/domain/commitment.dart';
import 'package:harvest/features/commitments/domain/schedule.dart';
import 'package:harvest/features/gamification/domain/streak_service.dart';
import 'package:harvest/features/gym/data/programs_repository.dart';
import 'package:harvest/features/gym/data/sessions_repository.dart';
import 'package:harvest/features/gym/domain/program.dart';
import 'package:harvest/features/gym/domain/session.dart';
import 'package:harvest/features/gym/domain/session_finisher.dart';

/// Phase 4, M4.6. The gym earns its XP through the same door as every
/// other seed, and these are the tests that it uses that door exactly
/// once per workout — not on starting, not on abandoning, and not
/// twice for one day.
void main() {
  late HarvestDatabase db;
  late ProgramsRepository programs;
  late SessionsRepository sessions;
  late CommitmentsRepository commitments;
  late CheckInService checkIns;
  late SessionFinisher finisher;

  setUp(() {
    db = HarvestDatabase.forTesting(NativeDatabase.memory());
    programs = ProgramsRepository(db);
    sessions = SessionsRepository(db);
    commitments = CommitmentsRepository(db);
    checkIns = CheckInService(db, StreakService(db));
    finisher = SessionFinisher(sessions, programs, commitments, checkIns);
  });

  tearDown(() async => db.close());

  /// A program of one day, bound to a habit — the shape M4.6 is about.
  Future<({Program program, ProgramDay day, Commitment? seed})> aProgram({
    bool planted = true,
    String? albumUuid,
    PhotoPrompt prompt = PhotoPrompt.after,
  }) async {
    final program = await programs.createProgram(name: 'nSuns');
    final day = await programs.addDay(program.uuid, name: 'Day 1');
    final slot = await programs.addSlot(day.uuid, exerciseId: '0025');
    await programs.addTargetSet(
      slot.uuid,
      reps: 5,
      weightGrams: 100 * gramsPerKg,
    );

    Commitment? seed;
    if (planted) {
      seed = await commitments.create(
        type: CommitmentType.habit,
        title: 'nSuns',
        schedule: const TimesPerWeekSchedule(times: 4),
      );
    }
    await programs.updateProgram(
      program.uuid,
      commitmentUuid: seed?.uuid,
      albumUuid: albumUuid,
      photoPrompt: prompt,
    );

    final fresh = (await programs.once(program.uuid))!;
    return (program: fresh, day: fresh.days.single, seed: seed);
  }

  Future<WorkoutSession> start(
    ({Program program, ProgramDay day, Commitment? seed}) made, {
    HarvestDay? on,
  }) => sessions.start(
    day: made.day,
    programUuid: made.program.uuid,
    title: 'Day 1',
    on: on,
  );

  Future<int> checkInsFor(String commitmentUuid) async =>
      (await db.select(db.checkIns).get())
          .where((row) => row.commitmentUuid == commitmentUuid)
          .length;

  group('finishing', () {
    test('checks the habit in, once, for ten XP', () async {
      final made = await aProgram();
      final session = await start(made);

      final outcome = await finisher.finish(session);

      expect(outcome.xpEarned, Xp.habitOrTodo);
      expect(await checkInsFor(made.seed!.uuid), 1);
    });

    test('checks nothing in for a program nobody planted', () async {
      final made = await aProgram(planted: false);
      final session = await start(made);

      final outcome = await finisher.finish(session);

      expect(outcome.xpEarned, 0);
      expect(await db.select(db.checkIns).get(), isEmpty);
    });

    test('checks nothing in for a session with no program at all', () async {
      final session = await sessions.startFreeform(title: 'Whatever');
      expect((await finisher.finish(session)).xpEarned, 0);
    });

    test('ends the session either way', () async {
      final made = await aProgram(planted: false);
      final session = await start(made);
      await finisher.finish(session);

      expect(await sessions.runningOnce(), isNull);
      expect(await sessions.finishedOnce(), hasLength(1));
    });
  });

  group('not finishing', () {
    test('starting checks nothing in', () async {
      final made = await aProgram();
      await start(made);
      expect(await checkInsFor(made.seed!.uuid), 0);
    });

    test('abandoning checks nothing in', () async {
      final made = await aProgram();
      final session = await start(made);
      await sessions.discard(session.uuid);
      expect(await checkInsFor(made.seed!.uuid), 0);
    });
  });

  group('twice in a day', () {
    test('the second session earns nothing', () async {
      final made = await aProgram();

      final first = await finisher.finish(await start(made));
      final second = await finisher.finish(await start(made));

      expect(first.xpEarned, Xp.habitOrTodo);
      // Two workouts in a day is admirable and still one check-in: a
      // habit is once a day here exactly as it is everywhere else.
      expect(second.xpEarned, 0);
      expect(await checkInsFor(made.seed!.uuid), 1);
    });

    test('a session on another day earns again', () async {
      final made = await aProgram();
      final yesterday = HarvestDay.today().previous;

      await finisher.finish(await start(made, on: yesterday));
      final today = await finisher.finish(await start(made));

      expect(today.xpEarned, Xp.habitOrTodo);
      expect(await checkInsFor(made.seed!.uuid), 2);
    });
  });

  group('the day it counts for', () {
    test("is the session's day, not the moment it was finished", () async {
      final made = await aProgram();
      // A session that began before 3 AM belongs to the night before,
      // and finishing it at 2:30 must not check in tomorrow.
      final lastNight = HarvestDay.today().previous;
      await finisher.finish(await start(made, on: lastNight));

      final rows = await db.select(db.checkIns).get();
      expect(rows.single.harvestDay, lastNight.key);
    });
  });

  group('the picture', () {
    test('is offered after, when that is the preference', () async {
      final made = await aProgram(albumUuid: 'album-1');
      expect((await finisher.finish(await start(made))).albumUuid, 'album-1');
    });

    test('is not offered after, when it is asked for before', () async {
      final made = await aProgram(
        albumUuid: 'album-1',
        prompt: PhotoPrompt.before,
      );
      expect((await finisher.finish(await start(made))).albumUuid, isNull);
    });

    test('is never offered when it is never wanted', () async {
      final made = await aProgram(
        albumUuid: 'album-1',
        prompt: PhotoPrompt.never,
      );
      expect((await finisher.finish(await start(made))).albumUuid, isNull);
    });

    test('is not offered by a program with no album', () async {
      final made = await aProgram();
      expect((await finisher.finish(await start(made))).albumUuid, isNull);
    });
  });

  group('a seed that went away', () {
    test('an archived habit is not checked in', () async {
      final made = await aProgram();
      await commitments.archive(made.seed!.uuid);

      final outcome = await finisher.finish(await start(made));

      expect(outcome.xpEarned, 0);
      expect(await checkInsFor(made.seed!.uuid), 0);
    });

    test('a deleted habit does not stop the session ending', () async {
      final made = await aProgram();
      await commitments.hardDelete(made.seed!.uuid);

      final session = await start(made);
      expect((await finisher.finish(session)).xpEarned, 0);
      expect(await sessions.finishedOnce(), hasLength(1));
    });
  });
}
