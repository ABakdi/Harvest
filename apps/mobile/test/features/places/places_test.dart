import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/db/database_provider.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/places/data/location_gateway.dart';
import 'package:harvest/features/places/data/places_repository.dart';
import 'package:harvest/features/places/data/trail_service.dart';
import 'package:harvest/features/places/domain/geotag_filler.dart';
import 'package:harvest/features/places/domain/place.dart';
import 'package:harvest/features/places/presentation/places_providers.dart';
import 'package:harvest/features/settings/data/settings_repository.dart';
import 'package:harvest/features/settings/domain/feature_switches.dart';

import '../../support/fake_location.dart';

/// Phase 5, M5.3: the trail and the geotags ([[Places]]).
void main() {
  late HarvestDatabase db;
  late PlacesRepository places;
  late FakeLocationGateway gateway;

  final now = DateTime(2026, 9, 19, 14);
  Fix at(double lat, double lon, DateTime when, {double accuracy = 10}) =>
      Fix(latitude: lat, longitude: lon, at: when, accuracyM: accuracy);

  setUp(() {
    db = HarvestDatabase.forTesting(NativeDatabase.memory());
    places = PlacesRepository(db);
    gateway = FakeLocationGateway();
  });

  tearDown(() async => db.close());

  Future<GeotagRow> tagOf(String table, String uuid) =>
      (db.select(db.geotags)..where(
            (g) => g.targetTable.equals(table) & g.targetUuid.equals(uuid),
          ))
          .getSingle();

  Future<void> fill() async => GeotagFiller(
    places,
    gateway,
    clock: () => now,
  ).fillAll(await places.pendingOnce());

  group('the filler (PL2, PL3)', () {
    test('uses a fresh, sharp trail point without asking the phone', () async {
      db.geotagging = true;
      await places.addPoint(
        at(36.75, 3.06, now.subtract(const Duration(seconds: 30))),
      );
      await db.logChange('expenses', 'e1', 'insert');
      await fill();

      final tag = await tagOf('expenses', 'e1');
      expect(tag.state, 'fixed');
      expect(tag.latitude, 36.75);
      expect(gateway.fixRequests, 0);
    });

    test(
      'asks for one fix when the trail is stale, for the whole batch',
      () async {
        db.geotagging = true;
        await places.addPoint(
          at(1, 1, now.subtract(const Duration(minutes: 10))),
        );
        await db.logChange('expenses', 'e1', 'insert');
        await db.logChange('money_txns', 'm1', 'insert');
        gateway.fix = at(36.7, 3.1, now);
        await fill();

        expect((await tagOf('expenses', 'e1')).latitude, 36.7);
        expect((await tagOf('money_txns', 'm1')).latitude, 36.7);
        expect(gateway.fixRequests, 1);
      },
    );

    test('the last known position stands in, only while recent', () async {
      db.geotagging = true;
      await db.logChange('expenses', 'e1', 'insert');
      gateway.last = at(5, 5, now.subtract(const Duration(minutes: 3)));
      await fill();
      expect((await tagOf('expenses', 'e1')).latitude, 5);

      await db.logChange('expenses', 'e2', 'insert');
      gateway.last = at(6, 6, now.subtract(const Duration(hours: 2)));
      await fill();
      expect((await tagOf('expenses', 'e2')).state, 'unavailable');
    });

    test('a vague point is not good enough', () async {
      db.geotagging = true;
      await places.addPoint(
        at(1, 1, now.subtract(const Duration(seconds: 5)), accuracy: 800),
      );
      await db.logChange('notes', 'n1', 'insert');
      gateway.fix = at(2, 2, now);
      await fill();
      expect((await tagOf('notes', 'n1')).latitude, 2);
    });

    test('no permission marks it unavailable, and it stays that way', () async {
      db.geotagging = true;
      await db.logChange('memories', 'p1', 'insert');
      gateway.granted = LocationAccess.none;
      await fill();
      final tag = await tagOf('memories', 'p1');
      expect(tag.state, 'unavailable');
      expect(tag.latitude, isNull);
      expect(gateway.fixRequests, 0);
      expect(await places.pendingOnce(), isEmpty);
    });

    test(
      "an old pending tag, as sync brings one, never gets this phone's place",
      () async {
        Future<void> pendingAt(String uuid, DateTime when) =>
            db.into(db.geotags).insert(
              GeotagsCompanion.insert(
                uuid: uuid,
                targetTable: 'notes',
                targetUuid: 'n-$uuid',
                harvestDay: harvestDayKeyOf(when),
                at: when,
              ),
            );
        await pendingAt('old', now.subtract(const Duration(hours: 2)));
        await pendingAt('mine', now.subtract(const Duration(minutes: 1)));
        gateway.fix = at(36.7, 3.1, now);
        await fill();

        final old = await tagOf('notes', 'n-old');
        expect(old.state, 'unavailable');
        expect(old.latitude, isNull);
        expect(old.longitude, isNull);
        final mine = await tagOf('notes', 'n-mine');
        expect(mine.state, 'fixed');
        expect(mine.latitude, 36.7);
        expect(gateway.fixRequests, 1);
        expect(await places.pendingOnce(), isEmpty);
      },
    );
    test('an old pending tag takes the trail from its own time', () async {
      final then = now.subtract(const Duration(hours: 2));
      await places.addPoint(at(36.8, 3, then.add(const Duration(seconds: 40))));
      await places.addPoint(at(36.9, 3.2, now.subtract(const Duration(seconds: 20))));
      await db.into(db.geotags).insert(
        GeotagsCompanion.insert(
          uuid: 'waited',
          targetTable: 'notes',
          targetUuid: 'n-waited',
          harvestDay: harvestDayKeyOf(then),
          at: then,
        ),
      );
      await fill();

      final tag = await tagOf('notes', 'n-waited');
      expect(tag.state, 'fixed');
      expect(tag.latitude, 36.8);
      expect(gateway.fixRequests, 0);
    });
  });

  group('stays (PL5)', () {
    final morning = DateTime(2026, 9, 19, 8);

    test('two points far apart in time and close in space are a stay', () {
      final stays = staysIn([
        at(36.7000, 3, morning),
        at(36.7002, 3.0001, morning.add(const Duration(hours: 9))),
        at(36.7300, 3.0500, morning.add(const Duration(hours: 9, minutes: 20))),
      ]);
      expect(stays, hasLength(1));
      expect(stays.single.length, const Duration(hours: 9));
    });

    test('moving on is not a stay, and a saved place names one', () {
      const home = SavedPlace(
        uuid: 'h',
        name: 'Home',
        latitude: 36.7001,
        longitude: 3,
      );
      final trail = [
        for (var i = 0; i < 5; i++)
          at(36.60 + i * 0.01, 3, morning.add(Duration(minutes: i * 3))),
        at(36.7001, 3, morning.add(const Duration(hours: 1))),
        at(36.7002, 3, morning.add(const Duration(hours: 2))),
      ];
      final stays = staysIn(trail, places: [home]);
      expect(stays.single.place?.name, 'Home');
    });
  });

  test('a day of trail is deleted whole and comes back (PL4)', () async {
    final day = HarvestDay.of(now);
    await places.addPoint(at(1, 1, now));
    await places.addPoint(at(1.1, 1.1, now.add(const Duration(minutes: 5))));
    final deletedAt = await places.deleteDay(day);
    expect(await places.watchTrail(day, day).first, isEmpty);
    await places.restoreDay(day, deletedAt);
    expect(await places.watchTrail(day, day).first, hasLength(2));
  });

  group('the controller (PL1)', () {
    late ProviderContainer container;
    late FakeTrailService trail;

    setUp(() {
      trail = FakeTrailService();
      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          locationGatewayProvider.overrideWithValue(gateway),
          trailServiceProvider.overrideWithValue(trail),
        ],
      );
    });
    tearDown(() => container.dispose());

    PlacesController controller() =>
        container.read(placesControllerProvider.notifier);

    test('switching Places on turns on geotags, not the trail', () async {
      gateway.granted = LocationAccess.none;
      await container.read(placesControllerProvider.future);
      await controller().enable();
      expect(db.geotagging, isTrue);
      expect(trail.running, isFalse);
      expect(
        await SettingsRepository(db).getString(FeatureKeys.places),
        'true',
      );
    });

    test('the trail runs only with "all the time", and pauses', () async {
      await container.read(placesControllerProvider.future);
      await controller().enable();

      gateway.alwaysAnswer = LocationAccess.whileInUse;
      await controller().setTrail(on: true);
      expect(trail.running, isFalse, reason: 'refused: geotags only');

      gateway.alwaysAnswer = LocationAccess.always;
      await controller().setTrail(on: true);
      expect(trail.running, isTrue);

      await controller().pause(DateTime.now().add(const Duration(hours: 1)));
      expect(trail.running, isFalse);
      await controller().resume();
      expect(trail.running, isTrue);

      await controller().disable();
      expect(trail.running, isFalse);
      expect(db.geotagging, isFalse);
    });

    test('a pause that has run out resumes on the next sync', () async {
      await container.read(placesControllerProvider.future);
      await controller().enable();
      await controller().setTrail(on: true);
      await controller().pause(
        DateTime.now().subtract(const Duration(minutes: 1)),
      );
      expect(trail.running, isTrue);
    });
  });
}
