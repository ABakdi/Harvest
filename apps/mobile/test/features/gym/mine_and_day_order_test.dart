import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/features/gym/data/exercise_catalogue.dart';
import 'package:harvest/features/gym/data/exercises_repository.dart';
import 'package:harvest/features/gym/data/programs_repository.dart';
import 'package:harvest/features/gym/data/sessions_repository.dart';
import 'package:harvest/features/gym/domain/exercise.dart';
import 'package:harvest/features/gym/domain/program.dart';
import 'package:harvest/features/gym/presentation/exercise_picker.dart';
import 'package:harvest/features/gym/presentation/program_editor.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// Records what the picker creates instead of writing it.
class _RecordingExercises extends ExercisesRepository {
  // ignore: matching_super_parameters — the repository names it `_db`.
  _RecordingExercises(super.db);

  final created = <Map<String, String?>>[];

  @override
  Future<Exercise> create({
    required String name,
    String? bodyPart,
    String? equipment,
    String? target,
    String? note,
  }) async {
    created.add({
      'name': name,
      'bodyPart': bodyPart,
      'equipment': equipment,
      'target': target,
    });
    return Exercise(id: 'mine-1', name: name.trim(), mine: true);
  }
}

/// Records how the days were put in order instead of writing it.
class _RecordingPrograms extends ProgramsRepository {
  // ignore: matching_super_parameters — the repository names it `_db`.
  _RecordingPrograms(super.db);

  final orders = <List<String>>[];

  @override
  Future<void> reorderDays(List<String> uuids) async => orders.add(uuids);
}

