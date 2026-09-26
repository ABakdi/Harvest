import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/db/database_provider.dart';
import 'package:harvest/features/lists/presentation/lists_screen.dart';
import 'package:harvest/features/notes/presentation/notes_screen.dart';
import 'package:harvest/features/records/presentation/records_screen.dart';
import 'package:harvest/features/settings/data/settings_repository.dart';
import 'package:harvest/features/settings/domain/feature_switches.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// Lists is Records' fourth half ([[Lists]]): its own switch, its own
/// tab, and remembered like the other three.
void main() {
  late HarvestDatabase db;

  setUp(() => db = HarvestDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() async => db.close());

  Future<void> pumpRecords(
    WidgetTester tester, {
    required bool notes,
    bool everything = false,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          notesEnabledProvider.overrideWithValue(notes),
          galleryEnabledProvider.overrideWithValue(everything),
          placesEnabledProvider.overrideWithValue(everything),
          listsEnabledProvider.overrideWithValue(true),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: RecordsScreen(),
        ),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> leave(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('on its own, Lists is Records and names itself', (tester) async {
    await pumpRecords(tester, notes: false);
    expect(find.byType(ListsScreen), findsOneWidget);
    expect(find.text('Lists'), findsOneWidget);
    await leave(tester);
  });

  testWidgets('beside Notes it is a tab, and Records comes back to it', (
    tester,
  ) async {
    await tester.runAsync(
      () => SettingsRepository(
        db,
      ).setString(SettingKeys.recordsTab, RecordsTab.lists.name),
    );
    await pumpRecords(tester, notes: true);

    expect(find.byType(ListsScreen), findsOneWidget);
    expect(find.byType(NotesScreen), findsNothing);
    expect(find.text('Notes'), findsOneWidget); // the tab row
    await leave(tester);
  });

  testWidgets('the tabs read Notes · Lists · Gallery · Places (M6.13)', (
    tester,
  ) async {
    expect(RecordsTab.values, [
      RecordsTab.notes,
      RecordsTab.lists,
      RecordsTab.gallery,
      RecordsTab.places,
    ]);
    await pumpRecords(tester, notes: true, everything: true);

    final tabs = [
      for (final label in ['Notes', 'Lists', 'Gallery', 'Places'])
        find.descendant(of: find.byType(TabBar), matching: find.text(label)),
    ];
    for (final tab in tabs) {
      expect(tab, findsOneWidget);
    }
    final starts = [for (final tab in tabs) tester.getTopLeft(tab).dx];
    expect(starts, [...starts]..sort());
    await leave(tester);
  });
}
