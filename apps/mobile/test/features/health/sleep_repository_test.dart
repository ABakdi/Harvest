import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/health/data/sleep_repository.dart';
import 'package:harvest/features/health/domain/sleep.dart';

/// Phase 4, M4.7. The write path, where the two rules that matter live:
/// one night per morning, and the XP is paid once however many times I
/// go back and fix the numbers.
void main() {
  late HarvestDatabase db;
  late SleepRepository sleep;

  final today = HarvestDay.parse('2026-09-07');
  final midnight = DateTime(2026, 9, 7);

  setUp(() {
    db = HarvestDatabase.forTesting(NativeDatabase.memory());
    sleep = SleepRepository(db);
  });

  tearDown(() async => db.close());

  Future<bool> log(
    HarvestDay day, {
    double from = -1,
    double to = 7,
    int? stars,
  }) => sleep.log(
    day: day,
    fellAsleepAt: midnight.add(Duration(minutes: (from * 60).round())),
    wokeAt: midnight.add(Duration(minutes: (to * 60).round())),
    targetMinutes: 8 * 60,
    restedStars: stars,
  );

  Future<int> xpTotal() async {
    final rows = await db.select(db.ledger).get();
    return rows
        .where((row) => row.reason.startsWith('sleep'))
        .fold<int>(0, (sum, row) => sum + row.delta);
  }

  group('writing a night', () {
    test('reads back what was written', () async {
      await log(today, from: -0.75, to: 6.5, stars: 4);
      final night = (await sleep.on(today))!;

      expect(night.day, today);
      expect(night.sleptMinutes, 7 * 60 + 15);
      expect(night.restedStars, 4);
      expect(night.targetMinutes, 480);
    });

    test('earns fifteen the first time', () async {
      expect(await log(today), isTrue);
      expect(await xpTotal(), sleepXp);
    });

    test('correcting it corrects the record and pays nothing again', () async {
      await log(today, to: 6);
      expect(await log(today, to: 8, stars: 5), isFalse);

      final night = (await sleep.on(today))!;
      expect(night.sleptMinutes, 9 * 60);
      expect(night.restedStars, 5);
      // One night, one payment — however many times I fix the numbers.
      expect(await sleep.recentOnce(), hasLength(1));
      expect(await xpTotal(), sleepXp);
    });

    test(
      'a correction keeps the target the night was judged by (#3)',
      () async {
        await log(today);
        await sleep.log(
          day: today,
          fellAsleepAt: midnight.add(const Duration(hours: -1)),
          wokeAt: midnight.add(const Duration(hours: 8)),
          targetMinutes: 9 * 60,
        );
        expect((await sleep.on(today))!.targetMinutes, 8 * 60);
      },
    );

    test('a correction without a note keeps the one already there', () async {
      await sleep.log(
        day: today,
        fellAsleepAt: midnight.add(const Duration(hours: -1)),
        wokeAt: midnight.add(const Duration(hours: 7)),
        targetMinutes: 8 * 60,
        note: 'late coffee',
      );
      await log(today, to: 6);
      expect((await sleep.on(today))!.note, 'late coffee');
    });

    test('a different morning is a different night', () async {
      await log(today);
      await log(today.next);
      expect(await sleep.recentOnce(), hasLength(2));
      expect(await xpTotal(), sleepXp * 2);
    });

    test('knows whether a morning is accounted for', () async {
      expect(await sleep.logged(today), isFalse);
      await log(today);
      expect(await sleep.logged(today), isTrue);
    });
  });

  group('removing a night', () {
    test('takes it out of the line', () async {
      await log(today);
      final night = (await sleep.on(today))!;
      await sleep.remove(night.uuid);

      expect(await sleep.on(today), isNull);
      expect(await sleep.recentOnce(), isEmpty);
    });

    test('takes the XP back with a mirror row', () async {
      await log(today);
      final night = (await sleep.on(today))!;
      await sleep.remove(night.uuid);

      // The +15 was paid for a night that is no longer written down.
      // It comes back off with its own row, the way an undone check-in
      // does, so the ledger stays a sum of true events (Audit 2, B-06)
      // — and so log-delete-log cannot farm it.
      expect(await xpTotal(), 0);
      final rows = await db.select(db.ledger).get();
      expect(
        rows.any((row) => row.reason == 'sleep-undo:${night.uuid}'),
        isTrue,
      );
    });

    test('and a night logged again after that earns again, once', () async {
      await log(today);
      await sleep.remove((await sleep.on(today))!.uuid);
      expect(await log(today), isTrue);
      expect(await xpTotal(), sleepXp);
    });
  });

  group('reading them back', () {
    test('newest morning first', () async {
      await log(today.previous);
      await log(today);
      final nights = await sleep.recentOnce();
      expect(nights.first.day, today);
    });

    test('no further back than asked', () async {
      for (var i = 0; i < 5; i++) {
        await log(today.addDays(-i));
      }
      expect(await sleep.recentOnce(nights: 3), hasLength(3));
    });

    test('the debt reads straight off them', () async {
      await log(today.previous, to: 6);
      await log(today, to: 6);
      final debt = sleepDebt(
        await sleep.recentOnce(),
        targetMinutes: 480,
      );
      // Two nights an hour short of eight, twice.
      expect(debt.minutes, 120);
    });
  });

  group('two nights for one morning, by sync (Q5-20)', () {
    /// A second night written straight into the table, the way a pull
    /// from another device lands it, with its own XP.
    Future<void> arriveFromElsewhere(String uuid) async {
      await db
          .into(db.sleepSessions)
          .insert(
            SleepSessionsCompanion.insert(
              uuid: uuid,
              harvestDay: today.key,
              fellAsleepAt: midnight.subtract(const Duration(hours: 2)),
              wokeAt: midnight.add(const Duration(hours: 6)),
              targetMinutes: 8 * 60,
              updatedAt: Value(DateTime.now().add(const Duration(minutes: 1))),
            ),
          );
      await db.insertLedger(
        LedgerCompanion.insert(
          uuid: 'xp-$uuid',
          kind: 'xp',
          delta: sleepXp,
          reason: 'sleep:$uuid',
          harvestDay: today.key,
        ),
      );
    }

    test('read as one, the newer, and paid once', () async {
      await log(today);
      await arriveFromElsewhere('web');
      expect((await sleep.on(today))!.uuid, 'web');
      final nights = await sleep.watchRecent().first;
      expect(nights.map((n) => n.uuid), ['web']);
      // The older one is put away as it is seen.
      await pumpEventQueue();
      final live = await (db.select(
        db.sleepSessions,
      )..where((s) => s.deletedAt.isNull())).get();
      expect(live.map((row) => row.uuid), ['web']);
      expect(await xpTotal(), sleepXp);
    });

    test('logging the morning again does not throw', () async {
      await log(today);
      await arriveFromElsewhere('web');
      await log(today, stars: 4);
      final live = await (db.select(
        db.sleepSessions,
      )..where((s) => s.deletedAt.isNull())).get();
      expect(live, hasLength(1));
      expect(live.single.restedStars, 4);
      expect(await xpTotal(), sleepXp);
    });
  });

  group('the sheet reads the clock, not the elapsed time (Q5-21)', () {
    test('a clock reading goes there and back', () {
      for (final minutes in [-240, -60, 0, 7 * 60, 7 * 60 + 35, 15 * 60]) {
        expect(wallMinutesOn(today, wallMomentOn(today, minutes)), minutes);
      }
    });

    test('on a morning the clocks change, 07:00 is still 07:00', () {
      // Only meaningful where the zone moves its clocks; everywhere
      // else it is the plain case above.
      final morning = HarvestDay.parse('2026-03-29');
      final seven = wallMomentOn(morning, 7 * 60);
      expect(seven.hour, 7);
      expect(seven.minute, 0);
      expect(wallMinutesOn(morning, seven), 7 * 60);
      expect(wallMinutesOn(morning, DateTime(2026, 3, 28, 23, 30)), -30);
    });
  });
}
