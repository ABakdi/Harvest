import 'dart:math';

import 'package:drift/drift.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/db/database_provider.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/commitments/domain/commitment.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

part 'quest_service.g.dart';

/// What a quest pays out.
enum QuestReward { xp, coin }

/// A stored daily quest, decoupled from the database row type.
class QuestState {
  const QuestState({
    required this.uuid,
    required this.templateId,
    required this.target,
    required this.claimed,
  });

  final String uuid;
  final String templateId;
  final int target;
  final bool claimed;
}

/// A quest blueprint: id, goal, reward, and how to measure progress.
class QuestTemplate {
  const QuestTemplate({
    required this.id,
    required this.target,
    required this.reward,
    required this.amount,
    required this.progress,
  });

  final String id;
  final int target;
  final QuestReward reward;
  final int amount;
  final Future<int> Function(HarvestDatabase db, HarvestDay day) progress;
}

/// The Phase 1 quest pool. Later phases append finance/sleep/screen quests.
final questPool = <QuestTemplate>[
  QuestTemplate(
    id: 'habits2',
    target: 2,
    reward: QuestReward.coin,
    amount: 20,
    progress: (db, day) => _distinctChecked(db, day, CommitmentType.habit),
  ),
  QuestTemplate(
    id: 'habitsEarly',
    target: 2,
    reward: QuestReward.xp,
    amount: 50,
    progress: (db, day) =>
        _distinctChecked(db, day, CommitmentType.habit, beforeHour: 9),
  ),
  const QuestTemplate(
    id: 'projectUnits20',
    target: 20,
    reward: QuestReward.coin,
    amount: 30,
    progress: _projectUnits,
  ),
  QuestTemplate(
    id: 'todos2',
    target: 2,
    reward: QuestReward.xp,
    amount: 25,
    progress: (db, day) => _distinctChecked(db, day, CommitmentType.todo),
  ),
  QuestTemplate(
    id: 'actions4',
    target: 4,
    reward: QuestReward.xp,
    amount: 40,
    progress: (db, day) => _distinctChecked(db, day, null),
  ),
];

Future<int> _distinctChecked(
  HarvestDatabase db,
  HarvestDay day,
  CommitmentType? type, {
  int? beforeHour,
}) async {
  final join = db.select(db.checkIns).join([
    innerJoin(
      db.commitments,
      db.commitments.uuid.equalsExp(db.checkIns.commitmentUuid),
    ),
  ])
    ..where(
      db.checkIns.harvestDay.equals(day.key) & db.checkIns.deletedAt.isNull(),
    );
  if (type != null) {
    join.where(db.commitments.type.equals(type.name));
  }
  final rows = await join.get();
  final seen = <String>{};
  for (final row in rows) {
    final checkIn = row.readTable(db.checkIns);
    if (beforeHour != null) {
      final at = checkIn.loggedAt.toLocal();
      final inWindow = at.hour >= HarvestDay.boundaryHour &&
          at.hour < beforeHour &&
          HarvestDay.of(at) == day;
      if (!inWindow) continue;
    }
    seen.add(checkIn.commitmentUuid);
  }
  return seen.length;
}

Future<int> _projectUnits(HarvestDatabase db, HarvestDay day) async {
  final quantity = db.checkIns.quantity.sum();
  final query = db.selectOnly(db.checkIns)
    ..addColumns([quantity])
    ..join([
      innerJoin(
        db.commitments,
        db.commitments.uuid.equalsExp(db.checkIns.commitmentUuid),
      ),
    ])
    ..where(
      db.checkIns.harvestDay.equals(day.key) &
          db.checkIns.deletedAt.isNull() &
          db.commitments.type.equals(CommitmentType.project.name),
    );
  final row = await query.getSingle();
  return row.read(quantity) ?? 0;
}

/// Generates, measures, and pays out the four daily quests.
class QuestService {
  QuestService(this._db);

  final HarvestDatabase _db;
  static const _uuid = Uuid();
  static const questsPerDay = 4;

  /// Creates today's quests if they don't exist yet. Deterministic per
  /// day, so running twice (app open + background job) is harmless.
  Future<void> ensureGenerated(HarvestDay day) async {
    final existing = await (_db.select(_db.quests)
          ..where((q) => q.harvestDay.equals(day.key))
          ..limit(1))
        .getSingleOrNull();
    if (existing != null) return;

    final rng = Random(day.key.hashCode);
    final pool = [...questPool]..shuffle(rng);
    final picked = pool.take(questsPerDay);

    await _db.batch((batch) {
      for (final template in picked) {
        batch.insert(
          _db.quests,
          QuestsCompanion.insert(
            uuid: _uuid.v4(),
            harvestDay: day.key,
            templateId: template.id,
            target: template.target,
          ),
        );
      }
    });
  }

  Stream<List<QuestState>> watchDay(HarvestDay day) => (_db.select(_db.quests)
        ..where((q) => q.harvestDay.equals(day.key))
        ..orderBy([(q) => OrderingTerm.asc(q.uuid)]))
      .watch()
      .map(
        (rows) => rows
            .map(
              (row) => QuestState(
                uuid: row.uuid,
                templateId: row.templateId,
                target: row.target,
                claimed: row.claimedAt != null,
              ),
            )
            .toList(),
      );

  Future<int> measure(QuestTemplate template, HarvestDay day) =>
      template.progress(_db, day);

  /// Pays out a completed, unclaimed quest. Verifies progress server-side
  /// of the UI so a stale button can't double-claim.
  Future<bool> claim(String questUuid) async {
    final quest = await (_db.select(_db.quests)
          ..where((q) => q.uuid.equals(questUuid)))
        .getSingleOrNull();
    if (quest == null || quest.claimedAt != null) return false;

    final template =
        questPool.firstWhere((t) => t.id == quest.templateId);
    final progress =
        await measure(template, HarvestDay.parse(quest.harvestDay));
    if (progress < quest.target) return false;

    await _db.transaction(() async {
      await (_db.update(_db.quests)..where((q) => q.uuid.equals(questUuid)))
          .write(
        QuestsCompanion(
          progress: Value(progress),
          claimedAt: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
        ),
      );
      await _db.into(_db.ledger).insert(
            LedgerCompanion.insert(
              uuid: _uuid.v4(),
              kind: template.reward == QuestReward.xp ? 'xp' : 'coin',
              delta: template.amount,
              reason: 'quest:${quest.templateId}',
              harvestDay: quest.harvestDay,
            ),
          );
    });
    return true;
  }
}

@Riverpod(keepAlive: true)
QuestService questService(Ref ref) =>
    QuestService(ref.watch(databaseProvider));
