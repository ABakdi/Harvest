import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:harvest/core/domain/harvest_day.dart';
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
class GalleryStorage {
  GalleryStorage();

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

  /// Moves an imported or captured file in, creating the album folder.
  Future<String> take(File source, String relative) async {
    final destination = await fileOf(relative);
    await destination.parent.create(recursive: true);
    await source.copy(destination.path);
    // The picker's temp copy is ours to clean up; failing to is not
    // worth losing the memory over.
    try {
      await source.delete();
    } on FileSystemException catch (error) {
      debugPrint('[gallery] temp file left behind: ${error.osError?.message}');
    }
    return relative;
  }

  /// Writes bytes straight in — the importer's path.
  Future<String> write(List<int> bytes, String relative) async {
    final destination = await fileOf(relative);
    await destination.parent.create(recursive: true);
    await destination.writeAsBytes(bytes);
    return relative;
  }

  Future<int> sizeOf(String relative) async {
    final file = await fileOf(relative);
    if (!file.existsSync()) return 0;
    return file.length();
  }

  Future<void> delete(String relative) async {
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
GalleryStorage galleryStorage(Ref ref) => GalleryStorage();
