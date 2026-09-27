import 'dart:async';

import 'package:flutter/painting.dart' show FileImage;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harvest/features/account/domain/account.dart';
import 'package:harvest/features/gallery/data/gallery_repository.dart';
import 'package:harvest/features/gallery/data/gallery_storage.dart';
import 'package:harvest/features/gallery/domain/gallery.dart';

/// Ticks each time a file lands on this phone, by a sync or on demand,
/// so whatever shows one looks again ([[Gallery]] G9).
class FileArrivals extends Notifier<int> {
  @override
  int build() => 0;

  void landed() => state++;
}

final fileArrivalsProvider = NotifierProvider<FileArrivals, int>(
  FileArrivals.new,
);

/// A picture on screen that has not come down yet is fetched now, on
/// its own, rather than waiting its turn in a sync that carries twenty
/// files at a time ([[Gallery]] G9).
class MemoryFiles {
  MemoryFiles(this._ref);

  final Ref _ref;
  final _running = <String, Future<bool>>{};

  /// When each hash last failed to come down: a frame shown again and
  /// again (the timelapse plays several a second) asks once a minute,
  /// not every time. *Try again* asks now.
  final _failedAt = <String, DateTime>{};
  static const _patience = Duration(minutes: 1);

  /// Fetches [memory]'s file. True when it is here now. [retry] asks
  /// even when it failed a moment ago. [again] fetches it even when a
  /// file is already there — one that would not draw; the copy there is
  /// only replaced by bytes that match its name.
  Future<bool> fetch(Memory memory, {bool retry = false, bool again = false}) {
    final hash = memory.fileHash;
    if (hash == null) return Future.value(false);
    final failed = _failedAt[hash];
    if (!retry &&
        !again &&
        failed != null &&
        DateTime.now().difference(failed) < _patience) {
      return Future.value(false);
    }
    return _running[hash] ??= _fetch(
      memory,
      hash,
      again: again,
    ).whenComplete(() => _running.remove(hash));
  }

  Future<bool> _fetch(Memory memory, String hash, {required bool again}) async {
    if (!GalleryStorage.isSafeRelative(memory.path)) return false;
    final file = await _ref.read(galleryRepositoryProvider).fileOf(memory);
    if (!again && file.existsSync()) return true;
    final files = await _ref.read(fileSyncProvider.future);
    if (files == null) return false;
    final landed = await files.fetch(hash, file);
    if (!landed) {
      _failedAt[hash] = DateTime.now();
      return false;
    }
    _failedAt.remove(hash);
    // A picture drawn from the old bytes is drawn again from the new.
    if (again) unawaited(FileImage(file).evict());
    _ref.read(fileArrivalsProvider.notifier).landed();
    return landed;
  }
}

final memoryFilesProvider = Provider<MemoryFiles>(MemoryFiles.new);
