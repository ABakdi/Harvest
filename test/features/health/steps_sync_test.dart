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

      await sync.sync(today: today, goal: 8000);
      expect(await stepXp(), stepGoalXp);

      await sync.sync(today: today, goal: 8000);
      expect(await stepXp(), stepGoalXp, reason: 'once a day');
    });

    test('pays nothing while short of it', () async {
      source.perWindow = [for (var i = 0; i < 30; i++) 7999];
      await sync.sync(today: today, goal: 8000);
      expect(await stepXp(), 0);
    });
  });
}
