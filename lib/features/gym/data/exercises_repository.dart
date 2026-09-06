import 'package:drift/drift.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/db/database_provider.dart';
import 'package:harvest/features/gym/data/exercise_catalogue.dart';
import 'package:harvest/features/gym/domain/exercise.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

part 'exercises_repository.g.dart';

/// The exercises I added myself.
///
/// Unlike the catalogue, these **are** my data: they migrate, they
/// export, and they will sync ([[Business-Rules]] #14). They exist
/// because a catalogue of 1,324 will still be missing the one machine
/// in my gym with a name only my gym uses.
class ExercisesRepository {
  ExercisesRepository(this._db);

  final HarvestDatabase _db;
  static const _uuid = Uuid();

  Stream<List<Exercise>> watchMine() {
    final query = _db.select(_db.exercises)
      ..where((e) => e.deletedAt.isNull())
      ..orderBy([(e) => OrderingTerm.asc(e.name)]);
    return query.watch().map((rows) => rows.map(_toDomain).toList());
  }

  Future<Exercise> create({
    required String name,
    String? bodyPart,
    String? equipment,
    String? target,
    String? note,
  }) async {
    final exercise = Exercise(
      id: _uuid.v4(),
      name: name.trim(),
      bodyPart: bodyPart,
      equipment: equipment,
      target: target,
      mine: true,
    );
    await _db.transaction(() async {
      await _db
          .into(_db.exercises)
          .insert(
            ExercisesCompanion.insert(
              uuid: exercise.id,
              name: exercise.name,
              bodyPart: Value(bodyPart),
              equipment: Value(equipment),
              target: Value(target),
              note: Value(note),
            ),
          );
      await _outbox(exercise.id, 'insert');
    });
    return exercise;
  }

  Future<void> remove(String uuid) => _db.transaction(() async {
    await (_db.update(_db.exercises)..where((e) => e.uuid.equals(uuid))).write(
      ExercisesCompanion(
        deletedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );
    await _outbox(uuid, 'update');
  });

  Future<void> _outbox(String rowUuid, String op) => _db
      .into(_db.outbox)
      .insert(
        OutboxCompanion.insert(
          targetTable: 'exercises',
          rowUuid: rowUuid,
          op: op,
        ),
      );

  static Exercise _toDomain(ExerciseRow row) => Exercise(
    id: row.uuid,
    name: row.name,
    bodyPart: row.bodyPart,
    equipment: row.equipment,
    target: row.target,
    mine: true,
  );
}

@Riverpod(keepAlive: true)
ExercisesRepository exercisesRepository(Ref ref) =>
    ExercisesRepository(ref.watch(databaseProvider));

/// Mine and the catalogue's, as one list.
///
/// Everything downstream — a program slot, a session, a personal
/// record — refers to an exercise by id and does not care which side of
/// the line it came from.
@riverpod
Future<List<Exercise>> allExercises(Ref ref) async {
  final catalogue = await ref.watch(exerciseCatalogueProvider.future);
  final mine = await ref.watch(myExercisesProvider.future);
  return [...mine, ...catalogue.all];
}

@riverpod
Stream<List<Exercise>> myExercises(Ref ref) =>
    ref.watch(exercisesRepositoryProvider).watchMine();

/// One exercise by id, whichever side it lives on.
@riverpod
Future<Exercise?> exerciseById(Ref ref, String id) async {
  final all = await ref.watch(allExercisesProvider.future);
  for (final exercise in all) {
    if (exercise.id == id) return exercise;
  }
  return null;
}
