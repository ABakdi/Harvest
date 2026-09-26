import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/db/database_provider.dart';
import 'package:harvest/features/lists/data/lists_repository.dart';
import 'package:harvest/features/lists/domain/lists.dart';
import 'package:harvest/features/lists/domain/share_links.dart';
import 'package:harvest/features/lists/presentation/share_flow.dart';
import 'package:harvest/features/settings/data/settings_repository.dart';
import 'package:harvest/features/settings/domain/feature_switches.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// Share → Harvest ([[Lists]]: Saving from anywhere): what another app
/// shares is read into a title, a link and a list — from the text
/// alone, nothing fetched (L9) — and saved only once I say so.
void main() {
  group('reading a share', () {
    test('a video with its name lands in To watch as a video', () {
      final draft = SharedDraft.of(
        subject: 'Me at the zoo',
        text: 'https://www.youtube.com/watch?v=jNQXAC9IVRw',
      );
      expect(draft.title, 'Me at the zoo');
      expect(draft.link, 'https://www.youtube.com/watch?v=jNQXAC9IVRw');
      expect(draft.target?.list, BuiltInList.watch);
      expect(draft.target?.mediaType, MediaType.video);
    });

    test('a bare link is its own title until I type one', () {
      final draft = SharedDraft.of(text: 'https://example.com/essay');
      expect(draft.title, 'https://example.com/essay');
      expect(draft.link, 'https://example.com/essay');
      expect(draft.target?.list, BuiltInList.read);
      expect(draft.target?.mediaType, MediaType.article);
    });

    test('a line of text with a link in it: the link, and the rest as '
        'the title', () {
      final draft = SharedDraft.of(
        text: 'Worth a read: https://example.com/a.',
      );
      expect(draft.link, 'https://example.com/a');
      expect(draft.title, 'Worth a read');
      expect(draft.target?.list, BuiltInList.read);
    });

    test('text without a link goes to a plain list', () {
      final draft = SharedDraft.of(text: 'Buy a birthday card for Sami');
      expect(draft.title, 'Buy a birthday card for Sami');
      expect(draft.link, isNull);
      expect(draft.target, isNull);
    });
  });

  group('the list a share starts in', () {
    ItemList list(String name, ListKind kind, {BuiltInList? builtIn}) =>
        ItemList(
          uuid: builtIn?.uuid ?? name,
          name: name,
          kind: kind,
          builtIn: builtIn,
          createdAt: DateTime(2026),
        );

    final buy = list('To buy', ListKind.shopping, builtIn: BuiltInList.buy);
    final read = list('To read', ListKind.media, builtIn: BuiltInList.read);
    final watch = list('To watch', ListKind.media, builtIn: BuiltInList.watch);
    final ideas = list('Ideas', ListKind.plain);
    final packing = list('Packing', ListKind.plain);

    test('a link: To read, or To watch for a video site', () {
      final lists = [buy, read, watch, ideas];
      expect(
        shareTargetOf(SharedDraft.of(text: 'https://youtu.be/x'), lists),
        watch,
      );
      expect(
        shareTargetOf(SharedDraft.of(text: 'https://example.com'), lists),
        read,
      );
    });

    test('text: the first plain list I made, or none, and the sheet asks', () {
      final text = SharedDraft.of(text: 'Call the plumber');
      expect(shareTargetOf(text, [buy, read, watch, ideas, packing]), ideas);
      expect(shareTargetOf(text, [buy, read, watch]), isNull);
    });
  });

  group('the Save to a list sheet', () {
    late HarvestDatabase db;
    late ListsRepository repo;

    setUp(() {
      db = HarvestDatabase.forTesting(NativeDatabase.memory());
      repo = ListsRepository(db);
    });

    tearDown(() async => db.close());

    /// Lets the database's own work land, a frame at a time.
    Future<void> drain(WidgetTester tester) async {
      for (var i = 0; i < 6; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    Future<void> share(WidgetTester tester, SharedDraft draft) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) => TextButton(
                  onPressed: () => saveShared(context, ref, draft),
                  child: const Text('share'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('share'));
      await drain(tester);
      await tester.pumpAndSettle();
    }

    Future<void> save(WidgetTester tester) async {
      await tester.ensureVisible(find.text('Save'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await drain(tester);
    }

    Future<List<ListItem>> itemsOf(WidgetTester tester, BuiltInList list) async =>
        (await tester.runAsync(() => repo.watchItems(list.uuid).first))!;

    testWidgets('a video lands in To watch with its shared name, and Lists '
        'is switched on to show it', (tester) async {
      await share(
        tester,
        SharedDraft.of(
          subject: 'Me at the zoo',
          text: 'https://www.youtube.com/watch?v=jNQXAC9IVRw',
        ),
      );
      expect(find.text('Save to a list'), findsOneWidget);
      final watch = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'To watch'),
      );
      expect(watch.selected, isTrue);

      await save(tester);
      final saved = (await itemsOf(tester, BuiltInList.watch)).single;
      expect(saved.title, 'Me at the zoo');
      expect(saved.link, 'https://www.youtube.com/watch?v=jNQXAC9IVRw');
      expect(saved.mediaType, MediaType.video);
      expect(
        await tester.runAsync(
          () => SettingsRepository(db).getBool(FeatureKeys.lists),
        ),
        isTrue,
      );
      expect(find.text('Saved to To watch'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('a bare link: the title field waits empty, the link as its '
        'hint, and saves as the title', (tester) async {
      await share(tester, SharedDraft.of(text: 'https://example.com/essay'));

      final title = tester.widget<TextField>(find.byType(TextField).first);
      expect(title.controller?.text, isEmpty);
      expect(title.decoration?.hintText, 'https://example.com/essay');
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'To read'))
            .selected,
        isTrue,
      );

      await save(tester);
      final saved = (await itemsOf(tester, BuiltInList.read)).single;
      expect(saved.title, 'https://example.com/essay');
      expect(saved.mediaType, MediaType.article);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('text with no plain list to go to asks which list first', (
      tester,
    ) async {
      await share(tester, SharedDraft.of(text: 'Call the plumber'));

      expect(find.text('Pick the list it goes in.'), findsOneWidget);
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Save to a list'), findsOneWidget); // still open

      await tester.tap(find.widgetWithText(ChoiceChip, 'To buy'));
      await tester.pumpAndSettle();
      await save(tester);
      expect(
        (await itemsOf(tester, BuiltInList.buy)).single.title,
        'Call the plumber',
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  });
}
