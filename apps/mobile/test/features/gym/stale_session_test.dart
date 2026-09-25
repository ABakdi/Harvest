import 'package:drift/native.dart';
import 'package:flutter/material.dart';
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
import 'package:harvest/features/gym/domain/exercise.dart';
import 'package:harvest/features/gym/domain/program.dart';
import 'package:harvest/features/gym/domain/session.dart';
import 'package:harvest/features/gym/domain/session_finisher.dart';
import 'package:harvest/features/gym/presentation/weight_text.dart';
import 'package:harvest/features/health/domain/body_weight.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// A session started on the 14th and opened again eleven days later:
/// its clock, the day it checks in on, and when it is taken to have
/// ended. Then the smaller gym fixes from the same round.
void main() {
  group('a session left running past its day', () {
    final day = HarvestDay.parse('2026-09-14');
    final started = DateTime(2026, 9, 14, 18);
    WorkoutSession session({List<SessionExercise> exercises = const []}) =>
        WorkoutSession(
          uuid: 'w',
          day: day,
          startedAt: started,
          exercises: exercises,
        );

    test('is stale from the next Harvest Day, not before', () {
      expect(session().staleOn(day), isFalse);
      expect(session().staleOn(day.addDays(11)), isTrue);
      final finished = WorkoutSession(
        uuid: 'w',
        day: day,
        startedAt: started,
        endedAt: started.add(const Duration(hours: 1)),
      );
      expect(finished.staleOn(day.addDays(11)), isFalse);
    });

    test('ends at its last ticked set, not now', () {
      final lastSet = started.add(const Duration(minutes: 40));
      final exercises = [
        SessionExercise(
          uuid: 'e',
          sessionUuid: 'w',
          position: 0,
          exerciseId: '0025',
          sets: [
            WorkoutSet(
              uuid: 'a',
              sessionExerciseUuid: 'e',
              position: 0,
              weightGrams: 100000,
              reps: 5,
              done: true,
              loggedAt: lastSet,
            ),
            // Unticked, touched later: not training.
            WorkoutSet(
              uuid: 'b',
              sessionExerciseUuid: 'e',
              position: 1,
              weightGrams: 100000,
              reps: 5,
              loggedAt: lastSet.add(const Duration(days: 3)),
            ),
          ],
        ),
      ];
      expect(session(exercises: exercises).lastActivity, lastSet);
      expect(session().lastActivity, started);
    });

    test('reads hours, not 15977 minutes', () {
      expect(
        formatSessionClock(const Duration(minutes: 4, seconds: 5)),
        '4:05',
      );
      expect(
        formatSessionClock(const Duration(hours: 1, minutes: 4, seconds: 5)),
        '1:04:05',
      );
      expect(
        formatSessionClock(const Duration(minutes: 15977, seconds: 10)),
        '266:17:10',
      );
    });

    test('finishes on its own day, at its last set', () async {
      final db = HarvestDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final programs = ProgramsRepository(db);
      final sessions = SessionsRepository(db);
      final commitments = CommitmentsRepository(db);
      final finisher = SessionFinisher(
        sessions,
        programs,
        commitments,
        CheckInService(db, StreakService(db)),
      );
      final program = await programs.createProgram(name: 'nSuns');
      final programDay = await programs.addDay(program.uuid, name: 'Day 1');
      final slot = await programs.addSlot(programDay.uuid, exerciseId: '0025');
      await programs.addTargetSet(slot.uuid, reps: 5, weightGrams: 100000);
      final seed = await commitments.create(
        type: CommitmentType.habit,
        title: 'Gym',
        schedule: const TimesPerWeekSchedule(times: 4),
      );
      await programs.updateProgram(program.uuid, commitmentUuid: seed.uuid);
      final fresh = (await programs.once(program.uuid))!;
      final started = await sessions.start(
        day: fresh.days.single,
        programUuid: fresh.uuid,
        title: 'Day 1',
        on: day,
      );
      final set = started.exercises.single.sets.single;
      await sessions.logSet(set.uuid, weightGrams: 100000, reps: 5);
      final running = (await sessions.runningOnce())!;

      await finisher.finish(running, endedAt: running.lastActivity);

      final checkIns = await db.select(db.checkIns).get();
      expect(checkIns.single.harvestDay, day.key);
      final ended = (await sessions.finishedOnce()).single;
      expect(ended.endedAt, running.lastActivity);
    });
  });

  group('pounds read to the quarter pound (Y8)', () {
    testWidgets('60 kg is 132.25 lb in the label and the box alike', (
      tester,
    ) async {
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (inner) {
              context = inner;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(formatLoad(context, 60000, WeightUnit.lb), '132.25 lb');
      expect(loadField(60000, WeightUnit.lb), '132.25');
      expect(loadField(60000, WeightUnit.kg), '60');
      expect(formatLoad(context, 82500, WeightUnit.kg), '82.5 kg');
    });
  });

  group('the program editor', () {
    test('a new set copies the last plain one', () {
      const sets = [
        TargetSet(uuid: 'a', position: 0, reps: 5, weightGrams: 100000),
        TargetSet(uuid: 'b', position: 1, reps: 3, weightGrams: 110000),
        TargetSet(
          uuid: 'c',
          position: 2,
          reps: 1,
          percentTenths: 950,
          openEnded: true,
        ),
      ];
      final next = nextTargetSet(sets);
      expect(next.reps, 3);
      expect(next.weightGrams, 110000);
      expect(next.percentTenths, isNull);
      expect(nextTargetSet(const []).reps, 5);
    });
  });

  group('exercise names', () {
    test('are title-cased for display, stored as they are', () {
      const catalogue = Exercise(id: '0025', name: 'barbell bench press');
      expect(catalogue.displayName, 'Barbell Bench Press');
      expect(catalogue.name, 'barbell bench press');
      expect(
        titleCase('push-up (on stability ball)'),
        'Push-Up (On Stability Ball)',
      );
      expect(
        titleCase('lying leg raise with a band'),
        'Lying Leg Raise with a Band',
      );
      const mine = Exercise(id: 'x', name: 'my odd lift', mine: true);
      expect(mine.displayName, 'my odd lift');
    });
  });
}
