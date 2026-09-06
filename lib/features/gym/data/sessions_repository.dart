import 'package:drift/drift.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/db/database_provider.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/gym/domain/program.dart';
import 'package:harvest/features/gym/domain/session.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

part 'sessions_repository.g.dart';

/// Sessions, the exercises in them and the sets in those.
///
/// The rule this whole class exists to keep: **a set is written when it
/// is ticked**, not when the session ends ([[Gym]] rule Y3). A workout
/// is thirty to ninety minutes of data and losing it to a process kill
/// is not acceptable, so nothing is held in memory waiting for Finish.
/// One day I did an exercise, and what came of it.
typedef ExerciseOuting = ({
  HarvestDay day,
  List<WorkoutSet> sets,
  int volumeGrams,
  int? bestEstimate,
});

class SessionsRepository {
  SessionsRepository(this._db);

  final HarvestDatabase _db;
  static const _uuid = Uuid();

  TableUpdateQuery get _sessionTables => TableUpdateQuery.onAllTables([
    _db.workoutSessions,
    _db.sessionExercises,
    _db.workoutSets,
  ]);

  // --------------------------------------------------------------- reads

  Stream<WorkoutSession?> watchOne(String uuid) async* {
    yield await once(uuid);
    await for (final _ in _db.tableUpdates(_sessionTables)) {
      yield await once(uuid);
    }
  }

  /// The session that is still running, if there is one.
  ///
  /// This is the resume: the app does not need to remember it was
  /// interrupted, because an unfinished session is one with no end.
  Stream<WorkoutSession?> watchRunning() async* {
    yield await runningOnce();
    await for (final _ in _db.tableUpdates(_sessionTables)) {
      yield await runningOnce();
    }
  }

  Future<WorkoutSession?> runningOnce() async {
    final row =
        await (_db.select(_db.workoutSessions)
              ..where((s) => s.endedAt.isNull() & s.deletedAt.isNull())
              ..orderBy([
                (s) => OrderingTerm.desc(s.startedAt),
                (s) => OrderingTerm.desc(s.rowId),
              ])
              ..limit(1))
            .getSingleOrNull();
    return row == null ? null : _hydrate(row);
  }

  Stream<List<WorkoutSession>> watchFinished({int limit = 50}) async* {
    yield await finishedOnce(limit: limit);
    await for (final _ in _db.tableUpdates(_sessionTables)) {
      yield await finishedOnce(limit: limit);
    }
  }

  Future<List<WorkoutSession>> finishedOnce({int limit = 50}) async {
    final rows =
        await (_db.select(_db.workoutSessions)
              ..where((s) => s.endedAt.isNotNull() & s.deletedAt.isNull())
              ..orderBy([
                (s) => OrderingTerm.desc(s.startedAt),
                (s) => OrderingTerm.desc(s.rowId),
              ])
              ..limit(limit))
            .get();
    return [for (final row in rows) await _hydrate(row)];
  }

  Future<WorkoutSession?> once(String uuid) async {
    final row = await (_db.select(
      _db.workoutSessions,
    )..where((s) => s.uuid.equals(uuid))).getSingleOrNull();
    return row == null ? null : _hydrate(row);
  }

