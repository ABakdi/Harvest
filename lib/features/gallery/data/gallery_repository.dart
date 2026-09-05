import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/db/database_provider.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/commitments/domain/schedule.dart';
import 'package:harvest/features/gallery/data/gallery_storage.dart';
import 'package:harvest/features/gallery/domain/gallery.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

part 'gallery_repository.g.dart';

/// Albums and the pictures in them (schema v10).
///
/// A memory row points at a file, which makes this the one repository
/// where a delete has to reach outside the database — and the one where
/// a soft delete would be wrong (rule G5).
class GalleryRepository {
  GalleryRepository(this._db, this._storage);

  final HarvestDatabase _db;
  final GalleryStorage _storage;
  static const _uuid = Uuid();

  // ---------------------------------------------------------------- reads

  Stream<List<Album>> watchAlbums() {
    final query = _db.select(_db.albums)
      ..where((a) => a.deletedAt.isNull())
      ..orderBy([(a) => OrderingTerm.asc(a.createdAt)]);
    return query.watch().map((rows) => rows.map(_toAlbum).toList());
  }

  Stream<Album?> watchAlbum(String uuid) {
    final query = _db.select(_db.albums)
      ..where((a) => a.uuid.equals(uuid) & a.deletedAt.isNull());
    return query.watchSingleOrNull().map(
      (row) => row == null ? null : _toAlbum(row),
    );
  }

  /// One album's memories, oldest first — the order a timelapse plays.
  Stream<List<Memory>> watchMemories(String albumUuid) {
    final query = _db.select(_db.memories)
      ..where((m) => m.albumUuid.equals(albumUuid) & m.deletedAt.isNull())
      ..orderBy([
        (m) => OrderingTerm.asc(m.harvestDay),
        (m) => OrderingTerm.asc(m.capturedAt),
      ]);
    return query.watch().map((rows) => rows.map(_toMemory).toList());
  }

  Stream<List<Memory>> watchAllMemories() {
    final query = _db.select(_db.memories)
      ..where((m) => m.deletedAt.isNull())
      ..orderBy([(m) => OrderingTerm.desc(m.capturedAt)]);
    return query.watch().map((rows) => rows.map(_toMemory).toList());
  }

  /// Deleted memories and the albums they belonged to, newest first.
  Stream<List<Memory>> watchDeletedMemories() {
    final query = _db.select(_db.memories)
      ..where((m) => m.deletedAt.isNotNull())
      ..orderBy([(m) => OrderingTerm.desc(m.deletedAt)]);
    return query.watch().map((rows) => rows.map(_toMemory).toList());
  }

  /// Albums in the trash, newest first.
  Stream<List<Album>> watchDeletedAlbums() {
    final query = _db.select(_db.albums)
      ..where((a) => a.deletedAt.isNotNull())
      ..orderBy([(a) => OrderingTerm.desc(a.deletedAt)]);
    return query.watch().map((rows) => rows.map(_toAlbum).toList());
  }

  /// Every memory of an album, trashed ones included — what deleting
  /// the album has to sweep up, and what emptying the trash removes.
  Future<List<Memory>> allMemoriesOnce(String albumUuid) async {
    final rows = await (_db.select(
      _db.memories,
    )..where((m) => m.albumUuid.equals(albumUuid))).get();
    return rows.map(_toMemory).toList();
  }

  Future<List<Memory>> memoriesOnce(String albumUuid) async {
    final rows =
        await (_db.select(_db.memories)
              ..where((m) => m.albumUuid.equals(albumUuid) & m.deletedAt.isNull())
              ..orderBy([(m) => OrderingTerm.asc(m.harvestDay)]))
            .get();
    return rows.map(_toMemory).toList();
  }

  Future<List<Album>> albumsOnce() async {
    final rows = await (_db.select(
      _db.albums,
    )..where((a) => a.deletedAt.isNull())).get();
    return rows.map(_toAlbum).toList();
  }

  /// How many memories one album holds on a given day — the album's
  /// version of "did I check in today".
  Future<int> countOn(String albumUuid, HarvestDay day) async {
    final count = _db.memories.uuid.count();
    final query = _db.selectOnly(_db.memories)
      ..addColumns([count])
      ..where(
        _db.memories.albumUuid.equals(albumUuid) &
            _db.memories.harvestDay.equals(day.key) &
            _db.memories.deletedAt.isNull(),
      );
    return (await query.getSingle()).read(count) ?? 0;
  }

