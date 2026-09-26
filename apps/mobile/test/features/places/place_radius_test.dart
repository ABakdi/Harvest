import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/features/places/data/places_repository.dart';
import 'package:harvest/features/places/domain/place.dart';
import 'package:harvest/features/places/presentation/place_form.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// A saved place's reach is edited on its card, on the phone as on the
/// web, between the same bounds ([[Places]]).
void main() {
  group('the repository', () {
    late HarvestDatabase db;
    late PlacesRepository places;

    setUp(() {
      db = HarvestDatabase.forTesting(NativeDatabase.memory());
      places = PlacesRepository(db);
    });

    tearDown(() async => db.close());

    Future<SavedPlace> home() async =>
        (await places.watchSavedPlaces().first).single;

    test('changes the reach and leaves the rest as it was', () async {
      await places.savePlace(
        name: 'Home',
        latitude: 36.75,
        longitude: 3.06,
        notes: 'Blue door',
      );
      final before = await home();
      final logged = (await db.select(db.outbox).get()).length;

      await places.updatePlace(before.uuid, radiusM: 250);

      final after = await home();
      expect(after.radiusM, 250);
      expect(after.name, 'Home');
      expect(after.notes, 'Blue door');
      expect(after.latitude, before.latitude);
      // Synced like any edit.
      expect(await db.select(db.outbox).get(), hasLength(logged + 1));
    });

    test('a name-only edit keeps the reach', () async {
      await places.savePlace(
        name: 'Gym',
        latitude: 1,
        longitude: 1,
        radiusM: 40,
      );
      final gym = await home();
      await places.updatePlace(gym.uuid, name: 'The gym', changeName: true);
      expect((await home()).radiusM, 40);
    });

    test('refuses a reach out of bounds, writing nothing', () async {
      await places.savePlace(name: 'Home', latitude: 1, longitude: 1);
      final place = await home();
      final logged = (await db.select(db.outbox).get()).length;
      for (final bad in [minPlaceRadiusM - 1.0, maxPlaceRadiusM + 1.0]) {
        expect(
          () => places.updatePlace(place.uuid, radiusM: bad),
          throwsArgumentError,
        );
      }
      expect((await home()).radiusM, stayRadiusM);
      expect(await db.select(db.outbox).get(), hasLength(logged));
    });

    test("the bounds are the web form's", () {
      expect(minPlaceRadiusM, 10);
      expect(maxPlaceRadiusM, 5000);
    });
  });

  group('the form', () {
    PlaceDraft? draft;

    Future<void> openForm(WidgetTester tester, {double radiusM = 100}) async {
      draft = null;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  draft = await showDialog<PlaceDraft>(
                    context: context,
                    builder: (_) => PlaceFormDialog(
                      title: 'Edit place',
                      nameHint: 'Home',
                      initialName: 'Home',
                      initialRadiusM: radiusM,
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    Finder reach() => find.widgetWithText(TextField, 'Reach (m)');

    testWidgets("opens on the place's reach and hands back the new one", (
      tester,
    ) async {
      await openForm(tester, radiusM: 150);
      expect(find.text('150'), findsOneWidget);
      expect(find.text('Between 10 and 5000 m'), findsOneWidget);

      await tester.enterText(reach(), '320');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.byType(PlaceFormDialog), findsNothing);
      expect(draft?.name, 'Home');
      expect(draft?.radiusM, 320);
    });

    testWidgets('holds on a reach out of bounds', (tester) async {
      await openForm(tester);
      for (final bad in ['6000', '5', '']) {
        await tester.enterText(reach(), bad);
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        // Still open, the bounds now said as the error.
        expect(find.byType(PlaceFormDialog), findsOneWidget);
        final field = tester.widget<TextField>(reach());
        expect(field.decoration?.errorText, 'Between 10 and 5000 m');
      }
      expect(draft, isNull);
    });
  });
}
