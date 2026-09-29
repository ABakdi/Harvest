import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/db/database_provider.dart';
import 'package:harvest/features/notes/data/notes_repository.dart';
import 'package:harvest/features/notes/presentation/notes_screen.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// A note is a page: Back closes it and shows the notes (U6-07), and a
/// new note left untouched is not kept as an empty "Untitled" (U6-08).
void main() {
  late HarvestDatabase db;

  setUp(() => db = HarvestDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() async => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> pump(WidgetTester tester, {String? open}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: NotesScreen(initialUuid: open),
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> leave(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('Back on an open note closes it and shows the notes', (
    tester,
  ) async {
    final note = await tester.runAsync(
      () => NotesRepository(db).create(title: 'Plan', body: 'Words'),
    );
    await pump(tester, open: note!.uuid);
    expect(find.text('Plan'), findsWidgets);

    final popped = await tester.binding.handlePopRoute();
    await settle(tester);
    expect(popped, isTrue, reason: 'the note took the Back, not the tab');
    expect(find.text('Pick a note'), findsOneWidget);
    await leave(tester);
  });

  testWidgets('a new note left untouched is not kept', (tester) async {
    await pump(tester);
    await tester.tap(find.text('New note'));
    await settle(tester);
    final made = await tester.runAsync(() => db.select(db.notes).get());
    expect(made, hasLength(1));

    await tester.binding.handlePopRoute();
    await settle(tester);
    final left = await tester.runAsync(() => db.select(db.notes).get());
    expect(left, isEmpty);
    await leave(tester);
  });

  testWidgets('a new note with a title is kept', (tester) async {
    await pump(tester);
    await tester.tap(find.text('New note'));
    await settle(tester);
    await tester.enterText(find.byType(TextField).first, 'Groceries');
    await tester.pump(const Duration(seconds: 1));
    await settle(tester);

    await tester.binding.handlePopRoute();
    await settle(tester);
    final kept = await tester.runAsync(() => db.select(db.notes).get());
    expect(kept!.map((n) => n.title), ['Groceries']);
    await leave(tester);
  });
}
