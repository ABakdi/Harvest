import 'package:drift/drift.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/db/database_provider.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/commitments/domain/commitment.dart';
import 'package:harvest/features/gamification/domain/streak_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

part 'check_in_service.g.dart';

/// XP values from the gamification spec.
abstract final class Xp {
  static const habitOrTodo = 10;
  static const perProjectUnit = 2;
}

sealed class CheckInResult {
  const CheckInResult();
}

final class CheckInSuccess extends CheckInResult {
  const CheckInSuccess({required this.quantityLogged, required this.xpEarned});

  final int quantityLogged;
  final int xpEarned;
}

/// The over-log cap (business rule #2) refused part or all of the quantity.
final class CheckInCapped extends CheckInResult {
  const CheckInCapped({required this.quantityLogged, required this.xpEarned});

  final int quantityLogged;
  final int xpEarned;
}

/// Writes check-ins with validation, XP ledger entries, and outbox rows —
/// the single path through which effort enters the database.
class CheckInService {
  CheckInService(this._db, this._streaks);

  final HarvestDatabase _db;
  final StreakService _streaks;
  static const _uuid = Uuid();

  /// Logs [quantity] units for [commitment] on today's Harvest Day.
  /// The cap is read and the rows written inside one transaction, so
  /// two fast taps cannot both slip under it.
  Future<CheckInResult> checkIn(
    Commitment commitment, {
    int quantity = 1,
    HarvestDay? day,
  }) async {
    final harvestDay = day ?? HarvestDay.today();

    final result = await _db.transaction(() async {
      var toLog = quantity;
      var capped = false;
      final loggedToday = await _loggedOn(commitment.uuid, harvestDay);

      if (commitment.type == CommitmentType.project) {
        final room = commitment.maxUnitsPerDay - loggedToday;
        if (toLog > room) {
          toLog = room.clamp(0, quantity);
          capped = true;
        }
      } else {
        if (loggedToday > 0) {
          // Habits and to-dos are once per day; a second tap is a no-op.
          return const CheckInCapped(quantityLogged: 0, xpEarned: 0);
        }
        toLog = 1;
      }
      if (toLog <= 0) {
        return const CheckInCapped(quantityLogged: 0, xpEarned: 0);
      }

      final xp = commitment.type == CommitmentType.project
          ? Xp.perProjectUnit * toLog
          : Xp.habitOrTodo;
      final checkInUuid = _uuid.v4();
      await _db
          .into(_db.checkIns)
          .insert(
            CheckInsCompanion.insert(
              uuid: checkInUuid,
              commitmentUuid: commitment.uuid,
              harvestDay: harvestDay.key,
              quantity: Value(toLog),
            ),
          );
      await _db
          .into(_db.ledger)
          .insert(
            LedgerCompanion.insert(
              uuid: _uuid.v4(),
              kind: 'xp',
              delta: xp,
              reason: 'checkin:$checkInUuid',
              harvestDay: harvestDay.key,
            ),
          );
      await _outbox(checkInUuid, 'insert');
      return capped
          ? CheckInCapped(quantityLogged: toLog, xpEarned: xp)
          : CheckInSuccess(quantityLogged: toLog, xpEarned: xp);
    });

    final logged = switch (result) {
      CheckInSuccess(:final quantityLogged) => quantityLogged,
      CheckInCapped(:final quantityLogged) => quantityLogged,
    };
    if (logged > 0) await _streaks.onCheckIn(commitment, harvestDay);
    return result;
  }

  /// Undoes today's check-ins for [commitment] — same-day corrections
  /// only. Rows are soft-deleted and the XP is reversed with its own
  /// ledger entry, so history stays honest and sync can follow.
  Future<void> undoToday(Commitment commitment, {HarvestDay? day}) async {
    final harvestDay = day ?? HarvestDay.today();
    final now = DateTime.now();

    await _db.transaction(() async {
      final rows =
          await (_db.select(_db.checkIns)..where(
                (c) =>
                    c.commitmentUuid.equals(commitment.uuid) &
                    c.harvestDay.equals(harvestDay.key) &
                    c.deletedAt.isNull(),
              ))
              .get();
      for (final row in rows) {
        await (_db.update(
          _db.checkIns,
        )..where((c) => c.uuid.equals(row.uuid))).write(
          CheckInsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
        );
        final earned = _db.ledger.delta.sum();
        final earnedQuery = _db.selectOnly(_db.ledger)
          ..addColumns([earned])
          ..where(_db.ledger.reason.equals('checkin:${row.uuid}'));
        final xp = (await earnedQuery.getSingle()).read(earned) ?? 0;
        if (xp != 0) {
          await _db
              .into(_db.ledger)
              .insert(
                LedgerCompanion.insert(
                  uuid: _uuid.v4(),
                  kind: 'xp',
                  delta: -xp,
                  reason: 'undo:${row.uuid}',
                  harvestDay: harvestDay.key,
                ),
              );
        }
        await _outbox(row.uuid, 'update');
      }
    });
    await _streaks.onUndo(commitment, harvestDay);
  }

  Future<int> _loggedOn(String commitmentUuid, HarvestDay day) async {
    final quantity = _db.checkIns.quantity.sum();
    final query = _db.selectOnly(_db.checkIns)
      ..addColumns([quantity])
      ..where(
        _db.checkIns.commitmentUuid.equals(commitmentUuid) &
            _db.checkIns.harvestDay.equals(day.key) &
            _db.checkIns.deletedAt.isNull(),
      );
    final row = await query.getSingle();
    return row.read(quantity) ?? 0;
  }

  Future<void> _outbox(String uuid, String op) => _db
      .into(_db.outbox)
      .insert(
        OutboxCompanion.insert(
          targetTable: 'check_ins',
          rowUuid: uuid,
          op: op,
        ),
      );
}

@Riverpod(keepAlive: true)
CheckInService checkInService(Ref ref) => CheckInService(
  ref.watch(databaseProvider),
  ref.watch(streakServiceProvider),
);
