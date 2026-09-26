import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:harvest/app/router.dart';
import 'package:harvest/app/shell.dart';
import 'package:harvest/core/ui/widgets/action_snack_bar.dart';
import 'package:harvest/features/settings/domain/feature_switches.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// Back closes what is open, then goes home to the field, and only the
/// field leaves the app; a snack bar stays with the tab it was said on,
/// and an Undo goes away on its own.
void main() {
  late List<String> exits;

  setUp(() => exits = []);

  Future<void> pumpShell(WidgetTester tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'SystemNavigator.pop') exits.add(call.method);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    Widget page(String name) => Scaffold(
      appBar: AppBar(title: Text(name)),
      drawer: const Drawer(child: Text('the drawer')),
      body: Builder(
        builder: (context) => Column(
          children: [
            TextButton(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                actionSnackBar(
                  ScaffoldMessenger.of(context),
                  content: Text('said on $name'),
                  action: SnackBarAction(label: 'Undo', onPressed: () {}),
                ),
              ),
              child: Text('say on $name'),
            ),
          ],
        ),
      ),
    );

    StatefulShellBranch branch(String path) => StatefulShellBranch(
      routes: [GoRoute(path: path, builder: (_, _) => page(path))],
    );

    final router = GoRouter(
      initialLocation: AppRoutes.records,
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) =>
              HarvestShell(navigationShell: shell),
          branches: [
            branch(AppRoutes.field),
            branch(AppRoutes.finances),
            branch(AppRoutes.stats),
            branch(AppRoutes.settings),
            branch(AppRoutes.body),
            branch(AppRoutes.records),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          featureSwitchesProvider.overrideWith(
            (ref) => Stream.value({
              ...FeatureKeys.defaults,
              FeatureKeys.notes: true,
            }),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> back(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
  }

  testWidgets('back closes the drawer, then goes to the field, then out', (
    tester,
  ) async {
    await pumpShell(tester);
    expect(find.text(AppRoutes.records), findsOneWidget);

    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    expect(find.text('the drawer'), findsOneWidget);

    await back(tester);
    expect(find.text('the drawer'), findsNothing);
    expect(find.text(AppRoutes.records), findsOneWidget);
    expect(exits, isEmpty);

    await back(tester);
    expect(find.text(AppRoutes.field), findsOneWidget);
    expect(exits, isEmpty);

    await back(tester);
    expect(exits, hasLength(1));
  });

  testWidgets('a snack bar does not follow me to the next tab', (
    tester,
  ) async {
    await pumpShell(tester);
    await tester.tap(find.text('say on ${AppRoutes.records}'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('said on ${AppRoutes.records}'), findsOneWidget);

    await tester.tap(find.byType(NavigationDestination).first);
    await tester.pumpAndSettle();
    expect(find.text('said on ${AppRoutes.records}'), findsNothing);
  });

  testWidgets('an undo goes away on its own', (tester) async {
    await pumpShell(tester);
    await tester.tap(find.text('say on ${AppRoutes.records}'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('said on ${AppRoutes.records}'), findsOneWidget);

    // Frames go by while it is up, as they do on a phone: the messenger
    // starts its clock on a frame after the snack bar is fully in.
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    await tester.pumpAndSettle();
    expect(find.text('said on ${AppRoutes.records}'), findsNothing);
  });
}
