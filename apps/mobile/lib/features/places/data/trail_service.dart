import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:harvest/features/places/domain/trail_recorder.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'trail_service.g.dart';

/// Starts and stops the trail's foreground service; a fake in tests.
abstract interface class TrailService {
  Future<bool> isRunning();

  /// Starts the service with its permanent notification. False when the
  /// phone refused (no permission, or not allowed from the background).
  Future<bool> start({required String title, required String text});

  Future<void> stop();
}

class ForegroundTrailService implements TrailService {
  const ForegroundTrailService();

  static const _serviceId = 4200;

  static void _init() => FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'places_trail',
      channelName: 'Trail',
      channelDescription: 'Shown while Harvest records the trail.',
      onlyAlertOnce: true,
    ),
    iosNotificationOptions: const IOSNotificationOptions(
      showNotification: false,
    ),
    foregroundTaskOptions: ForegroundTaskOptions(
      eventAction: ForegroundTaskEventAction.nothing(),
      // Tracking survives a reboot if it was on (PL1): a trail that
      // silently stops on the first restart is not a trail.
      autoRunOnBoot: true,
    ),
  );

  @override
  Future<bool> isRunning() async {
    try {
      return await FlutterForegroundTask.isRunningService;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<bool> start({required String title, required String text}) async {
    try {
      _init();
      if (await FlutterForegroundTask.isRunningService) return true;
      final result = await FlutterForegroundTask.startService(
        serviceId: _serviceId,
        serviceTypes: [ForegroundServiceTypes.location],
        notificationTitle: title,
        notificationText: text,
        notificationInitialRoute: '/records',
        callback: startTrailRecorder,
      );
      return result is ServiceRequestSuccess;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<void> stop() async {
    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
      }
    } on PlatformException {
      return;
    } on MissingPluginException {
      return;
    }
  }
}

@Riverpod(keepAlive: true)
TrailService trailService(Ref ref) => const ForegroundTrailService();
