import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:harvest/features/places/data/location_gateway.dart';
import 'package:harvest/features/places/data/places_repository.dart';
import 'package:harvest/features/places/domain/place.dart';

/// How old a trail point may be and still say where an action happened.
const trailPointFreshness = Duration(minutes: 2);

/// How old the phone's last known position may be and still stand in
/// when a fresh fix does not come.
const lastKnownFreshness = Duration(minutes: 10);

/// How vague a trail point may be and still stand in for a fresh fix.
const trailPointAccuracyM = 100.0;

/// How old a pending geotag may be and still be given this phone's
/// position. Anything older was not made here just now — it came by
/// sync, or outlived an app that was closed before its fix — and where
/// the phone is today says nothing about where it happened.
const Duration ownTagWindow = lastKnownFreshness;

/// Gives every pending geotag a place, or marks it unavailable
/// ([[Places]] PL2, PL3).
///
/// Four tries, cheapest first: the trail's last point if it is recent
/// and sharp enough, then one fresh fix, then the phone's last known
/// position if it is from the last ten minutes — a fresh fix can fail
/// indoors, underground or with only satellites to ask — then nothing. The action it
/// tags was written long before any of this runs; a missing place
/// never reaches back to it.
///
/// Only a tag from the last [ownTagWindow] is given where the phone is
/// now. An older one can only take the trail point recorded at its own
/// time, if the trail was on; otherwise it is marked unavailable, with
/// no position, and the chip shows it muted (PL3, PL8).
class GeotagFiller {
  GeotagFiller(this._places, this._gateway, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final PlacesRepository _places;
  final LocationGateway _gateway;
  final DateTime Function() _clock;

  StreamSubscription<List<Geotag>>? _subscription;
  var _running = false;

  /// Resolves what is pending now, and again whenever more arrives.
  void start() {
    _subscription ??= _places.watchPending().listen((pending) {
      if (pending.isNotEmpty) unawaited(fillAll(pending));
    });
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  /// One pass over [pending]. A pass already running swallows the call:
  /// its own writes re-trigger the stream, which picks up the rest.
  Future<void> fillAll(List<Geotag> pending) async {
    if (_running) return;
    _running = true;
    try {
      // One fix serves every tag that arrived together — five rows of a
      // single expense flow are one place, not five GPS requests.
      Fix? fresh;
      var asked = false;
      final since = _clock().subtract(ownTagWindow);
      for (final tag in pending) {
        if (tag.at.isBefore(since)) {
          await _places.resolve(tag.uuid, await _fromTrailAt(tag.at));
          continue;
        }
        var fix = await _fromTrail();
        if (fix == null) {
          if (!asked) {
            asked = true;
            fresh = await _fresh();
          }
          fix = fresh;
        }
        await _places.resolve(tag.uuid, fix);
      }
    } on Object catch (error) {
      debugPrint('[places] geotags not filled: ${error.runtimeType}');
    } finally {
      _running = false;
    }
  }

  Future<Fix?> _fromTrail() async {
    final point = await _places.lastPointSince(
      _clock().subtract(trailPointFreshness),
    );
    if (point == null) return null;
    final accuracy = point.accuracyM;
    if (accuracy != null && accuracy > trailPointAccuracyM) return null;
    return point;
  }

  /// The trail at [at], not now: for a tag that waited.
  Future<Fix?> _fromTrailAt(DateTime at) async {
    final point = await _places.pointNear(at, trailPointFreshness);
    if (point == null) return null;
    final accuracy = point.accuracyM;
    if (accuracy != null && accuracy > trailPointAccuracyM) return null;
    return point;
  }

  Future<Fix?> _fresh() async {
    final access = await _gateway.access();
    if (access != LocationAccess.whileInUse &&
        access != LocationAccess.always) {
      return null;
    }
    final fresh = await _gateway.currentFix();
    if (fresh != null) return fresh;
    final last = await _gateway.lastKnown();
    if (last == null) return null;
    final age = _clock().difference(last.at);
    return age <= lastKnownFreshness ? last : null;
  }
}
