import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/db/database_provider.dart';
import 'package:harvest/features/gym/data/exercise_catalogue.dart';
import 'package:harvest/features/gym/data/exercise_media.dart';
import 'package:harvest/features/gym/data/programs_repository.dart';
import 'package:harvest/features/gym/domain/exercise.dart';
import 'package:harvest/features/gym/domain/program.dart';
import 'package:harvest/features/gym/presentation/exercise_image.dart';
import 'package:harvest/features/gym/presentation/exercise_picker.dart';
import 'package:harvest/features/gym/presentation/gym_screen.dart';
import 'package:harvest/features/gym/presentation/target_set_sheet.dart';
import 'package:harvest/features/settings/data/settings_repository.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// Records what is asked of the media cache instead of fetching.
class _Media extends ExerciseMedia {
  // ignore: matching_super_parameters — the cache names it `_settings`.
  _Media(super.settings);

  final asked = <String>[];

  @override
  Future<File?> get(String stem, MediaKind kind) async {
    asked.add('get $stem ${kind.name}');
    return null;
  }

  @override
  Future<File?> cached(String stem, MediaKind kind) async {
    asked.add('cached $stem ${kind.name}');
    return null;
  }
}

/// A repository whose writes fail, as a full disk would.
class _FailingPrograms extends ProgramsRepository {
  // ignore: matching_super_parameters — the repository names it `_db`.
  _FailingPrograms(super.db);

  @override
  Future<void> removeSlot(String uuid) async => throw Exception('disk full');
}

/// Gym controls that invited a tap and then did nothing (U6-17), and
/// the catalogue's copy (U6-36).
void main() {
  late HarvestDatabase db;

  setUp(() => db = HarvestDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Widget app({List<Exercise> exercises = const []}) => ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      exerciseCatalogueProvider.overrideWith(
        (ref) async => ExerciseCatalogue(exercises),
      ),
    ],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: GymScreen(),
    ),
  );

  Future<void> settle(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  }

  testWidgets('with no program, the button writes one instead of Start', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('Start'), findsNothing);
    final fab = find.descendant(
      of: find.byType(Scaffold),
      matching: find.text('New program'),
    );
    expect(fab, findsOneWidget);

    await tester.tap(fab);
    await tester.pumpAndSettle();
    FilledButton create() => tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Create'),
    );
    // Create waits for a name rather than closing on nothing.
    expect(create().onPressed, isNull);
    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    expect(create().onPressed, isNull);
    await tester.enterText(find.byType(TextField), 'Push pull legs');
    await tester.pump();
    expect(create().onPressed, isNotNull);
    await settle(tester);
  });

  testWidgets('the catalogue counts like money and browses by its name', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        exercises: [
          for (var i = 0; i < 1324; i++) Exercise(id: 'e$i', name: 'E$i'),
        ],
      ),
    );
    await tester.pumpAndSettle();
    final count = find.text('1,324 exercises');
    expect(count, findsOneWidget);
    await tester.ensureVisible(count);
    await tester.tap(count);
    await tester.pumpAndSettle();
    final picker = find.byType(ExercisePicker);
    expect(picker, findsOneWidget);
    expect(find.text('Choose an exercise'), findsNothing);
    expect(
      find.descendant(of: picker, matching: find.text('Exercises')),
      findsWidgets,
    );
    await settle(tester);
  });

  testWidgets('opening an animation keeps its thumbnail for the list', (
    tester,
  ) async {
    final media = _Media(SettingsRepository(db));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [exerciseMediaProvider.overrideWithValue(media)],
        child: const MaterialApp(
          home: ExerciseImage(
            exercise: Exercise(id: 'squat', name: 'Squat', mediaId: 'm1'),
            kind: MediaKind.animation,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(media.asked, contains('get squat-m1 thumbnail'));
    expect(media.asked, contains('get squat-m1 animation'));
    await settle(tester);
  });

  testWidgets('a removal that fails says so instead of vanishing (Q6-12)', (
    tester,
  ) async {
    const slot = ProgramSlot(
      uuid: 's1',
      dayUuid: 'd1',
      exerciseId: 'squat',
      position: 0,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          programsRepositoryProvider.overrideWithValue(_FailingPrograms(db)),
          programsProvider.overrideWith(
            (ref) => Stream.value(const [
              Program(
                uuid: 'p1',
                name: 'Strength',
                days: [
                  ProgramDay(
                    uuid: 'd1',
                    programUuid: 'p1',
                    name: 'Day 1',
                    position: 0,
                    slots: [slot],
                  ),
                ],
              ),
            ]),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showTargetSets(context, slot: slot),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final remove = find.text('Remove this exercise');
    await tester.ensureVisible(remove);
    await tester.tap(remove);
    await tester.pumpAndSettle();
    expect(find.text('That did not save. Try again.'), findsOneWidget);
    await settle(tester);
  });
}
