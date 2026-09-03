import 'package:drift/drift.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/db/database_provider.dart';
import 'package:harvest/core/domain/harvest_day.dart';
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
