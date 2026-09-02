import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/db/database_provider.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/commitments/domain/commitment.dart';
import 'package:harvest/features/commitments/domain/schedule.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

part 'commitments_repository.g.dart';

class CommitmentsRepository {
  CommitmentsRepository(this._db);

  final HarvestDatabase _db;
  static const _uuid = Uuid();

  // ---------------------------------------------------------------- reads

  /// All non-archived, non-deleted commitments.
  Stream<List<Commitment>> watchActive() {
    final query = _db.select(_db.commitments)
      ..where((c) => c.archivedAt.isNull() & c.deletedAt.isNull())
      ..orderBy([(c) => OrderingTerm.asc(c.createdAt)]);
    return query.watch().map((rows) => rows.map(_toDomain).toList());
  }

  /// Check-ins per commitment for one Harvest Day (uuid → units logged).
  Stream<Map<String, int>> watchLoggedOn(HarvestDay day) {
    final query = _db.select(_db.checkIns)
      ..where((c) => c.harvestDay.equals(day.key) & c.deletedAt.isNull());
    return query.watch().map(_sumByCommitment);
  }

  /// Lifetime units per commitment (project progress, todo completion).
  Stream<Map<String, int>> watchTotals() {
    final query = _db.select(_db.checkIns)
      ..where((c) => c.deletedAt.isNull());
    return query.watch().map(_sumByCommitment);
  }

  /// Distinct completed days per commitment within [day]'s week, up to and
  /// including [day] — feeds the times-per-week schedule.
  Stream<Map<String, int>> watchDoneDaysThisWeek(HarvestDay day) {
    final start = day.weekStart;
    final days = List.generate(7, (i) {
      var d = start;
      for (var j = 0; j < i; j++) {
        d = d.next;
      }
      return d.key;
    });
    final query = _db.select(_db.checkIns)
      ..where((c) => c.harvestDay.isIn(days) & c.deletedAt.isNull());
    return query.watch().map((rows) {
      final byCommitment = <String, Set<String>>{};
      for (final row in rows) {
        byCommitment
            .putIfAbsent(row.commitmentUuid, () => {})
            .add(row.harvestDay);
      }
      return byCommitment.map((k, v) => MapEntry(k, v.length));
    });
  }

  Map<String, int> _sumByCommitment(List<CheckInRow> rows) {
    final sums = <String, int>{};
    for (final row in rows) {
      sums.update(
        row.commitmentUuid,
        (v) => v + row.quantity,
        ifAbsent: () => row.quantity,
      );
    }
    return sums;
  }

  // --------------------------------------------------------------- writes

  Future<Commitment> create({
    required CommitmentType type,
    required String title,
    Schedule? schedule,
    int? totalTarget,
    int? dailyCommitment,
    HarvestDay? dueDay,
    String? note,
    String? remindAt,
    HarvestDay? deadline,
  }) async {
    final commitment = Commitment(
      uuid: _uuid.v4(),
      type: type,
      title: title,
      createdAt: DateTime.now(),
      schedule: schedule,
      totalTarget: totalTarget,
      dailyCommitment: dailyCommitment,
      dueDay: dueDay,
      note: note,
      remindAt: remindAt,
      deadline: deadline,
    );
    await _db.transaction(() async {
      await _db.into(_db.commitments).insert(_toRow(commitment));
      await _appendOutbox('commitments', commitment.uuid, 'insert');
    });
    return commitment;
  }

  Future<void> update(Commitment commitment) => _db.transaction(() async {
        await (_db.update(_db.commitments)
              ..where((c) => c.uuid.equals(commitment.uuid)))
            .write(
          _toRow(commitment).copyWith(updatedAt: Value(DateTime.now())),
        );
        await _appendOutbox('commitments', commitment.uuid, 'update');
      });

  /// Vacation mode on/off for a habit.
  Future<void> setPaused(String uuid, {required bool paused}) =>
      _db.transaction(() async {
        await (_db.update(_db.commitments)..where((c) => c.uuid.equals(uuid)))
            .write(
          CommitmentsCompanion(
            pausedAt: Value(paused ? DateTime.now() : null),
            updatedAt: Value(DateTime.now()),
          ),
        );
        await _appendOutbox('commitments', uuid, 'update');
      });

  Future<void> archive(String uuid) => _db.transaction(() async {
        await (_db.update(_db.commitments)..where((c) => c.uuid.equals(uuid)))
            .write(
          CommitmentsCompanion(
            archivedAt: Value(DateTime.now()),
            updatedAt: Value(DateTime.now()),
          ),
        );
        await _appendOutbox('commitments', uuid, 'update');
      });

  Future<void> _appendOutbox(String table, String rowUuid, String op) =>
      _db.into(_db.outbox).insert(
            OutboxCompanion.insert(
              targetTable: table,
              rowUuid: rowUuid,
              op: op,
            ),
          );

  // -------------------------------------------------------------- mapping

  Commitment _toDomain(CommitmentRow row) => Commitment(
        uuid: row.uuid,
        type: CommitmentType.values.byName(row.type),
        title: row.title,
        createdAt: row.createdAt,
        schedule: row.scheduleJson == null
            ? null
            : Schedule.fromJson(
                jsonDecode(row.scheduleJson!) as Map<String, dynamic>,
              ),
        totalTarget: row.totalTarget,
        dailyCommitment: row.dailyCommitment,
        dueDay: row.dueDay == null ? null : HarvestDay.parse(row.dueDay!),
        note: row.note,
        remindAt: row.remindAt,
        deadline:
            row.deadline == null ? null : HarvestDay.parse(row.deadline!),
        pausedAt: row.pausedAt,
        archivedAt: row.archivedAt,
      );

  CommitmentsCompanion _toRow(Commitment c) => CommitmentsCompanion.insert(
        uuid: c.uuid,
        type: c.type.name,
        title: c.title,
        scheduleJson: Value(
          c.schedule == null ? null : jsonEncode(c.schedule!.toJson()),
        ),
        totalTarget: Value(c.totalTarget),
        dailyCommitment: Value(c.dailyCommitment),
        dueDay: Value(c.dueDay?.key),
        note: Value(c.note),
        remindAt: Value(c.remindAt),
        deadline: Value(c.deadline?.key),
        pausedAt: Value(c.pausedAt),
        archivedAt: Value(c.archivedAt),
      );
}

@Riverpod(keepAlive: true)
CommitmentsRepository commitmentsRepository(Ref ref) =>
    CommitmentsRepository(ref.watch(databaseProvider));
