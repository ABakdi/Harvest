import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:harvest/features/export/data/export_repository.dart';
import 'package:harvest/features/export/domain/archive_layout.dart';
import 'package:harvest/features/export/domain/harvest_workbook.dart';
import 'package:harvest/features/export/domain/workbook.dart';
import 'package:harvest/features/gallery/data/gallery_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'archive_service.g.dart';

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

/// Builds the zip: the workbook, the vault, and the pictures.
///
/// It is deliberately not streamed to disk as it goes. A half-written
/// archive that looks finished is worse than no archive, and the whole
/// thing is assembled and then handed over in one piece (ADR-007).
class ArchiveService {
  ArchiveService(this._repository, this._storage);

  final ExportRepository _repository;
  final GalleryStorage _storage;

  /// [onProgress] is called for every entry; returning `false` from
  /// [cancelled] between entries stops the build.
  Future<Uint8List> build({
    DateTime? now,
    void Function(ArchiveProgress)? onProgress,
    bool Function()? cancelled,
  }) async {
    final at = now ?? DateTime.now();
    final contents = await _repository.readArchive(generatedAt: at);
    final archive = Archive();

    // The workbook, plus one entry per file. The count is known before
    // the slow part starts, which is the point of reporting at all.
    final total = 1 + contents.notes.length + contents.memories.length;
    var done = 0;

    void step(String? label) {
      done++;
      onProgress?.call((done: done, total: total, label: label));
    }

    void check() {
      if (cancelled?.call() ?? false) throw const ArchiveCancelled();
    }

    final workbook = buildWorkbook(harvestSheets(contents.data));
    archive.addFile(
      ArchiveFile(
        ArchivePaths.workbook,
        workbook.length,
        Uint8List.fromList(workbook),
      ),
    );
    step(ArchivePaths.workbook);

    for (final note in contents.notes) {
      check();
      final bytes = _utf8(note.body);
      archive.addFile(ArchiveFile(note.path, bytes.length, bytes));
      step(note.path);
    }

    for (final memory in contents.memories) {
      check();
      final file = await _storage.fileOf(memory.storedPath);
      // A row whose file is gone is not a reason to lose the archive;
      // the row still goes out, and the sheet is honest about it.
      if (!file.existsSync()) {
        step(memory.path);
        continue;
      }
      final bytes = await file.readAsBytes();
      archive.addFile(ArchiveFile(memory.path, bytes.length, bytes));
      step(memory.path);
    }

    check();
    final encoded = ZipEncoder().encode(archive);
    if (encoded == null) throw StateError('the archive would not encode');
    return Uint8List.fromList(encoded);
  }

  static Uint8List _utf8(String text) =>
      Uint8List.fromList(utf8.encode(text));
}

@Riverpod(keepAlive: true)
ArchiveService archiveService(Ref ref) => ArchiveService(
  ref.watch(exportRepositoryProvider),
  ref.watch(galleryStorageProvider),
);
