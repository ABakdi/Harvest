import 'package:drift/drift.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/db/database_provider.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/gamification/domain/day_activity.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'gamification_repository.g.dart';

/// Farmer ranks, one step per 1,000 lifetime XP.
enum FarmerRank {
  sprout,
  seedling,
  gardener,
  harvester,
  masterFarmer;

  static const xpPerRank = 1000;

  static FarmerRank forXp(int xp) {
    final index = (xp ~/ xpPerRank).clamp(0, FarmerRank.values.length - 1);
    return FarmerRank.values[index];
  }
}

class GamificationRepository {
  GamificationRepository(this._db);

  final HarvestDatabase _db;

  /// Lifetime XP — the sum over the ledger, never a stored counter.
  Stream<int> watchXpTotal() {
    final sum = _db.ledger.delta.sum();
    final query = _db.selectOnly(_db.ledger)
      ..addColumns([sum])
      ..where(_db.ledger.kind.equals('xp'));
    return query.watchSingle().map((row) => row.read(sum) ?? 0);
  }

  /// Lifetime coin balance — earnings minus spending over the ledger.
  Stream<int> watchCoinTotal() {
    final sum = _db.ledger.delta.sum();
    final query = _db.selectOnly(_db.ledger)
      ..addColumns([sum])
      ..where(_db.ledger.kind.equals('coin'));
    return query.watchSingle().map((row) => row.read(sum) ?? 0);
  }

  /// The global streak row; zeros until the streak engine writes it.
  Stream<({int current, int best, int freezes})> watchGlobalStreak() {
    final query = _db.select(_db.streaks)
      ..where((s) => s.scope.equals('global'));
    return query.watchSingleOrNull().map(
      (row) => (
        current: row?.current ?? 0,
        best: row?.best ?? 0,
        freezes: row?.freezesStored ?? 0,
      ),
    );
  }

  /// Distinct commitments checked per Harvest Day since [from] —
  /// the activity heat-map's fuel.
  Stream<Map<String, int>> watchDailyActivity(HarvestDay from) {
    final query = _db.select(_db.checkIns)
      ..where(
        (c) =>
            c.harvestDay.isBiggerOrEqualValue(from.key) & c.deletedAt.isNull(),
      );
    return query.watch().map((rows) {
      final byDay = <String, Set<String>>{};
      for (final row in rows) {
        byDay.putIfAbsent(row.harvestDay, () => {}).add(row.commitmentUuid);
      }
      return byDay.map((day, set) => MapEntry(day, set.length));
    });
  }

  /// Each day's productive actions from [start] to [end] — the
  /// heat-map's squares ([dayActivity], the web's rule too). Watches the
  /// four tables that feed it.
  Stream<Map<String, int>> watchHeatActivity(HarvestDay start, HarvestDay end) {
    final trigger = _db.customSelect(
      'SELECT 1',
      readsFrom: {_db.checkIns, _db.commitments, _db.albums, _db.memories},
    );
    return trigger.watch().asyncMap((_) async {
      final checkIns =
          await (_db.select(_db.checkIns)..where(
                (c) => c.harvestDay.isBetweenValues(start.key, end.key),
              ))
              .get();
      final seeds = await _db.select(_db.commitments).get();
      final albums = await _db.select(_db.albums).get();
      final memories =
          await (_db.select(_db.memories)..where(
                (m) => m.harvestDay.isBetweenValues(start.key, end.key),
              ))
              .get();
      return dayActivity(
        checkIns: [
          for (final row in checkIns)
            (
              commitmentUuid: row.commitmentUuid,
              harvestDay: row.harvestDay,
              quantity: row.quantity,
              deleted: row.deletedAt != null,
            ),
        ],
        seeds: [
          for (final row in seeds)
            (
              uuid: row.uuid,
              type: row.type,
              dailyCommitment: row.dailyCommitment,
              deleted: row.deletedAt != null,
            ),
        ],
        albums: [
          for (final row in albums)
            (
              uuid: row.uuid,
              scheduled: row.scheduleJson != null,
              deleted: row.deletedAt != null,
            ),
        ],
        memories: [
          for (final row in memories)
            (
              albumUuid: row.albumUuid,
              harvestDay: row.harvestDay,
              deleted: row.deletedAt != null,
            ),
        ],
        start: start,
        end: end,
      );
    });
  }

  /// Lifetime check-in count.
  Stream<int> watchCheckInCount() {
    final count = _db.checkIns.uuid.count();
    final query = _db.selectOnly(_db.checkIns)
      ..addColumns([count])
      ..where(_db.checkIns.deletedAt.isNull());
    return query.watchSingle().map((row) => row.read(count) ?? 0);
  }

  /// XP earned since [from] (inclusive) — the weekly report's total.
  Stream<int> watchXpSince(HarvestDay from) {
    final sum = _db.ledger.delta.sum();
    final query = _db.selectOnly(_db.ledger)
      ..addColumns([sum])
      ..where(
        _db.ledger.kind.equals('xp') &
            _db.ledger.harvestDay.isBiggerOrEqualValue(from.key),
      );
    return query.watchSingle().map((row) => row.read(sum) ?? 0);
  }

  /// The day the global streak was last earned, if it ever was.
  Stream<HarvestDay?> watchLastEarnedDay() {
    final query = _db.select(_db.streaks)
      ..where((s) => s.scope.equals('global'));
    return query.watchSingleOrNull().map(
      (row) => HarvestDay.tryParse(row?.lastEarnedDay),
    );
  }

  /// Every non-global streak row, keyed by commitment uuid.
  Stream<Map<String, ({int current, int best})>> watchCommitmentStreaks() {
    final query = _db.select(_db.streaks)
      ..where((s) => s.scope.equals('global').not());
    return query.watch().map(
      (rows) => {
        for (final row in rows)
          row.scope: (current: row.current, best: row.best),
      },
    );
  }
}

@Riverpod(keepAlive: true)
GamificationRepository gamificationRepository(Ref ref) =>
    GamificationRepository(ref.watch(databaseProvider));
