import 'package:drift/native.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/platform/notifications.dart';
import 'package:harvest/core/platform/reminder_actions.dart';

/// The snooze store keeps "remind me in…" alive across replans: it is
/// what the planner re-applies after cancelling its own ids.
void main() {
  late HarvestDatabase db;
  late SnoozeStore store;
  // Scheduling is best-effort and swallowed off-device, so the real
  // service is safe to use here; only the stored state is asserted.
  final notifications = NotificationService();
  final now = DateTime(2026, 9, 3, 9);

  setUp(() {
    db = HarvestDatabase.forTesting(NativeDatabase.memory());
    store = SnoozeStore(db);
  });

  tearDown(() => db.close());

  NotificationResponse tap(int id, String actionId, ReminderPayload payload) =>
      NotificationResponse(
        notificationResponseType:
            NotificationResponseType.selectedNotificationAction,
        id: id,
        actionId: actionId,
        payload: payload.encode(),
      );

  const payload = ReminderPayload(
    title: 'Water the basil',
    body: 'A seed is waiting.',
    channelId: NotificationChannels.reminders,
    route: 'field',
    snoozeLabels: [('snooze:10', 'In 10 min')],
  );

  test('a snooze lands above the planner ids at the chosen delay', () async {
    final when = await store.snooze(
      tap(2101, SnoozeActions.id(60), payload),
      notifications,
      now: now,
    );
    expect(when, now.add(const Duration(hours: 1)));
    final pending = await store.pending(now: now);
    expect(pending.single.$1, SnoozeStore.idBase + 2101);
    expect(pending.single.$2, when);
  });

  test('snoozing a snooze keeps the same id', () async {
    await store.snooze(
      tap(101, SnoozeActions.id(10), payload),
      notifications,
      now: now,
    );
    await store.snooze(
      tap(SnoozeStore.idBase + 101, SnoozeActions.id(180), payload),
      notifications,
      now: now,
    );
    final pending = await store.pending(now: now);
    expect(pending.length, 1);
    expect(pending.single.$1, SnoozeStore.idBase + 101);
    expect(pending.single.$2, now.add(const Duration(hours: 3)));
  });

  test('reapply prunes what has already fired', () async {
    await store.snooze(
      tap(101, SnoozeActions.id(10), payload),
      notifications,
      now: now,
    );
    await store.snooze(
      tap(102, SnoozeActions.id(180), payload),
      notifications,
      now: now,
    );
    await store.reapply(notifications, now: now.add(const Duration(hours: 1)));
    final pending = await store.pending(now: now.add(const Duration(hours: 1)));
    expect(pending.map((p) => p.$1), [SnoozeStore.idBase + 102]);
  });

  test('ignores taps that are not snoozes or carry no reminder', () async {
    expect(
      await store.snooze(
        tap(101, 'pomodoro.pause', payload),
        notifications,
        now: now,
      ),
      isNull,
    );
    final bare = NotificationResponse(
      notificationResponseType:
          NotificationResponseType.selectedNotificationAction,
      id: 101,
      actionId: SnoozeActions.id(10),
      payload: 'planner',
    );
    expect(await store.snooze(bare, notifications, now: now), isNull);
  });

  test('payload round-trips and accepts the legacy route form', () {
    final decoded = ReminderPayload.decode(payload.encode())!;
    expect(decoded.title, payload.title);
    expect(decoded.route, 'field');
    expect(decoded.snoozeLabels, payload.snoozeLabels);
    expect(ReminderPayload.decode('planner')!.route, 'planner');
    expect(ReminderPayload.decode(null), isNull);
  });
}
