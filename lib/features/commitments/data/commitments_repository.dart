import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
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
  Stream<List<Commitment>> watchActive() =>
      _activeQuery().watch().map(_toDomainList);

  /// One-shot version of [watchActive] for background work.
  Future<List<Commitment>> activeOnce() async =>
      _toDomainList(await _activeQuery().get());

  SimpleSelectStatement<$CommitmentsTable, CommitmentRow> _activeQuery() =>
      _db.select(_db.commitments)
        ..where((c) => c.archivedAt.isNull() & c.deletedAt.isNull())
        ..orderBy([(c) => OrderingTerm.asc(c.createdAt)]);

  /// Rows that cannot be mapped are skipped and logged rather than
  /// taking the whole field down with them.
  List<Commitment> _toDomainList(List<CommitmentRow> rows) {
    final result = <Commitment>[];
    for (final row in rows) {
      final commitment = toDomain(row);
      if (commitment != null) result.add(commitment);
    }
    return result;
  }

  /// Units logged for one commitment on one day.
  Future<int> loggedOnOnce(String commitmentUuid, HarvestDay day) async {
    final quantity = _db.checkIns.quantity.sum();
    final query = _db.selectOnly(_db.checkIns)
      ..addColumns([quantity])
      ..where(
        _db.checkIns.commitmentUuid.equals(commitmentUuid) &
            _db.checkIns.harvestDay.equals(day.key) &
            _db.checkIns.deletedAt.isNull(),
      );
    return (await query.getSingle()).read(quantity) ?? 0;
  }

  /// Lifetime units for one commitment.
  Future<int> totalOnce(String commitmentUuid) async {
    final quantity = _db.checkIns.quantity.sum();
    final query = _db.selectOnly(_db.checkIns)
      ..addColumns([quantity])
      ..where(
        _db.checkIns.commitmentUuid.equals(commitmentUuid) &
            _db.checkIns.deletedAt.isNull(),
      );
    return (await query.getSingle()).read(quantity) ?? 0;
  }

  /// Distinct completed days for one commitment in [day]'s week.
  Future<int> doneDaysInWeekOnce(String commitmentUuid, HarvestDay day) async {
    final query = _db.selectOnly(_db.checkIns, distinct: true)
      ..addColumns([_db.checkIns.harvestDay])
      ..where(
        _db.checkIns.commitmentUuid.equals(commitmentUuid) &
            _db.checkIns.harvestDay.isIn(day.weekDays.map((d) => d.key)) &
            _db.checkIns.deletedAt.isNull(),
      );
    return (await query.get()).length;
  }

  /// Check-ins per commitment for one Harvest Day (uuid → units logged).
  Stream<Map<String, int>> watchLoggedOn(HarvestDay day) {
    final query = _db.select(_db.checkIns)
      ..where((c) => c.harvestDay.equals(day.key) & c.deletedAt.isNull());
    return query.watch().map(_sumByCommitment);
  }

  /// Lifetime units per commitment (project progress, todo completion).
  Stream<Map<String, int>> watchTotals() {
    final query = _db.select(_db.checkIns)..where((c) => c.deletedAt.isNull());
    return query.watch().map(_sumByCommitment);
  }

  /// Distinct completed days per commitment within [day]'s week, up to and
  /// including [day] — feeds the times-per-week schedule.
  Stream<Map<String, int>> watchDoneDaysThisWeek(HarvestDay day) {
    final days = day.weekDays.map((d) => d.key).toList();
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
    await (_db.update(
      _db.commitments,
    )..where((c) => c.uuid.equals(commitment.uuid))).write(
      _toRow(commitment).copyWith(updatedAt: Value(DateTime.now())),
    );
    await _appendOutbox('commitments', commitment.uuid, 'update');
  });

  /// Vacation mode on/off for a habit.
  Future<void> setPaused(String uuid, {required bool paused}) =>
      _db.transaction(() async {
        await (_db.update(
          _db.commitments,
        )..where((c) => c.uuid.equals(uuid))).write(
          CommitmentsCompanion(
            pausedAt: Value(paused ? DateTime.now() : null),
            updatedAt: Value(DateTime.now()),
          ),
        );
        await _appendOutbox('commitments', uuid, 'update');
      });

  Future<void> archive(String uuid) => _db.transaction(() async {
    await (_db.update(
      _db.commitments,
    )..where((c) => c.uuid.equals(uuid))).write(
      CommitmentsCompanion(
        archivedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );
    await _appendOutbox('commitments', uuid, 'update');
  });

  /// Hard-deletes commitments and check-ins that were soft-deleted
  /// longer than [olderThan] ago. Archived seeds are kept: they are
  /// history, not deletions.
  Future<void> purgeDeleted({required Duration olderThan}) async {
    final cutoff = DateTime.now().subtract(olderThan);
    await _db.transaction(() async {
      await (_db.delete(
        _db.checkIns,
      )..where((c) => c.deletedAt.isSmallerThanValue(cutoff))).go();
      await (_db.delete(
        _db.commitments,
      )..where((c) => c.deletedAt.isSmallerThanValue(cutoff))).go();
    });
  }

  Future<void> _appendOutbox(String table, String rowUuid, String op) => _db
      .into(_db.outbox)
      .insert(
        OutboxCompanion.insert(
          targetTable: table,
          rowUuid: rowUuid,
          op: op,
        ),
      );

  // -------------------------------------------------------------- mapping

  /// Maps a row to the domain, tolerating what the database cannot
  /// promise: a habit without a readable schedule becomes daily, a
  /// corrupt day key is dropped, an unknown type is skipped (null).
  static Commitment? toDomain(CommitmentRow row) {
    final type = CommitmentType.values
        .where((t) => t.name == row.type)
        .firstOrNull;
    if (type == null) {
      debugPrint('[commitments] unknown type for ${row.uuid}');
      return null;
    }
    Schedule? schedule;
    if (row.scheduleJson != null) {
      try {
        schedule = Schedule.fromJson(
          jsonDecode(row.scheduleJson!) as Map<String, dynamic>,
        );
      } on Object {
        debugPrint('[commitments] unreadable schedule for ${row.uuid}');
      }
    }
    if (type == CommitmentType.habit && schedule == null) {
      schedule = const DailySchedule();
    }
    if (type == CommitmentType.project &&
        (row.totalTarget == null || row.dailyCommitment == null)) {
      debugPrint('[commitments] project without targets: ${row.uuid}');
      return null;
    }
    return Commitment(
      uuid: row.uuid,
      type: type,
      title: row.title,
      createdAt: row.createdAt,
      schedule: schedule,
      totalTarget: row.totalTarget,
      dailyCommitment: row.dailyCommitment,
      dueDay: HarvestDay.tryParse(row.dueDay),
      note: row.note,
      remindAt: row.remindAt,
      deadline: HarvestDay.tryParse(row.deadline),
      pausedAt: row.pausedAt,
      archivedAt: row.archivedAt,
    );
  }

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
