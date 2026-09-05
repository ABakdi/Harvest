import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/commitments/domain/check_in_service.dart';
import 'package:harvest/features/commitments/domain/schedule.dart';
import 'package:harvest/features/gallery/data/gallery_repository.dart';
import 'package:harvest/features/gallery/data/gallery_storage.dart';
import 'package:harvest/features/gallery/domain/gallery.dart';
import 'package:harvest/features/gallery/domain/gallery_service.dart';
import 'package:harvest/features/gamification/domain/streak_service.dart';

import '../../support/fake_camera.dart';
import '../../support/temp_gallery_storage.dart';

/// Phase 3, M3.2. The claim that makes the gallery more than a photo
/// folder: **a scheduled album is a seed** (rule G3). It is due like a
/// habit, it is checked in by adding a picture, and it pays the same XP
/// into the same ledger.
void main() {
  late HarvestDatabase db;
  late Directory root;
  late GalleryStorage storage;
  late GalleryRepository repository;
  late GalleryService gallery;
  late StreakService streaks;

  final monday = HarvestDay.parse('2026-09-07');
  final tuesday = HarvestDay.parse('2026-09-08');

  setUp(() async {
    db = HarvestDatabase.forTesting(NativeDatabase.memory());
    root = await Directory.systemTemp.createTemp('harvest-gallery-test');
    storage = TempGalleryStorage(root);
    repository = GalleryRepository(db, storage);
    streaks = StreakService(db);
    gallery = GalleryService(db, repository, storage, streaks);
  });

  tearDown(() async {
    await db.close();
    if (root.existsSync()) await root.delete(recursive: true);
  });

  Future<int> xpTotal() async {
    final rows = await db.select(db.ledger).get();
    return rows.fold<int>(0, (sum, row) => sum + row.delta);
  }

  /// The album's own streak row — the card on the field shows this.
  Future<int> albumStreak(String uuid) async {
    final row = await (db.select(
      db.streaks,
    )..where((s) => s.scope.equals(uuid))).getSingleOrNull();
    return row?.current ?? 0;
  }

  Future<Album> album({Schedule? schedule = const DailySchedule()}) =>
      repository.createAlbum(
        name: 'Gym',
        schedule: schedule,
        createdAt: DateTime(2026),
      );

  group('an album is due', () {
    test('only from the day it was made (business rule 12)', () async {
      final made = await repository.createAlbum(
        name: 'Face',
        schedule: const DailySchedule(),
        createdAt: DateTime(2026, 9, 8, 12),
      );

      expect(made.isDueOn(monday), isFalse);
      expect(made.isDueOn(tuesday), isTrue);
    });

    test('on the days its schedule says, and never without one', () async {
      final scheduled = await album(
        schedule: const WeeklySchedule(weekdays: {DateTime.tuesday}),
      );
      final shoebox = await album(schedule: null);

      expect(scheduled.isDueOn(monday), isFalse);
      expect(scheduled.isDueOn(tuesday), isTrue);
      expect(shoebox.isDueOn(monday), isFalse);
      expect(shoebox.isScheduled, isFalse);
    });

    test('a times-per-week album stops asking once it is fed', () async {
      final flexible = await album(
        schedule: const TimesPerWeekSchedule(times: 2),
      );

      expect(flexible.isDueOn(monday, doneDaysThisWeek: 1), isTrue);
      expect(flexible.isDueOn(monday, doneDaysThisWeek: 2), isFalse);
    });
  });

  group('adding a memory', () {
    test('is a check-in: it pays what a habit pays', () async {
      final gym = await album();

      await gallery.add(album: gym, path: 'gym/a.jpg', day: monday);

      expect(await xpTotal(), Xp.habitOrTodo);
      expect(await albumStreak(gym.uuid), 1);
      // The day counts towards the global streak exactly as a habit
      // does — it is one of the day's productive actions, not a
      // separate ladder.
      expect(await streaks.albumActions(monday), 1);
    });

    test('pays once a day, however many pictures I take', () async {
      final gym = await album();

      await gallery.add(album: gym, path: 'gym/a.jpg', day: monday);
      await gallery.add(album: gym, path: 'gym/b.jpg', day: monday);

      expect(await xpTotal(), Xp.habitOrTodo);
      expect(await repository.countOn(gym.uuid, monday), 2);
    });

    test('pays nothing for an album with no schedule', () async {
      final shoebox = await album(schedule: null);

      await gallery.add(album: shoebox, path: 'x/a.jpg', day: monday);

      expect(await xpTotal(), 0);
    });
  });

  group('removing a memory', () {
    test('moves it to the trash and leaves the file alone', () async {
      final gym = await album();
      final file = await storage.fileOf('gym/a.jpg');
      await file.create(recursive: true);
      await file.writeAsBytes([1, 2, 3]);
      final memory = await gallery.add(
        album: gym,
        path: 'gym/a.jpg',
        day: monday,
      );

      await gallery.remove(memory, album: gym);

      // The file survives so it can come back; the album no longer
      // counts it (rule G5, revised in checkpoint 5).
      expect(file.existsSync(), isTrue);
      expect(await repository.countOn(gym.uuid, monday), 0);
      expect(await repository.watchDeletedMemories().first, hasLength(1));
    });

    test('emptying the trash is what deletes the file', () async {
      final gym = await album();
      final file = await storage.fileOf('gym/a.jpg');
      await file.create(recursive: true);
      await file.writeAsBytes([1, 2, 3]);
      final memory = await gallery.add(
        album: gym,
        path: 'gym/a.jpg',
        day: monday,
      );
      await gallery.remove(memory, album: gym);

      expect(await repository.emptyTrash(), 1);

      expect(file.existsSync(), isFalse);
      expect(await db.select(db.memories).get(), isEmpty);
    });

    test('putting it back pays the day again', () async {
      final gym = await album();
      final memory = await gallery.add(
        album: gym,
        path: 'gym/a.jpg',
        day: monday,
      );
      await gallery.remove(memory, album: gym);
      expect(await xpTotal(), 0);

      await gallery.restore(memory, album: gym);

      expect(await xpTotal(), Xp.habitOrTodo);
      expect(await albumStreak(gym.uuid), 1);
      expect(await repository.countOn(gym.uuid, monday), 1);
    });

    test('takes the day back only when it was the last one', () async {
      final gym = await album();
      final first = await gallery.add(
        album: gym,
        path: 'gym/a.jpg',
        day: monday,
      );
      final second = await gallery.add(
        album: gym,
        path: 'gym/b.jpg',
        day: monday,
      );

      await gallery.remove(second, album: gym);
      expect(await xpTotal(), Xp.habitOrTodo);

      await gallery.remove(first, album: gym);
      expect(await xpTotal(), 0);
      expect(await albumStreak(gym.uuid), 0);
      expect(await streaks.albumActions(monday), 0);
    });
  });

  group('capturing', () {
    test('files the picture inside the app, never the camera roll', () async {
      final gym = await album();
      final source = File('${root.path}/incoming.jpg');
      await source.writeAsBytes([9, 9, 9]);

      final memory = await gallery.capture(
        album: gym,
        source: CaptureSource.camera,
        camera: FakeCamera(photo: source),
        day: monday,
      );

      expect(memory, isNotNull);
      expect(memory!.path, startsWith(gym.uuid));
      final stored = await storage.fileOf(memory.path);
      expect(stored.existsSync(), isTrue);
      expect(stored.path, startsWith(root.path));
    });

    test('a capture that did not happen is not an error', () async {
      final gym = await album();

      final memory = await gallery.capture(
        album: gym,
        source: CaptureSource.camera,
        camera: const FakeCamera(),
        day: monday,
      );

      expect(memory, isNull);
      expect(await xpTotal(), 0);
    });
  });

  group('deleting an album', () {
    test('moves it to the trash, pictures and files intact', () async {
      final gym = await album();
      final file = await storage.fileOf('gym/a.jpg');
      await file.create(recursive: true);
      await gallery.add(album: gym, path: 'gym/a.jpg', day: monday);

      await repository.deleteAlbum(gym.uuid);

      expect(await repository.albumsOnce(), isEmpty);
      expect(await repository.watchDeletedAlbums().first, hasLength(1));
      expect(file.existsSync(), isTrue);
    });

    test('comes back whole when restored', () async {
      final gym = await album();
      await gallery.add(album: gym, path: 'gym/a.jpg', day: monday);
      await repository.deleteAlbum(gym.uuid);

      await repository.restoreAlbum(gym.uuid);

      expect(await repository.albumsOnce(), hasLength(1));
      expect(await repository.countOn(gym.uuid, monday), 1);
    });

    test('emptying the trash takes every picture and file with it', () async {
      final gym = await album();
      final file = await storage.fileOf('gym/a.jpg');
      await file.create(recursive: true);
      await gallery.add(album: gym, path: 'gym/a.jpg', day: monday);
      await repository.deleteAlbum(gym.uuid);

      await repository.emptyTrash();

      expect(await db.select(db.albums).get(), isEmpty);
      expect(await db.select(db.memories).get(), isEmpty);
      expect(file.existsSync(), isFalse);
    });
  });

  group('bytes, read by a person', () {
    test('round to something a settings line can say', () {
      expect(formatBytes(512), '512 B');
      expect(formatBytes(1536), '1.5 KB');
      expect(formatBytes(15 * 1024 * 1024), '15 MB');
    });
  });
}
