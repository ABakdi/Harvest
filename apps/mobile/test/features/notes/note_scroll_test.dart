import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/ui/scroll_behavior.dart';
import 'package:harvest/features/notes/data/notes_repository.dart';
import 'package:harvest/features/notes/domain/note.dart';
import 'package:harvest/features/notes/presentation/editing_focus.dart';
import 'package:harvest/features/notes/presentation/live_markdown_controller.dart';
import 'package:harvest/features/notes/presentation/note_editor.dart';
import 'package:harvest/features/notes/presentation/notes_providers.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// Saves nowhere: these tests are about the page, not the database.
class _QuietNotes extends NotesRepository {
  // ignore: matching_super_parameters — the repository names it `_db`.
  _QuietNotes(super.db);

  @override
  Future<void> update(
    String uuid, {
    String? title,
    String? folder,
    String? body,
  }) async {}
}

/// A note longer than the screen scrolls with a finger on its text, in
/// reading and while writing, with and without the keyboard.
void main() {
  final body = [
    for (var i = 1; i <= 199; i++) 'Line number $i',
    'THE LAST LINE',
  ].join('\n');

  Future<LiveMarkdownController> open(WidgetTester tester) async {
    final db = HarvestDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final note = Note(
      uuid: 'n1',
      title: 'Long',
      body: body,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    final controller = LiveMarkdownController();
    addTearDown(controller.dispose);
    final container = ProviderContainer(
      overrides: [
        notesRepositoryProvider.overrideWithValue(_QuietNotes(db)),
        noteProvider(note.uuid).overrideWith((ref) => Stream.value(note)),
        backlinksProvider(
          note.uuid,
        ).overrideWith((ref) => Stream.value(const <Note>[])),
        allNotesProvider.overrideWith((ref) => Stream.value([note])),
      ],
    );
    addTearDown(container.dispose);
    // The notes screen keeps the writing flag alive; here the test does.
    final writing = container.listen(writingNoteProvider, (_, _) {});
    addTearDown(writing.close);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          scrollBehavior: const HarvestScrollBehavior(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: NoteEditor(
              uuid: note.uuid,
              onOpen: (_) {},
              controller: controller,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    return controller;
  }

  /// The page: the vertical scroll view that is not the field's own.
  ScrollPosition page(WidgetTester tester) => tester
      .state<ScrollableState>(
        find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      )
      .position;

  /// Where the end of the note is drawn, in screen coordinates.
  Rect lastCaret(WidgetTester tester) {
    final editable = tester
        .state<EditableTextState>(find.byType(EditableText).last)
        .renderEditable;
    final local = editable.getLocalRectForCaret(
      TextPosition(offset: body.length),
    );
    return MatrixUtils.transformRect(editable.getTransformTo(null), local);
  }

  /// Swipes up on the text, the way a thumb reads down a page.
  Future<void> swipeToEnd(WidgetTester tester, Offset on) async {
    for (var i = 0; i < 30; i++) {
      await tester.timedDragFrom(
        on,
        const Offset(0, -250),
        const Duration(milliseconds: 250),
      );
      await tester.pumpAndSettle();
    }
  }

  testWidgets('reading: a swipe on the text reaches the last line', (
    tester,
  ) async {
    await open(tester);
    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    expect(page(tester).maxScrollExtent, greaterThan(1000));
    expect(lastCaret(tester).top, greaterThan(screen.height));

    await swipeToEnd(tester, const Offset(200, 400));

    expect(page(tester).pixels, page(tester).maxScrollExtent);
    final caret = lastCaret(tester);
    expect(caret.top, greaterThanOrEqualTo(0));
    expect(caret.bottom, lessThanOrEqualTo(screen.height));
    expect(find.textContaining('THE LAST LINE'), findsOneWidget);
  });

  testWidgets('writing with the keyboard up: a swipe on the text reaches '
      'the last line, above the keyboard', (tester) async {
    await open(tester);
    await tester.tapAt(const Offset(200, 200));
    await tester.pump();
    // A third of the screen goes to the keyboard.
    tester.view.viewInsets = FakeViewPadding(
      bottom: tester.view.physicalSize.height / 3,
    );
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    final keyboardTop = screen.height * 2 / 3;

    await swipeToEnd(tester, const Offset(200, 250));

    expect(page(tester).pixels, page(tester).maxScrollExtent);
    final caret = lastCaret(tester);
    expect(caret.top, greaterThanOrEqualTo(0));
    expect(caret.bottom, lessThanOrEqualTo(keyboardTop));
  });

  testWidgets('typing at the end keeps the caret above the keyboard', (
    tester,
  ) async {
    final controller = await open(tester);
    await tester.tapAt(const Offset(200, 200));
    await tester.pump();
    tester.view.viewInsets = FakeViewPadding(
      bottom: tester.view.physicalSize.height / 3,
    );
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    final keyboardTop = screen.height * 2 / 3;

    controller.selection = TextSelection.collapsed(offset: body.length);
    await tester.pumpAndSettle();
    tester.testTextInput.updateEditingValue(
      TextEditingValue(
        text: '$body\nand one more',
        selection: TextSelection.collapsed(offset: body.length + 13),
      ),
    );
    await tester.pumpAndSettle();

    final editable = tester
        .state<EditableTextState>(find.byType(EditableText).last)
        .renderEditable;
    final caret = MatrixUtils.transformRect(
      editable.getTransformTo(null),
      editable.getLocalRectForCaret(TextPosition(offset: body.length + 13)),
    );
    expect(caret.top, greaterThanOrEqualTo(0));
    expect(caret.bottom, lessThanOrEqualTo(keyboardTop));
  });
}
