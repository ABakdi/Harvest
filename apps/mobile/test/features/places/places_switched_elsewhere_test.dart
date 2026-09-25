import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/db/database_provider.dart';
import 'package:harvest/features/places/data/location_gateway.dart';
import 'package:harvest/features/places/data/trail_service.dart';
import 'package:harvest/features/places/presentation/places_providers.dart';
import 'package:harvest/features/settings/data/settings_repository.dart';
import 'package:harvest/features/settings/domain/feature_switches.dart';

import '../../support/fake_location.dart';

/// Places switched on from the web arrives as a plain `features.places`
/// row, with no permission asked on this phone (PL1). The trail must
/// stay off until "all the time" is granted here, and nothing throws.
void main() {
  late HarvestDatabase db;
  late FakeLocationGateway gateway;
  late FakeTrailService trail;
  late ProviderContainer container;

  setUp(() {
    db = HarvestDatabase.forTesting(NativeDatabase.memory());
    gateway = FakeLocationGateway(granted: LocationAccess.none);
    trail = FakeTrailService();
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        locationGatewayProvider.overrideWithValue(gateway),
        trailServiceProvider.overrideWithValue(trail),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('a synced switch with no permission leaves the trail off', () async {
    await container.read(placesControllerProvider.future);
    final settings = SettingsRepository(db);
    // As the sync writes them: the switch, and a trail wanted elsewhere.
    await settings.setBool(FeatureKeys.places, value: true);
    await settings.setString(PlacesKeys.trail, 'true');

    await container.read(placesControllerProvider.notifier).sync();

    expect(db.geotagging, isTrue);
    expect(trail.running, isFalse);
    expect(trail.starts, 0);
    // Nothing was asked from the background either.
    expect(gateway.granted, LocationAccess.none);
    final state = container.read(placesControllerProvider).value!;
    expect(state.access, LocationAccess.none);
    expect(state.running, isFalse);

    // Granted later in the phone's settings: the next sync starts it.
    gateway.granted = LocationAccess.always;
    await container.read(placesControllerProvider.notifier).sync();
    expect(trail.running, isTrue);
  });
}
