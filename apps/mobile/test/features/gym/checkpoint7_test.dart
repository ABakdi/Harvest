import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/features/commitments/data/commitments_repository.dart';
import 'package:harvest/features/commitments/domain/check_in_service.dart';
import 'package:harvest/features/commitments/domain/commitment.dart';
import 'package:harvest/features/commitments/domain/schedule.dart';
import 'package:harvest/features/gamification/domain/streak_service.dart';
import 'package:harvest/features/gym/data/programs_repository.dart';
import 'package:harvest/features/gym/data/sessions_repository.dart';
import 'package:harvest/features/gym/domain/program.dart';
import 'package:harvest/features/gym/domain/session_finisher.dart';

/// Checkpoint 7: a gym seed is checked in by a session and nothing
/// else, the field can find the program behind a habit, and a dragged
/// exercise lands where it was dropped.
void main() {
  group('the bare session', () {
    late HarvestDatabase db;
    late ProgramsRepository programs;
    late SessionsRepository sessions;
    late CommitmentsRepository commitments;
    late SessionFinisher finisher;

    setUp(() {
      db = HarvestDatabase.forTesting(NativeDatabase.memory());
      programs = ProgramsRepository(db);
      sessions = SessionsRepository(db);
      commitments = CommitmentsRepository(db);
      finisher = SessionFinisher(
        sessions,
        programs,
        commitments,
        CheckInService(db, StreakService(db)),
      );
    });

    tearDown(() async => db.close());

    Future<({Program program, Commitment seed})> planted() async {
      final program = await programs.createProgram(name: 'nSuns');
      final seed = await commitments.create(
        type: CommitmentType.habit,
        title: 'nSuns',
        schedule: const TimesPerWeekSchedule(times: 4),
      );
      await programs.updateProgram(program.uuid, commitmentUuid: seed.uuid);
      return (program: (await programs.once(program.uuid))!, seed: seed);
    }

    test("went, no numbers, still goes through the program's door", () async {
      final made = await planted();
      final session = await sessions.startFreeform(
        title: 'Went, no numbers',
        programUuid: made.program.uuid,
      );
      expect(session.programUuid, made.program.uuid);
      expect(session.exercises, isEmpty);

      final outcome = await finisher.finish(session);
      expect(outcome.xpEarned, greaterThan(0), reason: 'the habit checked in');

      final finished = await sessions.finishedOnce();
      expect(finished.map((s) => s.uuid), [session.uuid]);
      expect(finished.single.totalSets, 0, reason: 'history says it was bare');
    });

    test('a second bare session the same day pays nothing more', () async {
      final made = await planted();
      final first = await sessions.startFreeform(
        programUuid: made.program.uuid,
      );
      await finisher.finish(first);
      final second = await sessions.startFreeform(
        programUuid: made.program.uuid,
      );
      final outcome = await finisher.finish(second);
      expect(outcome.xpEarned, 0);
    });

    test('the field finds the program behind the habit', () async {
      final made = await planted();
      final other = await commitments.create(
        type: CommitmentType.habit,
        title: 'Read',
        schedule: const DailySchedule(),
      );
      expect(
        (await programs.watchForCommitment(made.seed.uuid).first)?.uuid,
        made.program.uuid,
      );
      expect(await programs.watchForCommitment(other.uuid).first, isNull);
    });
  });

  group('dragging an exercise', () {
    const slots = ['a', 'b', 'c', 'd'];

    test('down lands where it was dropped', () {
      expect(reorderedUuids(slots, 0, 2), ['b', 'c', 'a', 'd']);
    });

    test('up lands where it was dropped', () {
      expect(reorderedUuids(slots, 3, 1), ['a', 'd', 'b', 'c']);
    });

    test('to the same place changes nothing', () {
      expect(reorderedUuids(slots, 1, 1), slots);
    });

    test('does not touch the list it was given', () {
      final original = [...slots];
      reorderedUuids(original, 0, 3);
      expect(original, slots);
    });
  });
}
