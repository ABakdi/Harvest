import 'package:drift/drift.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/db/database_provider.dart';
import 'package:harvest/features/gym/domain/program.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

part 'programs_repository.g.dart';

/// Programs, their days, their slots and their target sets.
///
/// A program is read whole — four tables joined into one object graph —
/// because every screen that wants a program wants all of it: the
/// editor draws the tree, and a session needs the day's slots and their
/// sets before it can put a single row on screen. Four queries once is
/// cheaper than lazy loading a nested list on a phone.
class ProgramsRepository {
  ProgramsRepository(this._db);

  final HarvestDatabase _db;
  static const _uuid = Uuid();

  // --------------------------------------------------------------- reads

  /// A program lives in four tables, and a stream that watches only
  /// the first one goes stale the moment an exercise is added to a
  /// day. Drift fires a query's stream for the tables that query
  /// *reads*, and the nested reads happen afterwards in Dart — so the
  /// change signal has to be asked for explicitly, across all four.
  TableUpdateQuery get _programTables => TableUpdateQuery.onAllTables([
    _db.programs,
    _db.programDays,
    _db.programSlots,
    _db.targetSets,
  ]);

  Stream<List<Program>> watchAll() async* {
    yield await allOnce();
    await for (final _ in _db.tableUpdates(_programTables)) {
      yield await allOnce();
    }
  }

  Stream<Program?> watchOne(String uuid) async* {
    yield await once(uuid);
    await for (final _ in _db.tableUpdates(_programTables)) {
      yield await once(uuid);
    }
  }

  Future<List<Program>> allOnce() async {
    final rows =
        await (_db.select(_db.programs)
              ..where((p) => p.deletedAt.isNull())
              ..orderBy([(p) => OrderingTerm.asc(p.createdAt)]))
            .get();
    return [for (final row in rows) await _hydrate(row)];
  }

  Future<Program?> once(String uuid) async {
    final row =
        await (_db.select(
              _db.programs,
            )..where((p) => p.uuid.equals(uuid) & p.deletedAt.isNull()))
            .getSingleOrNull();
    return row == null ? null : _hydrate(row);
  }

  Future<Program> _hydrate(ProgramRow row) async {
    final days =
        await (_db.select(_db.programDays)
              ..where((d) => d.programUuid.equals(row.uuid))
              ..orderBy([(d) => OrderingTerm.asc(d.position)]))
            .get();

    final built = <ProgramDay>[];
    for (final day in days) {
      final slots =
          await (_db.select(_db.programSlots)
                ..where((s) => s.dayUuid.equals(day.uuid))
                ..orderBy([(s) => OrderingTerm.asc(s.position)]))
              .get();

      final withSets = <ProgramSlot>[];
      for (final slot in slots) {
        final sets =
            await (_db.select(_db.targetSets)
                  ..where((t) => t.slotUuid.equals(slot.uuid))
                  ..orderBy([(t) => OrderingTerm.asc(t.position)]))
                .get();
        withSets.add(
          ProgramSlot(
            uuid: slot.uuid,
            dayUuid: slot.dayUuid,
            exerciseId: slot.exerciseId,
            position: slot.position,
            restSeconds: slot.restSeconds,
            barGrams: slot.barGrams,
            note: slot.note,
            sets: [
              for (final set in sets)
                TargetSet(
                  uuid: set.uuid,
                  position: set.position,
                  reps: set.reps,
                  weightGrams: set.weightGrams,
                  percentTenths: set.percentTenths,
                  openEnded: set.openEnded,
                ),
            ],
          ),
        );
      }

      built.add(
        ProgramDay(
          uuid: day.uuid,
          programUuid: day.programUuid,
          name: day.name,
          position: day.position,
          week: day.week,
          accessories: day.accessories,
          slots: withSets,
        ),
      );
    }

    return Program(
      uuid: row.uuid,
      name: row.name,
      note: row.note,
      weeks: row.weeks,
      commitmentUuid: row.commitmentUuid,
      albumUuid: row.albumUuid,
      photoPrompt: PhotoPrompt.fromName(row.photoPrompt),
      days: built,
    );
  }