/// Two things the web could do and the phone could not: add an exercise
/// of my own from the picker, and put a program's days in another
/// order. Both write what the web writes, so either side can be the
/// one that did it.
void main() {
  group('the repositories', () {
    late HarvestDatabase db;

    setUp(() => db = HarvestDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() async => db.close());

    test('an exercise of mine is stored as the web stores it', () async {
      final exercise = await ExercisesRepository(db).create(
        name: '  Hack squat, gym 2 ',
        bodyPart: ' upper legs ',
        equipment: '',
        target: '   ',
      );
      final row = await db.select(db.exercises).getSingle();
      expect(row.uuid, exercise.id);
      expect(row.name, 'Hack squat, gym 2');
      expect(row.bodyPart, 'upper legs');
      // A blank field is no field, on both sides.
      expect(row.equipment, isNull);
      expect(row.target, isNull);
      expect(exercise.mine, isTrue);
      final outbox = await db.select(db.outbox).get();
      expect(
        outbox.map((change) => (change.targetTable, change.op)),
        contains(('exercises', 'insert')),
      );
    });

    test('days reorder, and what is up next follows the order', () async {
      final programs = ProgramsRepository(db);
      final sessions = SessionsRepository(db);
      final program = await programs.createProgram(name: 'PPL');
      final push = await programs.addDay(program.uuid, name: 'Push');
      final pull = await programs.addDay(program.uuid, name: 'Pull');
      final legs = await programs.addDay(program.uuid, name: 'Legs');

      // Legs to the top: Legs, Push, Pull.
      await programs.reorderDays(
        reorderedUuids([push.uuid, pull.uuid, legs.uuid], 2, 0),
      );
      final reordered = (await programs.once(program.uuid))!;
      expect(
        [for (final day in reordered.days) day.name],
        [
          'Legs',
          'Push',
          'Pull',
        ],
      );
      expect([for (final day in reordered.days) day.position], [0, 1, 2]);

      // Having done Pull, the rotation wraps to the new top.
      final session = await sessions.startFreeform(
        programUuid: program.uuid,
        dayUuid: pull.uuid,
      );
      await sessions.finish(session.uuid);
      expect((await sessions.nextDay(reordered))?.name, 'Legs');
    });
  });

  group('the screens', () {
    late HarvestDatabase db;

    setUp(() => db = HarvestDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() async => db.close());

    Widget app(List<Override> overrides, Widget home) => ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    );

    testWidgets('the picker adds one of mine and picks it', (tester) async {
      final exercises = _RecordingExercises(db);
      Exercise? picked;
      await tester.pumpWidget(
        app(
          [
            exercisesRepositoryProvider.overrideWithValue(exercises),
            exerciseCatalogueProvider.overrideWith(
              (ref) async => ExerciseCatalogue(const []),
            ),
            allExercisesProvider.overrideWith((ref) async => const []),
          ],
          Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async => picked = await pickExercise(context),
                child: const Text('pick'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('pick'));
      await tester.pumpAndSettle();

      // What I was searching for is the name it starts with.
      await tester.enterText(find.byType(TextField).first, 'Belt squat');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add my own'));
      await tester.pumpAndSettle();

      final fields = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(TextField),
      );
      expect(
        tester.widget<TextField>(fields.first).controller!.text,
        'Belt squat',
      );
      await tester.enterText(fields.at(2), 'leverage machine');
      await tester.tap(find.text('Add it'));
      await tester.pumpAndSettle();

      expect(exercises.created, [
        {
          'name': 'Belt squat',
          'bodyPart': '',
          'equipment': 'leverage machine',
          'target': '',
        },
      ]);
      expect(picked?.id, 'mine-1');
      expect(find.byType(ExercisePicker), findsNothing);
    });

    testWidgets('the picker will not add a nameless one', (tester) async {
      final exercises = _RecordingExercises(db);
      await tester.pumpWidget(
        app(
          [
            exercisesRepositoryProvider.overrideWithValue(exercises),
            exerciseCatalogueProvider.overrideWith(
              (ref) async => ExerciseCatalogue(const []),
            ),
            allExercisesProvider.overrideWith((ref) async => const []),
          ],
          const ExercisePicker(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add my own'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add it'));
      await tester.pumpAndSettle();
      expect(exercises.created, isEmpty);
    });

    testWidgets('a day moves up and down from its menu', (tester) async {
      final programs = _RecordingPrograms(db);
      const program = Program(
        uuid: 'p',
        name: 'PPL',
        days: [
          ProgramDay(uuid: 'a', programUuid: 'p', name: 'Push', position: 0),
          ProgramDay(uuid: 'b', programUuid: 'p', name: 'Pull', position: 1),
          ProgramDay(uuid: 'c', programUuid: 'p', name: 'Legs', position: 2),
        ],
      );
      await tester.pumpWidget(
        app(
          [
            programsRepositoryProvider.overrideWithValue(programs),
            programProvider('p').overrideWith((ref) => Stream.value(program)),
            trainingMaxesProvider(
              'p',
            ).overrideWith((ref) => Stream.value(const <String, int>{})),
          ],
          const ProgramEditor(uuid: 'p'),
        ),
      );
      await tester.pumpAndSettle();

      Future<void> openMenuOf(String name) async {
        final card = find.ancestor(
          of: find.text(name),
          matching: find.byType(Card),
        );
        await tester.tap(
          find.descendant(
            of: card.first,
            matching: find.byType(PopupMenuButton<String>),
          ),
        );
        await tester.pumpAndSettle();
      }

      // The first day has nowhere higher to go.
      await openMenuOf('Push');
      final up = tester.widget<PopupMenuItem<String>>(
        find.widgetWithText(PopupMenuItem<String>, 'Move up'),
      );
      expect(up.enabled, isFalse);
      await tester.tap(find.text('Move down'));
      await tester.pumpAndSettle();
      expect(programs.orders.last, ['b', 'a', 'c']);

      await openMenuOf('Legs');
      final down = tester.widget<PopupMenuItem<String>>(
        find.widgetWithText(PopupMenuItem<String>, 'Move down'),
      );
      expect(down.enabled, isFalse);
      await tester.tap(find.text('Move up'));
      await tester.pumpAndSettle();
      expect(programs.orders.last, ['a', 'c', 'b']);
    });
  });
}
