import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/ui/widgets/harvest_sheet.dart';
import 'package:harvest/features/notes/data/note_folders.dart';
import 'package:harvest/features/notes/presentation/live_markdown_controller.dart';
import 'package:harvest/features/notes/presentation/notes_screen.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// A recording is drawn as the player where it is embedded — not a
/// stray `!` and a dashed file name — and a note moves to a folder
/// picked from a list rather than a path typed from memory.
void main() {
  const body = 'Walked home\n![[Voice 2026-09-19 14-32.m4a]]\nthen slept';

  group('a recording embed', () {
    testWidgets('is the player, in its place, while the caret is elsewhere', (
      tester,
    ) async {
      final controller = LiveMarkdownController(text: body)
        ..embedBuilder = (name) =>
            name.endsWith('.m4a') ? Text('player: $name') : null;
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextField(controller: controller, maxLines: null),
          ),
        ),
      );
      expect(
        find.text('player: Voice 2026-09-19 14-32.m4a'),
        findsOneWidget,
      );

      // Every character still has its offset: the player stands in for
      // one, the rest are folded, and nothing is added or lost.
      final span = controller.buildTextSpan(
        context: tester.element(find.byType(TextField)),
        withComposing: false,
      );
      expect(span.toPlainText().length, body.length);
      var widgets = 0;
      span.visitChildren((child) {
        if (child is WidgetSpan) widgets++;
        return true;
      });
      expect(widgets, 1);
    });

    testWidgets('is text again with the caret on its line', (tester) async {
      final controller = LiveMarkdownController(text: body)
        ..embedBuilder = ((name) => Text('player: $name'))
        ..selection = TextSelection.collapsed(offset: body.indexOf('!') + 3);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TextField(controller: controller)),
        ),
      );
      final span = controller.buildTextSpan(
        context: tester.element(find.byType(TextField)),
        withComposing: false,
      );
      var widgets = 0;
      span.visitChildren((child) {
        if (child is WidgetSpan) widgets++;
        return true;
      });
      expect(widgets, 0);
    });
  });

  testWidgets('moving a note offers the folders there are', (tester) async {
    String? picked = 'unset';
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          noteFolderTreeProvider.overrideWithValue(['Health', 'Work']),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async => picked = await showHarvestSheet<String>(
                  context,
                  builder: (_) => const NoteFolderSheet(initial: 'Work'),
                ),
                child: const Text('move'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('move'));
    await tester.pumpAndSettle();

    expect(find.text('Health'), findsOneWidget);
    expect(find.text('Work'), findsOneWidget);
    expect(find.text('No folder'), findsOneWidget);
    // No text box until a new folder is asked for.
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.text('New folder'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);

    await tester.tap(find.text('Health'));
    await tester.pumpAndSettle();
    expect(picked, 'Health');
  });
}
