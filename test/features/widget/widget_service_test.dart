import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/commitments/data/commitments_repository.dart';
import 'package:harvest/features/commitments/domain/check_in_service.dart';
import 'package:harvest/features/commitments/domain/commitment.dart';
import 'package:harvest/features/commitments/domain/schedule.dart';
import 'package:harvest/features/gamification/domain/streak_service.dart';
import 'package:harvest/features/settings/data/settings_repository.dart';
import 'package:harvest/features/widget/domain/widget_service.dart';

import '../../support/fake_home_widget.dart';

/// Checkpoint C3-11: the home-screen widget. It reads the database
/// rather than any screen, because it has to be right when no screen
/// exists — after the 3 AM reset, or with the app closed.
void main() {
  late HarvestDatabase db;
  late CommitmentsRepository repo;
  late CheckInService checkIns;
  late FakeHomeWidgetGateway home;
  late WidgetService service;

  final today = HarvestDay.parse('2026-09-10');

  setUp(() {
    db = HarvestDatabase.forTesting(NativeDatabase.memory());
    repo = CommitmentsRepository(db);
    checkIns = CheckInService(db, StreakService(db));
    home = FakeHomeWidgetGateway();
    service = WidgetService(db, home);
  });

  tearDown(() => db.close());

  Future<Commitment> habit(String title) => repo.create(
    type: CommitmentType.habit,
    title: title,
    schedule: const DailySchedule(),
    createdAt: DateTime(2026),
  );

  test('an empty field reports nothing due', () async {
    final snapshot = await service.snapshot(today: today);
    expect(snapshot.due, 0);
    expect(snapshot.done, 0);
    expect(snapshot.streak, 0);
  });

  test('counts what is due today and what is already done', () async {
    final a = await habit('Read');
    await habit('Exercise');
    await habit('Spanish');
    await checkIns.checkIn(a, day: today);

    final snapshot = await service.snapshot(today: today);
    expect(snapshot.due, 3);
    expect(snapshot.done, 1);
  });

  test('a paused habit is neither due nor done', () async {
    final a = await habit('Read');
    await habit('Exercise');
    await repo.setPaused(a.uuid, paused: true);

    expect((await service.snapshot(today: today)).due, 1);
  });

  test('a seed planted after the day counts for nothing on it', () async {
    await repo.create(
      type: CommitmentType.habit,
      title: 'New',
      schedule: const DailySchedule(),
      createdAt: today.next.startsAt,
    );
    expect((await service.snapshot(today: today)).due, 0);
  });

  test('the streak comes off its row, not a counter', () async {
    await db
        .into(db.streaks)
        .insert(
          StreaksCompanion.insert(
            scope: StreakService.globalScope,
            current: const Value(12),
            best: const Value(12),
          ),
        );
    final a = await habit('Read');
    await checkIns.checkIn(a, day: today);

    final snapshot = await service.snapshot(today: today);
    expect(snapshot.streak, 12);
  });

  test('refreshing writes the numbers out and redraws', () async {
    await db
        .into(db.streaks)
        .insert(
          StreaksCompanion.insert(
            scope: StreakService.globalScope,
            current: const Value(4),
            best: const Value(9),
          ),
        );
    final a = await habit('Read');
    await habit('Exercise');
    await checkIns.checkIn(a, day: today);

    await service.refresh(today: today);

    expect(home.data['streak'], '4');
    expect(home.data['progress'], '1/2 today');
    expect(home.data['streakLabel'], isNotEmpty);
    expect(home.refreshes, 1);
  });

  test('an empty field says so rather than showing 0/0', () async {
    await service.refresh(today: today);
    expect(home.data['progress'], 'Nothing due today');
    expect(home.data['tasks'], '[]');
  });

  group('the task list', () {
    test('carries what is due, undone first', () async {
      final a = await habit('Read');
      await habit('Exercise');
      await habit('Spanish');
      await checkIns.checkIn(a, day: today);

      await service.refresh(today: today);
      final tasks = (jsonDecode(home.data['tasks']! as String) as List)
          .cast<Map<String, dynamic>>();
      expect(tasks.map((t) => t['title']), ['Exercise', 'Spanish', 'Read']);
      expect(tasks.last['done'], isTrue);
      expect(tasks.first['done'], isFalse);
    });

    test('is bounded, because the widget scrolls rather than grows', () async {
      for (var i = 0; i < WidgetService.taskLimit + 5; i++) {
        await habit('Seed $i');
      }
      await service.refresh(today: today);
      final tasks = jsonDecode(home.data['tasks']! as String) as List;
      expect(tasks, hasLength(WidgetService.taskLimit));
    });
  });

  group('money', () {
    test("is today's spend and the wallet balance", () async {
      await db
          .into(db.expenses)
          .insert(
            ExpensesCompanion.insert(
              uuid: 'e1',
              amountMinor: 45000,
              category: 'food',
              harvestDay: today.key,
            ),
          );
      // Yesterday's spend is not today's.
      await db
          .into(db.expenses)
          .insert(
            ExpensesCompanion.insert(
              uuid: 'e2',
              amountMinor: 900,
              category: 'food',
              harvestDay: today.previous.key,
            ),
          );
      await db
          .into(db.moneyTxns)
          .insert(
            MoneyTxnsCompanion.insert(
              uuid: 'm1',
              account: 'wallet',
              deltaMinor: 230000,
              harvestDay: today.key,
            ),
          );

      final snapshot = await service.snapshot(today: today);
      expect(snapshot.spentToday, 45000);
      expect(snapshot.wallet, 230000);

      await service.refresh(today: today);
      // Stored in minor units, shown in major ones.
      expect(home.data['spent'], 'DA450 today');
      expect(home.data['wallet'], 'DA2,300 in the wallet');
    });

    test('a deleted expense stops counting', () async {
      await db
          .into(db.expenses)
          .insert(
            ExpensesCompanion.insert(
              uuid: 'e1',
              amountMinor: 45000,
              category: 'food',
              harvestDay: today.key,
              deletedAt: Value(DateTime(2026, 9, 10, 12)),
            ),
          );
      expect((await service.snapshot(today: today)).spentToday, 0);
    });
  });

  group('sections', () {
    test('all three are on for a widget nobody has configured', () async {
      await service.refresh(today: today);
      expect(home.data['showMoney'], isTrue);
      expect(home.data['showTasks'], isTrue);
      expect(home.data['showActions'], isTrue);
    });

    test('a section switched off is reported off', () async {
      final settings = SettingsRepository(db);
      await settings.setBool(WidgetKeys.money, value: false);
      await settings.setBool(WidgetKeys.actions, value: false);

      await service.refresh(today: today);
      expect(home.data['showMoney'], isFalse);
      expect(home.data['showTasks'], isTrue);
      expect(home.data['showActions'], isFalse);
    });

    test('the numbers are written whether or not they are shown', () async {
      // The provider decides visibility; the service always tells the
      // truth, so flipping a switch never needs a recompute.
      await SettingsRepository(db).setBool(WidgetKeys.money, value: false);
      await service.refresh(today: today);
      expect(home.data['spent'], isNotNull);
      expect(home.data['wallet'], isNotNull);
    });
  });
}
