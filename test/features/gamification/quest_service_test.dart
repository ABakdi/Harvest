import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/commitments/domain/check_in_service.dart';
import 'package:harvest/features/commitments/domain/commitment.dart';
import 'package:harvest/features/commitments/domain/schedule.dart';
import 'package:harvest/features/gamification/domain/quest_service.dart';
import 'package:harvest/features/gamification/domain/streak_service.dart';

void main() {
  late HarvestDatabase db;
  late QuestService quests;
  late StreakService streaks;
  late CheckInService checkIns;
  final day = HarvestDay.parse('2026-09-02');

  setUp(() {
    db = HarvestDatabase.forTesting(NativeDatabase.memory());
    quests = QuestService(db);
    streaks = StreakService(db);
    checkIns = CheckInService(db, streaks);
  });

  tearDown(() => db.close());

  Future<Commitment> habit(String id) async {
    await db.into(db.commitments).insertOnConflictUpdate(
          CommitmentsCompanion.insert(
            uuid: id,
            type: 'habit',
            title: id,
            scheduleJson: const Value('{"type":"daily"}'),
          ),
        );
    return Commitment(
      uuid: id,
      type: CommitmentType.habit,
      title: id,
      createdAt: DateTime(2026),
      schedule: const DailySchedule(),
    );
  }

  group('generation', () {
    test('creates exactly four quests, once', () async {
      await quests.ensureGenerated(day);
      await quests.ensureGenerated(day);
      final rows = await db.select(db.quests).get();
      expect(rows.length, QuestService.questsPerDay);
      expect(rows.map((r) => r.harvestDay).toSet(), {day.key});
    });

    test('is deterministic for a given day', () async {
      await quests.ensureGenerated(day);
      final first =
          (await db.select(db.quests).get()).map((r) => r.templateId).toSet();

      final db2 = HarvestDatabase.forTesting(NativeDatabase.memory());
      await QuestService(db2).ensureGenerated(day);
      final second =
          (await db2.select(db2.quests).get()).map((r) => r.templateId).toSet();
      await db2.close();

      expect(first, second);
    });
  });

  group('claiming', () {
    test('pays out once and only when the target is met', () async {
      final template = questPool.firstWhere((t) => t.id == 'habits2');
      await db.into(db.quests).insert(
            QuestsCompanion.insert(
              uuid: 'q1',
              harvestDay: day.key,
              templateId: template.id,
              target: template.target,
            ),
          );

      // Not enough progress yet.
      await checkIns.checkIn(await habit('a'), day: day);
      expect(await quests.claim('q1'), isFalse);

      await checkIns.checkIn(await habit('b'), day: day);
      expect(await quests.claim('q1'), isTrue);
      // Double-claim refused.
      expect(await quests.claim('q1'), isFalse);

      final rewards = await (db.select(db.ledger)
            ..where((l) => l.reason.equals('quest:habits2')))
          .get();
      expect(rewards.single.delta, template.amount);
      expect(rewards.single.kind, 'coin');
    });
  });

  group('freeze store', () {
    test('buying spends coins and respects the cap', () async {
      // Grant 250 coins.
      await db.into(db.ledger).insert(
            LedgerCompanion.insert(
              uuid: 'seed',
              kind: 'coin',
              delta: 250,
              reason: 'test',
              harvestDay: day.key,
            ),
          );

      expect(await streaks.buyFreeze(day: day), isTrue);
      expect(await streaks.buyFreeze(day: day), isTrue);
      // Cap of 2 reached.
      expect(await streaks.buyFreeze(day: day), isFalse);

      final sum = db.ledger.delta.sum();
      final query = db.selectOnly(db.ledger)
        ..addColumns([sum])
        ..where(db.ledger.kind.equals('coin'));
      final balance = (await query.getSingle()).read(sum) ?? 0;
      expect(balance, 250 - 2 * freezeCost);
    });

    test('refused when the balance is short', () async {
      expect(await streaks.buyFreeze(day: day), isFalse);
    });
  });
}
