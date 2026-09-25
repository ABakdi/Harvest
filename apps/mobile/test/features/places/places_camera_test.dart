import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/features/places/presentation/places_screen.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

/// Where the map's camera goes for a day's points ([[Places]]).
///
/// A day whose pins all sat in one spot used to be fitted with a box of
/// no size at all, which sent the camera to the map's deepest zoom: the
/// streets' tiles stretched twenty-fold, memory gone in seconds, the app
/// killed and no tile ever drawn.
void main() {
  const home = LatLng(36.758, 3.066);

  test('points all in one spot centre the map at street level', () {
    final update = placesCameraFor([home, home, home]).toJson() as List;
    expect(update.first, 'newLatLngZoom');
    expect(update[2], placesSpotZoom);
  });

  test('one point is a spot too', () {
    final update = placesCameraFor([home]).toJson() as List;
    expect(update.first, 'newLatLngZoom');
    expect(update[1], [home.latitude, home.longitude]);
  });

  test('points a few metres apart are one spot, not a box', () {
    final update =
        placesCameraFor([
              home,
              const LatLng(36.7581, 3.0661),
              const LatLng(36.7579, 3.0662),
            ]).toJson()
            as List;
    expect(update.first, 'newLatLngZoom');
    expect(update[2], lessThanOrEqualTo(placesMaxZoom));
  });

  test('a day across town is fitted in a box', () {
    final update =
        placesCameraFor([home, const LatLng(36.73, 3.09)]).toJson() as List;
    expect(update.first, 'newLatLngBounds');
  });

  test('the map never zooms past what its tiles can show', () {
    expect(placesMaxZoom, lessThanOrEqualTo(20));
    expect(placesSpotZoom, lessThanOrEqualTo(placesMaxZoom));
  });
}
