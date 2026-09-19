import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:harvest/features/places/data/location_gateway.dart';
import 'package:harvest/features/places/data/places_repository.dart';
import 'package:harvest/features/places/domain/place.dart';

/// How old a trail point may be and still say where an action happened.
const trailPointFreshness = Duration(minutes: 2);

/// How vague a trail point may be and still stand in for a fresh fix.
const trailPointAccuracyM = 100.0;

/// Gives every pending geotag a place, or marks it unavailable
/// ([[Places]] PL2, PL3).
///
/// Three tries, cheapest first: the trail's last point if it is recent
/// and sharp enough, then one fresh fix, then nothing. The action it
/// tags was written long before any of this runs; a missing place
/// never reaches back to it.
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
      for (final tag in pending) {
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

  Future<Fix?> _fresh() async {
    final access = await _gateway.access();
    if (access != LocationAccess.whileInUse &&
        access != LocationAccess.always) {
      return null;
    }
    return _gateway.currentFix();
  }
}
