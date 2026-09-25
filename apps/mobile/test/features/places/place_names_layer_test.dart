import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/features/places/domain/place.dart';
import 'package:harvest/features/places/presentation/places_screen.dart';

/// How the saved places' names reach the map ([[Places]]).
///
/// They used to be symbol annotations, whose font the plugin passes as a
/// per-feature expression; the native map refuses that for `text-font`
/// and drew no name on any base. The names now have their own source and
/// layer, with the font as one literal.
void main() {
  const office = SavedPlace(
    uuid: 'p-office',
    name: 'Office',
    latitude: 36.75,
    longitude: 3.06,
  );

  test('every saved place is a point with its uuid as the id', () {
    final json = placeNamesGeoJson([office]);
    final features = json['features'] as List;
    expect(features, hasLength(1));
    final feature = features.single as Map<String, dynamic>;
    expect(feature['id'], 'p-office');
    expect(feature['properties'], {'place': 'p-office', 'name': 'Office'});
    expect(feature['geometry'], {
      'type': 'Point',
      'coordinates': [3.06, 36.75],
    });
  });

  test('no saved places is an empty collection, not a missing one', () {
    expect(placeNamesGeoJson(const [])['features'], isEmpty);
  });

  test('the font is a literal, not read per feature', () {
    final json = placeNamesProperties().toJson();
    expect(json['text-font'], [
      'literal',
      ['Noto Sans Regular'],
    ]);
    expect(json['text-field'], ['get', 'name']);
  });
}
