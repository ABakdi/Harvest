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
    try {
      final decoded = jsonDecode(row.valueJson);
      return decoded is Map<String, dynamic> ? decoded : {};
    } on FormatException {
      return {};
    }
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
    NotificationGateway notifications, {
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
    // One shape on disk: the fire time plus the reminder's own payload.
    snoozes['$id'] = {
      'when': when.toIso8601String(),
      'payload': payload.encode(),
    };
    await _save(snoozes);
    await _schedule(id, when, payload, notifications);
    return when;
  }

  /// Drops elapsed snoozes and re-schedules the pending ones — run after
  /// every replan so a snoozed reminder outlives the planner's cancels.
  Future<void> reapply(
    NotificationGateway notifications, {
    DateTime? now,
  }) async {
    final at = now ?? DateTime.now();
    final snoozes = await _load();
    final pending = <String, dynamic>{};
    for (final entry in snoozes.entries) {
      final parsed = _parse(entry.key, entry.value);
      if (parsed == null || !parsed.when.isAfter(at)) continue;
      pending[entry.key] = entry.value;
      await _schedule(parsed.id, parsed.when, parsed.payload, notifications);
    }
    if (pending.length != snoozes.length) await _save(pending);
  }

  /// Pending snoozes, latest first (for tests and diagnostics).
  Future<List<(int, DateTime)>> pending({DateTime? now}) async {
    final at = now ?? DateTime.now();
    final result = <(int, DateTime)>[];
    for (final entry in (await _load()).entries) {
      final parsed = _parse(entry.key, entry.value);
      if (parsed != null && parsed.when.isAfter(at)) {
        result.add((parsed.id, parsed.when));
      }
    }
    result.sort((a, b) => b.$2.compareTo(a.$2));
    return result;
  }

  /// Reads one stored entry; null for anything malformed. Accepts the
  /// older flattened shape (title/body/channel/route/snooze at the top
  /// level) as well as the current `{when, payload}` one.
  ({int id, DateTime when, ReminderPayload payload})? _parse(
    String key,
    Object? value,
  ) {
    final id = int.tryParse(key);
    if (id == null || value is! Map<String, dynamic>) return null;
    final when = DateTime.tryParse(value['when'] as String? ?? '');
    if (when == null) return null;
    final ReminderPayload? payload;
    if (value['payload'] is String) {
      payload = ReminderPayload.decode(value['payload'] as String);
    } else {
      payload = ReminderPayload.decode(jsonEncode(value));
    }
    if (payload == null || payload.title.isEmpty) return null;
    return (id: id, when: when, payload: payload);
  }

  Future<void> _schedule(
    int id,
    DateTime when,
    ReminderPayload payload,
    NotificationGateway notifications,
  ) => notifications.schedule(
    id: id,
    channelId: payload.channelId,
    title: payload.title,
    body: payload.body,
    when: when,
    route: payload.route,
    snoozeLabels: payload.snoozeLabels,
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
    debugPrint('[notifications] snooze failed: ${error.runtimeType}');
  } finally {
    await db.close();
  }
}
