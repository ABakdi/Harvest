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
  Future<CheckInResult> checkIn(
    Commitment commitment, {
    int quantity = 1,
    HarvestDay? day,
  }) async {
    final harvestDay = day ?? HarvestDay.today();

    var toLog = quantity;
    var capped = false;

    if (commitment.type == CommitmentType.project) {
      final loggedToday = await _loggedOn(commitment.uuid, harvestDay);
      final room = commitment.maxUnitsPerDay - loggedToday;
      if (toLog > room) {
        toLog = room.clamp(0, quantity);
        capped = true;
      }
    } else {
      final loggedToday = await _loggedOn(commitment.uuid, harvestDay);
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

    await _db.transaction(() async {
      await _db.into(_db.checkIns).insert(
            CheckInsCompanion.insert(
              uuid: checkInUuid,
              commitmentUuid: commitment.uuid,
              harvestDay: harvestDay.key,
              quantity: Value(toLog),
            ),
          );
      await _db.into(_db.ledger).insert(
            LedgerCompanion.insert(
              uuid: _uuid.v4(),
              kind: 'xp',
              delta: xp,
              reason: 'checkin:$checkInUuid',
              harvestDay: harvestDay.key,
            ),
          );
      await _db.into(_db.outbox).insert(
            OutboxCompanion.insert(
              targetTable: 'check_ins',
              rowUuid: checkInUuid,
              op: 'insert',
            ),
          );
    });

    await _streaks.onCheckIn(commitment, harvestDay);

    return capped
        ? CheckInCapped(quantityLogged: toLog, xpEarned: xp)
        : CheckInSuccess(quantityLogged: toLog, xpEarned: xp);
  }

  /// Undoes today's check-ins for [commitment] — same-day corrections only.
  Future<void> undoToday(Commitment commitment, {HarvestDay? day}) async {
    final harvestDay = day ?? HarvestDay.today();
    final rows = await (_db.select(_db.checkIns)
          ..where(
            (c) =>
                c.commitmentUuid.equals(commitment.uuid) &
                c.harvestDay.equals(harvestDay.key) &
                c.deletedAt.isNull(),
          ))
        .get();

    await _db.transaction(() async {
      for (final row in rows) {
        await (_db.delete(_db.checkIns)..where((c) => c.uuid.equals(row.uuid)))
            .go();
        await (_db.delete(_db.ledger)
              ..where((l) => l.reason.equals('checkin:${row.uuid}')))
            .go();
        await _db.into(_db.outbox).insert(
              OutboxCompanion.insert(
                targetTable: 'check_ins',
                rowUuid: row.uuid,
                op: 'delete',
              ),
            );
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
}

@Riverpod(keepAlive: true)
CheckInService checkInService(Ref ref) => CheckInService(
      ref.watch(databaseProvider),
      ref.watch(streakServiceProvider),
    );
