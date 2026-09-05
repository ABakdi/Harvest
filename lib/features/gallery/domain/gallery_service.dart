import 'package:drift/drift.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/db/database_provider.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/commitments/domain/check_in_service.dart';
import 'package:harvest/features/gallery/data/camera_gateway.dart';
import 'package:harvest/features/gallery/data/gallery_repository.dart';
import 'package:harvest/features/gallery/data/gallery_storage.dart';
import 'package:harvest/features/gallery/domain/gallery.dart';
import 'package:harvest/features/gamification/domain/streak_service.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

part 'gallery_service.g.dart';

/// Where a memory came from.
enum CaptureSource { camera, library }

/// Adding a picture is a check-in.
///
/// This service is the gallery's answer to `CheckInService`, and it
/// exists for the same reason: filing the picture, granting the XP and
/// moving the streak have to happen together or not at all. On a
/// scheduled album the first memory of a day earns exactly what a habit
/// earns, because it *is* a habit that happens to leave a picture.
class GalleryService {
  GalleryService(this._db, this._repository, this._storage, this._streaks);

  final HarvestDatabase _db;
  final GalleryRepository _repository;
  final GalleryStorage _storage;
  final StreakService _streaks;
  static const _uuid = Uuid();

  /// Captures or picks, files the result, and records it.
  ///
  /// Null when the user backed out or the platform refused — a capture
  /// that did not happen is not an error.
  Future<Memory?> capture({
    required Album album,
    required CaptureSource source,
    required CameraGateway camera,
    bool video = false,
    String? note,
    HarvestDay? day,
  }) async {
    final taken = switch ((source, video)) {
      (CaptureSource.camera, false) => await camera.takePhoto(),
      (CaptureSource.camera, true) => await camera.takeVideo(),
      (CaptureSource.library, false) => await camera.pickPhoto(),
      (CaptureSource.library, true) => await camera.pickVideo(),
    };
    if (taken == null) return null;

    final harvestDay = day ?? HarvestDay.today();
    final uuid = _uuid.v4();
    final relative = _storage.pathFor(
      albumUuid: album.uuid,
      day: harvestDay,
      extension: _extensionOf(taken.file.path, video: taken.isVideo),
      uuid: uuid,
    );
    await _storage.take(taken.file, relative);

    return add(
      album: album,
      path: relative,
      day: harvestDay,
      kind: taken.isVideo ? MemoryKind.video : MemoryKind.photo,
      note: note,
    );
  }

  /// Records a file that is already in the gallery directory, and pays
  /// the check-in it counts as.
  Future<Memory> add({
    required Album album,
    required String path,
    required HarvestDay day,
    MemoryKind kind = MemoryKind.photo,
    String? note,
  }) async {
    // Whether the day was already earned decides whether this picture
    // is a check-in or just another picture.
    final before = await _repository.countOn(album.uuid, day);

    final memory = await _repository.addMemory(
      albumUuid: album.uuid,
      path: path,
      day: day,
      kind: kind,
      note: note,
    );

    if (album.isScheduled && before == 0) {
      await _db
          .into(_db.ledger)
          .insert(
            LedgerCompanion.insert(
              uuid: _uuid.v4(),
              kind: 'xp',
              delta: Xp.habitOrTodo,
              reason: 'memory:${memory.uuid}',
              harvestDay: day.key,
            ),
          );
      await _streaks.onAlbumMemory(album.uuid, day);
    }
    return memory;
  }

  /// Deletes a memory and its file, and takes back what it earned if it
  /// was the day's only one.
  Future<void> remove(Memory memory, {required Album album}) async {
    await _repository.deleteMemory(memory.uuid);
    if (!album.isScheduled) return;

    final left = await _repository.countOn(album.uuid, memory.day);
    if (left > 0) return;

    // The day is no longer earned: reverse the XP with its own row,
    // the way an undone check-in does, so history stays honest.
    final earned = _db.ledger.delta.sum();
    final query = _db.selectOnly(_db.ledger)
      ..addColumns([earned])
      ..where(_db.ledger.reason.equals('memory:${memory.uuid}'));
    final granted = (await query.getSingle()).read(earned) ?? 0;
    if (granted != 0) {
      await _db
          .into(_db.ledger)
          .insert(
            LedgerCompanion.insert(
              uuid: _uuid.v4(),
              kind: 'xp',
              delta: -granted,
              reason: 'memory-undo:${memory.uuid}',
              harvestDay: memory.day.key,
            ),
          );
    }
    await _streaks.onAlbumMemoryRemoved(album.uuid, memory.day);
  }

  /// `.jpg` unless the source says otherwise; a video keeps its own.
  static String _extensionOf(String source, {required bool video}) {
    final extension = p.extension(source).toLowerCase();
    if (extension.isNotEmpty && extension.length <= 5) return extension;
    return video ? '.mp4' : '.jpg';
  }
}

@Riverpod(keepAlive: true)
GalleryService galleryService(Ref ref) => GalleryService(
  ref.watch(databaseProvider),
  ref.watch(galleryRepositoryProvider),
  ref.watch(galleryStorageProvider),
  ref.watch(streakServiceProvider),
);