  /// Distinct days with a memory in [day]'s week — the times-per-week
  /// schedule needs it, exactly as habits do.
  Future<int> doneDaysInWeekOnce(String albumUuid, HarvestDay day) async {
    final query = _db.selectOnly(_db.memories, distinct: true)
      ..addColumns([_db.memories.harvestDay])
      ..where(
        _db.memories.albumUuid.equals(albumUuid) &
            _db.memories.harvestDay.isIn(day.weekDays.map((d) => d.key)) &
            _db.memories.deletedAt.isNull(),
      );
    return (await query.get()).length;
  }

  /// Memories per album on one day, for the field.
  Stream<Map<String, int>> watchCountsOn(HarvestDay day) {
    final query = _db.select(_db.memories)
      ..where((m) => m.harvestDay.equals(day.key) & m.deletedAt.isNull());
    return query.watch().map((rows) {
      final counts = <String, int>{};
      for (final row in rows) {
        counts.update(row.albumUuid, (v) => v + 1, ifAbsent: () => 1);
      }
      return counts;
    });
  }

  /// Distinct memory days per album within [day]'s week.
  Stream<Map<String, int>> watchDoneDaysThisWeek(HarvestDay day) {
    final days = day.weekDays.map((d) => d.key).toList();
    final query = _db.select(_db.memories)
      ..where((m) => m.harvestDay.isIn(days) & m.deletedAt.isNull());
    return query.watch().map((rows) {
      final byAlbum = <String, Set<String>>{};
      for (final row in rows) {
        byAlbum.putIfAbsent(row.albumUuid, () => {}).add(row.harvestDay);
      }
      return byAlbum.map((k, v) => MapEntry(k, v.length));
    });
  }

  /// What the album list shows: count, size on disk, latest picture.
  Stream<List<AlbumSummary>> watchSummaries(HarvestDay today) =>
      watchAlbums().asyncMap((albums) async {
        final summaries = <AlbumSummary>[];
        for (final album in albums) {
          final memories = await memoriesOnce(album.uuid);
          var bytes = 0;
          for (final memory in memories) {
            bytes += await _storage.sizeOf(memory.path);
          }
          summaries.add((
            album: album,
            count: memories.length,
            bytes: bytes,
            latest: memories.isEmpty ? null : memories.last,
            doneToday: memories.any((m) => m.day == today),
          ));
        }
        return summaries;
      });

  // --------------------------------------------------------------- writes

