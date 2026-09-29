import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:harvest/core/security/file_vault.dart';
import 'package:harvest/features/export/data/export_repository.dart';
import 'package:harvest/features/export/domain/archive_layout.dart';
import 'package:harvest/features/export/domain/harvest_workbook.dart';
import 'package:harvest/features/export/domain/workbook.dart';
import 'package:harvest/features/gallery/data/gallery_storage.dart';
import 'package:harvest/features/import/domain/archive_reader.dart'
    show ArchiveLimits;
import 'package:harvest/features/notes/data/note_attachments.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'archive_service.g.dart';

/// One entry of the zip: its bytes when they are small and made here
/// (the workbook, a note), or the path of a picture or a recording on
/// disk, read only by the isolate that zips it.
typedef _Entry = ({String name, Uint8List? bytes, String? path, bool compress});

/// Zips plain entries, reading each file from disk as it goes, opened
/// with the files' `key` when they are sealed ([FileVault]): the archive
/// is mine to take elsewhere, so it holds them plain. Plain data only, so
/// it crosses to a background isolate as it is, and the pictures are
/// never held on the UI isolate (P6-07).
Future<Uint8List?> _encodeZip(
  ({List<_Entry> entries, List<int>? key}) job,
) async {
  final archive = Archive();
  for (final entry in job.entries) {
    final key = job.key;
    final bytes =
        entry.bytes ??
        (key == null
            ? File(entry.path!).readAsBytesSync()
            : await openFileNow(key, entry.path!));
    archive.addFile(
      ArchiveFile(entry.name, bytes.length, bytes)..compress = entry.compress,
    );
  }
  final encoded = ZipEncoder().encode(archive);
  if (encoded == null) return null;
  return encoded is Uint8List ? encoded : Uint8List.fromList(encoded);
}

/// The MIME type Android files a `.zip` under.
const zipMimeType = 'application/zip';

/// `harvest-2026-09-05-1430.zip` — sortable, and never two archives on
/// the same name unless they were a minute apart.
String archiveFileName(DateTime at) {
  String two(int value) => value.toString().padLeft(2, '0');
  return 'harvest-${at.year}-${two(at.month)}-${two(at.day)}'
      '-${two(at.hour)}${two(at.minute)}.zip';
}

/// How far the archive has got, for a screen to show.
typedef ArchiveProgress = ({int done, int total, String? label});

/// Raised when the archive was cancelled part-way. Nothing has been
/// written anywhere: the zip is assembled in memory and only saved at
/// the end.
class ArchiveCancelled implements Exception {
  const ArchiveCancelled();

  @override
  String toString() => 'ArchiveCancelled';
}

/// Builds the zip: the workbook, the vault with its recordings, and the
/// pictures.
///
/// It is deliberately not streamed to disk as it goes. A half-written
/// archive that looks finished is worse than no archive, and the whole
/// thing is assembled and then handed over in one piece (ADR-007).
class ArchiveService {
  ArchiveService(this._repository, this._storage, this._attachments);

  final ExportRepository _repository;
  final GalleryStorage _storage;
  final AttachmentStorage _attachments;

  /// [onProgress] is called for every entry; returning `false` from
  /// [cancelled] between entries stops the build. [onTooLarge] hears of
  /// each file left out for being bigger than an importer takes
  /// ([ArchiveLimits.entryBytes]): its row still goes out, like a row
  /// whose file is gone, and the archive stays one that opens (Q5-06).
  /// [onNotHere] hears of each picture only the server holds so far —
  /// named, not yet downloaded — so the export can say how many it could
  /// not carry (Q5-61).
  Future<Uint8List> build({
    DateTime? now,
    void Function(ArchiveProgress)? onProgress,
    bool Function()? cancelled,
    bool includePlaces = true,
    void Function(String path)? onTooLarge,
    void Function(String path)? onNotHere,
  }) async {
    final at = now ?? DateTime.now();
    final contents = await _repository.readArchive(
      generatedAt: at,
      includePlaces: includePlaces,
    );
    final entries = <_Entry>[];
    void add(String name, {Uint8List? bytes, String? path}) => entries.add((
      name: name,
      bytes: bytes,
      path: path,
      compress: !_alreadyCompressed.hasMatch(name),
    ));

    // The workbook, plus one entry per file. The count is known before
    // the slow part starts, which is the point of reporting at all.
    final total =
        1 +
        contents.notes.length +
        contents.attachments.length +
        contents.memories.length;
    var done = 0;

    void step(String? label) {
      done++;
      onProgress?.call((done: done, total: total, label: label));
    }

    void check() {
      if (cancelled?.call() ?? false) throw const ArchiveCancelled();
    }

    final workbook = buildWorkbook(harvestSheets(contents.data));
    add(ArchivePaths.workbook, bytes: Uint8List.fromList(workbook));
    step(ArchivePaths.workbook);

    for (final note in contents.notes) {
      check();
      add(note.path, bytes: _utf8(note.body));
      step(note.path);
    }

    for (final attachment in contents.attachments) {
      check();
      // The stored path is my own, but it is still only read from when
      // it stays inside the attachments directory.
      final file = GalleryStorage.isSafeRelative(attachment.storedPath)
          ? await _attachments.fileOf(attachment.storedPath)
          : null;
      if (file == null || !file.existsSync()) {
        step(attachment.path);
        continue;
      }
      if (file.lengthSync() > ArchiveLimits.entryBytes) {
        onTooLarge?.call(attachment.path);
        step(attachment.path);
        continue;
      }
      add(attachment.path, path: file.path);
      step(attachment.path);
    }

    for (final memory in contents.memories) {
      check();
      final file = await _storage.fileOf(memory.storedPath);
      // A row whose file is gone is not a reason to lose the archive;
      // the row still goes out, and the sheet is honest about it.
      if (!file.existsSync()) {
        if (memory.hash != null) onNotHere?.call(memory.path);
        step(memory.path);
        continue;
      }
      if (file.lengthSync() > ArchiveLimits.entryBytes) {
        onTooLarge?.call(memory.path);
        step(memory.path);
        continue;
      }
      add(memory.path, path: file.path);
      step(memory.path);
    }

    check();
    // Zipped off the UI isolate (P6-07); pictures and recordings are
    // stored as they are, since deflate gains nothing on them.
    // The files' key only when a file goes in: an archive of rows alone
    // never makes one.
    final key = entries.any((entry) => entry.path != null)
        ? await (_storage.vault ?? _attachments.vault)?.key()
        : null;
    final encoded = await compute(_encodeZip, (entries: entries, key: key));
    if (encoded == null) throw StateError('the archive would not encode');
    return encoded;
  }

  static final _alreadyCompressed = RegExp(
    r'\.(jpe?g|png|webp|heic|gif|mp4|mov|m4a|aac|mp3|ogg|opus|webm)$',
    caseSensitive: false,
  );

  static Uint8List _utf8(String text) => Uint8List.fromList(utf8.encode(text));
}

@Riverpod(keepAlive: true)
ArchiveService archiveService(Ref ref) => ArchiveService(
  ref.watch(exportRepositoryProvider),
  ref.watch(galleryStorageProvider),
  ref.watch(attachmentStorageProvider),
);
