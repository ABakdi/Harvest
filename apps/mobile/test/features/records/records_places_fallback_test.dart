import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/app/current_day.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/db/database_provider.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/notes/presentation/notes_screen.dart';
import 'package:harvest/features/places/data/location_gateway.dart';
import 'package:harvest/features/places/presentation/places_providers.dart';
import 'package:harvest/features/places/presentation/places_screen.dart';
import 'package:harvest/features/records/presentation/records_screen.dart';
import 'package:harvest/features/settings/data/settings_repository.dart';
import 'package:harvest/features/settings/domain/feature_switches.dart';
import 'package:harvest/l10n/app_localizations.dart';

import '../../support/fake_location.dart';

class _FixedDay extends CurrentHarvestDay {
  @override
  HarvestDay build() => HarvestDay.parse('2026-09-19');
}

class _QuietController extends PlacesController {
  @override
  Future<TrailState> build() async => const TrailState(
    access: LocationAccess.whileInUse,
    wanted: false,
    running: false,
  );
}

/// Records remembers its last half, and Places is one of them. A map
/// that took the app down must not be landed on again every time
/// Records opens: until the map has been seen to draw on this phone,
/// Records opens on Notes, and Places stays a tap away ([[Places]]).
void main() {
  late HarvestDatabase db;

  setUp(() => db = HarvestDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() async => db.close());

  Future<void> pumpRecords(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          currentHarvestDayProvider.overrideWith(_FixedDay.new),
          notesEnabledProvider.overrideWithValue(true),
          galleryEnabledProvider.overrideWithValue(false),
          placesEnabledProvider.overrideWithValue(true),
          placesControllerProvider.overrideWith(_QuietController.new),
          locationGatewayProvider.overrideWithValue(FakeLocationGateway()),
          // No style: the platform map stays out of the test.
          placesStyleUrlProvider.overrideWith((ref) => const Stream.empty()),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: RecordsScreen(),
        ),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// Takes the screen down and lets the database's streams close.
  Future<void> leave(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  Future<String?> mark() =>
      SettingsRepository(db).getString(PlacesMapHealth.key);

  testWidgets('a map that never drew sends Records to Notes', (tester) async {
    final settings = SettingsRepository(db);
    await settings.setString(SettingKeys.recordsTab, RecordsTab.places.name);
    // Left by the last visit, which never got as far as drawing.
    await settings.setString(PlacesMapHealth.key, PlacesMapHealth.opening);

    await pumpRecords(tester);

    expect(find.byType(NotesScreen), findsOneWidget);
    expect(find.byType(PlacesScreen), findsNothing);
    await leave(tester);
  });

  testWidgets('a map never opened on this phone is not landed on either', (
    tester,
  ) async {
    await SettingsRepository(
      db,
    ).setString(SettingKeys.recordsTab, RecordsTab.places.name);

    await pumpRecords(tester);

    expect(find.byType(NotesScreen), findsOneWidget);
    expect(find.byType(PlacesScreen), findsNothing);
    await leave(tester);
  });

  testWidgets('a map that has drawn is remembered, and marked on the way in', (
    tester,
  ) async {
    final settings = SettingsRepository(db);
    await settings.setString(SettingKeys.recordsTab, RecordsTab.places.name);
    await settings.setString(PlacesMapHealth.key, PlacesMapHealth.shown);

    await pumpRecords(tester);

    expect(find.byType(PlacesScreen), findsOneWidget);
    // Opening the map marks it, until it draws again: a crash from
    // here on lands the next visit on Notes.
    expect(await tester.runAsync(mark), PlacesMapHealth.opening);
    await leave(tester);
  });
}