  Future<WorkoutSession> _hydrate(WorkoutSessionRow row) async {
    final exercises =
        await (_db.select(_db.sessionExercises)
              ..where((e) => e.sessionUuid.equals(row.uuid))
              ..orderBy([(e) => OrderingTerm.asc(e.position)]))
            .get();

    final built = <SessionExercise>[];
    for (final exercise in exercises) {
      final sets =
          await (_db.select(_db.workoutSets)
                ..where((s) => s.sessionExerciseUuid.equals(exercise.uuid))
                ..orderBy([(s) => OrderingTerm.asc(s.position)]))
              .get();
      built.add(
        SessionExercise(
          uuid: exercise.uuid,
          sessionUuid: exercise.sessionUuid,
          position: exercise.position,
          exerciseId: exercise.exerciseId,
          plannedExerciseId: exercise.plannedExerciseId,
          slotUuid: exercise.slotUuid,
          skipped: exercise.skipped,
          note: exercise.note,
          restSeconds: exercise.restSeconds,
          barGrams: exercise.barGrams,
          sets: [for (final set in sets) _toSet(set)],
        ),
      );
    }

    return WorkoutSession(
      uuid: row.uuid,
      programUuid: row.programUuid,
      dayUuid: row.dayUuid,
      title: row.title,
      day: HarvestDay.parse(row.harvestDay),
      startedAt: row.startedAt,
      endedAt: row.endedAt,
      note: row.note,
      exercises: built,
    );
  }

  /// What I did last time on this exercise — always on the session
  /// screen, because it is the only number that matters while deciding
  /// what to put on the bar.
  ///
  /// Two sessions can share a start instant — the same exercise twice
  /// in a day, or a clock coarser than the gap between them — so the
  /// row order breaks the tie: the later insert is the later session.
  Future<List<WorkoutSet>> lastTime(String exerciseId) async {
    final exercises = await (_db.select(
      _db.sessionExercises,
    )..where((e) => e.exerciseId.equals(exerciseId))).get();
    if (exercises.isEmpty) return const [];

    final finished =
        await (_db.select(_db.workoutSessions)
              ..where(
                (s) =>
                    s.uuid.isIn(exercises.map((e) => e.sessionUuid).toList()) &
                    s.endedAt.isNotNull() &
                    s.deletedAt.isNull(),
              )
              ..orderBy([
                (s) => OrderingTerm.desc(s.startedAt),
                (s) => OrderingTerm.desc(s.rowId),
              ])
              ..limit(1))
            .getSingleOrNull();
    if (finished == null) return const [];

    final exercise = exercises.firstWhere(
      (e) => e.sessionUuid == finished.uuid,
    );
    final sets =
        await (_db.select(_db.workoutSets)
              ..where(
                (s) =>
                    s.sessionExerciseUuid.equals(exercise.uuid) &
                    s.done.equals(true),
              )
              ..orderBy([(s) => OrderingTerm.asc(s.position)]))
            .get();
    return [for (final set in sets) _toSet(set)];
  }

  /// Every ticked set of an exercise, and the volume of each session it
  /// appeared in — everything [recordsFrom] needs.
  Future<ExerciseRecords> records(String exerciseId) async {
    final exercises = await (_db.select(
      _db.sessionExercises,
    )..where((e) => e.exerciseId.equals(exerciseId))).get();
    if (exercises.isEmpty) return noRecords;

    final sets = <WorkoutSet>[];
    final volumes = <String, int>{};
    for (final exercise in exercises) {
      final rows =
          await (_db.select(_db.workoutSets)..where(
                (s) =>
                    s.sessionExerciseUuid.equals(exercise.uuid) &
                    s.done.equals(true),
              ))
              .get();
      for (final row in rows) {
        final set = _toSet(row);
        sets.add(set);
        volumes.update(
          exercise.sessionUuid,
          (v) => v + set.volumeGrams,
          ifAbsent: () => set.volumeGrams,
        );
      }
    }
    return recordsFrom(sets, sessionVolumes: volumes.values);
  }

