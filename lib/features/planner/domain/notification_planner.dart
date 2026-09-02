import 'dart:convert';
import 'dart:ui' show Locale;

import 'package:drift/drift.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/db/database_provider.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/core/platform/notifications.dart';
import 'package:harvest/features/gamification/domain/streak_service.dart';
import 'package:harvest/l10n/app_localizations.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'notification_planner.g.dart';

/// Reserved notification ids for the daily reminders.
abstract final class ReminderIds {
  static const morning = 101;
  static const eveningPlan = 102;
  static const primeTime = 103;
  static const streakRisk = 104;

  static const List<int> all = [morning, eveningPlan, primeTime, streakRisk];
}

/// Settings keys for reminder configuration. Times are stored as
/// "HH:mm" strings; switches as JSON booleans.
abstract final class ReminderKeys {
  static const enabled = 'reminders.enabled';
  static const morningTime = 'reminders.morningTime';
  static const eveningTime = 'reminders.eveningTime';
  static const streakNudge = 'reminders.streakNudge';
}

/// Plans the day's reminder notifications (anti-spam rules):
/// everything is scheduled at the 3 AM reset or app open, and
/// [reevaluate] silences what is no longer needed the moment the
/// Daily Harvest Goal is met. Never more than 4 scheduled per day.
class NotificationPlanner {
  NotificationPlanner(this._db, this._notifications, this._streaks);

  final HarvestDatabase _db;
  final NotificationService _notifications;
  final StreakService _streaks;

  /// (Re)schedules today's reminders. Idempotent: cancels the reserved
  /// ids first, then schedules only what still lies ahead.
  Future<void> planToday({DateTime? now}) async {
    final at = now ?? DateTime.now();
    for (final id in ReminderIds.all) {
      await _notifications.cancel(id);
    }
    if (!await _boolSetting(ReminderKeys.enabled, defaultValue: false)) {
      return;
    }

    final l10n = await _l10n();
    final goalMet = await _goalMetToday(at);

    final morning = _todayAt(await _timeSetting(
      ReminderKeys.morningTime,
      const TimeOfDay(hour: 7, minute: 0),
    ), at);
    if (morning.isAfter(at)) {
      await _notifications.schedule(
        id: ReminderIds.morning,
        channelId: NotificationChannels.reminders,
        title: l10n.notifMorningTitle,
        body: l10n.notifMorningBody,
        when: morning,
      );
    }

    final evening = _todayAt(await _timeSetting(
      ReminderKeys.eveningTime,
      const TimeOfDay(hour: 21, minute: 30),
    ), at);
    if (evening.isAfter(at)) {
      await _notifications.schedule(
        id: ReminderIds.eveningPlan,
        channelId: NotificationChannels.reminders,
        title: l10n.notifEveningTitle,
        body: l10n.notifEveningBody,
        when: evening,
        payload: 'planner',
      );
    }

    if (!goalMet) {
      final prime = await _primeTime(at);
      if (prime != null && prime.isAfter(at)) {
        await _notifications.schedule(
          id: ReminderIds.primeTime,
          channelId: NotificationChannels.reminders,
          title: l10n.notifPrimeTitle,
          body: l10n.notifPrimeBody,
          when: prime,
        );
      }

      if (await _boolSetting(ReminderKeys.streakNudge, defaultValue: true)) {
        final streak = await _streaks.currentGlobal();
        final lateCheck = _todayAt(const TimeOfDay(hour: 23, minute: 0), at);
        if (streak > 0 && lateCheck.isAfter(at)) {
          await _notifications.schedule(
            id: ReminderIds.streakRisk,
            channelId: NotificationChannels.streak,
            title: l10n.notifStreakTitle,
            body: l10n.notifStreakBody,
            when: lateCheck,
          );
        }
      }
    }
  }

  /// Called after every check-in: once the goal is met, the urgency
  /// notifications have nothing left to say.
  Future<void> reevaluate({DateTime? now}) async {
    if (await _goalMetToday(now ?? DateTime.now())) {
      await _notifications.cancel(ReminderIds.primeTime);
      await _notifications.cancel(ReminderIds.streakRisk);
    }
  }

  /// The learned logging window: median first-check-in time over the
  /// last 14 days, minus 30 minutes. Null until a week of history.
  Future<DateTime?> _primeTime(DateTime now) async {
    final since = HarvestDay.of(now.subtract(const Duration(days: 14)));
    final rows = await (_db.select(_db.checkIns)
          ..where(
            (c) =>
                c.harvestDay.isBiggerOrEqualValue(since.key) &
                c.deletedAt.isNull(),
          ))
        .get();
    final firstByDay = <String, DateTime>{};
    for (final row in rows) {
      final logged = row.loggedAt.toLocal();
      final day = row.harvestDay;
      if (day == HarvestDay.of(now).key) continue; // today doesn't teach
      final existing = firstByDay[day];
      if (existing == null || logged.isBefore(existing)) {
        firstByDay[day] = logged;
      }
    }
    if (firstByDay.length < 7) return null;

    final minutes = firstByDay.values
        .map((t) => t.hour * 60 + t.minute)
        .toList()
      ..sort();
    final median = minutes[minutes.length ~/ 2];
    final nudge = median - 30;
    return DateTime(now.year, now.month, now.day, nudge ~/ 60, nudge % 60);
  }

  Future<bool> _goalMetToday(DateTime now) async {
    final goal = await _streaks.dailyGoal();
    final actions = await _streaks.productiveActions(HarvestDay.of(now));
    return actions >= goal;
  }

  Future<AppLocalizations> _l10n() async {
    final row = await (_db.select(_db.kvSettings)
          ..where((s) => s.key.equals('locale')))
        .getSingleOrNull();
    var code = 'en';
    if (row != null) {
      final value = jsonDecode(row.valueJson);
      if (value == 'ar') code = 'ar';
    }
    return lookupAppLocalizations(Locale(code));
  }

  DateTime _todayAt(TimeOfDay time, DateTime now) =>
      DateTime(now.year, now.month, now.day, time.hour, time.minute);

  Future<bool> _boolSetting(String key, {required bool defaultValue}) async {
    final row = await (_db.select(_db.kvSettings)
          ..where((s) => s.key.equals(key)))
        .getSingleOrNull();
    if (row == null) return defaultValue;
    final value = jsonDecode(row.valueJson);
    if (value is bool) return value;
    return value == 'true';
  }

  Future<TimeOfDay> _timeSetting(String key, TimeOfDay fallback) async {
    final row = await (_db.select(_db.kvSettings)
          ..where((s) => s.key.equals(key)))
        .getSingleOrNull();
    if (row == null) return fallback;
    final raw = jsonDecode(row.valueJson).toString();
    final parts = raw.split(':');
    if (parts.length != 2) return fallback;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return fallback;
    return TimeOfDay(hour: hour, minute: minute);
  }
}

@Riverpod(keepAlive: true)
NotificationPlanner notificationPlanner(Ref ref) => NotificationPlanner(
      ref.watch(databaseProvider),
      ref.watch(notificationServiceProvider),
      ref.watch(streakServiceProvider),
    );
