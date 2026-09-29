import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:harvest/features/places/domain/place.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

/// The closest the map goes. The streets' tiles stop at 14 and are
/// stretched past it; left unbounded, a fit around points that all sit
/// in one spot asked for zoom 25, where the stretched buildings took the
/// phone's memory in seconds and no tile was ever drawn.
const placesMaxZoom = 19.0;

/// How close the map comes to a single spot, or to points too near
/// each other to be worth a box around them.
const placesSpotZoom = 15.0;

/// Points closer together than this, in degrees (about 150 m), are one
/// spot: the map centres on them rather than fitting a box.
const placesSpotSpan = 0.0015;

/// Where the camera goes to show [points]: centred on one spot, or
/// fitted around them with room left for the timeline sheet.
CameraUpdate placesCameraFor(List<LatLng> points) {
  var south = points.first.latitude;
  var north = south;
  var west = points.first.longitude;
  var east = west;
  for (final p in points) {
    south = math.min(south, p.latitude);
    north = math.max(north, p.latitude);
    west = math.min(west, p.longitude);
    east = math.max(east, p.longitude);
  }
  // Every pin in one place — a day spent at home — has no box to fit.
  if (north - south < placesSpotSpan && east - west < placesSpotSpan) {
    return CameraUpdate.newLatLngZoom(
      LatLng((south + north) / 2, (west + east) / 2),
      placesSpotZoom,
    );
  }
  return CameraUpdate.newLatLngBounds(
    LatLngBounds(
      southwest: LatLng(south, west),
      northeast: LatLng(north, east),
    ),
    left: 48,
    top: 48,
    right: 48,
    bottom: 220,
  );
}

/// The source and layer the saved places' names are drawn from. Their
/// own, not symbol annotations: those pass the font per feature, which
/// the native map refuses ("text-font must be literals") and draws no
/// name at all.
const placeNamesSource = 'harvest-place-names';
const placeNamesLayer = 'harvest-place-names-text';

/// The saved places as GeoJSON points, each with its uuid as the
/// feature id (what a tap on its name hands back) and its name.
Map<String, dynamic> placeNamesGeoJson(List<SavedPlace> places) => {
  'type': 'FeatureCollection',
  'features': [
    for (final place in places)
      {
        'type': 'Feature',
        'id': place.uuid,
        'properties': {'place': place.uuid, 'name': place.name},
        'geometry': {
          'type': 'Point',
          'coordinates': [place.longitude, place.latitude],
        },
      },
  ],
};

/// How the names look: dark text on a white halo under the red dot. The
/// font is one literal for every name — the one font OpenFreeMap serves
/// that every base can reach; the default stack names fonts it does not
/// have, and draws nothing.
SymbolLayerProperties placeNamesProperties() => const SymbolLayerProperties(
  textField: [Expressions.get, 'name'],
  textFont: [
    Expressions.literal,
    ['Noto Sans Regular'],
  ],
  textSize: 12.5,
  textColor: '#202124',
  textHaloColor: '#FFFFFF',
  textHaloWidth: 1.5,
  textAnchor: 'top',
  textOffset: [
    Expressions.literal,
    [0, 0.4],
  ],
  textAllowOverlap: true,
);

/// A floating map button, in the Google shape: a white card that casts
/// a shadow, with an icon that darkens when touched.
class PlacesMapButton extends StatelessWidget {
  const PlacesMapButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    super.key,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        elevation: 2,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          // 48 dp, the least a finger can be asked to hit (Q5-62).
          child: SizedBox(
            width: 48,
            height: 48,
            child: Icon(icon, size: 22),
          ),
        ),
      ),
    );
  }
}
