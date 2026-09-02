import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

part 'notifications.g.dart';

/// Notification channel ids — one per reminder category so each can be
/// muted individually from system settings.
abstract final class NotificationChannels {
  static const reminders = 'reminders';
  static const streak = 'streak';
  static const pomodoro = 'pomodoro';
}

/// Thin wrapper around the local-notifications plugin: initialization,
/// permission request, and timezone-aware scheduling.
class NotificationService {
  final _plugin = FlutterLocalNotificationsPlugin();
  var _initialized = false;

  /// Invoked with the notification payload when the user taps one.
  void Function(String payload)? onTap;

  Future<void> initialize() async {
    if (_initialized) return;
    tz.initializeTimeZones();
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) onTap?.call(payload);
      },
    );
    _initialized = true;
  }

  Future<bool> requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
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
    return false;
  }

  /// Schedules a one-shot notification at [when] (local time).
  Future<void> schedule({
    required int id,
    required String channelId,
    required String title,
    required String body,
    required DateTime when,
    String? payload,
  }) async {
    try {
      await initialize();
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
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
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
          ),
          iOS: const DarwinNotificationDetails(),
        ),
      );
    } on Object catch (error) {
      debugPrint('notification show failed: $error');
    }
  }

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