  /// Every training max the program has, by exercise.
  Stream<Map<String, int>> watchTrainingMaxes(String programUuid) {
    final query = _db.select(_db.trainingMaxes)
      ..where((t) => t.programUuid.equals(programUuid));
    return query.watch().map(
      (rows) => {for (final row in rows) row.exerciseId: row.grams},
    );
  }

  Future<Map<String, int>> trainingMaxesOnce(String programUuid) async {
    final rows = await (_db.select(
      _db.trainingMaxes,
    )..where((t) => t.programUuid.equals(programUuid))).get();
    return {for (final row in rows) row.exerciseId: row.grams};
  }

  // -------------------------------------------------------------- writes

  Future<Program> createProgram({
    required String name,
    String? note,
    int? weeks,
  }) async {
    final uuid = _uuid.v4();
    await _db.transaction(() async {
      await _db
          .into(_db.programs)
          .insert(
            ProgramsCompanion.insert(
              uuid: uuid,
              name: name.trim(),
              note: Value(note),
              weeks: Value(weeks),
            ),
          );
      await _outbox('programs', uuid, 'insert');
    });
    return (await once(uuid))!;
  }

  Future<void> updateProgram(
    String uuid, {
    String? name,
    String? note,
    int? weeks,
    String? commitmentUuid,
    String? albumUuid,
    PhotoPrompt? photoPrompt,
    bool clearCommitment = false,
    bool clearAlbum = false,
  }) => _db.transaction(() async {
    await (_db.update(_db.programs)..where((p) => p.uuid.equals(uuid))).write(
      ProgramsCompanion(
        name: name == null ? const Value.absent() : Value(name.trim()),
        note: note == null ? const Value.absent() : Value(note),
        weeks: weeks == null ? const Value.absent() : Value(weeks),
        commitmentUuid: clearCommitment
            ? const Value(null)
            : commitmentUuid == null
            ? const Value.absent()
            : Value(commitmentUuid),
        albumUuid: clearAlbum
            ? const Value(null)
            : albumUuid == null
            ? const Value.absent()
            : Value(albumUuid),
        photoPrompt: photoPrompt == null
            ? const Value.absent()
            : Value(photoPrompt.name),
        updatedAt: Value(DateTime.now()),
      ),
    );
    await _outbox('programs', uuid, 'update');
  });

