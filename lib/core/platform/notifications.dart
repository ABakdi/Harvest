import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:harvest/core/platform/reminder_actions.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

part 'notifications.g.dart';

/// Notification channel ids — one per reminder category so each can be
/// muted individually from system settings. Android freezes a channel's
/// importance and sound on first use, so the alarm-grade reminders got a
/// fresh id when they became alarms.
abstract final class NotificationChannels {
  static const reminders = 'reminders_alarm';
  static const streak = 'streak';
  static const pomodoro = 'pomodoro';
}

/// Snooze actions carried by every reminder: `snooze:<minutes>`.
abstract final class SnoozeActions {
  static const prefix = 'snooze:';

  static bool isSnooze(String? actionId) =>
      actionId != null && actionId.startsWith(prefix);

  static int? minutes(String? actionId) =>
      actionId == null ? null : int.tryParse(actionId.substring(prefix.length));

  static String id(int minutes) => '$prefix$minutes';
}

/// Everything a reminder needs to come back later: the route to open on
/// tap and the content to repeat on snooze. Travels as the notification
/// payload so a snooze can be honored with the app closed.
@immutable
class ReminderPayload {
  const ReminderPayload({
    required this.title,
    required this.body,
    required this.channelId,
    this.route,
    this.snoozeLabels = const [],
  });

  final String title;
  final String body;
  final String channelId;
  final String? route;

  /// (actionId, label) pairs, already localized.
  final List<(String, String)> snoozeLabels;

  String encode() => jsonEncode({
    'title': title,
    'body': body,
    'channel': channelId,
    if (route != null) 'route': route,
    'snooze': [
      for (final (id, label) in snoozeLabels) [id, label],
    ],
  });

  /// Accepts the JSON form and, for older notifications, a bare route.
  static ReminderPayload? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw);
      if (map is Map<String, dynamic>) {
        return ReminderPayload(
          title: map['title'] as String? ?? '',
          body: map['body'] as String? ?? '',
          channelId:
              map['channel'] as String? ?? NotificationChannels.reminders,
          route: map['route'] as String?,
          snoozeLabels: [
            for (final pair in (map['snooze'] as List<dynamic>? ?? []))
              if (pair is List && pair.length == 2)
                (pair[0] as String, pair[1] as String),
          ],
        );
      }
    } on FormatException {
      // Not JSON: a legacy route-only payload.
    }
    return ReminderPayload(
      title: '',
      body: '',
      channelId: NotificationChannels.reminders,
      route: raw,
    );
  }
}

/// What the planner needs from the notification layer — implemented by
/// [NotificationService] on device and by a recording fake in tests.
abstract interface class NotificationGateway {
  /// Localized snooze actions attached to every reminder.
  List<(String, String)> get snoozeLabels;
  set snoozeLabels(List<(String, String)> labels);

  Future<void> schedule({
    required int id,
    required String channelId,
    required String title,
    required String body,
    required DateTime when,
    String? route,
    bool alarm = true,
    List<(String, String)>? snoozeLabels,
  });

  Future<void> cancel(int id);
}

/// Thin wrapper around the local-notifications plugin: initialization,
/// permission requests, and timezone-aware alarm-grade scheduling.
class NotificationService implements NotificationGateway {
  final _plugin = FlutterLocalNotificationsPlugin();
  var _initialized = false;

  /// Invoked with the reminder's route when the user taps one.
  void Function(String route)? onTap;

  /// Invoked with the action id when the user taps a non-snooze action.
  void Function(String actionId)? onAction;

  /// Handles a snooze tapped while the app is running (the closed-app
  /// case goes through [reminderBackgroundHandler]).
  Future<void> Function(NotificationResponse response)? onSnooze;

  /// Localized snooze actions attached to every reminder; the planner
  /// sets these once per plan.
  @override
  List<(String, String)> snoozeLabels = const [];

