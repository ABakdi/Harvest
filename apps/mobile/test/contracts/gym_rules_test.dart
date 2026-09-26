import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/gym/data/programs_repository.dart';
import 'package:harvest/features/gym/data/sessions_repository.dart';
import 'package:harvest/features/gym/domain/exercise.dart';
import 'package:harvest/features/gym/domain/plates.dart';
import 'package:harvest/features/gym/domain/program.dart';
import 'package:harvest/features/gym/domain/session.dart';
import 'package:harvest/features/gym/presentation/weight_text.dart';
import 'package:harvest/features/health/domain/body_weight.dart';

/// The gym's arithmetic, read from the fixture the web's
/// `packages/core/test/gym.test.ts` reads: a label the phone stores and
/// a day the phone says is next must be the same on both, because a
/// session started in one place is finished in the other.
void main() {
  final spec =
      jsonDecode(
            File('../../packages/core/fixtures/gym.json').readAsStringSync(),
          )
          as Map<String, Object?>;

  List<Map<String, Object?>> list(String key) => [
    for (final item in spec[key]! as List<Object?>) item! as Map<String, Object?>,
  ];

  WorkoutSet setOf(Map<String, Object?> json, [int index = 0]) => WorkoutSet(
    uuid: 's$index',
    sessionExerciseUuid: 'e',
    position: index,
    weightGrams: json['weightGrams']! as int,
    reps: json['reps']! as int,
    done: json['done']! as bool,
  );

  WeightUnit unitOf(Map<String, Object?> entry) =>
      WeightUnit.fromName(entry['unit'] as String?);

  test('loads round to a quarter of the unit they are read in', () {
    for (final entry in list('roundLoad')) {
      expect(
        roundLoad(entry['grams']! as int, unit: unitOf(entry)),
        entry['rounded'],
        reason: entry['why'] as String?,
      );
    }
  });

  test('a stored label reads back alike in either unit', () {
    for (final entry in list('labelsRead')) {
      expect(
        storedLabelGrams(entry['label']! as String, unitOf(entry)),
        entry['grams'],
        reason: entry['why'] as String?,
      );
    }
  });

  test('percentages and field values are written alike', () {
    for (final entry in list('percents')) {
      expect(formatPercent(entry['tenths']! as int), entry['text']);
    }
    for (final entry in list('fieldValues')) {
      final unit = WeightUnit.fromName(entry['unit']! as String);
      expect(loadFieldValue(entry['grams']! as int, unit), entry['text']);
    }
  });

  test('Epley estimates alike', () {
    for (final entry in list('estimates')) {
      expect(
        estimatedOneRepMax(
          weightGrams: entry['weightGrams']! as int,
          reps: entry['reps']! as int,
        ),
        entry['estimate'],
        reason: entry['why'] as String?,
      );
    }
  });

  test('records come out of the log alike', () {
    for (final entry in list('records')) {
      final raw = entry['sets']! as List<Object?>;
      final sets = [
        for (final (i, item) in raw.indexed)
          setOf(item! as Map<String, Object?>, i),
      ];
      final records = recordsFrom(
        sets,
        sessionVolumes: [
          for (final v in entry['sessionVolumes']! as List<Object?>) v! as int,
        ],
      );
      final why = entry['why'] as String?;
      expect(records.heaviest?.position, entry['heaviest'], reason: why);
      expect(records.bestSet?.position, entry['bestSet'], reason: why);
      expect(records.bestSetEstimate, entry['bestSetEstimate'], reason: why);
      expect(
        records.bestSessionVolumeGrams,
        entry['bestSessionVolumeGrams'],
        reason: why,
      );
    }
  });

  test('a set beats the same records', () {
    for (final entry in list('beaten')) {
      final given = entry['records']! as Map<String, Object?>;
      final heaviest = given['heaviestGrams'] as int?;
      final records = (
        heaviest: heaviest == null
            ? null
            : WorkoutSet(
                uuid: 'h',
                sessionExerciseUuid: 'e',
                position: 0,
                weightGrams: heaviest,
                reps: 1,
                done: true,
              ),
        bestSet: null,
        bestSetEstimate: given['bestSetEstimate'] as int?,
        bestSessionVolumeGrams: 0,
      );
      final beaten = recordsBeatenBy(
        setOf(entry['set']! as Map<String, Object?>),
        records,
      );
      expect(
        [for (final kind in beaten) kind.name],
        entry['kinds'],
        reason: entry['why'] as String?,
      );
    }
  });

  test('the plates go on alike', () {
    for (final entry in list('plates')) {
      final plan = platesFor(
        entry['targetGrams']! as int,
        barGrams: entry['barGrams']! as int,
        unit: unitOf(entry),
      );
      final why = entry['why'] as String?;
      expect(
        [
          for (final stack in plan.stacks)
            {'grams': stack.grams, 'perSide': stack.perSide},
        ],
        entry['stacks'],
        reason: why,
      );
      expect(plan.totalGrams, entry['totalGrams'], reason: why);
      expect(plan.shortfallGrams, entry['shortfallGrams'], reason: why);
      expect(plan.overGrams, entry['overGrams'], reason: why);
    }
  });

  test('a pound gym is the same gym on both', () {
    final gym = spec['poundGym']! as Map<String, Object?>;
    expect(defaultBarGramsLb, gym['bar']);
    expect(barChoicesIn(WeightUnit.lb), gym['bars']);
    expect(platesIn(WeightUnit.lb), gym['plates']);
    for (final entry in list('barsIn')) {
      expect(
        barIn(entry['barGrams']! as int, unitOf(entry)),
        entry['bar'],
        reason: entry['why'] as String?,
      );
    }
  });

  test('a bar is a bar on both', () {
    for (final entry in list('bars')) {
      final exercise = Exercise(
        id: 'x',
        name: entry['name']! as String,
        equipment: entry['equipment'] as String?,
      );
      expect(exercise.usesBar, entry['usesBar'], reason: exercise.name);
    }
  });

  test('a search finds the same exercises in the same order', () {
    final catalogue = [
      for (final entry in list('catalogue'))
        Exercise(
          id: entry['id']! as String,
          name: entry['name']! as String,
          bodyPart: entry['bodyPart'] as String?,
          equipment: entry['equipment'] as String?,
          target: entry['target'] as String?,
          secondary: [
            for (final muscle in entry['secondary']! as List<Object?>)
              muscle! as String,
          ],
          mine: entry['mine']! as bool,
        ),
    ];
    for (final entry in list('searches')) {
      final found = filterExercises(catalogue, (
        search: entry['search']! as String,
        bodyPart: entry['bodyPart'] as String?,
        equipment: entry['equipment'] as String?,
      ));
      expect(
        [for (final exercise in found) exercise.id],
        entry['ids'],
        reason: entry['why'] as String?,
      );
    }
  });

  test('the clock stands at the same second', () {
    for (final entry in list('clocks')) {
      DateTime? at(String key) => entry[key] == null
          ? null
          : DateTime.parse(entry[key]! as String);
      final session = WorkoutSession(
        uuid: 's',
        day: HarvestDay.parse('2026-09-19'),
        startedAt: at('startedAt')!,
        endedAt: at('endedAt'),
        pausedAt: at('pausedAt'),
        pausedSeconds: entry['pausedSeconds']! as int,
      );
      expect(
        session.elapsedAt(at('now')!).inSeconds,
        entry['seconds'],
        reason: entry['why'] as String?,
      );
    }
  });

  test('a drag reorders alike', () {
    for (final entry in list('reorders')) {
      expect(
        reorderedUuids(
          [for (final id in entry['uuids']! as List<Object?>) id! as String],
          entry['from']! as int,
          entry['to']! as int,
        ),
        entry['result'],
      );
    }
  });

  test('a new row goes after the highest position', () {
    for (final entry in list('nextPositions')) {
      expect(
        nextPosition([
          for (final position in entry['positions']! as List<Object?>)
            position! as int,
        ]),
        entry['next'],
        reason: entry['why'] as String?,
      );
    }
  });

  group('through the repositories', () {
    late HarvestDatabase db;
    late ProgramsRepository programs;
    late SessionsRepository sessions;

    setUp(() {
      db = HarvestDatabase.forTesting(NativeDatabase.memory());
      programs = ProgramsRepository(db);
      sessions = SessionsRepository(db);
    });

    tearDown(() async => db.close());

    test('a started set is prefilled and labelled as the web writes it', () async {
      for (final entry in list('targets')) {
        final target = entry['target']! as Map<String, Object?>;
        final program = await programs.createProgram(name: 'P');
        final day = await programs.addDay(program.uuid, name: 'Day 1');
        final slot = await programs.addSlot(day.uuid, exerciseId: '0025');
        await programs.addTargetSet(
          slot.uuid,
          reps: target['reps'] as int?,
          weightGrams: target['weightGrams'] as int?,
          percentTenths: target['percentTenths'] as int?,
          openEnded: target['openEnded']! as bool,
        );
        final max = entry['trainingMaxGrams'] as int?;
        if (max != null) {
          await programs.setTrainingMax(
            programUuid: program.uuid,
            exerciseId: '0025',
            grams: max,
          );
        }
        final fresh = (await programs.once(program.uuid))!;
        final session = await sessions.start(
          day: fresh.days.single,
          programUuid: program.uuid,
          title: 'Day 1',
          trainingMaxes: await programs.trainingMaxesOnce(program.uuid),
          unit: unitOf(entry),
        );
        final set = session.exercises.single.sets.single;
        final why = entry['why'] as String?;
        expect(set.weightGrams, (entry['grams'] as int?) ?? 0, reason: why);
        expect(set.targetLabel, entry['label'], reason: why);
        await sessions.discard(session.uuid);
      }
    });

    test('the same day is up next', () async {
      for (final entry in list('nextDays')) {
        final program = await programs.createProgram(name: 'P');
        final ids = <String, String>{};
        for (final name in entry['days']! as List<Object?>) {
          final day = await programs.addDay(program.uuid, name: name! as String);
          ids[day.name] = day.uuid;
        }
        final last = entry['last'] as String?;
        if (last != null) {
          final session = await sessions.startFreeform(
            programUuid: program.uuid,
            dayUuid: ids[last] ?? 'gone',
          );
          await sessions.finish(session.uuid);
        }
        final next = await sessions.nextDay(
          (await programs.once(program.uuid))!,
        );
        expect(next?.name, entry['next'], reason: entry['why'] as String?);
      }
    });
  });
}
