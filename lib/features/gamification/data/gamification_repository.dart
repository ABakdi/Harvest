import 'package:drift/drift.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/db/database_provider.dart';
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

  /// The global streak row; zeros until the streak engine writes it.
  Stream<({int current, int best})> watchGlobalStreak() {
    final query = _db.select(_db.streaks)
      ..where((s) => s.scope.equals('global'));
    return query.watchSingleOrNull().map(
          (row) => (current: row?.current ?? 0, best: row?.best ?? 0),
        );
  }
}

@Riverpod(keepAlive: true)
GamificationRepository gamificationRepository(Ref ref) =>
    GamificationRepository(ref.watch(databaseProvider));

@riverpod
Stream<int> xpTotal(Ref ref) =>
    ref.watch(gamificationRepositoryProvider).watchXpTotal();

@riverpod
Stream<({int current, int best})> globalStreak(Ref ref) =>
    ref.watch(gamificationRepositoryProvider).watchGlobalStreak();
