import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart'
    show MissingPluginException, PlatformException;
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

/// Where a tapped reminder lands. Kept as plain strings because they
/// travel inside notification payloads.
abstract final class ReminderRoutes {
  static const field = 'field';
  static const planner = 'planner';
  static const finances = 'finances';
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

/// The answer to "may we ring?" — denied and unavailable are different
/// problems and the settings screen says so.
enum ReminderPermission { granted, denied, unavailable }

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
  /// Anything malformed inside the JSON is ignored field by field —
  /// a bad stored payload must never wedge the reminder pipeline.
  static ReminderPayload? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw);
      if (map is Map<String, dynamic>) {
        final title = map['title'];
        final body = map['body'];
        final channel = map['channel'];
        final route = map['route'];
        final snooze = map['snooze'];
        return ReminderPayload(
          title: title is String ? title : '',
          body: body is String ? body : '',
          channelId: channel is String
              ? channel
              : NotificationChannels.reminders,
          route: route is String ? route : null,
          snoozeLabels: [
            if (snooze is List)
              for (final pair in snooze)
                if (pair is List &&
                    pair.length == 2 &&
                    pair[0] is String &&
                    pair[1] is String)
                  (pair[0] as String, pair[1] as String),
          ],
        );
      }
    } on Object {
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

  /// Localized channel names shown in system settings, by channel id.
  Map<String, String> get channelNames;
  set channelNames(Map<String, String> names);

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

  @override
  List<(String, String)> snoozeLabels = const [];

  @override
  Map<String, String> channelNames = const {};

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
    } on PlatformException catch (error) {
      _log('launch details', error);
      return null;
    } on MissingPluginException catch (error) {
      _log('launch details', error);
      return null;
    }
  }

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  /// Asks for everything an alarm needs: to post notifications, to fire
  /// at the exact minute, and to show over the lock screen.
  Future<ReminderPermission> requestPermissionStatus() async {
    try {
      await initialize();
      final android = _android;
      if (android != null) {
        final granted = await android.requestNotificationsPermission();
        if (await android.canScheduleExactNotifications() != true) {
          await android.requestExactAlarmsPermission();
        }
        try {
          await android.requestFullScreenIntentPermission();
        } on PlatformException {
          // Older Android: full-screen intents need no runtime grant.
        }
        return switch (granted) {
          true => ReminderPermission.granted,
          false => ReminderPermission.denied,
          null => ReminderPermission.unavailable,
        };
      }
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (ios != null) {
        final granted = await ios.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false
            ? ReminderPermission.granted
            : ReminderPermission.denied;
      }
    } on PlatformException catch (error) {
      _log('permission', error);
    } on MissingPluginException catch (error) {
      _log('permission', error);
    }
    return ReminderPermission.unavailable;
  }

  /// Convenience for callers that only care whether we may ring.
  Future<bool> requestPermission() async =>
      await requestPermissionStatus() == ReminderPermission.granted;

  /// Whether the OS lets us fire at the exact minute.
  Future<bool> canScheduleExact() async {
    try {
      await initialize();
      return await _android?.canScheduleExactNotifications() ?? true;
    } on PlatformException catch (error) {
      _log('exact check', error);
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Schedules a reminder at [when] (local time): exact when allowed,
  /// with sound and vibration, private on the lock screen, shown over
  /// the lock screen when [alarm], and carrying the snooze actions.
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
            channelNames[channelId] ?? channelId,
            importance: Importance.max,
            priority: Priority.max,
            category: AndroidNotificationCategory.reminder,
            // Content stays hidden on the lock screen until unlocked.
            visibility: NotificationVisibility.private,
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
    } on PlatformException catch (error) {
      _log('schedule #$id', error);
    } on MissingPluginException catch (error) {
      // Tests and background isolates without the plugin: reminders are
      // best-effort and must never break the caller.
      _log('schedule #$id', error);
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
            channelNames[channelId] ?? channelId,
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
    } on PlatformException catch (error) {
      _log('show #$id', error);
    } on MissingPluginException catch (error) {
      _log('show #$id', error);
    }
  }

  @override
  Future<void> cancel(int id) async {
    try {
      await _plugin.cancel(id: id);
    } on PlatformException catch (error) {
      _log('cancel #$id', error);
    } on MissingPluginException catch (error) {
      _log('cancel #$id', error);
    }
  }

  Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
    } on PlatformException catch (error) {
      _log('cancelAll', error);
    } on MissingPluginException catch (error) {
      _log('cancelAll', error);
    }
  }

  // Never logs payloads or user text — only what failed.
  void _log(String what, Object error) =>
      debugPrint('[notifications] $what failed: ${error.runtimeType}');
}

@Riverpod(keepAlive: true)
NotificationService notificationService(Ref ref) => NotificationService();