  Future<void> deleteProgram(String uuid) => _db.transaction(() async {
    await (_db.update(_db.programs)..where((p) => p.uuid.equals(uuid))).write(
      ProgramsCompanion(
        deletedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );
    await _outbox('programs', uuid, 'update');
  });

  Future<ProgramDay> addDay(
    String programUuid, {
    required String name,
    int? week,
    String? accessories,
  }) async {
    final uuid = _uuid.v4();
    final existing = await (_db.select(
      _db.programDays,
    )..where((d) => d.programUuid.equals(programUuid))).get();
    await _db
        .into(_db.programDays)
        .insert(
          ProgramDaysCompanion.insert(
            uuid: uuid,
            programUuid: programUuid,
            name: name.trim(),
            position: existing.length,
            week: Value(week),
            accessories: Value(accessories),
          ),
        );
    await _outbox('program_days', uuid, 'insert');
    return ProgramDay(
      uuid: uuid,
      programUuid: programUuid,
      name: name.trim(),
      position: existing.length,
      week: week,
      accessories: accessories,
    );
  }

  Future<void> updateDay(
    String uuid, {
    String? name,
    String? accessories,
    int? week,
  }) => _db.transaction(() async {
    await (_db.update(
      _db.programDays,
    )..where((d) => d.uuid.equals(uuid))).write(
      ProgramDaysCompanion(
        name: name == null ? const Value.absent() : Value(name.trim()),
        accessories: Value(accessories),
        week: week == null ? const Value.absent() : Value(week),
      ),
    );
    await _outbox('program_days', uuid, 'update');
  });

  Future<void> removeDay(String uuid) => _db.transaction(() async {
    final slots = await (_db.select(
      _db.programSlots,
    )..where((s) => s.dayUuid.equals(uuid))).get();
    for (final slot in slots) {
      await (_db.delete(
        _db.targetSets,
      )..where((t) => t.slotUuid.equals(slot.uuid))).go();
    }
    await (_db.delete(
      _db.programSlots,
    )..where((s) => s.dayUuid.equals(uuid))).go();
    await (_db.delete(_db.programDays)..where((d) => d.uuid.equals(uuid))).go();
    await _outbox('program_days', uuid, 'delete');
  });

  /// Copies a day, sets and all — the fastest way to write a program,
  /// because most days are the last day with two numbers changed.
  Future<void> duplicateDay(ProgramDay day, {String? name}) =>
      _db.transaction(() async {
        final copy = await addDay(
          day.programUuid,
          name: name ?? '${day.name} (2)',
          week: day.week,
          accessories: day.accessories,
        );
        for (final slot in day.slots) {
          final slotUuid = _uuid.v4();
          await _db
              .into(_db.programSlots)
              .insert(
                ProgramSlotsCompanion.insert(
                  uuid: slotUuid,
                  dayUuid: copy.uuid,
                  exerciseId: slot.exerciseId,
                  position: slot.position,
                  restSeconds: Value(slot.restSeconds),
                  barGrams: Value(slot.barGrams),
                  note: Value(slot.note),
                ),
              );
          for (final set in slot.sets) {
            // A fresh uuid per copied set. Reusing the original's
            // would not duplicate the day — it would make two days
            // share one row, so editing either edits both.
            await _insertSet(slotUuid, set.copyWith(), uuid: _uuid.v4());
          }
        }
      });

  Future<ProgramSlot> addSlot(
    String dayUuid, {
    required String exerciseId,
    int? restSeconds,
    int barGrams = defaultBarGrams,
  }) async {
    final uuid = _uuid.v4();
    final existing = await (_db.select(
      _db.programSlots,
    )..where((s) => s.dayUuid.equals(dayUuid))).get();
    await _db
        .into(_db.programSlots)
        .insert(
          ProgramSlotsCompanion.insert(
            uuid: uuid,
            dayUuid: dayUuid,
            exerciseId: exerciseId,
            position: existing.length,
            restSeconds: Value(restSeconds),
            barGrams: Value(barGrams),
          ),
        );
    await _outbox('program_slots', uuid, 'insert');
    return ProgramSlot(
      uuid: uuid,
      dayUuid: dayUuid,
      exerciseId: exerciseId,
      position: existing.length,
      restSeconds: restSeconds,
      barGrams: barGrams,
    );
  }

  Future<void> updateSlot(
    String uuid, {
    String? exerciseId,
    int? restSeconds,
    int? barGrams,
    String? note,
  }) => _db.transaction(() async {
    await (_db.update(
      _db.programSlots,
    )..where((s) => s.uuid.equals(uuid))).write(
      ProgramSlotsCompanion(
        exerciseId: exerciseId == null
            ? const Value.absent()
            : Value(exerciseId),
        restSeconds: Value(restSeconds),
        barGrams: barGrams == null ? const Value.absent() : Value(barGrams),
        note: Value(note),
      ),
    );
    await _outbox('program_slots', uuid, 'update');
  });

  Future<void> removeSlot(String uuid) => _db.transaction(() async {
    await (_db.delete(
      _db.targetSets,
    )..where((t) => t.slotUuid.equals(uuid))).go();
    await (_db.delete(
      _db.programSlots,
    )..where((s) => s.uuid.equals(uuid))).go();
    await _outbox('program_slots', uuid, 'delete');
  });

  /// Reorders the slots of a day to the given uuids, in that order.
  Future<void> reorderSlots(List<String> uuids) => _db.transaction(() async {
    for (final (index, uuid) in uuids.indexed) {
      await (_db.update(_db.programSlots)..where((s) => s.uuid.equals(uuid)))
          .write(ProgramSlotsCompanion(position: Value(index)));
      await _outbox('program_slots', uuid, 'update');
    }
  });

  Future<void> addTargetSet(
    String slotUuid, {
    int? reps,
    int? weightGrams,
    int? percentTenths,
    bool openEnded = false,
  }) async {
    final existing = await (_db.select(
      _db.targetSets,
    )..where((t) => t.slotUuid.equals(slotUuid))).get();
    await _insertSet(
      slotUuid,
      TargetSet(
        uuid: _uuid.v4(),
        position: existing.length,
        reps: reps,
        weightGrams: weightGrams,
        percentTenths: percentTenths,
        openEnded: openEnded,
      ),
    );
  }

  Future<void> updateTargetSet(
    String uuid, {
    int? reps,
    int? weightGrams,
    int? percentTenths,
    bool? openEnded,
    bool clearWeight = false,
    bool clearPercent = false,
  }) => _db.transaction(() async {
    await (_db.update(_db.targetSets)..where((t) => t.uuid.equals(uuid))).write(
      TargetSetsCompanion(
        reps: Value(reps),
        weightGrams: clearWeight
            ? const Value(null)
            : weightGrams == null
            ? const Value.absent()
            : Value(weightGrams),
        percentTenths: clearPercent
            ? const Value(null)
            : percentTenths == null
            ? const Value.absent()
            : Value(percentTenths),
        openEnded: openEnded == null ? const Value.absent() : Value(openEnded),
      ),
    );
    await _outbox('target_sets', uuid, 'update');
  });

  Future<void> removeTargetSet(String uuid) => _db.transaction(() async {
    await (_db.delete(_db.targetSets)..where((t) => t.uuid.equals(uuid))).go();
    await _outbox('target_sets', uuid, 'delete');
  });

  Future<void> setTrainingMax({
    required String programUuid,
    required String exerciseId,
    required int grams,
  }) => _db.transaction(() async {
    await _db
        .into(_db.trainingMaxes)
        .insertOnConflictUpdate(
          TrainingMaxesCompanion.insert(
            programUuid: programUuid,
            exerciseId: exerciseId,
            grams: grams,
            updatedAt: Value(DateTime.now()),
          ),
        );
    await _outbox('training_maxes', '$programUuid/$exerciseId', 'update');
  });

  /// [uuid] overrides the set's own, which is what a copy needs.
  Future<void> _insertSet(
    String slotUuid,
    TargetSet set, {
    String? uuid,
  }) async {
    final id = uuid ?? set.uuid;
    await _db
        .into(_db.targetSets)
        .insert(
          TargetSetsCompanion.insert(
            uuid: id,
            slotUuid: slotUuid,
            position: set.position,
            reps: Value(set.reps),
            weightGrams: Value(set.weightGrams),
            percentTenths: Value(set.percentTenths),
            openEnded: Value(set.openEnded),
          ),
        );
    await _outbox('target_sets', id, 'insert');
  }

  Future<void> _outbox(String table, String rowUuid, String op) =>
      _db.logChange(table, rowUuid, op);
}

@Riverpod(keepAlive: true)
ProgramsRepository programsRepository(Ref ref) =>
    ProgramsRepository(ref.watch(databaseProvider));

@riverpod
Stream<List<Program>> programs(Ref ref) =>
    ref.watch(programsRepositoryProvider).watchAll();

@riverpod
Stream<Program?> program(Ref ref, String uuid) =>
    ref.watch(programsRepositoryProvider).watchOne(uuid);

@riverpod
Stream<Map<String, int>> trainingMaxes(Ref ref, String programUuid) =>
    ref.watch(programsRepositoryProvider).watchTrainingMaxes(programUuid);