  /// Every session that logged this exercise, newest first.
  ///
  /// One entry per session rather than a flat list of sets, because
  /// the question is always "what did I do that day", never "what is
  /// the 400th set I have ever done".
  Future<List<ExerciseOuting>> history(
    String exerciseId, {
    int limit = 30,
  }) async {
    final exercises = await (_db.select(
      _db.sessionExercises,
    )..where((e) => e.exerciseId.equals(exerciseId))).get();
    if (exercises.isEmpty) return const [];

    final sessions =
        await (_db.select(_db.workoutSessions)
              ..where(
                (s) =>
                    s.uuid.isIn(exercises.map((e) => e.sessionUuid).toList()) &
                    s.endedAt.isNotNull() &
                    s.deletedAt.isNull(),
              )
              ..orderBy([
                (s) => OrderingTerm.desc(s.startedAt),
                (s) => OrderingTerm.desc(s.rowId),
              ])
              ..limit(limit))
            .get();

    final outings = <ExerciseOuting>[];
    for (final session in sessions) {
      final exercise = exercises.firstWhere(
        (e) => e.sessionUuid == session.uuid,
      );
      final rows =
          await (_db.select(_db.workoutSets)
                ..where(
                  (s) =>
                      s.sessionExerciseUuid.equals(exercise.uuid) &
                      s.done.equals(true),
                )
                ..orderBy([(s) => OrderingTerm.asc(s.position)]))
              .get();
      if (rows.isEmpty) continue;
      final sets = [for (final row in rows) _toSet(row)];
      outings.add((
        day: HarvestDay.parse(session.harvestDay),
        sets: sets,
        volumeGrams: sets.fold(0, (sum, set) => sum + set.volumeGrams),
        bestEstimate: recordsFrom(sets).bestSetEstimate,
      ));
    }
    return outings;
  }

  // -------------------------------------------------------------- writes

  /// Opens a session from a program day, copying its targets in.
  ///
  /// The targets are copied rather than referenced so the session is a
  /// record of what was asked at the time: editing the program later
  /// must not rewrite last Tuesday.
  Future<WorkoutSession> start({
    required ProgramDay day,
    required String programUuid,
    required String title,
    Map<String, int> trainingMaxes = const {},
    HarvestDay? on,
  }) async {
    final uuid = _uuid.v4();
    final harvestDay = on ?? HarvestDay.today();

    await _db.transaction(() async {
      await _db
          .into(_db.workoutSessions)
          .insert(
            WorkoutSessionsCompanion.insert(
              uuid: uuid,
              programUuid: Value(programUuid),
              dayUuid: Value(day.uuid),
              title: Value(title),
              harvestDay: harvestDay.key,
            ),
          );

      for (final slot in day.slots) {
        final exerciseUuid = _uuid.v4();
        await _db
            .into(_db.sessionExercises)
            .insert(
              SessionExercisesCompanion.insert(
                uuid: exerciseUuid,
                sessionUuid: uuid,
                position: slot.position,
                exerciseId: slot.exerciseId,
                plannedExerciseId: Value(slot.exerciseId),
                slotUuid: Value(slot.uuid),
                restSeconds: Value(slot.restSeconds),
                barGrams: Value(slot.barGrams),
              ),
            );

        final resolved = resolveSlot(
          slot,
          trainingMaxGrams: trainingMaxes[slot.exerciseId],
        );
        for (final entry in resolved) {
          await _db
              .into(_db.workoutSets)
              .insert(
                WorkoutSetsCompanion.insert(
                  uuid: _uuid.v4(),
                  sessionExerciseUuid: exerciseUuid,
                  position: entry.target.position,
                  // Prefilled with the target, so a set that went to
                  // plan is one tap on the tick.
                  weightGrams: Value(entry.grams ?? 0),
                  reps: Value(entry.target.reps ?? 0),
                  openEnded: Value(entry.target.openEnded),
                  targetLabel: Value(_labelFor(entry)),
                ),
              );
        }
      }
      await _outbox(uuid, 'insert');
    });

    return (await once(uuid))!;
  }

  /// An empty session, for a day I am making up as I go.
  Future<WorkoutSession> startFreeform({String? title, HarvestDay? on}) async {
    final uuid = _uuid.v4();
    await _db
        .into(_db.workoutSessions)
        .insert(
          WorkoutSessionsCompanion.insert(
            uuid: uuid,
            title: Value(title),
            harvestDay: (on ?? HarvestDay.today()).key,
          ),
        );
    return (await once(uuid))!;
  }

