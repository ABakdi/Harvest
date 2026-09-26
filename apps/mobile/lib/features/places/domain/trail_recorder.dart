import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/features/places/data/location_gateway.dart';
import 'package:harvest/features/places/data/places_repository.dart';

/// How far I move before the trail takes another point ([[Places]]).
const trailDistanceFilterM = 50;

/// The least time between two points, however fast I move.
const trailInterval = Duration(seconds: 60);

/// Sent to the app's isolate after each point, so a map on screen
/// redraws: the recorder writes through its own connection, which the
/// app's streams cannot see.
const trailPointMessage = 'places.point';

/// Entry point of the foreground service's isolate.
@pragma('vm:entry-point')
void startTrailRecorder() {
  FlutterForegroundTask.setTaskHandler(TrailRecorder());
}

/// Records the trail while the foreground service runs.
///
/// It lives in the service's own isolate, so it outlasts the app's
/// screens: closing the app from recents does not stop the trail, only
/// the switch does. It opens its own database connection, the way the
/// 3 AM job does, and closes it when the service stops.
class TrailRecorder extends TaskHandler {
  HarvestDatabase? _db;
  StreamSubscription<Position>? _positions;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    DartPluginRegistrant.ensureInitialized();
    final db = _db = HarvestDatabase();
    final places = PlacesRepository(db);
    final high = await _highAccuracy(db);
    _positions =
        Geolocator.getPositionStream(
          locationSettings: AndroidSettings(
            accuracy: high ? LocationAccuracy.high : LocationAccuracy.medium,
            distanceFilter: trailDistanceFilterM,
            intervalDuration: trailInterval,
            forceLocationManager: true,
          ),
        ).listen(
          (position) async {
            try {
              await places.addPoint(fixOf(position));
              FlutterForegroundTask.sendDataToMain(trailPointMessage);
            } on Object catch (error) {
              debugPrint('[places] point not written: ${error.runtimeType}');
            }
          },
          onError: (Object error) =>
              debugPrint('[places] trail error: ${error.runtimeType}'),
        );
  }

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    await _positions?.cancel();
    await _db?.close();
    _db = null;
  }

  Future<bool> _highAccuracy(HarvestDatabase db) async {
    final row = await (db.select(
      db.kvSettings,
    )..where((s) => s.key.equals('places.highAccuracy'))).getSingleOrNull();
    return row?.valueJson.contains('true') ?? false;
  }
}
