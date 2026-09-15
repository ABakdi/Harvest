import 'package:drift/drift.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/db/database_provider.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/health/domain/body_weight.dart';
import 'package:harvest/features/health/domain/steps.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

part 'health_repository.g.dart';

/// What a logged weight pays, once a day at most ([[Gamification]]).
const weightXp = 5;

/// What meeting the step goal pays, once a day, and only once a goal
/// has been asked for ([[Health]]).
const stepGoalXp = 5;

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
      // A second weigh-in the same day is a second fact, not a second
      // payment.
      await _payOnce(
        reason: 'weight:${weight.day.key}',
        xp: weightXp,
        day: weight.day,
      );
    });
    return weight;
  }

  Future<void> updateWeight(
    String uuid, {
    int? grams,
    String? note,
    DateTime? measuredAt,
  }) => _db.transaction(() async {
    await (_db.update(
      _db.bodyWeights,
    )..where((w) => w.uuid.equals(uuid))).write(
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
    await (_db.update(
      _db.bodyWeights,
    )..where((w) => w.uuid.equals(uuid))).write(
      BodyWeightsCompanion(
        deletedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );
    await _outbox('body_weights', uuid, 'update');
  });

  Future<void> restoreWeight(String uuid) => _db.transaction(() async {
    await (_db.update(
      _db.bodyWeights,
    )..where((w) => w.uuid.equals(uuid))).write(
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

  Future<void> saveStepDay(StepDay day) => saveStepDays([day]);

  /// Writes a run of days in one go — a month of Health Connect totals
  /// arrives as one list and should land as one transaction.
  Future<void> saveStepDays(Iterable<StepDay> days) =>
      _db.transaction(() async {
        for (final day in days) {
          await _db
              .into(_db.stepDays)
              .insertOnConflictUpdate(
                StepDaysCompanion.insert(
                  harvestDay: day.day.key,
                  steps: Value(day.steps),
                  lastCounter: Value(day.lastCounter),
                  updatedAt: Value(DateTime.now()),
                ),
              );
        }
      });

  /// Pays the step goal for [day] if it has been met and not yet paid.
  /// Returns whether it paid. A goal of zero is no goal, and pays
  /// nothing: the number is shown before a goal is ever asked for.
  Future<bool> payStepGoal(HarvestDay day, {required int goal}) async {
    if (goal <= 0) return false;
    final steps = await stepsOn(day);
    if (steps.steps < goal) return false;
    return _payOnce(reason: 'steps:${day.key}', xp: stepGoalXp, day: day);
  }

  /// One ledger row per [reason], ever. Returns whether one was added.
  Future<bool> _payOnce({
    required String reason,
    required int xp,
    required HarvestDay day,
  }) async {
    final paid = await (_db.select(
      _db.ledger,
    )..where((l) => l.reason.equals(reason))).getSingleOrNull();
    if (paid != null) return false;
    await _db
        .into(_db.ledger)
        .insert(
          LedgerCompanion.insert(
            uuid: _uuid.v4(),
            kind: 'xp',
            delta: xp,
            reason: reason,
            harvestDay: day.key,
          ),
        );
    return true;
  }

  // ---------------------------------------------------------------------

  Future<void> _outbox(String table, String rowUuid, String op) =>
      _db.logChange(table, rowUuid, op);

  static BodyWeight _toWeight(BodyWeightRow row) => BodyWeight(
    uuid: row.uuid,
    grams: row.grams,
    day: HarvestDay.tryParse(row.harvestDay) ?? HarvestDay.of(row.measuredAt),
    measuredAt: row.measuredAt,
    note: row.note,
  );

  static StepDay _toStepDay(StepDayRow row) => StepDay(
    day: HarvestDay.tryParse(row.harvestDay) ?? HarvestDay.of(row.updatedAt),
    steps: row.steps,
    lastCounter: row.lastCounter,
  );
}

@Riverpod(keepAlive: true)
HealthRepository healthRepository(Ref ref) =>
    HealthRepository(ref.watch(databaseProvider));
