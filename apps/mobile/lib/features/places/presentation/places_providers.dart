import 'dart:async';

import 'package:drift/drift.dart' show TableUpdate;
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:harvest/core/db/database_provider.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/places/data/location_gateway.dart';
import 'package:harvest/features/places/data/places_repository.dart';
import 'package:harvest/features/places/data/trail_service.dart';
import 'package:harvest/features/places/domain/geotag_filler.dart';
import 'package:harvest/features/places/domain/place.dart';
import 'package:harvest/features/places/domain/trail_recorder.dart';
import 'package:harvest/features/settings/data/settings_repository.dart';
import 'package:harvest/features/settings/domain/feature_switches.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'places_providers.g.dart';

abstract final class PlacesKeys {
  /// Whether the trail should be recording ('true' / 'false').
  static const trail = 'places.trail';

  /// A pause's end, as an ISO timestamp; absent when not paused.
  static const pausedUntil = 'places.pausedUntil';

  static const highAccuracy = 'places.highAccuracy';

  /// The map style ([[ADR-010-Maps]]): OpenFreeMap's by default.
  static const styleUrl = 'places.styleUrl';

  static const defaultStyleUrl = 'https://tiles.openfreemap.org/styles/liberty';
}

/// What the Places settings and screen show about the trail.
@immutable
class TrailState {
  const TrailState({
    required this.access,
    required this.wanted,
    required this.running,
    this.pausedUntil,
  });

  final LocationAccess access;

  /// I switched the trail on (it may still be paused or refused).
  final bool wanted;

  /// The service is actually up.
  final bool running;
  final DateTime? pausedUntil;

  bool get paused => pausedUntil != null;
}

/// Keeps the trail, the geotags and the filler in step with the
/// settings ([[Places]]).
///
/// Everything here is idempotent and cheap to call again: it runs at
/// startup, on every resume, and after every switch.
@Riverpod(keepAlive: true)
class PlacesController extends _$PlacesController {
  GeotagFiller? _filler;
  var _listening = false;

  @override
  Future<TrailState> build() => _read();

  Future<TrailState> _read() async {
    final settings = ref.read(settingsRepositoryProvider);
    final wanted = await settings.getString(PlacesKeys.trail) == 'true';
    final paused = DateTime.tryParse(
      await settings.getString(PlacesKeys.pausedUntil) ?? '',
    );
    return TrailState(
      access: await ref.read(locationGatewayProvider).access(),
      wanted: wanted,
      running: await ref.read(trailServiceProvider).isRunning(),
      pausedUntil: paused,
    );
  }

  /// Brings everything in line with the settings. Called at startup,
  /// on resume and after any change.
  Future<void> sync({String? title, String? text}) async {
    final enabled = await _enabled();
    ref.read(databaseProvider).geotagging = enabled;
    _listenForPoints();

    final repository = ref.read(placesRepositoryProvider);
    if (enabled) {
      (_filler ??= GeotagFiller(
        repository,
        ref.read(locationGatewayProvider),
      )).start();
    } else {
      await _filler?.stop();
    }

    final settings = ref.read(settingsRepositoryProvider);
    var pausedUntil = DateTime.tryParse(
      await settings.getString(PlacesKeys.pausedUntil) ?? '',
    );
    if (pausedUntil != null && !pausedUntil.isAfter(DateTime.now())) {
      await settings.remove(PlacesKeys.pausedUntil);
      pausedUntil = null;
    }
    final wanted = await settings.getString(PlacesKeys.trail) == 'true';
    final access = await ref.read(locationGatewayProvider).access();
    final service = ref.read(trailServiceProvider);
    final shouldRun =
        enabled &&
        wanted &&
        pausedUntil == null &&
        access == LocationAccess.always;
    if (shouldRun) {
      await service.start(
        title: title ?? 'Harvest',
        text: text ?? 'Recording your trail',
      );
    } else {
      await service.stop();
    }
    state = AsyncData(await _read());
  }

  /// First switch-on: the "while using the app" ask (PL1, step one).
  Future<LocationAccess> enable() async {
    final access = await ref.read(locationGatewayProvider).requestWhileInUse();
    await ref
        .read(settingsRepositoryProvider)
        .setBool(FeatureKeys.places, value: true);
    await sync();
    return access;
  }

  Future<void> disable() async {
    await ref
        .read(settingsRepositoryProvider)
        .setBool(FeatureKeys.places, value: false);
    await sync();
  }

  /// The trail on: the "all the time" ask (PL1, step two). Refused, the
  /// trail stays off and geotags keep working.
  Future<LocationAccess> setTrail({
    required bool on,
    String? title,
    String? text,
  }) async {
    final settings = ref.read(settingsRepositoryProvider);
    var access = await ref.read(locationGatewayProvider).access();
    if (on && access != LocationAccess.always) {
      access = await ref.read(locationGatewayProvider).requestAlways();
    }
    await settings.setBool(
      PlacesKeys.trail,
      value: on && access == LocationAccess.always,
    );
    if (!on) await settings.remove(PlacesKeys.pausedUntil);
    await sync(title: title, text: text);
    return access;
  }

  /// Stops the service until [until]; the next sync after it resumes.
  Future<void> pause(DateTime until) async {
    await ref
        .read(settingsRepositoryProvider)
        .setString(PlacesKeys.pausedUntil, until.toIso8601String());
    await sync();
  }

  Future<void> resume() async {
    await ref.read(settingsRepositoryProvider).remove(PlacesKeys.pausedUntil);
    await sync();
  }

  Future<bool> _enabled() async =>
      await ref
          .read(settingsRepositoryProvider)
          .getString(FeatureKeys.places) ==
      'true';

  /// The recorder writes through its own connection; each point it
  /// sends here tells the app's streams to look again.
  void _listenForPoints() {
    if (_listening) return;
    _listening = true;
    try {
      FlutterForegroundTask.initCommunicationPort();
      FlutterForegroundTask.addTaskDataCallback((data) {
        if (data == trailPointMessage) {
          final db = ref.read(databaseProvider);
          db.notifyUpdates({TableUpdate.onTable(db.locationPoints)});
        }
      });
    } on Object catch (error) {
      debugPrint('[places] no trail channel: ${error.runtimeType}');
    }
  }
}

/// The span the map shows: one day, or a range for the travel view.
typedef PlacesSpan = ({HarvestDay from, HarvestDay to});

@riverpod
Stream<List<TrailPoint>> trail(Ref ref, PlacesSpan span) =>
    ref.watch(placesRepositoryProvider).watchTrail(span.from, span.to);

@riverpod
Stream<List<Geotag>> geotags(Ref ref, PlacesSpan span) =>
    ref.watch(placesRepositoryProvider).watchGeotags(span.from, span.to);

@riverpod
Stream<List<SavedPlace>> savedPlaces(Ref ref) =>
    ref.watch(placesRepositoryProvider).watchSavedPlaces();

@riverpod
Stream<int> pointsOn(Ref ref, HarvestDay day) =>
    ref.watch(placesRepositoryProvider).watchCountOn(day);
