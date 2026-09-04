import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/gamification/domain/streak_service.dart';
import 'package:harvest/features/planner/domain/comeback.dart';
import 'package:harvest/features/planner/domain/notification_planner.dart';
import 'package:harvest/features/settings/data/settings_repository.dart';

import '../../support/fake_notifications.dart';

/// Checkpoint C3-8: the comeback ladder. An app that goes quiet the
/// moment you stop opening it has given up on the one thing it does.
void main() {
  group('the ladder itself', () {
    final lastActive = HarvestDay.parse('2026-09-01');

    test('a rung fires the morning after its run of missed days', () {
      final days = comebackDays(lastActive);
      // One missed day is the 2nd; the nudge lands on the 3rd.
      expect(days[ComebackRung.day1], HarvestDay.parse('2026-09-03'));
      expect(days[ComebackRung.week1], HarvestDay.parse('2026-09-09'));
      expect(days[ComebackRung.month1], HarvestDay.parse('2026-10-02'));
    });

    test('at most one rung lands on any day', () {
      final days = comebackDays(lastActive).values.toList();
      expect(days.toSet(), hasLength(days.length));
    });

    test('rungs already behind us are dropped', () {
      final upcoming = upcomingComebacks(
        lastActive,
        HarvestDay.parse('2026-09-09'),
      );
      expect(upcoming.map((r) => r.$1), [
        ComebackRung.week1,
        ComebackRung.week2,
        ComebackRung.month1,
        ComebackRung.month2,
      ]);
    });

    test('a day carrying no rung has none', () {
      // The rungs land on the 3rd, 5th, 9th, 16th, and so on.
      expect(rungOn(lastActive, HarvestDay.parse('2026-09-04')), isNull);
      expect(
        rungOn(lastActive, HarvestDay.parse('2026-09-03')),
        ComebackRung.day1,
      );
      expect(
        rungOn(lastActive, HarvestDay.parse('2026-09-09')),
        ComebackRung.week1,
      );
    });
  });

  group('planning', () {
    late HarvestDatabase db;
    late FakeNotificationGateway gateway;
    late NotificationPlanner planner;
    late SettingsRepository settings;

    final noon = DateTime(2026, 9, 10, 10);

    setUp(() async {
      db = HarvestDatabase.forTesting(NativeDatabase.memory());
      gateway = FakeNotificationGateway();
      settings = SettingsRepository(db);
      planner = NotificationPlanner(db, gateway, StreakService(db));
      await settings.setBool(ReminderKeys.enabled, value: true);
    });

    tearDown(() => db.close());

    Future<void> seedCheckIn(HarvestDay day) => db
        .into(db.checkIns)
        .insert(
          CheckInsCompanion.insert(
            uuid: 'c-${day.key}',
            commitmentUuid: 'seed',
            harvestDay: day.key,
          ),
        );

    Future<void> seedCommitment() => db
        .into(db.commitments)
        .insert(
          CommitmentsCompanion.insert(
            uuid: 'seed',
            type: 'habit',
            title: 'Read',
            scheduleJson: const Value('{"type":"daily"}'),
            createdAt: Value(DateTime(2026)),
          ),
        );

    List<int> comebackIds() => gateway.ids
        .where((id) => id >= ReminderIds.comebackBase && id < 5000)
        .toList();

    test('nothing is scheduled while the master switch is off', () async {
      await settings.setBool(ReminderKeys.enabled, value: false);
      await seedCommitment();
      await planner.planToday(now: noon);
      expect(comebackIds(), isEmpty);
    });

    test('the whole ladder is scheduled ahead of a quiet stretch', () async {
      await seedCommitment();
      await seedCheckIn(HarvestDay.parse('2026-09-09'));
      await planner.planToday(now: noon);

      expect(comebackIds(), hasLength(ComebackRung.values.length));
      final first = gateway.scheduled[ReminderIds.comebackBase]!;
      // Last active on the 9th, so one missed day is the 10th and the
      // nudge lands on the morning of the 11th.
      expect(first.when, DateTime(2026, 9, 11, 7));
      expect(first.title, isNotEmpty);
      expect(first.body, isNotEmpty);
      // A "we miss you" nudge is not an alarm and cannot be snoozed.
      expect(first.alarm, isFalse);
    });

    test('every rung says something different', () async {
      await seedCommitment();
      await seedCheckIn(HarvestDay.parse('2026-09-09'));
      await planner.planToday(now: noon);

      final bodies = comebackIds()
          .map((id) => gateway.scheduled[id]!.body)
          .toSet();
      expect(bodies, hasLength(ComebackRung.values.length));
    });

    test('logging anything today pushes the whole ladder back', () async {
      await seedCommitment();
      await seedCheckIn(HarvestDay.parse('2026-09-09'));
      await planner.planToday(now: noon);
      final before = gateway.scheduled[ReminderIds.comebackBase]!.when;

      await seedCheckIn(HarvestDay.of(noon));
      await planner.reevaluate(now: noon);
      final after = gateway.scheduled[ReminderIds.comebackBase]!.when;

      expect(after.isAfter(before), isTrue);
      expect(after, DateTime(2026, 9, 12, 7));
    });

    test('an expense counts as showing up, not just a check-in', () async {
      await seedCommitment();
      await db
          .into(db.expenses)
          .insert(
            ExpensesCompanion.insert(
              uuid: 'e1',
              amountMinor: 500,
              category: 'food',
              harvestDay: HarvestDay.of(noon).key,
            ),
          );
      await planner.planToday(now: noon);
      expect(
        gateway.scheduled[ReminderIds.comebackBase]!.when,
        DateTime(2026, 9, 12, 7),
      );
    });

    test('an app installed and never used still speaks up', () async {
      // No check-ins at all: the ladder counts from the first seed,
      // planted in January — every rung is long past, so what is left
      // is the monthly heartbeat.
      await seedCommitment();
      await planner.planToday(now: noon);
      expect(comebackIds(), hasLength(1));
      expect(
        gateway.scheduled[comebackIds().single]!.when,
        DateTime(2026, 10, 10, 7),
      );
    });

    test('replanning cancels the previous ladder first', () async {
      await seedCommitment();
      await seedCheckIn(HarvestDay.parse('2026-09-09'));
      await planner.planToday(now: noon);
      await planner.planToday(now: noon);
      expect(gateway.cancelled, contains(ReminderIds.comebackBase));
    });

    test(
      'a comeback day speaks instead of the morning ritual, not on top',
      () async {
        await seedCommitment();
        // Last active on the 8th: one missed day (the 9th), so the
        // day-1 rung is due this morning, the 10th.
        await seedCheckIn(HarvestDay.parse('2026-09-08'));
        await planner.planToday(now: DateTime(2026, 9, 10, 6));

        expect(gateway.ids, isNot(contains(ReminderIds.morning)));
        expect(
          gateway.scheduled[ReminderIds.comebackBase]!.when,
          DateTime(2026, 9, 10, 7),
        );
      },
    );

    test('an ordinary day keeps its morning ritual', () async {
      await seedCommitment();
      await seedCheckIn(HarvestDay.parse('2026-09-09'));
      await planner.planToday(now: DateTime(2026, 9, 10, 6));
      expect(gateway.ids, contains(ReminderIds.morning));
    });
  });
}
