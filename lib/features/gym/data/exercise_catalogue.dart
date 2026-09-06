import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:harvest/features/gym/domain/exercise.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'exercise_catalogue.g.dart';

/// The 1,324 borrowed exercises, read once from the bundled asset.
///
/// It is an asset rather than a table on purpose: it is not my data, so
/// it has no migration, no outbox rows and no place in the archive
/// ([[ADR-008-Exercise-Catalogue]], [[Business-Rules]] #14). A logged
/// set refers to an exercise by its id, and that is the whole
/// relationship.
///
/// About 0.8 MB of JSON, parsed once and held: a mid-session search has
/// to be instant, and re-reading the file per keystroke would not be.
class ExerciseCatalogue {
  ExerciseCatalogue(this._exercises)
    : _byId = {for (final exercise in _exercises) exercise.id: exercise};

  static const asset = 'assets/exercises/exercises.json';

  final List<Exercise> _exercises;
  final Map<String, Exercise> _byId;

  static Future<ExerciseCatalogue> load() async {
    final raw = await rootBundle.loadString(asset);
    final decoded = jsonDecode(raw) as List<dynamic>;
    return ExerciseCatalogue([
      for (final entry in decoded)
        Exercise.fromJson(entry as Map<String, dynamic>),
    ]);
  }

  List<Exercise> get all => List.unmodifiable(_exercises);

  Exercise? byId(String id) => _byId[id];

  /// Every body part in the catalogue, for the filter chips.
  late final List<String> bodyParts =
      _exercises.map((e) => e.bodyPart).whereType<String>().toSet().toList()
        ..sort();

  /// Every equipment type, same reason.
  late final List<String> equipment =
      _exercises.map((e) => e.equipment).whereType<String>().toSet().toList()
        ..sort();
}

@Riverpod(keepAlive: true)
Future<ExerciseCatalogue> exerciseCatalogue(Ref ref) =>
    ExerciseCatalogue.load();