  /// Ticks a set — and writes it, now.
  Future<void> logSet(
    String uuid, {
    required int weightGrams,
    required int reps,
    bool done = true,
  }) => _db.transaction(() async {
    await (_db.update(
      _db.workoutSets,
    )..where((s) => s.uuid.equals(uuid))).write(
      WorkoutSetsCompanion(
        weightGrams: Value(weightGrams),
        reps: Value(reps),
        done: Value(done),
        loggedAt: Value(DateTime.now()),
      ),
    );
    await _touch(uuid);
  });

  Future<void> addSet(
    String sessionExerciseUuid, {
    int weightGrams = 0,
    int reps = 0,
  }) async {
    final existing = await (_db.select(
      _db.workoutSets,
    )..where((s) => s.sessionExerciseUuid.equals(sessionExerciseUuid))).get();
    await _db
        .into(_db.workoutSets)
        .insert(
          WorkoutSetsCompanion.insert(
            uuid: _uuid.v4(),
            sessionExerciseUuid: sessionExerciseUuid,
            position: existing.length,
            weightGrams: Value(
              existing.isEmpty ? 0 : existing.last.weightGrams,
            ),
            reps: Value(existing.isEmpty ? 0 : existing.last.reps),
          ),
        );
  }

  Future<void> removeSet(String uuid) =>
      (_db.delete(_db.workoutSets)..where((s) => s.uuid.equals(uuid))).go();

  Future<void> skipExercise(String uuid, {required bool skipped}) =>
      (_db.update(_db.sessionExercises)..where((e) => e.uuid.equals(uuid)))
          .write(SessionExercisesCompanion(skipped: Value(skipped)));

  /// Swaps an exercise for another mid-session.
  ///
  /// The planned exercise is left alone, so history can still say what
  /// the day was meant to be (rule Y7).
  Future<void> replaceExercise(String uuid, {required String exerciseId}) =>
      (_db.update(_db.sessionExercises)..where((e) => e.uuid.equals(uuid)))
          .write(SessionExercisesCompanion(exerciseId: Value(exerciseId)));

  Future<void> addExercise(
    String sessionUuid, {
    required String exerciseId,
    int? restSeconds,
  }) async {
    final existing = await (_db.select(
      _db.sessionExercises,
    )..where((e) => e.sessionUuid.equals(sessionUuid))).get();
    final uuid = _uuid.v4();
    await _db
        .into(_db.sessionExercises)
        .insert(
          SessionExercisesCompanion.insert(
            uuid: uuid,
            sessionUuid: sessionUuid,
            position: existing.length,
            exerciseId: exerciseId,
            restSeconds: Value(restSeconds),
          ),
        );
    await addSet(uuid);
  }

  /// The rest for this exercise, in this session only.
  ///
  /// Changing it mid-workout does not rewrite the program: today the
  /// gym is busy and the rest is longer, and that is a fact about
  /// today, not about the program.
  Future<void> setExerciseRest(String uuid, int? seconds) =>
      (_db.update(_db.sessionExercises)..where((e) => e.uuid.equals(uuid)))
          .write(SessionExercisesCompanion(restSeconds: Value(seconds)));

  Future<void> setExerciseNote(String uuid, String? note) =>
      (_db.update(_db.sessionExercises)..where((e) => e.uuid.equals(uuid)))
          .write(SessionExercisesCompanion(note: Value(note)));

  Future<void> setSessionNote(String uuid, String? note) =>
      (_db.update(
        _db.workoutSessions,
      )..where((s) => s.uuid.equals(uuid))).write(
        WorkoutSessionsCompanion(
          note: Value(note),
          updatedAt: Value(DateTime.now()),
        ),
      );

