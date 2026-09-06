import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/commitments/domain/schedule.dart';
import 'package:harvest/features/export/data/export_repository.dart';
import 'package:harvest/features/export/domain/archive_layout.dart';
import 'package:harvest/features/export/domain/archive_service.dart';
import 'package:harvest/features/gallery/data/gallery_repository.dart';
import 'package:harvest/features/gallery/data/gallery_storage.dart';
import 'package:harvest/features/notes/data/notes_repository.dart';

import '../../support/temp_gallery_storage.dart';

/// Phase 3, M3.3. The archive is a browsable tree with the workbook as
/// its index (ADR-007), which means two things have to be true at once:
/// the paths in the sheet are the paths in the zip, and an awkward
/// title survives the trip in both directions.
void main() {
  late HarvestDatabase db;
  late Directory root;
  late GalleryStorage storage;
  late GalleryRepository gallery;
  late NotesRepository notes;
  late ArchiveService archive;

  final day = HarvestDay.parse('2026-09-05');

  setUp(() async {
    db = HarvestDatabase.forTesting(NativeDatabase.memory());
    root = await Directory.systemTemp.createTemp('harvest-archive-test');
    storage = TempGalleryStorage(root);
    gallery = GalleryRepository(db, storage);
    notes = NotesRepository(db);
    archive = ArchiveService(ExportRepository(db), storage);
  });

  tearDown(() async {
    await db.close();
    if (root.existsSync()) await root.delete(recursive: true);
  });

  Future<Archive> zip() async => ZipDecoder().decodeBytes(await archive.build());

  Set<String> namesOf(Archive zip) => {
    for (final file in zip.files)
      if (file.isFile) file.name,
  };

  group('the tree', () {
    test('always holds the workbook, even with nothing else', () async {
      expect(namesOf(await zip()), {ArchivePaths.workbook});
    });

    test('writes notes as a vault in their own folders', () async {
      await notes.create(title: 'Reading', body: 'p. 40');
      await notes.create(
        title: 'Sleep log',
        folder: 'Health',
        body: 'seven hours',
      );

      expect(namesOf(await zip()), {
        ArchivePaths.workbook,
        'notes/Reading.md',
        'notes/Health/Sleep log.md',
      });
    });

    test('writes each album as a folder of days', () async {
      final gym = await gallery.createAlbum(
        name: 'Gym',
        schedule: const DailySchedule(),
      );
      final file = await storage.fileOf('a.jpg');
      await file.writeAsBytes([1, 2, 3]);
      await gallery.addMemory(
        albumUuid: gym.uuid,
        path: 'a.jpg',
        day: day,
      );

      expect(namesOf(await zip()), {
        ArchivePaths.workbook,
        'gallery/Gym/2026-09-05.jpg',
      });
    });

    test('a note body comes back out byte for byte', () async {
      await notes.create(title: 'Reading', body: '# Head\n\nline\n');

      final entry = (await zip()).files.firstWhere(
        (file) => file.name == 'notes/Reading.md',
      );
      expect(
        String.fromCharCodes(entry.content as List<int>),
        '# Head\n\nline\n',
      );
    });
  });

  group('an awkward title', () {
    test('is made safe in the tree and kept whole in the sheet', () async {
      await notes.create(title: 'Q4: what now?', body: 'hm');

      final contents = await ExportRepository(db).readArchive();
      final row = contents.data.notes.single;

      expect(row[1], 'Q4: what now?');
      expect(row[3], 'notes/Q4- what now-.md');
      expect(namesOf(await zip()), contains('notes/Q4- what now-.md'));
    });

    test('two notes that sanitise the same both survive', () async {
      await notes.create(title: 'Q4: what now?');
      await notes.create(title: 'Q4- what now-');

      final names = namesOf(await zip());
      expect(names, contains('notes/Q4- what now-.md'));
      expect(names, contains('notes/Q4- what now- (2).md'));
    });

    test('two pictures on one day do not overwrite each other', () async {
      final gym = await gallery.createAlbum(name: 'Gym');
      for (final name in ['a.jpg', 'b.jpg']) {
        await (await storage.fileOf(name)).writeAsBytes([1]);
        await gallery.addMemory(
          albumUuid: gym.uuid,
          path: name,
          day: day,
        );
      }

      final names = namesOf(await zip());
      expect(names, contains('gallery/Gym/2026-09-05.jpg'));
      expect(names, contains('gallery/Gym/2026-09-05-2.jpg'));
    });
  });

  group('the sheet is the index', () {
    test('every memory row points at a file that is there', () async {
      final gym = await gallery.createAlbum(name: 'Gym');
      await (await storage.fileOf('a.jpg')).writeAsBytes([1, 2]);
      await gallery.addMemory(albumUuid: gym.uuid, path: 'a.jpg', day: day);

      final contents = await ExportRepository(db).readArchive();
      final names = namesOf(await zip());

      for (final row in contents.data.memories) {
        expect(names, contains(row[3]));
      }
    });

    test('a row whose file has gone does not lose the archive', () async {
      final gym = await gallery.createAlbum(name: 'Gym');
      await gallery.addMemory(albumUuid: gym.uuid, path: 'gone.jpg', day: day);

      final names = namesOf(await zip());
      expect(names, {ArchivePaths.workbook});
    });

    test('a deleted note keeps its row but leaves no file', () async {
      final note = await notes.create(title: 'Draft', body: 'x');
      await notes.remove(note.uuid);

      final contents = await ExportRepository(db).readArchive();
      expect(contents.data.notes.single[0], note.uuid);
      expect(contents.data.notes.single[3], isNull);
      expect(namesOf(await zip()), {ArchivePaths.workbook});
    });
  });

  group('progress and cancelling', () {
    test('counts every entry, the workbook included', () async {
      await notes.create(title: 'One');
      await notes.create(title: 'Two');

      final seen = <ArchiveProgress>[];
      await archive.build(onProgress: seen.add);

      expect(seen.length, 3);
      expect(seen.last.done, 3);
      expect(seen.last.total, 3);
    });

    test('stopping part-way writes nothing at all', () async {
      await notes.create(title: 'One');

      expect(
        () => archive.build(cancelled: () => true),
        throwsA(isA<ArchiveCancelled>()),
      );
    });
  });

  group('the file name', () {
    test('sorts by when it was taken', () {
      expect(
        archiveFileName(DateTime(2026, 9, 5, 14, 30)),
        'harvest-2026-09-05-1430.zip',
      );
    });
  });
}
