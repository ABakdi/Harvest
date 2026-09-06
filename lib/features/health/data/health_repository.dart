import 'package:drift/drift.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/db/database_provider.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/health/domain/body_weight.dart';
import 'package:harvest/features/health/domain/steps.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

part 'health_repository.g.dart';

/// Weights and steps.
class HealthRepository {
  HealthRepository(this._db);

  final HarvestDatabase _db;
  static const _uuid = Uuid();

  // -------------------------------------------------------------- weight

  Stream<List<BodyWeight>> watchWeights() {
    final query = _db.select(_db.bodyWeights)
      ..where((w) => w.deletedAt.isNull())
      ..orderBy([(w) => OrderingTerm.asc(w.measuredAt)]);
    return query.watch().map((rows) => rows.map(_toWeight).toList());
  }

  Future<BodyWeight> logWeight({
    required int grams,
    String? note,
    DateTime? measuredAt,
  }) async {
    final at = measuredAt ?? DateTime.now();
    final weight = BodyWeight(
      uuid: _uuid.v4(),
      grams: grams,
      day: HarvestDay.of(at),
      measuredAt: at,
      note: note,
    );
    await _db.transaction(() async {
      await _db
          .into(_db.bodyWeights)
          .insert(
            BodyWeightsCompanion.insert(
              uuid: weight.uuid,
              grams: grams,
              harvestDay: weight.day.key,
              note: Value(note),
              measuredAt: Value(at),
            ),
          );
      await _outbox('body_weights', weight.uuid, 'insert');
    });
    return weight;
  }

  Future<void> updateWeight(
    String uuid, {
    int? grams,
    String? note,
    DateTime? measuredAt,
  }) => _db.transaction(() async {
    await (_db.update(_db.bodyWeights)..where((w) => w.uuid.equals(uuid)))
        .write(
          BodyWeightsCompanion(
            grams: grams == null ? const Value.absent() : Value(grams),
            note: Value(note),
            harvestDay: measuredAt == null
                ? const Value.absent()
                : Value(HarvestDay.of(measuredAt).key),
            measuredAt: measuredAt == null
                ? const Value.absent()
                : Value(measuredAt),
            updatedAt: Value(DateTime.now()),
          ),
        );
    await _outbox('body_weights', uuid, 'update');
  });

  Future<void> removeWeight(String uuid) => _db.transaction(() async {
    await (_db.update(_db.bodyWeights)..where((w) => w.uuid.equals(uuid)))
        .write(
          BodyWeightsCompanion(
            deletedAt: Value(DateTime.now()),
            updatedAt: Value(DateTime.now()),
          ),
        );
    await _outbox('body_weights', uuid, 'update');
  });

  Future<void> restoreWeight(String uuid) => _db.transaction(() async {
    await (_db.update(_db.bodyWeights)..where((w) => w.uuid.equals(uuid)))
        .write(
          const BodyWeightsCompanion(deletedAt: Value(null)),
        );
    await _outbox('body_weights', uuid, 'update');
  });

  // --------------------------------------------------------------- steps

  Stream<List<StepDay>> watchSteps({int days = 30}) {
    final from = HarvestDay.today().addDays(-(days - 1)).key;
    final query = _db.select(_db.stepDays)
      ..where((s) => s.harvestDay.isBiggerOrEqualValue(from))
      ..orderBy([(s) => OrderingTerm.asc(s.harvestDay)]);
    return query.watch().map((rows) => rows.map(_toStepDay).toList());
  }

  Stream<StepDay?> watchStepsOn(HarvestDay day) {
    final query = _db.select(_db.stepDays)
      ..where((s) => s.harvestDay.equals(day.key));
    return query.watchSingleOrNull().map(
      (row) => row == null ? null : _toStepDay(row),
    );
  }

  Future<StepDay> stepsOn(HarvestDay day) async {
    final row = await (_db.select(
      _db.stepDays,
    )..where((s) => s.harvestDay.equals(day.key))).getSingleOrNull();
    return row == null ? startOfDay(day) : _toStepDay(row);
  }

  /// The reading the *previous* day ended on, so a new day starts
  /// anchored rather than adding a whole boot's worth of steps.
  Future<int?> lastCounterBefore(HarvestDay day) async {
    final row =
        await (_db.select(_db.stepDays)
              ..where((s) => s.harvestDay.isSmallerThanValue(day.key))
              ..orderBy([(s) => OrderingTerm.desc(s.harvestDay)])
              ..limit(1))
            .getSingleOrNull();
    return row?.lastCounter;
  }

  Future<void> saveStepDay(StepDay day) => _db
      .into(_db.stepDays)
      .insertOnConflictUpdate(
        StepDaysCompanion.insert(
          harvestDay: day.day.key,
          steps: Value(day.steps),
          lastCounter: Value(day.lastCounter),
          updatedAt: Value(DateTime.now()),
        ),
      );

  // ---------------------------------------------------------------------

  Future<void> _outbox(String table, String rowUuid, String op) => _db
      .into(_db.outbox)
      .insert(
        OutboxCompanion.insert(targetTable: table, rowUuid: rowUuid, op: op),
      );

  static BodyWeight _toWeight(BodyWeightRow row) => BodyWeight(
    uuid: row.uuid,
    grams: row.grams,
    day: HarvestDay.parse(row.harvestDay),
    measuredAt: row.measuredAt,
    note: row.note,
  );

  static StepDay _toStepDay(StepDayRow row) => StepDay(
    day: HarvestDay.parse(row.harvestDay),
    steps: row.steps,
    lastCounter: row.lastCounter,
  );
}

@Riverpod(keepAlive: true)
HealthRepository healthRepository(Ref ref) =>
    HealthRepository(ref.watch(databaseProvider));
