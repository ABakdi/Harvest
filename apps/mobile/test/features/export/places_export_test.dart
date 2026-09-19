import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/features/export/data/export_repository.dart';
import 'package:harvest/features/places/data/places_repository.dart';
import 'package:harvest/features/places/domain/place.dart';

/// Location leaves the phone in an export only with my say-so, per
/// export ([[Places]] PL6).
void main() {
  test('an export can leave the location history out', () async {
    final db = HarvestDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final places = PlacesRepository(db);
    await places.addPoint(
      Fix(latitude: 36.7, longitude: 3.1, at: DateTime(2026, 9, 19, 12)),
    );
    await places.savePlace(name: 'Home', latitude: 36.7, longitude: 3.1);
    db.geotagging = true;
    await db.logChange('notes', 'n1', 'insert');

    final repository = ExportRepository(db);
    final full = (await repository.readArchive()).data;
    expect(full.locationPoints, hasLength(1));
    expect(full.savedPlaces, hasLength(1));
    expect(full.geotags, hasLength(1));

    final without = (await repository.readArchive(includePlaces: false)).data;
    expect(without.locationPoints, isEmpty);
    expect(without.savedPlaces, isEmpty);
    expect(without.geotags, isEmpty);
  });
}