  Future<Album> createAlbum({
    required String name,
    Schedule? schedule,
    String? remindAt,
    String? note,
    DateTime? createdAt,
  }) async {
    final now = createdAt ?? DateTime.now();
    final album = Album(
      uuid: _uuid.v4(),
      name: name.trim(),
      createdAt: now,
      schedule: schedule,
      remindAt: remindAt,
      note: note,
    );
    await _db.transaction(() async {
      await _db
          .into(_db.albums)
          .insert(
            AlbumsCompanion.insert(
              uuid: album.uuid,
              name: album.name,
              scheduleJson: Value(
                schedule == null ? null : jsonEncode(schedule.toJson()),
              ),
              remindAt: Value(remindAt),
              note: Value(note),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      await _outbox('albums', album.uuid, 'insert');
    });
    return album;
  }

  Future<void> updateAlbum(Album album) => _db.transaction(() async {
    await (_db.update(_db.albums)..where((a) => a.uuid.equals(album.uuid)))
        .write(
          AlbumsCompanion(
            name: Value(album.name),
            scheduleJson: Value(
              album.schedule == null
                  ? null
                  : jsonEncode(album.schedule!.toJson()),
            ),
            remindAt: Value(album.remindAt),
            note: Value(album.note),
            updatedAt: Value(DateTime.now()),
          ),
        );
    await _outbox('albums', album.uuid, 'update');
  });

  /// Moves an album to the trash. Its pictures go with it and its
  /// files stay on disk — restoring brings the whole run back.
  Future<void> deleteAlbum(String uuid) => _db.transaction(() async {
    await (_db.update(_db.albums)..where((a) => a.uuid.equals(uuid))).write(
      AlbumsCompanion(
        deletedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );
    await _outbox('albums', uuid, 'update');
  });

  Future<void> restoreAlbum(String uuid) => _db.transaction(() async {
    await (_db.update(_db.albums)..where((a) => a.uuid.equals(uuid))).write(
      AlbumsCompanion(
        deletedAt: const Value(null),
        updatedAt: Value(DateTime.now()),
      ),
    );
    await _outbox('albums', uuid, 'update');
  });

  /// The album, its rows and every one of its files, for good.
  Future<void> purgeAlbum(String uuid) async {
    final memories = await allMemoriesOnce(uuid);
    for (final memory in memories) {
      await _storage.delete(memory.path);
    }
    await _db.transaction(() async {
      await (_db.delete(_db.memories)..where((m) => m.albumUuid.equals(uuid)))
          .go();
      await (_db.delete(_db.albums)..where((a) => a.uuid.equals(uuid))).go();
      await _outbox('albums', uuid, 'delete');
    });
  }

  /// Files a picture that is already in the gallery directory.
  Future<Memory> addMemory({
    required String albumUuid,
    required String path,
    required HarvestDay day,
    MemoryKind kind = MemoryKind.photo,
    String? note,
    DateTime? capturedAt,
  }) async {
    final now = capturedAt ?? DateTime.now();
    final memory = Memory(
      uuid: _uuid.v4(),
      albumUuid: albumUuid,
      day: day,
      path: path,
      kind: kind,
      note: note,
      capturedAt: now,
    );
    await _db.transaction(() async {
      await _db
          .into(_db.memories)
          .insert(
            MemoriesCompanion.insert(
              uuid: memory.uuid,
              albumUuid: albumUuid,
              harvestDay: day.key,
              path: path,
              kind: Value(kind.name),
              note: Value(note),
              capturedAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      await _outbox('memories', memory.uuid, 'insert');
    });
    return memory;
  }

  Future<void> setMemoryNote(String uuid, String? note) =>
      _db.transaction(() async {
        await (_db.update(_db.memories)..where((m) => m.uuid.equals(uuid)))
            .write(
              MemoriesCompanion(
                note: Value(note),
                updatedAt: Value(DateTime.now()),
              ),
            );
        await _outbox('memories', uuid, 'update');
      });

  /// Moves a memory to the trash. The file stays where it is until the
  /// trash is emptied — rule G5 revised: gone for good is still the
  /// promise, it just now takes two deliberate steps to get there.
  Future<void> deleteMemory(String uuid) => _db.transaction(() async {
    await (_db.update(_db.memories)..where((m) => m.uuid.equals(uuid))).write(
      MemoriesCompanion(
        deletedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );
    await _outbox('memories', uuid, 'update');
  });

  Future<void> restoreMemory(String uuid) => _db.transaction(() async {
    await (_db.update(_db.memories)..where((m) => m.uuid.equals(uuid))).write(
      MemoriesCompanion(
        deletedAt: const Value(null),
        updatedAt: Value(DateTime.now()),
      ),
    );
    await _outbox('memories', uuid, 'update');
  });

  /// The step that actually deletes: the row goes, and so does the
  /// file. There is nothing behind this one.
  Future<void> purgeMemory(String uuid) async {
    final row =
        await (_db.select(_db.memories)..where((m) => m.uuid.equals(uuid)))
            .getSingleOrNull();
    if (row == null) return;
    await _storage.delete(row.path);
    await _db.transaction(() async {
      await (_db.delete(_db.memories)..where((m) => m.uuid.equals(uuid))).go();
      await _outbox('memories', uuid, 'delete');
    });
  }

  /// Empties the gallery trash: every trashed memory, and every
  /// picture inside a trashed album, files and all.
  Future<int> emptyTrash() async {
    final memories = await watchDeletedMemories().first;
    for (final memory in memories) {
      await purgeMemory(memory.uuid);
    }
    final albums = await watchDeletedAlbums().first;
    for (final album in albums) {
      await purgeAlbum(album.uuid);
    }
    return memories.length + albums.length;
  }

  Future<File> fileOf(Memory memory) => _storage.fileOf(memory.path);

  Future<void> _outbox(String table, String rowUuid, String op) => _db
      .into(_db.outbox)
      .insert(
        OutboxCompanion.insert(
          targetTable: table,
          rowUuid: rowUuid,
          op: op,
        ),
      );

  static Album _toAlbum(AlbumRow row) {
    Schedule? schedule;
    if (row.scheduleJson != null) {
      try {
        schedule = Schedule.fromJson(
          jsonDecode(row.scheduleJson!) as Map<String, dynamic>,
        );
      } on Object {
        schedule = null;
      }
    }
    return Album(
      uuid: row.uuid,
      name: row.name,
      createdAt: row.createdAt,
      schedule: schedule,
      remindAt: row.remindAt,
      note: row.note,
    );
  }

  static Memory _toMemory(MemoryRow row) => Memory(
    uuid: row.uuid,
    albumUuid: row.albumUuid,
    day: HarvestDay.tryParse(row.harvestDay) ?? HarvestDay.today(),
    path: row.path,
    kind: MemoryKind.fromName(row.kind),
    note: row.note,
    capturedAt: row.capturedAt,
  );
}

@Riverpod(keepAlive: true)
GalleryRepository galleryRepository(Ref ref) => GalleryRepository(
  ref.watch(databaseProvider),
  ref.watch(galleryStorageProvider),
);
