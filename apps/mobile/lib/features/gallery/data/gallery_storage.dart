import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/core/security/file_vault.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'gallery_storage.g.dart';

/// Where the pictures live.
///
/// Inside the app's own documents directory, never in the system
/// gallery (rule G2): a diet progress album is not something to scatter
/// through a camera roll that other people scroll past. Rows store a
/// path *relative* to this directory, so the app moving between
/// installs does not orphan every memory.
///
/// Every picture and video is sealed on disk by [FileVault] (Phase 7,
/// M7.4): written through [take] and [write], read through [read] and
/// [openCopy]. Without a vault (a test with no Keystore) files are kept
/// as they are.
class GalleryStorage {
  GalleryStorage([this.vault]);

  final FileVault? vault;

  Directory? _root;

  static const folder = 'gallery';

  Future<Directory> root() async {
    if (_root != null) return _root!;
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory(p.join(documents.path, folder));
    if (!directory.existsSync()) await directory.create(recursive: true);
    return _root = directory;
  }

  Future<File> fileOf(String relative) async =>
      File(p.join((await root()).path, relative));

  /// Whether [relative] is a path this storage will write to: relative,
  /// normalised, and staying inside the gallery directory.
  ///
  /// The importer hands over paths an archive named, and an archive is
  /// data, not instructions ([[Audit-v2-Beta]] S2-01). `..` walks out;
  /// an absolute path makes `join` discard the root entirely; a drive
  /// letter or a scheme is not a path at all. None of them is a place
  /// for a picture.
  static bool isSafeRelative(String relative) {
    if (relative.isEmpty || relative.length > 512) return false;
    if (relative.contains(r'\') || relative.contains(':')) return false;
    if (p.posix.isAbsolute(relative)) return false;
    final normalized = p.posix.normalize(relative);
    if (normalized == '.' || normalized == '..') return false;
    if (normalized.startsWith('../') || normalized.startsWith('/')) {
      return false;
    }
    return normalized == relative;
  }

  /// A relative path for a new memory: one folder per album, named by
  /// the day, so the tree is already the shape the export wants.
  String pathFor({
    required String albumUuid,
    required HarvestDay day,
    required String extension,
    required String uuid,
  }) => p.join(albumUuid, '${day.key}-${uuid.substring(0, 8)}$extension');

  /// Moves an imported or captured file in, sealed, creating the album
  /// folder.
  Future<String> take(File source, String relative) async {
    final destination = await fileOf(relative);
    await destination.parent.create(recursive: true);
    final vault = this.vault;
    if (vault == null) {
      await source.copy(destination.path);
    } else {
      await vault.sealFrom(source, destination);
    }
    // The picker's temp copy is ours to clean up; failing to is not
    // worth losing the memory over.
    try {
      await source.delete();
    } on FileSystemException catch (error) {
      debugPrint('[gallery] temp file left behind: ${error.osError?.message}');
    }
    return relative;
  }

  /// Writes bytes straight in, sealed — the importer's path.
  Future<String> write(List<int> bytes, String relative) async {
    final destination = await fileOf(relative);
    await destination.parent.create(recursive: true);
    final vault = this.vault;
    if (vault == null) {
      await destination.writeAsBytes(bytes);
    } else {
      await vault.write(destination, bytes);
    }
    return relative;
  }

  /// A video (or picture) opened into a temporary file, for what can only
  /// play a path; the caller lets it go with [FileVault.release].
  Future<File> openCopy(String relative) async {
    final file = await fileOf(relative);
    return vault?.openCopy(file) ?? file;
  }

  /// A picture's bytes, opened.
  Future<Uint8List> read(String relative) async {
    final file = await fileOf(relative);
    return vault?.read(file) ?? file.readAsBytes();
  }

  Future<int> sizeOf(String relative) async {
    final file = await fileOf(relative);
    if (!file.existsSync()) return 0;
    return file.length();
  }

  /// Deletes a memory's file. A path from a row is still a path from
  /// somewhere else (S6-08): one that could lead out of the gallery is
  /// never deleted, as every other use of it is never read or written.
  Future<void> delete(String relative) async {
    if (!isSafeRelative(relative)) return;
    final file = await fileOf(relative);
    if (file.existsSync()) await file.delete();
  }

  /// Total bytes under the gallery directory.
  Future<int> totalBytes() async {
    final directory = await root();
    var total = 0;
    await for (final entity in directory.list(recursive: true)) {
      if (entity is File) total += await entity.length();
    }
    return total;
  }
}

@Riverpod(keepAlive: true)
GalleryStorage galleryStorage(Ref ref) =>
    GalleryStorage(ref.watch(fileVaultProvider));
