import 'package:drift/drift.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/domain/harvest_day.dart';

/// What counts as *doing something* in this app — one answer.
///
/// Three places used to decide this for themselves, and they
/// disagreed ([[Audit-v2-Beta]] B-04): the goal counted check-ins and
/// scheduled-album pictures, the streak engine's idle fast path
/// counted check-ins only, and the comeback ladder counted check-ins
/// and expenses. Someone who wrote their sleep down every morning
/// was, to the ladder, a week absent.
///
/// This is the list, and everything asks it. A day is active when any
/// of these has a row on it:
///
/// * a check-in (habits, to-dos, projects — and a finished gym
///   session, which goes through the same door);
/// * a picture in a **scheduled** album, which is a seed;
/// * an expense;
/// * a night written down;
/// * a weight logged;
/// * a workout session finished.
///
/// Steps are not on it: the phone counted those, not me
/// ([[Health]] H3).
class ActivityLog {
  const ActivityLog(this._db);

  final HarvestDatabase _db;

  /// Whether anything at all was logged on a day in `[from, to]`.
  Future<bool> anyBetween(HarvestDay from, HarvestDay to) async {
    for (final query in _daysQueries(from: from, to: to, limit: 1)) {
      if ((await query).isNotEmpty) return true;
    }
    return false;
  }

  Future<bool> activeOn(HarvestDay day) => anyBetween(day, day);

  /// The most recent active day, or null when nothing was ever logged.
  Future<HarvestDay?> lastActiveDay({HarvestDay? upTo}) async {
    HarvestDay? latest;
    for (final query in _daysQueries(to: upTo, latestFirst: true, limit: 1)) {
      for (final key in await query) {
        final day = HarvestDay.tryParse(key);
        if (day == null) continue;
        if (latest == null || day.compareTo(latest) > 0) latest = day;
      }
    }
    return latest;
  }

  /// One query per table, each answering "which days have a row",
  /// bounded and ordered as asked. Kept as a list so the definition
  /// above is the only place a table is added.
  List<Future<List<String>>> _daysQueries({
    HarvestDay? from,
    HarvestDay? to,
    bool latestFirst = false,
    int? limit,
  }) {
    Future<List<String>> pick<T extends Table, R>(
      TableInfo<T, R> table,
      TextColumn dayColumn,
      Expression<bool> alive,
    ) async {
      final query = _db.selectOnly(table, distinct: true)
        ..addColumns([dayColumn])
        ..where(alive);
      if (from != null) {
        query.where(dayColumn.isBiggerOrEqualValue(from.key));
      }
      if (to != null) query.where(dayColumn.isSmallerOrEqualValue(to.key));
      if (latestFirst) query.orderBy([OrderingTerm.desc(dayColumn)]);
      if (limit != null) query.limit(limit);
      return [
        for (final row in await query.get()) row.read(dayColumn)!,
      ];
    }

    final scheduledAlbums = _db.selectOnly(_db.albums)
      ..addColumns([_db.albums.uuid])
      ..where(
        _db.albums.deletedAt.isNull() & _db.albums.scheduleJson.isNotNull(),
      );

    return [
      pick(
        _db.checkIns,
        _db.checkIns.harvestDay,
        _db.checkIns.deletedAt.isNull(),
      ),
      pick(
        _db.memories,
        _db.memories.harvestDay,
        _db.memories.deletedAt.isNull() &
            _db.memories.albumUuid.isInQuery(scheduledAlbums),
      ),
      pick(
        _db.expenses,
        _db.expenses.harvestDay,
        _db.expenses.deletedAt.isNull(),
      ),
      pick(
        _db.sleepSessions,
        _db.sleepSessions.harvestDay,
        _db.sleepSessions.deletedAt.isNull(),
      ),
      pick(
        _db.bodyWeights,
        _db.bodyWeights.harvestDay,
        _db.bodyWeights.deletedAt.isNull(),
      ),
      pick(
        _db.workoutSessions,
        _db.workoutSessions.harvestDay,
        _db.workoutSessions.deletedAt.isNull() &
            _db.workoutSessions.endedAt.isNotNull(),
      ),
    ];
  }
}
