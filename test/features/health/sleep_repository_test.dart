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
        .where((row) => row.reason.startsWith('sleep:'))
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

    test('leaves the XP where it is', () async {
      await log(today);
      final night = (await sleep.on(today))!;
      await sleep.remove(night.uuid);

      // Deleting a row is a correction to the record, not a clawback:
      // the app does not take XP back off anybody.
      expect(await xpTotal(), sleepXp);
    });

    test('and a night logged again after that earns again', () async {
      await log(today);
      await sleep.remove((await sleep.on(today))!.uuid);
      expect(await log(today), isTrue);
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
}