  Future<void> initialize() async {
    if (_initialized) return;
    tz.initializeTimeZones();
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: _onResponse,
      onDidReceiveBackgroundNotificationResponse: reminderBackgroundHandler,
    );
    _initialized = true;
  }

  void _onResponse(NotificationResponse response) {
    final actionId = response.actionId;
    if (SnoozeActions.isSnooze(actionId)) {
      final handler = onSnooze;
      if (handler != null) unawaited(handler(response));
      return;
    }
    if (actionId != null && actionId.isNotEmpty) {
      onAction?.call(actionId);
      return;
    }
    final route = ReminderPayload.decode(response.payload)?.route;
    if (route != null && route.isNotEmpty) onTap?.call(route);
  }

  /// The route of the notification that launched the app, if any.
  Future<String?> launchRoute() async {
    try {
      await initialize();
      final details = await _plugin.getNotificationAppLaunchDetails();
      if (details?.didNotificationLaunchApp != true) return null;
      final response = details!.notificationResponse;
      if (response == null || SnoozeActions.isSnooze(response.actionId)) {
        return null;
      }
      return ReminderPayload.decode(response.payload)?.route;
    } on Object catch (error) {
      debugPrint('launch details failed: $error');
      return null;
    }
  }

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  /// Asks for everything an alarm needs: to post notifications, to
  /// fire at the exact minute, and to show over the lock screen.
  Future<bool> requestPermission() async {
    try {
      await initialize();
      final android = _android;
      if (android != null) {
        final granted = await android.requestNotificationsPermission() ?? false;
        if (await android.canScheduleExactNotifications() != true) {
          await android.requestExactAlarmsPermission();
        }
        try {
          await android.requestFullScreenIntentPermission();
        } on Object catch (_) {
          // Older Android: full-screen intents need no runtime grant.
        }
        return granted;
      }
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (ios != null) {
        return await ios.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
      }
    } on Object catch (error) {
      debugPrint('notification permission failed: $error');
    }
    return false;
  }

  /// Whether the OS lets us fire at the exact minute.
  Future<bool> canScheduleExact() async {
    try {
      await initialize();
      return await _android?.canScheduleExactNotifications() ?? true;
    } on Object catch (_) {
      return false;
    }
  }

  /// Schedules a reminder at [when] (local time): exact when allowed,
  /// with sound and vibration, shown over the lock screen when [alarm],
  /// and carrying the snooze actions.
  @override
  Future<void> schedule({
    required int id,
    required String channelId,
    required String title,
    required String body,
    required DateTime when,
    String? route,
    bool alarm = true,
    List<(String, String)>? snoozeLabels,
  }) async {
    try {
      await initialize();
      final labels = snoozeLabels ?? this.snoozeLabels;
      final payload = ReminderPayload(
        title: title,
        body: body,
        channelId: channelId,
        route: route,
        snoozeLabels: labels,
      ).encode();
      final exact = await canScheduleExact();
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        payload: payload,
        scheduledDate: tz.TZDateTime.from(when, tz.local),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            channelId,
            importance: Importance.max,
            priority: Priority.max,
            category: AndroidNotificationCategory.reminder,
            visibility: NotificationVisibility.public,
            fullScreenIntent: alarm,
            audioAttributesUsage: alarm
                ? AudioAttributesUsage.alarm
                : AudioAttributesUsage.notification,
            actions: [
              for (final (actionId, label) in labels)
                AndroidNotificationAction(actionId, label),
            ],
          ),
          iOS: const DarwinNotificationDetails(
            interruptionLevel: InterruptionLevel.timeSensitive,
          ),
        ),
        androidScheduleMode: exact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } on Object catch (error) {
      // Reminders are best-effort: never let a platform hiccup break
      // the caller (tests and background isolates included).
      debugPrint('notification schedule failed: $error');
    }
  }

  /// Ongoing countdown notification driven by the system chronometer —
  /// no periodic updates needed, and it survives the app being killed.
  Future<void> showCountdown({
    required int id,
    required String channelId,
    required String title,
    required DateTime until,
    List<(String, String)> actions = const [],
  }) async {
    try {
      await initialize();
      await _plugin.show(
        id: id,
        title: title,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            channelId,
            importance: Importance.low,
            priority: Priority.low,
            ongoing: true,
            autoCancel: false,
            usesChronometer: true,
            chronometerCountDown: true,
            when: until.millisecondsSinceEpoch,
            actions: [
              for (final (actionId, label) in actions)
                AndroidNotificationAction(
                  actionId,
                  label,
                  // Deliver the tap to the running app.
                  showsUserInterface: true,
                ),
            ],
          ),
          iOS: const DarwinNotificationDetails(),
        ),
      );
    } on Object catch (error) {
      debugPrint('notification show failed: $error');
    }
  }

  @override
  Future<void> cancel(int id) async {
    try {
      await _plugin.cancel(id: id);
    } on Object catch (error) {
      debugPrint('notification cancel failed: $error');
    }
  }

  Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
    } on Object catch (error) {
      debugPrint('notification cancelAll failed: $error');
    }
  }
}

@Riverpod(keepAlive: true)
NotificationService notificationService(Ref ref) => NotificationService();
