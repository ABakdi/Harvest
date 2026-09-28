import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/db/database_provider.dart';
import 'package:harvest/features/onboarding/presentation/onboarding_screen.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// First run: a picked seed says so plainly and a tap lands on the row
/// it was aimed at; the reminders row switches from its label; and the
/// last page counts what it lists.
void main() {
  Future<void> pumpOnboarding(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final db = HarvestDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: OnboardingScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  // The settings streams close on a zero timer once the tree is gone.
  Future<void> leave(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  }

  Future<void> next(WidgetTester tester) async {
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
  }

  testWidgets('templates are rows with a tick, each its own target', (
    tester,
  ) async {
    await pumpOnboarding(tester);
    await next(tester);

    bool ticked(String label) => tester
        .widget<CheckboxListTile>(
          find.ancestor(
            of: find.textContaining(label),
            matching: find.byType(CheckboxListTile),
          ),
        )
        .value!;

    expect(ticked('Read a book'), isTrue);
    expect(ticked('Journal'), isFalse);
    await tester.tap(find.textContaining('Journal'));
    await tester.pumpAndSettle();
    expect(ticked('Journal'), isTrue);
    // The neighbours did not move.
    expect(ticked('Meditate'), isFalse);
    await leave(tester);
  });

  testWidgets('Back goes to the page before, not out (U6-28)', (
    tester,
  ) async {
    await pumpOnboarding(tester);
    await next(tester);
    expect(find.textContaining('Journal'), findsOneWidget);
    final handled = await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(handled, isTrue);
    expect(find.textContaining('Journal'), findsNothing);
    expect(find.text('English'), findsOneWidget);
    await leave(tester);
  });

  testWidgets('the reminders label switches reminders', (tester) async {
    await pumpOnboarding(tester);
    await next(tester);
    await next(tester);
    await next(tester);

    bool on() =>
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value;
    expect(on(), isTrue);
    await tester.tap(find.text('Allow reminders'));
    await tester.pumpAndSettle();
    expect(on(), isFalse);
    await leave(tester);
  });

  testWidgets('the last page does not say two when it lists six', (
    tester,
  ) async {
    await pumpOnboarding(tester);
    for (var i = 0; i < 4; i++) {
      await next(tester);
    }
    expect(find.textContaining('Two more'), findsNothing);
    expect(find.byType(SwitchListTile), findsNWidgets(6));
    await leave(tester);
  });
}
