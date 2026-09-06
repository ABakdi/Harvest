import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/features/gym/data/exercise_catalogue.dart';
import 'package:harvest/features/gym/data/exercise_media.dart';
import 'package:harvest/features/gym/domain/exercise.dart';
import 'package:harvest/features/settings/data/settings_repository.dart';

/// Phase 4, M4.3. The catalogue is borrowed data trimmed by a script,
/// so the two things worth testing are that the asset the script
/// produced is the shape the app expects, and that searching it finds
/// what a person mid-session would be looking for.
void main() {
  late HarvestDatabase db;

  group('the bundled asset', () {
    late List<Exercise> all;

    setUpAll(() async {
      // Read from disk rather than through rootBundle: this is a test
      // of what the trim script wrote.
      final raw = File(ExerciseCatalogue.asset).readAsStringSync();
      all = [
        for (final entry in jsonDecode(raw) as List<dynamic>)
          Exercise.fromJson(entry as Map<String, dynamic>),
      ];
    });

    test('holds the whole catalogue', () {
      expect(all, hasLength(1324));
    });

    test('every exercise has an id, a name and a picture to fetch', () {
      for (final exercise in all) {
        expect(exercise.id, matches(RegExp(r'^\d{4}$')), reason: exercise.name);
        expect(exercise.name, isNotEmpty);
        expect(exercise.mediaStem, isNotNull, reason: exercise.name);
      }
    });

    test('ids are unique, because a set refers to one by id', () {
      expect(all.map((e) => e.id).toSet(), hasLength(all.length));
    });

    test('carries English instructions and no other language', () {
      final withSteps = all.where((e) => e.steps.isNotEmpty);
      expect(withSteps.length / all.length, greaterThan(0.9));

      // The trim exists to drop nine languages we never show; if the
      // asset grew back past a couple of megabytes, it did not work.
      final bytes = File(ExerciseCatalogue.asset).lengthSync();
      expect(bytes, lessThan(2 * 1024 * 1024));
    });

    test('is sorted by id, so a diff of it is readable', () {
      final ids = all.map((e) => e.id).toList();
      expect(ids, orderedEquals([...ids]..sort()));
    });

    test('nothing in it is mine', () {
      expect(all.every((e) => !e.mine), isTrue);
    });
  });

  group('searching', () {
    final catalogue = [
      const Exercise(
        id: '0001',
        name: 'Barbell Bench Press',
        bodyPart: 'chest',
        equipment: 'barbell',
        target: 'pectorals',
        secondary: ['triceps', 'deltoids'],
      ),
      const Exercise(
        id: '0002',
        name: 'Cable Row',
        bodyPart: 'back',
        equipment: 'cable',
        target: 'upper back',
      ),
      const Exercise(
        id: '0003',
        name: 'Cable Triceps Pushdown',
        bodyPart: 'upper arms',
        equipment: 'cable',
        target: 'triceps',
      ),
      const Exercise(
        id: 'mine-1',
        name: 'The odd machine in my gym',
        bodyPart: 'back',
        mine: true,
      ),
    ];

    List<Exercise> find(String search, {String? bodyPart, String? equipment}) =>
        filterExercises(catalogue, (
          search: search,
          bodyPart: bodyPart,
          equipment: equipment,
        ));

    test('finds by name', () {
      expect(find('bench').single.id, '0001');
    });

    test('finds by muscle, which is the mid-session question', () {
      // "What else hits triceps that is not this bench?"
      expect(
        find('triceps').map((e) => e.id),
        containsAll(['0001', '0003']),
      );
    });

    test('every word has to match, so two words narrow rather than widen', () {
      expect(find('cable row').single.id, '0002');
      expect(find('cable').length, 2);
    });

    test('filters by body part and equipment', () {
      expect(find('', bodyPart: 'back').map((e) => e.id), ['mine-1', '0002']);
      expect(find('', equipment: 'cable').length, 2);
    });

    test('puts mine first — I added them because one was missing', () {
      expect(find('').first.id, 'mine-1');
    });

    test('a name that starts with the search beats one that contains it', () {
      final results = find('cable');
      expect(results.first.name, 'Cable Row');
    });

    test('an empty search returns everything', () {
      expect(find(''), hasLength(catalogue.length));
    });
  });

  group('media urls', () {
    late ExerciseMedia media;

    setUp(() {
      db = HarvestDatabase.forTesting(NativeDatabase.memory());
      media = ExerciseMedia(SettingsRepository(db));
    });

    tearDown(() async => db.close());

    test('point at the pinned commit, not at a moving branch', () {
      final url = media.urlFor('0001-2gPfomN', MediaKind.animation);
      expect(url.toString(), contains(datasetCommit));
      expect(url.toString(), endsWith('/videos/0001-2gPfomN.gif'));
      expect(url.toString(), isNot(contains('/main/')));
    });

    test('a thumbnail and an animation share a stem', () {
      expect(
        media.urlFor('0001-2gPfomN', MediaKind.thumbnail).toString(),
        endsWith('/images/0001-2gPfomN.jpg'),
      );
    });
  });
}
