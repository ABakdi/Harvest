import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/features/notes/data/notes_repository.dart';
import 'package:harvest/features/notes/domain/note.dart';
import 'package:harvest/features/notes/presentation/notes_providers.dart';

/// Phase 3, M3.1. The vault's two claims: the body is the truth and the
/// link index follows it (rule N2), and a link to a note I have not
/// written yet is a normal thing rather than an error.
void main() {
  late HarvestDatabase db;
  late NotesRepository notes;

  setUp(() async {
    db = HarvestDatabase.forTesting(NativeDatabase.memory());
    notes = NotesRepository(db);
  });

  tearDown(() async => db.close());

  group('links in a body', () {
    test('are found in order, with the title trimmed', () {
      expect(
        linksIn('see [[Sleep]] and [[ Sleep ]] and [[Creatine]]')
            .map((link) => link.title),
        ['Sleep', 'Sleep', 'Creatine'],
      );
    });

    test('stop at a line break, so a stray bracket is just text', () {
      expect(linksIn('[[not\na link]]'), isEmpty);
      expect(linksIn('a lone [[ ]] pair'), isEmpty);
    });
  });

  group('the link index', () {
    test('follows the body on every write', () async {
      final sleep = await notes.create(title: 'Sleep');
      final log = await notes.create(title: 'Log');
      await notes.update(log.uuid, body: 'went to bed early, see [[Sleep]]');

      expect(
        (await notes.watchBacklinks(sleep.uuid).first).map((n) => n.uuid),
        [log.uuid],
      );

      await notes.update(log.uuid, body: 'nothing links anywhere now');
      expect(await notes.watchBacklinks(sleep.uuid).first, isEmpty);
    });

    test('holds an unresolved link until the note exists', () async {
      final log = await notes.create(title: 'Log');
      await notes.update(log.uuid, body: 'see [[Creatine]]');

      final before = await notes.watchOutgoing(log.uuid).first;
      expect(before.single.title, 'Creatine');
      expect(before.single.uuid, isNull);

      final creatine = await notes.create(title: 'Creatine');
      final after = await notes.watchOutgoing(log.uuid).first;
      expect(after.single.uuid, creatine.uuid);
      expect(
        (await notes.watchBacklinks(creatine.uuid).first).map((n) => n.uuid),
        [log.uuid],
      );
    });

    test('can be rebuilt from the bodies alone (rule N2)', () async {
      final sleep = await notes.create(title: 'Sleep');
      final log = await notes.create(title: 'Log', body: 'see [[Sleep]]');

      await db.delete(db.noteLinks).go();
      expect(await notes.watchBacklinks(sleep.uuid).first, isEmpty);

      await notes.reindexAll();
      expect(
        (await notes.watchBacklinks(sleep.uuid).first).map((n) => n.uuid),
        [log.uuid],
      );
    });

    test('a rename repoints what pointed at the old title', () async {
      final sleep = await notes.create(title: 'Sleep');
      final log = await notes.create(title: 'Log', body: 'see [[Rest]]');

      expect((await notes.watchOutgoing(log.uuid).first).single.uuid, isNull);

      await notes.update(sleep.uuid, title: 'Rest');
      expect(
        (await notes.watchOutgoing(log.uuid).first).single.uuid,
        sleep.uuid,
      );
    });
  });

  group('deleting', () {
    test('is soft, and undoing it puts the note back', () async {
      final note = await notes.create(title: 'Draft', body: 'a start');

      await notes.remove(note.uuid);
      expect(await notes.watchAll().first, isEmpty);

      await notes.restore(note.uuid);
      expect((await notes.watchAll().first).single.body, 'a start');
    });
  });

  group('searching and sorting', () {
    test('matches titles and bodies, and filters by folder', () {
      final now = DateTime(2026, 9, 5);
      final list = [
        Note(
          uuid: 'a',
          title: 'Creatine',
          folder: 'Health',
          body: 'five grams',
          createdAt: now,
          updatedAt: now,
        ),
        Note(
          uuid: 'b',
          title: 'Rent',
          body: 'due on the first',
          createdAt: now,
          updatedAt: now,
        ),
      ];

      expect(
        filterNotes(list, (search: 'grams', folder: '', sort: NoteSort.title))
            .map((n) => n.uuid),
        ['a'],
      );
      expect(
        filterNotes(list, (search: 'rent', folder: '', sort: NoteSort.title))
            .map((n) => n.uuid),
        ['b'],
      );
      expect(
        filterNotes(
          list,
          (search: '', folder: 'Health', sort: NoteSort.title),
        ).map((n) => n.uuid),
        ['a'],
      );
    });
  });

  group('a filename', () {
    test('survives an awkward title', () {
      expect(safeFileName('Q4: what now?'), 'Q4- what now-');
      expect(safeFileName(r'a/b\c'), 'a-b-c');
      expect(safeFileName('   '), 'untitled');
      expect(safeFileName('...hidden'), 'hidden');
    });
  });
}
