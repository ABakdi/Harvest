import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/gym/domain/session.dart';

/// Phase 4, M4.5. The records are the reason the gym exists, so the
/// arithmetic behind them is checked here rather than trusted.
void main() {
  var counter = 0;
  WorkoutSet set(int kg, int reps, {bool done = true}) => WorkoutSet(
    uuid: 's${counter++}',
    sessionExerciseUuid: 'e',
    position: counter,
    weightGrams: kg * 1000,
    reps: reps,
    done: done,
  );

  group('estimated one-rep max', () {
    test('a single rep estimates to itself', () {
      expect(estimatedOneRepMax(weightGrams: 100000, reps: 1), 100000);
    });

    test('follows Epley', () {
      // 100 × (1 + 5/30) = 116.67
      expect(estimatedOneRepMax(weightGrams: 100000, reps: 5), 116667);
      // 60 × (1 + 10/30) = 80
      expect(estimatedOneRepMax(weightGrams: 60000, reps: 10), 80000);
    });

    test('lets a heavy triple be compared with a light ten', () {
      final triple = estimatedOneRepMax(weightGrams: 140000, reps: 3)!;
      final ten = estimatedOneRepMax(weightGrams: 100000, reps: 10)!;
      expect(triple, greaterThan(ten));
    });

    test('is null for nothing lifted', () {
      expect(estimatedOneRepMax(weightGrams: 0, reps: 5), isNull);
      expect(estimatedOneRepMax(weightGrams: 100000, reps: 0), isNull);
    });
  });

  group('records', () {
    test('are empty with nothing logged', () {
      expect(recordsFrom(const []).heaviest, isNull);
      expect(recordsFrom(const []).bestSetEstimate, isNull);
    });

    test('ignore sets that were never ticked', () {
      final records = recordsFrom([set(200, 1, done: false), set(100, 5)]);
      expect(records.heaviest!.weightGrams, 100000);
    });

    test('heaviest is the most weight, whatever the reps', () {
      final records = recordsFrom([set(100, 10), set(140, 1), set(120, 5)]);
      expect(records.heaviest!.weightGrams, 140000);
    });

    test('best set is the best estimate, which is not the heaviest', () {
      // 140 × 1 estimates to 140. 120 × 5 estimates to 140. 100 × 12
      // estimates to 140. But 125 × 5 estimates to 145.83 — the best
      // set of the day, at a weight that is not the heaviest.
      final records = recordsFrom([set(140, 1), set(125, 5)]);
      expect(records.heaviest!.weightGrams, 140000);
      expect(records.bestSet!.weightGrams, 125000);
      expect(records.bestSetEstimate, 145833);
    });

    test('best volume comes from the sessions the caller counted', () {
      final records = recordsFrom(
        [set(100, 5)],
        sessionVolumes: [4000000, 9500000, 7000000],
      );
      expect(records.bestSessionVolumeGrams, 9500000);
    });

    test('are derived, so deleting a bad set corrects them', () {
      final all = [set(100, 5), set(500, 1), set(110, 5)];
      expect(recordsFrom(all).heaviest!.weightGrams, 500000);
      // That 500 kg was a typo. Take it out and the record is the
      // real one, with nothing to reset by hand (rule Y5).
      final corrected = [...all]..removeAt(1);
      expect(recordsFrom(corrected).heaviest!.weightGrams, 110000);
    });
  });

  group('beating a record', () {
    final standing = recordsFrom([set(120, 5)]);

    test('a heavier set beats the heaviest', () {
      expect(
        recordsBeatenBy(set(125, 3), standing),
        contains(RecordKind.heaviest),
      );
    });

    test('a lighter set for more reps can still beat the estimate', () {
      // 120 × 5 estimates to 140. 110 × 8 estimates to 139.3 — close,
      // but not a record. 115 × 8 is 145.7, which is.
      expect(recordsBeatenBy(set(110, 8), standing), isEmpty);
      expect(
        recordsBeatenBy(set(115, 8), standing),
        contains(RecordKind.estimated),
      );
    });

    test('a set that only ties beats nothing', () {
      expect(recordsBeatenBy(set(120, 5), standing), isEmpty);
    });

    test('anything beats no record at all', () {
      expect(recordsBeatenBy(set(40, 5), noRecords), hasLength(2));
    });

    test('an unticked set beats nothing', () {
      expect(recordsBeatenBy(set(500, 5, done: false), standing), isEmpty);
    });
  });

  group('a session', () {
    WorkoutSession sessionWith(List<WorkoutSet> sets) => WorkoutSession(
      uuid: 'w',
      day: HarvestDay.parse('2026-09-06'),
      startedAt: DateTime(2026, 9, 6, 18),
      exercises: [
        SessionExercise(
          uuid: 'e',
          sessionUuid: 'w',
          position: 0,
          exerciseId: '0001',
          sets: sets,
        ),
      ],
    );

    test('is running until it ends', () {
      expect(sessionWith(const []).running, isTrue);
    });

    test('counts only the sets that were ticked', () {
      final session = sessionWith([set(100, 5), set(100, 5, done: false)]);
      expect(session.totalSets, 2);
      expect(session.doneSets, 1);
      expect(session.volumeGrams, 500000);
    });
  });

  group('a session exercise', () {
    test('knows it was swapped for something else', () {
      const swapped = SessionExercise(
        uuid: 'e',
        sessionUuid: 'w',
        position: 0,
        exerciseId: 'front-squat',
        plannedExerciseId: 'back-squat',
      );
      expect(swapped.replaced, isTrue);

      const asPlanned = SessionExercise(
        uuid: 'e',
        sessionUuid: 'w',
        position: 0,
        exerciseId: 'back-squat',
        plannedExerciseId: 'back-squat',
      );
      expect(asPlanned.replaced, isFalse);
    });
  });
}
