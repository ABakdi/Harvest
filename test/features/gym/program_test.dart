import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/features/gym/domain/plates.dart';
import 'package:harvest/features/gym/domain/program.dart';

/// Phase 4, M4.4. Two pieces of arithmetic that decide what goes on a
/// bar, so both of them are wrong in ways I would only notice standing
/// under it.
int _plateCount(PlatePlan plan) =>
    plan.stacks.fold(0, (sum, stack) => sum + stack.perSide);

void main() {
  TargetSet percent(int tenths, {int? reps, bool open = false}) => TargetSet(
    uuid: 's',
    position: 1,
    reps: reps,
    percentTenths: tenths,
    openEnded: open,
  );

  group('rounding', () {
    test('lands on a quarter of a kilo', () {
      expect(roundLoad(83250), 83250);
      expect(roundLoad(83260), 83250);
      expect(roundLoad(83400), 83500);
      expect(roundLoad(83125), 83250, reason: 'halfway rounds up');
    });

    test('never produces a number nobody can load (rule Y8)', () {
      for (var tm = 40000; tm <= 250000; tm += 1250) {
        for (final tenths in [500, 625, 750, 825, 900, 950, 1000]) {
          final grams = percent(tenths).resolve(trainingMaxGrams: tm)!;
          expect(
            grams % roundingGrams,
            0,
            reason: '$tenths‰ of $tm came out at $grams',
          );
        }
      }
    });
  });

  group('a target set', () {
    test('with a weight resolves to that weight, training max or not', () {
      const set = TargetSet(
        uuid: 's',
        position: 1,
        reps: 5,
        weightGrams: 100000,
      );
      expect(set.resolve(), 100000);
      expect(set.resolve(trainingMaxGrams: 999999), 100000);
      expect(set.isPercentage, isFalse);
    });

    test('with a percentage needs a training max to mean anything', () {
      final set = percent(750, reps: 5);
      expect(
        set.resolve(),
        isNull,
        reason: 'a missing training max is a question, not a zero',
      );
      expect(set.resolve(trainingMaxGrams: 100000), 75000);
    });

    test('does the arithmetic 5/3/1 actually asks for', () {
      // A 111 kg training max, the awkward one: 75% is 83.25.
      expect(percent(750).resolve(trainingMaxGrams: 111000), 83250);
      expect(percent(850).resolve(trainingMaxGrams: 111000), 94250);
      expect(percent(950).resolve(trainingMaxGrams: 111000), 105500);
      // And a half-percent, which programmes really do write.
      expect(percent(825).resolve(trainingMaxGrams: 111000), 91500);
    });

    test('an open set is marked rather than inferred from its reps', () {
      final amrap = percent(950, reps: 1, open: true);
      expect(amrap.openEnded, isTrue);
      expect(percent(950, reps: 1).openEnded, isFalse);
    });
  });

  group('a slot', () {
    ProgramSlot slotWith(List<TargetSet> sets) => ProgramSlot(
      uuid: 'slot',
      dayUuid: 'day',
      exerciseId: '0001',
      position: 1,
      sets: sets,
    );

    test('knows when it is waiting on a training max', () {
      expect(slotWith([percent(750)]).needsTrainingMax, isTrue);
      expect(
        slotWith([
          const TargetSet(uuid: 'a', position: 1, weightGrams: 60000),
        ]).needsTrainingMax,
        isFalse,
      );
    });

    test('defaults to a 20 kg bar', () {
      expect(slotWith(const []).barGrams, 20000);
      expect(defaultBarGrams, 20000);
    });

    test('resolves every set against one training max', () {
      final resolved = resolveSlot(
        slotWith([percent(750), percent(850), percent(950, open: true)]),
        trainingMaxGrams: 100000,
      );
      expect(resolved.map((r) => r.grams), [75000, 85000, 95000]);
      expect(resolved.last.target.openEnded, isTrue);
    });
  });

  group('a program', () {
    test('lists the exercises it needs a training max for', () {
      final program = Program(
        uuid: 'p',
        name: 'nSuns',
        days: [
          ProgramDay(
            uuid: 'd1',
            programUuid: 'p',
            name: 'Day 1',
            position: 1,
            slots: [
              ProgramSlot(
                uuid: 's1',
                dayUuid: 'd1',
                exerciseId: 'deadlift',
                position: 1,
                sets: [percent(750)],
              ),
              const ProgramSlot(
                uuid: 's2',
                dayUuid: 'd1',
                exerciseId: 'curl',
                position: 2,
                sets: [TargetSet(uuid: 'x', position: 1, weightGrams: 20000)],
              ),
            ],
          ),
        ],
      );
      expect(program.percentageExercises, {'deadlift'});
    });
  });

  group('the plate calculator', () {
    test('makes the target exactly, with as few plates as possible', () {
      final plan = platesFor(100000);
      expect(plan.totalGrams, 100000);
      expect(plan.shortfallGrams, 0);
      // 40 kg a side is two plates. Which two is the gym's business:
      // 25+15 and 20+20 are the same number of plates and the same
      // weight, and preferring one would be a house style rather than
      // a fact.
      expect(_plateCount(plan), 2);
    });

    test('goes heaviest first, the way anybody does at a rack', () {
      final plan = platesFor(142500);
      // 61.25 a side: 25 + 25 + 10 + 1.25
      expect(plan.stacks, [
        (grams: 25000, perSide: 2),
        (grams: 10000, perSide: 1),
        (grams: 1250, perSide: 1),
      ]);
      expect(plan.totalGrams, 142500);
    });

    test('an empty bar is an empty bar', () {
      final plan = platesFor(20000);
      expect(plan.stacks, isEmpty);
      expect(plan.totalGrams, 20000);
      expect(plan.shortfallGrams, 0);
    });

    test('a target under the bar asks for nothing', () {
      final plan = platesFor(15000);
      expect(plan.stacks, isEmpty);
      expect(plan.totalGrams, 20000);
    });

    test('respects a bar that is not 20 kg', () {
      final plan = platesFor(50000, barGrams: 10000);
      expect(plan.totalGrams, 50000);
      expect(plan.stacks, [(grams: 20000, perSide: 1)]);
    });

    test('comes up short rather than loading more than asked', () {
      // Nothing under 0.25 kg exists, so 20.1 kg cannot be made.
      final plan = platesFor(20100);
      expect(plan.totalGrams, lessThanOrEqualTo(20100));
      expect(plan.shortfallGrams, greaterThan(0));
    });

    test('never overshoots, whatever the target', () {
      for (var grams = 20000; grams <= 250000; grams += 250) {
        final plan = platesFor(grams);
        expect(
          plan.totalGrams,
          lessThanOrEqualTo(grams),
          reason: 'overshot at $grams',
        );
      }
    });

    test('makes every half-kilo target exactly, given micro-plates', () {
      for (var grams = 20500; grams <= 200000; grams += 500) {
        expect(platesFor(grams).shortfallGrams, 0, reason: 'short at $grams');
      }
    });

    test('says so when a barbell cannot make a 0.25 kg target', () {
      // Weights round to 0.25 kg, which is right for dumbbells and
      // machines. A barbell is loaded in pairs, so the smallest total
      // step it can make is **0.5 kg** — 20.25 kg wants 0.125 a side
      // and no such plate exists.
      //
      // The app does not quietly round that away. The plan comes back
      // short and says by how much, and the session screen shows it.
      final plan = platesFor(20250);
      expect(plan.totalGrams, 20000);
      expect(plan.shortfallGrams, 250);
    });
  });
}
