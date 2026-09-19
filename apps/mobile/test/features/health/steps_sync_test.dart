import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/health/data/health_repository.dart';
import 'package:harvest/features/health/data/steps_source.dart';
import 'package:harvest/features/health/domain/steps_sync.dart';

import '../../support/fake_steps.dart';

/// Checkpoint 6: the steps card had a table and a card and nothing
/// feeding them. This is the feed — Health Connect per day, the sensor
/// by delta — and the three answers the card has to tell apart.
void main() {
  late HarvestDatabase db;
  late HealthRepository repository;
  late FakeStepsSource source;
  late StepsSync sync;

  final today = HarvestDay.parse('2026-09-11');

  setUp(() {
    db = HarvestDatabase.forTesting(NativeDatabase.memory());
    repository = HealthRepository(db);
    source = FakeStepsSource();
    sync = StepsSync(repository, source);
  });

  tearDown(() async => db.close());

  Future<int> stepsOn(String day) async =>
      (await repository.stepsOn(HarvestDay.parse(day))).steps;

  Future<int> stepXp() async {
    final rows = await db.select(db.ledger).get();
    return rows
        .where((row) => row.reason.startsWith('steps:'))
        .fold<int>(0, (sum, row) => sum + row.delta);
  }

  group('health connect', () {
    test('asks one 3 AM → 3 AM window per day and writes each total', () async {
      source.perWindow = [for (var i = 0; i < 30; i++) 100 * (i + 1)];
      final outcome = await sync.sync(today: today, goal: 0);

      expect(outcome, StepsSyncOutcome.synced);
      final windows = source.lastWindows!;
      expect(windows, hasLength(stepsSyncDays));
      expect(windows.last.start, DateTime(2026, 9, 11, 3));
      expect(windows.last.end, DateTime(2026, 9, 12, 3));
      expect(windows.first.start, DateTime(2026, 8, 13, 3));
      expect(await stepsOn('2026-09-11'), 3000);
      expect(await stepsOn('2026-08-13'), 100);
    });

    test(
      'a later pull overwrites, so a day the store revised is revised here',
      () async {
        source.perWindow = [for (var i = 0; i < 30; i++) 500];
        await sync.sync(today: today, goal: 0);
        source.perWindow = [for (var i = 0; i < 30; i++) 700];
        await sync.sync(today: today, goal: 0);
        expect(await stepsOn('2026-09-11'), 700);
      },
    );

    test(
      'a refused read asks for permission rather than writing zeros',
      () async {
        source.granted = false;
        await repository.saveStepDay(
          (await repository.stepsOn(today)).copyWith(steps: 4200),
        );
        final outcome = await sync.sync(today: today, goal: 0);
        expect(outcome, StepsSyncOutcome.needsPermission);
        expect(
          await stepsOn('2026-09-11'),
          4200,
          reason: 'nothing overwritten',
        );
      },
    );
  });

  group('sensor', () {
    setUp(() => source.backend = StepsBackend.sensor);

    test('the first reading anchors, the next ones count', () async {
      source.sinceBoot = 12000;
      await sync.sync(today: today, goal: 0);
      expect(await stepsOn('2026-09-11'), 0);

      source.sinceBoot = 12800;
      await sync.sync(today: today, goal: 0);
      expect(await stepsOn('2026-09-11'), 800);
    });

    test('a new day starts from where yesterday left the counter', () async {
      source.sinceBoot = 12000;
      await sync.sync(today: today.previous, goal: 0);
      source.sinceBoot = 15000;
      await sync.sync(today: today.previous, goal: 0);
      expect(await stepsOn('2026-09-10'), 3000);

      // First look at the new day: the 500 since yesterday's last
      // reading belong to today, not to nobody.
      source.sinceBoot = 15500;
      await sync.sync(today: today, goal: 0);
      expect(await stepsOn('2026-09-11'), 500);
    });

    test('a silent sensor changes nothing', () async {
      source.sinceBoot = null;
      final outcome = await sync.sync(today: today, goal: 0);
      expect(outcome, StepsSyncOutcome.synced);
      expect(await stepsOn('2026-09-11'), 0);
    });

    test('without the permission it asks', () async {
      source.granted = false;
      expect(
        await sync.sync(today: today, goal: 0),
        StepsSyncOutcome.needsPermission,
      );
    });
  });

  test('a phone with no source says so', () async {
    source.backend = StepsBackend.none;
    expect(
      await sync.sync(today: today, goal: 0),
      StepsSyncOutcome.unavailable,
    );
  });

  group('the goal', () {
    test('pays +5 once when met, and never without a goal', () async {
      source.perWindow = [for (var i = 0; i < 30; i++) 9000];
      await sync.sync(today: today, goal: 0);
      expect(await stepXp(), 0, reason: 'no goal, no payment');

      // Today and yesterday: a pull pays the day that ended too, so an
      // evening walk with the app shut is not an unpaid goal
      // ([[Checkpoint-8]]).
      await sync.sync(today: today, goal: 8000);
      expect(await stepXp(), 2 * stepGoalXp);

      await sync.sync(today: today, goal: 8000);
      expect(await stepXp(), 2 * stepGoalXp, reason: 'once a day');
    });

    test('pays nothing while short of it', () async {
      source.perWindow = [for (var i = 0; i < 30; i++) 7999];
      await sync.sync(today: today, goal: 8000);
      expect(await stepXp(), 0);
    });
  });

  group('the day-end pull', () {
    final yesterday = today.previous;
    final justAfter3 = today.startsAt.add(const Duration(minutes: 5));

    test('closes yesterday on the sensor and anchors today', () async {
      source
        ..backend = StepsBackend.sensor
        ..sinceBoot = 1000;
      await sync.sync(today: yesterday, goal: 0);
      source.sinceBoot = 4500;
      await sync.sync(today: yesterday, goal: 0);
      expect(await stepsOn(yesterday.key), 3500);

      // 3 AM: the evening walk happened with the app shut.
      source.sinceBoot = 6000;
      final outcome = await sync.closeDay(
        ended: yesterday,
        goal: 0,
        now: justAfter3,
      );
      expect(outcome, StepsSyncOutcome.synced);
      expect(await stepsOn(yesterday.key), 5000, reason: 'the day closed');
      final started = await repository.stepsOn(today);
      expect(started.steps, 0);
      expect(started.lastCounter, 6000, reason: 'today starts where it left');

      // The morning pull measures from the anchor, not from zero.
      source.sinceBoot = 6800;
      await sync.sync(today: today, goal: 0);
      expect(await stepsOn(today.key), 800);
      expect(await stepsOn(yesterday.key), 5000, reason: 'unchanged');
    });

    test('does not re-anchor a day a pull already started', () async {
      source
        ..backend = StepsBackend.sensor
        ..sinceBoot = 1000;
      await sync.sync(today: yesterday, goal: 0);
      source.sinceBoot = 1200;
      await sync.sync(today: today, goal: 0);
      source.sinceBoot = 1500;
      await sync.closeDay(ended: yesterday, goal: 0, now: justAfter3);
      final started = await repository.stepsOn(today);
      expect(started.lastCounter, 1200);
      // And the ended day does not take the 300 the new day will count
      // on its next read ([[Audit-v2]] B3-01).
      expect(await stepsOn(yesterday.key), 0);
      expect(started.steps, 200);
    });

    test('a job Doze held back until morning leaves both days alone', () async {
      source
        ..backend = StepsBackend.sensor
        ..sinceBoot = 1000;
      await sync.sync(today: yesterday, goal: 0);
      source.sinceBoot = 3000;
      await sync.sync(today: yesterday, goal: 0);
      source.sinceBoot = 4000;
      await sync.closeDay(
        ended: yesterday,
        goal: 0,
        now: today.startsAt.add(const Duration(hours: 6)),
      );
      expect(await stepsOn(yesterday.key), 2000);
      expect((await repository.stepsOn(today)).lastCounter, isNull);
    });

    test('a job that runs before 3 AM (a DST change) closes nothing', () async {
      source
        ..backend = StepsBackend.sensor
        ..sinceBoot = 1000;
      await sync.sync(today: yesterday, goal: 0);
      source.sinceBoot = 5000;
      await sync.closeDay(
        ended: yesterday,
        goal: 0,
        now: today.startsAt.subtract(const Duration(hours: 1)),
      );
      expect(await stepsOn(yesterday.key), 0);
    });

    test('pays the goal of the day that ended', () async {
      source.perWindow = [for (var i = 0; i < 30; i++) 8000];
      await sync.closeDay(ended: yesterday, goal: 6000);
      final rows = await db.select(db.ledger).get();
      expect(
        rows.map((row) => row.reason),
        contains('steps:${yesterday.key}'),
      );
      expect(await stepXp(), 5, reason: 'yesterday only, not the month');
    });

    test('an ordinary pull pays yesterday too, once', () async {
      source.perWindow = [for (var i = 0; i < 30; i++) 8000];
      await sync.sync(today: today, goal: 6000);
      await sync.sync(today: today, goal: 6000);
      expect(await stepXp(), 10, reason: 'today and yesterday, each once');
    });

    test('a pull pays every day since the last one paid', () async {
      source.perWindow = [for (var i = 0; i < 30; i++) 8000];
      // Paid on the 8th (and the 7th), then nothing read for three days.
      await sync.sync(today: HarvestDay.parse('2026-09-08'), goal: 6000);
      expect(await stepXp(), 10);

      await sync.sync(today: today, goal: 6000);
      expect(await stepXp(), 25, reason: 'the 9th, 10th and 11th');
      final reasons = (await db.select(db.ledger).get()).map((r) => r.reason);
      expect(reasons, isNot(contains('steps:2026-09-06')));
    });

    test('a read that fails keeps the days and pays nothing', () async {
      source
        ..perWindow = [for (var i = 0; i < 30; i++) 8000]
        ..unreadable = true;
      final outcome = await sync.sync(today: today, goal: 6000);
      expect(outcome, StepsSyncOutcome.failed);
      expect(await stepXp(), 0);
    });
  });
}
