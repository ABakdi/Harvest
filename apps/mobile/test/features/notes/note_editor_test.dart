import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/features/notes/data/notes_repository.dart';
import 'package:harvest/features/notes/domain/note.dart';
import 'package:harvest/features/notes/presentation/editing_focus.dart';
import 'package:harvest/features/notes/presentation/live_markdown_controller.dart';
import 'package:harvest/features/notes/presentation/note_editor.dart';
import 'package:harvest/features/notes/presentation/notes_providers.dart';
import 'package:harvest/l10n/app_localizations.dart';

/// Records saves instead of writing them, so the widget test never
/// waits on the database.
class _RecordingNotes extends NotesRepository {
  // ignore: matching_super_parameters — the repository names it `_db`.
  _RecordingNotes(super.db);

  final saves = <String?>[];

  @override
  Future<void> update(
    String uuid, {
    String? title,
    String? folder,
    String? body,
  }) async => saves.add(body);
}

/// [[Audit-v2]] U3-01: closing a note must neither throw nor lose the
/// half-second of typing still waiting for its save.
void main() {
  testWidgets('closing within the debounce saves the body and clears the '
      'writing flag', (tester) async {
    final db = HarvestDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final notes = _RecordingNotes(db);
    final note = Note(
      uuid: 'n1',
      title: 'Log',
      body: '',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    final controller = LiveMarkdownController();
    addTearDown(controller.dispose);
    final container = ProviderContainer(
      overrides: [
        notesRepositoryProvider.overrideWithValue(notes),
        noteProvider(note.uuid).overrideWith((ref) => Stream.value(note)),
        backlinksProvider(
          note.uuid,
        ).overrideWith((ref) => Stream.value(const <Note>[])),
      ],
    );
    addTearDown(container.dispose);
    // The notes screen watches the flag; so does the test.
    final writing = container.listen(writingNoteProvider, (_, _) {});
    addTearDown(writing.close);

    Widget app({required bool open}) => UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: open
              ? NoteEditor(
                  uuid: note.uuid,
                  onOpen: (_) {},
                  controller: controller,
                )
              : const SizedBox(),
        ),
      ),
    );

    await tester.pumpWidget(app(open: true));
    await tester.pump();

    container.read(writingNoteProvider.notifier).set(true);
    controller.text = 'went to bed early';
    await tester.pump(const Duration(milliseconds: 100));
    expect(notes.saves, isEmpty);

    // Closed long before the 500 ms debounce fires.
    await tester.pumpWidget(app(open: false));
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 1));

    expect(notes.saves, ['went to bed early']);
    expect(container.read(writingNoteProvider), isFalse);
  });
}
