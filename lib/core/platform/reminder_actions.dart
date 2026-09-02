import 'dart:convert';
import 'dart:ui';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/platform/notifications.dart';

/// Snoozed reminders ("remind me in…") live in settings storage so they
/// survive the daily replan and a reboot, and fire on their own id
/// range so the planner never overwrites them.
class SnoozeStore {
  SnoozeStore(this._db);

  final HarvestDatabase _db;

  static const key = 'reminders.snoozes';

  /// Snoozed copies live above every planner id (rituals 1xx, tasks
  /// 21xx, debts 31xx).
  static const idBase = 5000;

  Future<Map<String, dynamic>> _load() async {
    final row = await (_db.select(
      _db.kvSettings,
    )..where((s) => s.key.equals(key))).getSingleOrNull();
    if (row == null) return {};
    final decoded = jsonDecode(row.valueJson);
    return decoded is Map<String, dynamic> ? decoded : {};
  }

  Future<void> _save(Map<String, dynamic> snoozes) => _db
      .into(_db.kvSettings)
      .insertOnConflictUpdate(
        KvSettingsCompanion.insert(
          key: key,
          valueJson: jsonEncode(snoozes),
          updatedAt: Value(DateTime.now()),
        ),
      );

  /// Re-shows the reminder behind [response] after its snooze delay.
  /// Returns when it will fire, or null when the response isn't a
  /// snooze on a reminder we can repeat.
  Future<DateTime?> snooze(
    NotificationResponse response,
    NotificationService notifications, {
    DateTime? now,
  }) async {
    final minutes = SnoozeActions.minutes(response.actionId);
    final payload = ReminderPayload.decode(response.payload);
    if (minutes == null || payload == null || payload.title.isEmpty) {
      return null;
    }
    final original = response.id ?? 0;
    final id = original >= idBase ? original : idBase + original;
    final when = (now ?? DateTime.now()).add(Duration(minutes: minutes));

    final snoozes = await _load();
    snoozes['$id'] = {
      'when': when.toIso8601String(),
      'title': payload.title,
      'body': payload.body,
      'channel': payload.channelId,
      if (payload.route != null) 'route': payload.route,
      'snooze': [
        for (final (actionId, label) in payload.snoozeLabels) [actionId, label],
      ],
    };
    await _save(snoozes);
    await _schedule(id, snoozes['$id'] as Map<String, dynamic>, notifications);
    return when;
  }

  /// Drops elapsed snoozes and re-schedules the pending ones — run after
  /// every replan so a snoozed reminder outlives the planner's cancels.
  Future<void> reapply(
    NotificationService notifications, {
    DateTime? now,
  }) async {
    final at = now ?? DateTime.now();
    final snoozes = await _load();
    final pending = <String, dynamic>{};
    for (final entry in snoozes.entries) {
      final item = entry.value;
      if (item is! Map<String, dynamic>) continue;
      final when = DateTime.tryParse(item['when'] as String? ?? '');
      if (when == null || !when.isAfter(at)) continue;
      pending[entry.key] = item;
      await _schedule(int.parse(entry.key), item, notifications);
    }
    if (pending.length != snoozes.length) await _save(pending);
  }

  /// Pending snoozes, newest first (for tests and diagnostics).
  Future<List<(int, DateTime)>> pending({DateTime? now}) async {
    final at = now ?? DateTime.now();
    final snoozes = await _load();
    final result = <(int, DateTime)>[];
    snoozes.forEach((id, item) {
      if (item is! Map<String, dynamic>) return;
      final when = DateTime.tryParse(item['when'] as String? ?? '');
      if (when != null && when.isAfter(at)) {
        result.add((int.parse(id), when));
      }
    });
    result.sort((a, b) => b.$2.compareTo(a.$2));
    return result;
  }

  Future<void> _schedule(
    int id,
    Map<String, dynamic> item,
    NotificationService notifications,
  ) => notifications.schedule(
    id: id,
    channelId: item['channel'] as String? ?? NotificationChannels.reminders,
    title: item['title'] as String? ?? '',
    body: item['body'] as String? ?? '',
    when: DateTime.parse(item['when'] as String),
    route: item['route'] as String?,
    snoozeLabels: [
      for (final pair in (item['snooze'] as List<dynamic>? ?? []))
        if (pair is List && pair.length == 2)
          (pair[0] as String, pair[1] as String),
    ],
  );
}

/// Runs in its own isolate when a snooze action is tapped with the app
/// closed: opens a fresh database, stores the snooze, schedules it.
@pragma('vm:entry-point')
Future<void> reminderBackgroundHandler(NotificationResponse response) async {
  if (!SnoozeActions.isSnooze(response.actionId)) return;
  DartPluginRegistrant.ensureInitialized();
  final db = HarvestDatabase();
  try {
    await SnoozeStore(db).snooze(response, NotificationService());
  } on Object catch (error) {
    debugPrint('snooze failed: $error');
  } finally {
    await db.close();
  }
}
