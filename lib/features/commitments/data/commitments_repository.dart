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

  /// Archived seeds, most recently put away first — the archive screen.
  Stream<List<Commitment>> watchArchived() {
    final query = _db.select(_db.commitments)
      ..where((c) => c.archivedAt.isNotNull() & c.deletedAt.isNull())
      ..orderBy([(c) => OrderingTerm.desc(c.archivedAt)]);
    return query.watch().map(_toDomainList);
  }

  /// One seed by uuid, archived or not; null when it is gone.
  Stream<Commitment?> watchOne(String uuid) {
    final query = _db.select(_db.commitments)
      ..where((c) => c.uuid.equals(uuid) & c.deletedAt.isNull());
    return query.watchSingleOrNull().map(
      (row) => row == null ? null : toDomain(row),
    );
  }

  /// Every check-in for one seed, newest day first — its history.
  Stream<List<({HarvestDay day, int quantity, DateTime loggedAt})>>
  watchHistory(String uuid) {
    final query = _db.select(_db.checkIns)
      ..where((c) => c.commitmentUuid.equals(uuid) & c.deletedAt.isNull())
      ..orderBy([(c) => OrderingTerm.desc(c.loggedAt)]);
    return query.watch().map((rows) {
      final byDay = <String, ({int quantity, DateTime loggedAt})>{};
      for (final row in rows) {
        final seen = byDay[row.harvestDay];
        byDay[row.harvestDay] = (
          quantity: (seen?.quantity ?? 0) + row.quantity,
          loggedAt: seen == null || seen.loggedAt.isBefore(row.loggedAt)
              ? row.loggedAt
              : seen.loggedAt,
        );
      }
      final days = byDay.keys.map(HarvestDay.tryParse).nonNulls.toList()
        ..sort((a, b) => b.compareTo(a));
      return [
        for (final day in days)
          (
            day: day,
            quantity: byDay[day.key]!.quantity,
            loggedAt: byDay[day.key]!.loggedAt,
          ),
      ];
    });
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
    DateTime? createdAt,
  }) async {
    final commitment = Commitment(
      uuid: _uuid.v4(),
      type: type,
      title: title,
      // When the seed starts counting. Only tests pass it; the app
      // always plants in the present.
      createdAt: createdAt ?? DateTime.now(),
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

  /// Vacation mode on/off for a habit. [at] is when the pause takes
  /// effect: days that ended before it are still judged, so pausing
  /// after a miss cannot rewrite the miss.
  Future<void> setPaused(String uuid, {required bool paused, DateTime? at}) =>
      _db.transaction(() async {
        final now = at ?? DateTime.now();
        await (_db.update(
          _db.commitments,
        )..where((c) => c.uuid.equals(uuid))).write(
          CommitmentsCompanion(
            pausedAt: Value(paused ? now : null),
            updatedAt: Value(now),
          ),
        );
        await _appendOutbox('commitments', uuid, 'update');
      });

  /// Moves one seed's reminder, and nothing else about it.
  ///
  /// The daily cycle shifts reminders when the wake time moves, and it
  /// has no business rewriting a whole row to do it.
  Future<void> setRemindAt(String uuid, String? remindAt) =>
      _db.transaction(() async {
        await (_db.update(
          _db.commitments,
        )..where((c) => c.uuid.equals(uuid))).write(
          CommitmentsCompanion(
            remindAt: Value(remindAt),
            updatedAt: Value(DateTime.now()),
          ),
        );
        await _appendOutbox('commitments', uuid, 'update');
      });

  /// Puts a seed away, with the note that says why. History stays.
  Future<void> archive(String uuid, {String? note}) =>
      _db.transaction(() async {
        final now = DateTime.now();
        await (_db.update(
          _db.commitments,
        )..where((c) => c.uuid.equals(uuid))).write(
          CommitmentsCompanion(
            archivedAt: Value(now),
            archiveNote: Value(note),
            updatedAt: Value(now),
          ),
        );
        await _appendOutbox('commitments', uuid, 'update');
      });

  /// Back onto the field, note and all cleared.
  Future<void> restore(String uuid) => _db.transaction(() async {
    await (_db.update(
      _db.commitments,
    )..where((c) => c.uuid.equals(uuid))).write(
      CommitmentsCompanion(
        archivedAt: const Value(null),
        archiveNote: const Value(null),
        updatedAt: Value(DateTime.now()),
      ),
    );
    await _appendOutbox('commitments', uuid, 'update');
  });

  /// Gone for good: the seed, its check-ins, its notes and its streak.
  ///
  /// The ordinary way to retire a seed is [archive], which keeps every
  /// row it ever wrote. This is the other case — the one I planted by
  /// mistake — and for it a soft delete is the wrong answer: the row
  /// would keep skewing stats for thirty days and then vanish anyway.
  /// The UI confirms first; nothing here is recoverable.
  Future<void> hardDelete(String uuid) => _db.transaction(() async {
    await (_db.delete(
      _db.seedNotes,
    )..where((n) => n.commitmentUuid.equals(uuid))).go();
    await (_db.delete(
      _db.checkIns,
    )..where((c) => c.commitmentUuid.equals(uuid))).go();
    await (_db.delete(_db.streaks)..where((s) => s.scope.equals(uuid))).go();
    await (_db.update(_db.pomodoroSessions)
          ..where((p) => p.commitmentUuid.equals(uuid)))
        .write(const PomodoroSessionsCompanion(commitmentUuid: Value(null)));
    await (_db.delete(
      _db.commitments,
    )..where((c) => c.uuid.equals(uuid))).go();
    await _appendOutbox('commitments', uuid, 'delete');
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
      archiveNote: row.archiveNote,
    );
  }

  CommitmentsCompanion _toRow(Commitment c) => CommitmentsCompanion.insert(
    uuid: c.uuid,
    type: c.type.name,
    title: c.title,
    createdAt: Value(c.createdAt),
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
    archiveNote: Value(c.archiveNote),
  );
}

@Riverpod(keepAlive: true)
CommitmentsRepository commitmentsRepository(Ref ref) =>
    CommitmentsRepository(ref.watch(databaseProvider));