  Future<void> finish(String uuid) => _db.transaction(() async {
    await (_db.update(
      _db.workoutSessions,
    )..where((s) => s.uuid.equals(uuid))).write(
      WorkoutSessionsCompanion(
        endedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );
    await _outbox(uuid, 'update');
  });

  /// Throws the session away. The UI asks twice.
  Future<void> discard(String uuid) => _db.transaction(() async {
    final exercises = await (_db.select(
      _db.sessionExercises,
    )..where((e) => e.sessionUuid.equals(uuid))).get();
    for (final exercise in exercises) {
      await (_db.delete(
        _db.workoutSets,
      )..where((s) => s.sessionExerciseUuid.equals(exercise.uuid))).go();
    }
    await (_db.delete(
      _db.sessionExercises,
    )..where((e) => e.sessionUuid.equals(uuid))).go();
    await (_db.delete(
      _db.workoutSessions,
    )..where((s) => s.uuid.equals(uuid))).go();
  });

  Future<void> _touch(String setUuid) async {
    final set = await (_db.select(
      _db.workoutSets,
    )..where((s) => s.uuid.equals(setUuid))).getSingleOrNull();
    if (set == null) return;
    final exercise = await (_db.select(
      _db.sessionExercises,
    )..where((e) => e.uuid.equals(set.sessionExerciseUuid))).getSingleOrNull();
    if (exercise == null) return;
    await (_db.update(_db.workoutSessions)
          ..where((s) => s.uuid.equals(exercise.sessionUuid)))
        .write(WorkoutSessionsCompanion(updatedAt: Value(DateTime.now())));
  }

  Future<void> _outbox(String rowUuid, String op) => _db
      .into(_db.outbox)
      .insert(
        OutboxCompanion.insert(
          targetTable: 'workout_sessions',
          rowUuid: rowUuid,
          op: op,
        ),
      );

  static String? _labelFor(ResolvedSet entry) {
    final reps = entry.target.openEnded
        ? '${entry.target.reps ?? 1}+'
        : '${entry.target.reps ?? 1}';
    if (entry.grams != null) {
      return '${(entry.grams! / 1000).toStringAsFixed(2)}×$reps';
    }
    if (entry.target.percentTenths != null) {
      return '${entry.target.percentTenths! / 10}%×$reps';
    }
    return '×$reps';
  }

  static WorkoutSet _toSet(WorkoutSetRow row) => WorkoutSet(
    uuid: row.uuid,
    sessionExerciseUuid: row.sessionExerciseUuid,
    position: row.position,
    weightGrams: row.weightGrams,
    reps: row.reps,
    done: row.done,
    targetLabel: row.targetLabel,
    openEnded: row.openEnded,
    loggedAt: row.loggedAt,
  );
}

@Riverpod(keepAlive: true)
SessionsRepository sessionsRepository(Ref ref) =>
    SessionsRepository(ref.watch(databaseProvider));

/// The session that is still running, if any. The gym screen offers to
/// resume it and the field knows a workout is in progress.
@riverpod
Stream<WorkoutSession?> runningSession(Ref ref) =>
    ref.watch(sessionsRepositoryProvider).watchRunning();

@riverpod
Stream<WorkoutSession?> session(Ref ref, String uuid) =>
    ref.watch(sessionsRepositoryProvider).watchOne(uuid);

@riverpod
Stream<List<WorkoutSession>> finishedSessions(Ref ref) =>
    ref.watch(sessionsRepositoryProvider).watchFinished();

@riverpod
Future<ExerciseRecords> exerciseRecords(Ref ref, String exerciseId) =>
    ref.watch(sessionsRepositoryProvider).records(exerciseId);

@riverpod
Future<List<WorkoutSet>> lastTime(Ref ref, String exerciseId) =>
    ref.watch(sessionsRepositoryProvider).lastTime(exerciseId);

@riverpod
Future<List<ExerciseOuting>> exerciseHistory(Ref ref, String exerciseId) =>
    ref.watch(sessionsRepositoryProvider).history(exerciseId);
