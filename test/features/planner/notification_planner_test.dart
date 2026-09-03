import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/core/platform/notifications.dart';
import 'package:harvest/features/gamification/domain/streak_service.dart';
import 'package:harvest/features/planner/domain/notification_planner.dart';
import 'package:harvest/features/settings/data/settings_repository.dart';

import '../../support/fake_notifications.dart';

/// The reminder planner, asserted through what it schedules: which ids
/// fire, when, on which channel, and what silences them.
void main() {
  late HarvestDatabase db;
  late FakeNotificationGateway gateway;
  late NotificationPlanner planner;
  late SettingsRepository settings;

  // A Thursday, mid-morning.
  final noon = DateTime(2026, 9, 3, 10);
  final today = HarvestDay.of(noon);

  setUp(() {
    db = HarvestDatabase.forTesting(NativeDatabase.memory());
    gateway = FakeNotificationGateway();
    settings = SettingsRepository(db);
    planner = NotificationPlanner(db, gateway, StreakService(db));
  });

  tearDown(() => db.close());

  Future<void> seedCommitment(
    String uuid, {
    String type = 'habit',
    String? scheduleJson = '{"type":"daily"}',
    String? remindAt,
    String? dueDay,
    int? totalTarget,
    int? dailyCommitment,
  }) => db
      .into(db.commitments)
      .insert(
        CommitmentsCompanion.insert(
          uuid: uuid,
          type: type,
          title: uuid,
          scheduleJson: Value(scheduleJson),
          remindAt: Value(remindAt),
          dueDay: Value(dueDay),
          totalTarget: Value(totalTarget),
          dailyCommitment: Value(dailyCommitment),
        ),
      );

  Future<void> seedCheckIn(String commitment, HarvestDay day) => db
      .into(db.checkIns)
      .insert(
        CheckInsCompanion.insert(
          uuid: '$commitment-${day.key}',
          commitmentUuid: commitment,
          harvestDay: day.key,
          loggedAt: Value(day.startsAt.add(const Duration(hours: 9))),
        ),
      );

  group('rituals', () {
    test('nothing is scheduled while the master switch is off', () async {
      await planner.planToday(now: noon);
      expect(gateway.scheduled, isEmpty);
    });

    test(
      'morning, evening, expense and streak-risk with their defaults',
      () async {
        await settings.setBool(ReminderKeys.enabled, value: true);
        await db
            .into(db.streaks)
            .insert(
              StreaksCompanion.insert(
                scope: StreakService.globalScope,
                current: const Value(3),
                best: const Value(3),
              ),
            );
        await planner.planToday(now: DateTime(2026, 9, 3, 6));

        expect(gateway.ids, [
          ReminderIds.morning,
          ReminderIds.eveningPlan,
          ReminderIds.streakRisk,
          ReminderIds.expenses,
        ]);
        expect(
          gateway.scheduled[ReminderIds.morning]!.when,
          DateTime(2026, 9, 3, 7),
        );
        expect(
          gateway.scheduled[ReminderIds.eveningPlan]!.route,
          ReminderRoutes.planner,
        );
        expect(
          gateway.scheduled[ReminderIds.expenses]!.when,
          DateTime(2026, 9, 3, 20),
        );
        expect(
          gateway.scheduled[ReminderIds.streakRisk]!.channelId,
          NotificationChannels.streak,
        );
        expect(gateway.scheduled[ReminderIds.streakRisk]!.alarm, isFalse);
        expect(
          gateway.channelNames[NotificationChannels.reminders],
          isNotEmpty,
        );
      },
    );

    test(
      'times that already passed are skipped; custom times are honoured',
      () async {
        await settings.setBool(ReminderKeys.enabled, value: true);
        await settings.setTime(ReminderKeys.eveningTime, 22, 15);
        await planner.planToday(now: noon);
        expect(gateway.scheduled.containsKey(ReminderIds.morning), isFalse);
        expect(
          gateway.scheduled[ReminderIds.eveningPlan]!.when,
          DateTime(2026, 9, 3, 22, 15),
        );
      },
    );

    test('the streak nudge is silent once the goal is met', () async {
      await settings.setBool(ReminderKeys.enabled, value: true);
      await settings.setInt(StreakService.goalKey, 1);
      await db
          .into(db.streaks)
          .insert(
            StreaksCompanion.insert(
              scope: StreakService.globalScope,
              current: const Value(1),
              best: const Value(1),
            ),
          );
      await seedCommitment('read');
      await seedCheckIn('read', today);
      await planner.planToday(now: noon);
      expect(gateway.scheduled.containsKey(ReminderIds.streakRisk), isFalse);
    });

    test('no expense reminder once something was logged today', () async {
      await settings.setBool(ReminderKeys.enabled, value: true);
      await db
          .into(db.expenses)
          .insert(
            ExpensesCompanion.insert(
              uuid: 'e',
              amountMinor: 500,
              category: 'food',
              harvestDay: today.key,
            ),
          );
      await planner.planToday(now: noon);
      expect(gateway.scheduled.containsKey(ReminderIds.expenses), isFalse);
    });

    test(
      'planning at 01:30 judges the rituals against the coming day',
      () async {
        // 01:30 on Sep 3 is still Harvest Day Sep 2; the 20:00 reminder
        // belongs to Sep 3, where nothing is logged yet.
        await settings.setBool(ReminderKeys.enabled, value: true);
        final yesterday = today.previous;
        await db
            .into(db.expenses)
            .insert(
              ExpensesCompanion.insert(
                uuid: 'e',
                amountMinor: 500,
                category: 'food',
                harvestDay: yesterday.key,
              ),
            );
        await planner.planToday(now: DateTime(2026, 9, 3, 1, 30));
        expect(gateway.scheduled.containsKey(ReminderIds.expenses), isTrue);
        expect(
          gateway.scheduled[ReminderIds.expenses]!.when,
          DateTime(2026, 9, 3, 20),
        );
      },
    );

    test('reevaluate cancels what is no longer needed', () async {
      await settings.setBool(ReminderKeys.enabled, value: true);
      await settings.setInt(StreakService.goalKey, 1);
      await db
          .into(db.streaks)
          .insert(
            StreaksCompanion.insert(
              scope: StreakService.globalScope,
              current: const Value(1),
              best: const Value(1),
            ),
          );
      await seedCommitment('read');
      await planner.planToday(now: noon);
      expect(gateway.scheduled.containsKey(ReminderIds.streakRisk), isTrue);

      await seedCheckIn('read', today);
      await planner.reevaluate(now: noon);
      expect(gateway.cancelled, contains(ReminderIds.streakRisk));
    });
  });

  group('seed reminders', () {
    test(
      'fire regardless of the master switch, only for seeds due today',
      () async {
        await seedCommitment('daily', remindAt: '18:00');
        await seedCommitment(
          'weekend',
          scheduleJson: '{"type":"weekly","weekdays":[6,7]}',
          remindAt: '18:00',
        );
        await planner.planToday(now: noon);
        final titles = gateway.scheduled.values.map((r) => r.title).toList();
        expect(titles, ['daily']);
        expect(
          gateway.scheduled[ReminderIds.taskBase]!.when,
          DateTime(2026, 9, 3, 18),
        );
      },
    );

    test('a seed already watered today is not nagged', () async {
      await seedCommitment('daily', remindAt: '18:00');
      await seedCheckIn('daily', today);
      await planner.planToday(now: noon);
      expect(gateway.scheduled, isEmpty);
    });

    test(
      'a times-per-week habit stops nagging once its quota is met',
      () async {
        await seedCommitment(
          'gym',
          scheduleJson: '{"type":"timesPerWeek","times":2}',
          remindAt: '18:00',
        );
        await seedCheckIn('gym', today.previous);
        await seedCheckIn('gym', today.previous.previous);
        await planner.planToday(now: noon);
        expect(gateway.scheduled, isEmpty);
      },
    );

    test('overdue and future to-dos: only the overdue one reminds', () async {
      await seedCommitment(
        'late',
        type: 'todo',
        scheduleJson: null,
        dueDay: today.previous.key,
        remindAt: '18:00',
      );
      await seedCommitment(
        'later',
        type: 'todo',
        scheduleJson: null,
        dueDay: today.next.key,
        remindAt: '18:00',
      );
      await planner.planToday(now: noon);
      expect(gateway.scheduled.values.map((r) => r.title), ['late']);
    });

    test('replanning cancels the previous ids first', () async {
      await seedCommitment('daily', remindAt: '18:00');
      await planner.planToday(now: noon);
      await planner.reevaluate(now: noon);
      expect(gateway.cancelled, contains(ReminderIds.taskBase));
      expect(gateway.ids, [ReminderIds.taskBase]);
    });
  });

  group('debt reminders', () {
    test('quote what is still owed and default to 19:00', () async {
      await db
          .into(db.debts)
          .insert(
            DebtsCompanion.insert(
              uuid: 'd',
              person: 'Sami',
              amountMinor: 10000,
              currency: const Value('DZD'),
            ),
          );
      await db
          .into(db.debtPayments)
          .insert(
            DebtPaymentsCompanion.insert(
              uuid: 'p',
              debtUuid: 'd',
              amountMinor: 2500,
              harvestDay: today.key,
            ),
          );
      await planner.planToday(now: noon);
      final debt = gateway.scheduled[ReminderIds.debtBase]!;
      expect(debt.when, DateTime(2026, 9, 3, 19));
      expect(debt.body, contains('DA75'));
      expect(debt.route, ReminderRoutes.finances);
    });

    test('settled debts are quiet', () async {
      await db
          .into(db.debts)
          .insert(
            DebtsCompanion.insert(
              uuid: 'd',
              person: 'Sami',
              amountMinor: 10000,
              settledAt: Value(noon),
            ),
          );
      await planner.planToday(now: noon);
      expect(gateway.scheduled, isEmpty);
    });
  });
}
