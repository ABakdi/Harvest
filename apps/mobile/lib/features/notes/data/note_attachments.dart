import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/db/database_provider.dart';
import 'package:harvest/features/gallery/data/gallery_storage.dart';
import 'package:harvest/features/notes/domain/voice.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

part 'note_attachments.g.dart';

/// A recording that belongs to a note ([[Notes]] N7).
@immutable
class NoteAttachment {
  const NoteAttachment({
    required this.uuid,
    required this.noteUuid,
    required this.fileName,
    required this.storedPath,
    required this.sizeBytes,
    this.durationMs,
  });

  final String uuid;
  final String noteUuid;

  /// What the body's embed names: `![[fileName]]`.
  final String fileName;

  /// Relative to [AttachmentStorage.root].
  final String storedPath;
  final int sizeBytes;
  final int? durationMs;

  Duration? get duration =>
      durationMs == null ? null : Duration(milliseconds: durationMs!);
}

/// Where recordings live: the app's own documents, one folder per note,
/// never the shared music folder — a voice note is a note.
class AttachmentStorage {
  AttachmentStorage({Future<Directory> Function()? documents})
    : _documents = documents ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _documents;
  Directory? _root;

  static const folder = 'note_attachments';

  Future<Directory> root() async {
    if (_root != null) return _root!;
    final directory = Directory(p.join((await _documents()).path, folder));
    if (!directory.existsSync()) await directory.create(recursive: true);
    return _root = directory;
  }

  Future<File> fileOf(String relative) async =>
      File(p.join((await root()).path, relative));

  /// A new recording's path, before anything is written to it: the
  /// recorder writes straight here.
  Future<({String relative, File file})> reserve(
    String noteUuid,
    String fileName,
  ) async {
    final relative = p.posix.join(noteUuid, fileName);
    final file = await fileOf(relative);
    await file.parent.create(recursive: true);
    return (relative: relative, file: file);
  }

  Future<void> delete(String relative) async {
    if (!GalleryStorage.isSafeRelative(relative)) return;
    try {
      final file = await fileOf(relative);
      if (file.existsSync()) await file.delete();
    } on FileSystemException catch (error) {
      debugPrint('[notes] recording left behind: ${error.osError?.message}');
    }
  }
}

/// The recordings in notes.
class NoteAttachmentsRepository {
  NoteAttachmentsRepository(this._db, this._storage);

  final HarvestDatabase _db;
  final AttachmentStorage _storage;
  static const _uuid = Uuid();

  AttachmentStorage get storage => _storage;

  /// A note's recordings, live, oldest first.
  Stream<List<NoteAttachment>> watchForNote(String noteUuid) {
    final query = _db.select(_db.noteAttachments)
      ..where((a) => a.noteUuid.equals(noteUuid) & a.deletedAt.isNull())
      ..orderBy([(a) => OrderingTerm.asc(a.createdAt)]);
    return query.watch().map((rows) => rows.map(_toDomain).toList());
  }

  /// Every recording's name, so a new one never collides.
  Future<Set<String>> takenNames() async {
    final rows = await _db.select(_db.noteAttachments).get();
    return {for (final row in rows) row.fileName};
  }

  /// Records a finished recording that is already on disk.
  Future<NoteAttachment> add({
    required String noteUuid,
    required String fileName,
    required String storedPath,
    required int sizeBytes,
    int? durationMs,
  }) => _db.transaction(() async {
    final uuid = _uuid.v4();
    await _db
        .into(_db.noteAttachments)
        .insert(
          NoteAttachmentsCompanion.insert(
            uuid: uuid,
            noteUuid: noteUuid,
            fileName: fileName,
            storedPath: storedPath,
            sizeBytes: Value(sizeBytes),
            durationMs: Value(durationMs),
          ),
        );
    await _db.logChange('note_attachments', uuid, 'insert');
    return NoteAttachment(
      uuid: uuid,
      noteUuid: noteUuid,
      fileName: fileName,
      storedPath: storedPath,
      sizeBytes: sizeBytes,
      durationMs: durationMs,
    );
  });

  /// Recordings a note's body no longer embeds go to the trash with
  /// its next save; one embedded again comes back. The embed line is
  /// the truth, as the body always is (N2).
  Future<void> reconcile(String noteUuid, String body) async {
    final embedded = audioEmbedsIn(body).map((n) => n.toLowerCase()).toSet();
    final rows = await (_db.select(
      _db.noteAttachments,
    )..where((a) => a.noteUuid.equals(noteUuid))).get();
    final now = DateTime.now();
    for (final row in rows) {
      final wanted = embedded.contains(row.fileName.toLowerCase());
      final trashed = row.deletedAt != null;
      if (wanted == !trashed) continue;
      await (_db.update(
        _db.noteAttachments,
      )..where((a) => a.uuid.equals(row.uuid))).write(
        NoteAttachmentsCompanion(
          deletedAt: Value(wanted ? null : now),
          updatedAt: Value(now),
        ),
      );
      await _db.logChange('note_attachments', row.uuid, 'update');
    }
  }

  /// Files and rows gone for good: recordings trashed longer than
  /// [olderThan], and any whose note no longer exists at all.
  Future<int> purge({required Duration olderThan}) async {
    final cutoff = DateTime.now().subtract(olderThan);
    final notes = {
      for (final row in await _db.select(_db.notes).get()) row.uuid,
    };
    final rows = await _db.select(_db.noteAttachments).get();
    var purged = 0;
    for (final row in rows) {
      final orphan = !notes.contains(row.noteUuid);
      final expired = row.deletedAt != null && row.deletedAt!.isBefore(cutoff);
      if (!orphan && !expired) continue;
      await _storage.delete(row.storedPath);
      await (_db.delete(
        _db.noteAttachments,
      )..where((a) => a.uuid.equals(row.uuid))).go();
      await _db.logChange('note_attachments', row.uuid, 'delete');
      purged++;
    }
    return purged;
  }

  static NoteAttachment _toDomain(NoteAttachmentRow row) => NoteAttachment(
    uuid: row.uuid,
    noteUuid: row.noteUuid,
    fileName: row.fileName,
    storedPath: row.storedPath,
    sizeBytes: row.sizeBytes,
    durationMs: row.durationMs,
  );
}

@Riverpod(keepAlive: true)
AttachmentStorage attachmentStorage(Ref ref) => AttachmentStorage();

@Riverpod(keepAlive: true)
NoteAttachmentsRepository noteAttachmentsRepository(Ref ref) =>
    NoteAttachmentsRepository(
      ref.watch(databaseProvider),
      ref.watch(attachmentStorageProvider),
    );

@riverpod
Stream<List<NoteAttachment>> noteAttachments(Ref ref, String noteUuid) =>
    ref.watch(noteAttachmentsRepositoryProvider).watchForNote(noteUuid);
