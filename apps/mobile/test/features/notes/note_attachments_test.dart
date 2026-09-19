import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/features/notes/data/note_attachments.dart';
import 'package:harvest/features/notes/data/notes_repository.dart';

/// Phase 5, M5.5: a recording lives as long as its embed line (N7).
void main() {
  late HarvestDatabase db;
  late Directory temp;
  late NoteAttachmentsRepository attachments;
  late NotesRepository notes;

  setUp(() async {
    db = HarvestDatabase.forTesting(NativeDatabase.memory());
    temp = await Directory.systemTemp.createTemp('harvest_voice');
    attachments = NoteAttachmentsRepository(
      db,
      AttachmentStorage(documents: () async => temp),
    );
    notes = NotesRepository(db);
  });

  tearDown(() async {
    await db.close();
    await temp.delete(recursive: true);
  });

  Future<NoteAttachment> record(String noteUuid, String name) async {
    final slot = await attachments.storage.reserve(noteUuid, name);
    await slot.file.writeAsBytes([1, 2, 3]);
    return attachments.add(
      noteUuid: noteUuid,
      fileName: name,
      storedPath: slot.relative,
      sizeBytes: 3,
      durationMs: 1200,
    );
  }

  test(
    'a deleted embed trashes its recording, and undo brings it back',
    () async {
      final note = await notes.create(title: 'Walk');
      await record(note.uuid, 'Voice 2026-09-19 14-32.m4a');
      expect(await attachments.watchForNote(note.uuid).first, hasLength(1));

      await attachments.reconcile(note.uuid, 'nothing embedded now');
      expect(await attachments.watchForNote(note.uuid).first, isEmpty);

      await attachments.reconcile(note.uuid, '![[Voice 2026-09-19 14-32.m4a]]');
      expect(await attachments.watchForNote(note.uuid).first, hasLength(1));
    },
  );

  test(
    'the purge removes expired and orphaned files, and only those',
    () async {
      final kept = await notes.create(title: 'Kept');
      final a = await record(kept.uuid, 'a.m4a');
      final b = await record(kept.uuid, 'b.m4a');
      await record('gone-note', 'c.m4a');

      await attachments.reconcile(kept.uuid, '![[a.m4a]]');
      expect(
        await attachments.purge(olderThan: const Duration(days: 30)),
        1,
        reason: 'the orphan only; b is in the trash, not expired',
      );
      expect(await attachments.purge(olderThan: Duration.zero), 1);

      expect(
        (await attachments.storage.fileOf(a.storedPath)).existsSync(),
        isTrue,
      );
      expect(
        (await attachments.storage.fileOf(b.storedPath)).existsSync(),
        isFalse,
      );
      final names = (await db.select(db.noteAttachments).get()).map(
        (r) => r.fileName,
      );
      expect(names, ['a.m4a']);
    },
  );
}
