import 'dart:math' as math;

import 'package:harvest/core/domain/harvest_day.dart';
import 'package:meta/meta.dart';

/// Where the phone was, once.
@immutable
class Fix {
  const Fix({
    required this.latitude,
    required this.longitude,
    required this.at,
    this.accuracyM,
    this.speedMps,
    this.altitudeM,
  });

  final double latitude;
  final double longitude;
  final DateTime at;
  final double? accuracyM;
  final double? speedMps;
  final double? altitudeM;

  /// Metres to [other], on a sphere. Good to a few metres at the scales
  /// a day covers, which is all a stay or a geotag needs.
  double metresTo(({double latitude, double longitude}) other) =>
      haversineMetres(latitude, longitude, other.latitude, other.longitude);
}

/// One point of the trail, as stored.
@immutable
class TrailPoint {
  const TrailPoint({required this.uuid, required this.day, required this.fix});

  final String uuid;
  final HarvestDay day;
  final Fix fix;
}

/// Where an action happened ([[Places]] PL2).
@immutable
class Geotag {
  const Geotag({
    required this.uuid,
    required this.targetTable,
    required this.targetUuid,
    required this.day,
    required this.at,
    required this.state,
    this.latitude,
    this.longitude,
    this.accuracyM,
  });

  final String uuid;
  final String targetTable;
  final String targetUuid;
  final HarvestDay day;
  final DateTime at;
  final GeotagState state;
  final double? latitude;
  final double? longitude;
  final double? accuracyM;

  bool get hasPlace => latitude != null && longitude != null;
}

enum GeotagState { pending, fixed, unavailable }

/// A stay I gave a name.
@immutable
class SavedPlace {
  const SavedPlace({
    required this.uuid,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.radiusM = 100,
    this.notes,
  });

  final String uuid;
  final String name;
  final double latitude;
  final double longitude;
  final double radiusM;

  /// Whatever I want to remember about this place.
  final String? notes;

  bool contains(double lat, double lon) =>
      haversineMetres(latitude, longitude, lat, lon) <= radiusM;
}

/// A stretch of time spent in one spot ([[Places]] PL5): derived from
/// the trail, never stored.
@immutable
class Stay {
  const Stay({
    required this.latitude,
    required this.longitude,
    required this.from,
    required this.to,
    this.place,
  });

  final double latitude;
  final double longitude;
  final DateTime from;
  final DateTime to;

  /// The saved place it falls inside, if any.
  final SavedPlace? place;

  Duration get length => to.difference(from);
}

/// How long and how close a run of points must be to count as a stay.
const stayMinimum = Duration(minutes: 10);
const stayRadiusM = 100.0;

/// How far a saved place may reach, in metres: a room, a street, a
/// village. The web's form holds to the same numbers.
const minPlaceRadiusM = 10;
const maxPlaceRadiusM = 5000;

/// The stays in a day's trail, oldest first.
///
/// A stay is a run of consecutive points that all fall within
/// [stayRadiusM] of the run's first point and span at least
/// [stayMinimum]. The balanced sampler records nothing while the phone
/// sits still, so a stay is usually two points far apart in time and
/// close in space — which is why the rule is about the span, not the
/// count.
List<Stay> staysIn(
  List<Fix> trail, {
  List<SavedPlace> places = const [],
}) {
  final sorted = [...trail]..sort((a, b) => a.at.compareTo(b.at));
  final stays = <Stay>[];
  var i = 0;
  while (i < sorted.length) {
    final anchor = sorted[i];
    var j = i;
    while (j + 1 < sorted.length &&
        anchor.metresTo((
              latitude: sorted[j + 1].latitude,
              longitude: sorted[j + 1].longitude,
            )) <=
            stayRadiusM) {
      j++;
    }
    final run = sorted.sublist(i, j + 1);
    final span = run.last.at.difference(run.first.at);
    if (span >= stayMinimum) {
      final lat =
          run.fold<double>(0, (sum, fix) => sum + fix.latitude) / run.length;
      final lon =
          run.fold<double>(0, (sum, fix) => sum + fix.longitude) / run.length;
      stays.add(
        Stay(
          latitude: lat,
          longitude: lon,
          from: run.first.at,
          to: run.last.at,
          place: places.where((p) => p.contains(lat, lon)).firstOrNull,
        ),
      );
      i = j + 1;
    } else {
      i++;
    }
  }
  return stays;
}

double haversineMetres(double lat1, double lon1, double lat2, double lon2) {
  const earth = 6371000.0;
  double rad(double degrees) => degrees * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLon = rad(lon2 - lon1);
  final a =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(lat1)) *
          math.cos(rad(lat2)) *
          math.pow(math.sin(dLon / 2), 2);
  return 2 * earth * math.asin(math.sqrt(a));
}

/// The total length of a trail, in metres.
double trailMetres(List<Fix> trail) {
  var total = 0.0;
  for (var i = 1; i < trail.length; i++) {
    total += trail[i - 1].metresTo((
      latitude: trail[i].latitude,
      longitude: trail[i].longitude,
    ));
  }
  return total;
}
