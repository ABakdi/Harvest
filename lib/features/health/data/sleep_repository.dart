import 'package:drift/drift.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/db/database_provider.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/health/domain/sleep.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

part 'sleep_repository.g.dart';

/// Nights, written and read back.
///
/// One night per morning: logging the same morning twice replaces what
/// is there rather than adding a second night, because I did not sleep
/// twice.
class SleepRepository {
  SleepRepository(this._db);

  final HarvestDatabase _db;
  static const _uuid = Uuid();

  Stream<List<SleepNight>> watchRecent({int nights = 30}) {
    final query = _db.select(_db.sleepSessions)
      ..where((s) => s.deletedAt.isNull())
      ..orderBy([(s) => OrderingTerm.desc(s.harvestDay)])
      ..limit(nights);
    return query.watch().map(
      (rows) => [for (final row in rows) _toNight(row)],
    );
  }

  Future<List<SleepNight>> recentOnce({int nights = 30}) async {
    final rows =
        await (_db.select(_db.sleepSessions)
              ..where((s) => s.deletedAt.isNull())
              ..orderBy([(s) => OrderingTerm.desc(s.harvestDay)])
              ..limit(nights))
            .get();
    return [for (final row in rows) _toNight(row)];
  }

  Future<SleepNight?> on(HarvestDay day) async {
    final row =
        await (_db.select(_db.sleepSessions)..where(
              (s) => s.harvestDay.equals(day.key) & s.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    return row == null ? null : _toNight(row);
  }

  /// Whether the morning is already accounted for — what decides
  /// between showing the retrospective and leaving me alone.
  Future<bool> logged(HarvestDay day) async => await on(day) != null;

  /// Writes the night, replacing any night already filed under that
  /// morning, and pays the XP the first time.
  ///
  /// Sleep touches no streak and checks nothing in: it is not a seed,
  /// and a bad night is not a broken promise. It earns [sleepXp] for
  /// being written down, once, and correcting it later corrects the
  /// record without paying again. Returns whether it paid.
  Future<bool> log({
    required HarvestDay day,
    required DateTime fellAsleepAt,
    required DateTime wokeAt,
    required int targetMinutes,
    int? restedStars,
    String? note,
  }) => _db.transaction(() async {
    // Read inside the transaction: two saves for the same morning that
    // overlap must see each other, or the morning ends up with two
    // nights and the card with an exception ([[Audit-v2-Beta]] B-07).
    final existing = await on(day);
    final uuid = existing?.uuid ?? _uuid.v4();

    await _db
        .into(_db.sleepSessions)
        .insertOnConflictUpdate(
          SleepSessionsCompanion.insert(
            uuid: uuid,
            harvestDay: day.key,
            fellAsleepAt: fellAsleepAt,
            wokeAt: wokeAt,
            targetMinutes: targetMinutes,
            restedStars: Value(restedStars),
            note: Value(note),
            updatedAt: Value(DateTime.now()),
          ),
        );
    var paid = false;
    if (existing == null && await _xpNet(uuid) == 0) {
      await _db
          .into(_db.ledger)
          .insert(
            LedgerCompanion.insert(
              uuid: _uuid.v4(),
              kind: 'xp',
              delta: sleepXp,
              reason: 'sleep:$uuid',
              harvestDay: day.key,
            ),
          );
      paid = true;
    }
    await _outbox(uuid, existing == null ? 'insert' : 'update');
    return paid;
  });

  /// Removes a night, and takes back what writing it down paid — with
  /// a mirror row, so the ledger stays a sum of true events
  /// ([[Audit-v2-Beta]] B-06).
  Future<void> remove(String uuid) => _db.transaction(() async {
    final row = await (_db.select(
      _db.sleepSessions,
    )..where((s) => s.uuid.equals(uuid))).getSingleOrNull();
    await (_db.update(_db.sleepSessions)..where((s) => s.uuid.equals(uuid)))
        .write(SleepSessionsCompanion(deletedAt: Value(DateTime.now())));
    final net = await _xpNet(uuid);
    if (row != null && net > 0) {
      await _db
          .into(_db.ledger)
          .insert(
            LedgerCompanion.insert(
              uuid: _uuid.v4(),
              kind: 'xp',
              delta: -net,
              reason: 'sleep-undo:$uuid',
              harvestDay: row.harvestDay,
            ),
          );
    }
    await _outbox(uuid, 'delete');
  });

  /// What this night's XP nets to: the payment less any reversal.
  Future<int> _xpNet(String uuid) async {
    final sum = _db.ledger.delta.sum();
    final query = _db.selectOnly(_db.ledger)
      ..addColumns([sum])
      ..where(
        _db.ledger.reason.equals('sleep:$uuid') |
            _db.ledger.reason.equals('sleep-undo:$uuid'),
      );
    return (await query.getSingle()).read(sum) ?? 0;
  }

  Future<void> _outbox(String rowUuid, String op) =>
      _db.logChange('sleep_sessions', rowUuid, op);

  static SleepNight _toNight(SleepSessionRow row) => SleepNight(
    uuid: row.uuid,
    day: HarvestDay.tryParse(row.harvestDay) ?? HarvestDay.today(),
    fellAsleepAt: row.fellAsleepAt,
    wokeAt: row.wokeAt,
    targetMinutes: row.targetMinutes,
    restedStars: row.restedStars,
    note: row.note,
  );
}

@Riverpod(keepAlive: true)
SleepRepository sleepRepository(Ref ref) =>
    SleepRepository(ref.watch(databaseProvider));
