import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/app/current_day.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/places/data/location_gateway.dart';
import 'package:harvest/features/places/domain/place.dart';
import 'package:harvest/features/places/presentation/places_providers.dart';
import 'package:harvest/features/places/presentation/places_screen.dart';
import 'package:harvest/l10n/app_localizations.dart';

import '../../support/fake_location.dart';

/// A day that stays put, so the test never arms the 3 AM rollover.
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

/// A location link lands the map on its day ([[Places]]): the request
/// is claimed outside build and cleared once taken.
void main() {
  final today = HarvestDay.parse('2026-09-19');
  final linked = HarvestDay.parse('2026-09-12');

  late ProviderContainer container;

  Future<void> pumpScreen(WidgetTester tester) async {
    container = ProviderContainer(
      overrides: [
        currentHarvestDayProvider.overrideWith(_FixedDay.new),
        placesControllerProvider.overrideWith(_QuietController.new),
        locationGatewayProvider.overrideWithValue(FakeLocationGateway()),
        // No style yet: the map widget itself stays out of the test.
        placesStyleUrlProvider.overrideWith((ref) => const Stream.empty()),
        placesMapBaseProvider.overrideWith(
          (ref) => Stream.value(MapBase.streets),
        ),
        savedPlacesProvider.overrideWith((ref) => Stream.value(const [])),
        for (final day in [today, linked]) ...[
          trailProvider((
            from: day,
            to: day,
          )).overrideWith((ref) => Stream.value(const [])),
          geotagsProvider((from: day, to: day)).overrideWith(
            (ref) => Stream.value(const <Geotag>[]),
          ),
        ],
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: PlacesScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  PlacesFocus focusOn(HarvestDay day) =>
      PlacesFocus(day: day, table: 'expenses', uuid: 'e1');

  testWidgets('a link that opened the map is claimed, without a build-time write', (
    tester,
  ) async {
    await pumpScreen(tester);
    // Set before the screen is built, as the chip does before pushing.
    await tester.pumpWidget(const SizedBox());
    container.read(placesFocusRequestProvider.notifier).focus = focusOn(
      linked,
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: PlacesScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(container.read(placesFocusRequestProvider), isNull);
    expect(find.textContaining('Sep 12'), findsWidgets);
    expect(find.textContaining('Sep 19'), findsNothing);
  });

  testWidgets('a link followed while the map is open is claimed too', (
    tester,
  ) async {
    await pumpScreen(tester);

    container.read(placesFocusRequestProvider.notifier).focus = focusOn(
      linked,
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(container.read(placesFocusRequestProvider), isNull);
    expect(find.textContaining('Sep 12'), findsWidgets);
    expect(find.textContaining('Sep 19'), findsNothing);
  });
}
