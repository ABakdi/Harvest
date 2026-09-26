import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:harvest/app/router.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/places/domain/place.dart';
import 'package:harvest/features/places/presentation/geotag_chip.dart';
import 'package:harvest/features/places/presentation/places_providers.dart';
import 'package:harvest/features/settings/domain/feature_switches.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// The "where was it" line ([[Places]] PL2, PL3) and the map's
/// satellite view.
void main() {
  Geotag tag(GeotagState state, {double? latitude, double? longitude}) =>
      Geotag(
        uuid: 't1',
        targetTable: 'expenses',
        targetUuid: 'e1',
        day: HarvestDay.parse('2026-09-18'),
        at: DateTime(2026, 9, 18, 10),
        state: state,
        latitude: latitude,
        longitude: longitude,
      );

  late ProviderContainer container;

  Future<void> pumpChip(
    WidgetTester tester,
    Geotag? geotag, {
    bool placesOn = true,
  }) async {
    container = ProviderContainer(
      overrides: [
        geotagForProvider((
          table: 'expenses',
          uuid: 'e1',
        )).overrideWith((ref) => Stream.value(geotag)),
        savedPlacesProvider.overrideWith((ref) => Stream.value(const [])),
        placesEnabledProvider.overrideWith((ref) => placesOn),
      ],
    );
    addTearDown(container.dispose);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(
            body: GeotagChip(targetTable: 'expenses', targetUuid: 'e1'),
          ),
        ),
        GoRoute(
          path: AppRoutes.places,
          builder: (context, state) => const Scaffold(body: Text('the map')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a geotag still looking for its fix says nothing yet', (
    tester,
  ) async {
    await pumpChip(tester, tag(GeotagState.pending));
    expect(find.text('No location recorded'), findsNothing);
    expect(find.byType(InkWell), findsNothing);
  });

  testWidgets('a geotag that found no fix says so, quietly (PL3)', (
    tester,
  ) async {
    await pumpChip(tester, tag(GeotagState.unavailable));
    expect(find.text('No location recorded'), findsOneWidget);
  });

  testWidgets('a pin opens the map on it', (tester) async {
    await pumpChip(
      tester,
      tag(GeotagState.fixed, latitude: 36.75, longitude: 3.05),
    );
    await tester.tap(find.byType(InkWell));
    await tester.pumpAndSettle();

    expect(find.text('the map'), findsOneWidget);
    expect(container.read(placesFocusRequestProvider)?.uuid, 'e1');
  });

  testWidgets('with Places off, a pin leaves no request behind', (
    tester,
  ) async {
    await pumpChip(
      tester,
      tag(GeotagState.fixed, latitude: 36.75, longitude: 3.05),
      placesOn: false,
    );
    await tester.tap(find.byType(GeotagChip));
    await tester.pumpAndSettle();

    expect(find.text('the map'), findsNothing);
    expect(container.read(placesFocusRequestProvider), isNull);
  });

  test('the satellite view carries fonts for the map labels', () {
    final style = jsonDecode(satelliteStyleJson) as Map<String, dynamic>;
    expect(
      style['glyphs'],
      'https://tiles.openfreemap.org/fonts/{fontstack}/{range}.pbf',
    );
  });

  test('shows() is the one rule the photo viewer asks', () {
    expect(GeotagChip.shows(null), isFalse);
    expect(GeotagChip.shows(tag(GeotagState.pending)), isFalse);
    expect(GeotagChip.shows(tag(GeotagState.unavailable)), isTrue);
    expect(
      GeotagChip.shows(
        tag(GeotagState.fixed, latitude: 36.75, longitude: 3.05),
      ),
      isTrue,
    );
  });
}
