import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/commitments/data/commitments_repository.dart';
import 'package:harvest/features/commitments/domain/commitment.dart';
import 'package:harvest/features/commitments/domain/schedule.dart';
import 'package:harvest/features/export/data/export_repository.dart';
import 'package:harvest/features/export/domain/archive_service.dart';
import 'package:harvest/features/export/domain/harvest_workbook.dart';
import 'package:harvest/features/gallery/data/gallery_repository.dart';
import 'package:harvest/features/gallery/data/gallery_storage.dart';
import 'package:harvest/features/gym/data/programs_repository.dart';
import 'package:harvest/features/gym/data/sessions_repository.dart';
import 'package:harvest/features/gym/domain/program.dart';
import 'package:harvest/features/health/data/health_repository.dart';
import 'package:harvest/features/health/data/sleep_repository.dart';
import 'package:harvest/features/import/domain/archive_reader.dart';
import 'package:harvest/features/import/domain/import_service.dart';
import 'package:harvest/features/notes/data/notes_repository.dart';

import '../../support/temp_gallery_storage.dart';

/// Phase 3, M3.4. The promise ADR-007 makes: an archive is a **merge**,
/// by uuid, newer wins, and **nothing local is ever deleted for being
/// missing from it**.
///
/// Everything here goes through a real zip written by the real exporter
/// — a round trip proves the two halves agree in a way two fixtures
/// never could.
void main() {
  late HarvestDatabase source;
  late HarvestDatabase target;
  late Directory sourceRoot;
  late Directory targetRoot;
  late GalleryStorage sourceStorage;
  late GalleryStorage targetStorage;
  late ImportService importer;

  final day = HarvestDay.parse('2026-09-05');

  setUp(() async {
    source = HarvestDatabase.forTesting(NativeDatabase.memory());
    target = HarvestDatabase.forTesting(NativeDatabase.memory());
    sourceRoot = await Directory.systemTemp.createTemp('harvest-import-src');
    targetRoot = await Directory.systemTemp.createTemp('harvest-import-dst');
    sourceStorage = TempGalleryStorage(sourceRoot);
    targetStorage = TempGalleryStorage(targetRoot);
    importer = ImportService(target, targetStorage);
  });

  tearDown(() async {
    await source.close();
    await target.close();
    for (final directory in [sourceRoot, targetRoot]) {
      if (directory.existsSync()) await directory.delete(recursive: true);
    }
  });

  /// The archive the source database would write, opened.
  Future<ArchiveBundle> bundle() async {
    final bytes = await ArchiveService(
      ExportRepository(source),
      sourceStorage,
    ).build();
    return readArchive(bytes);
  }

  group('a broken archive', () {
    test('is refused rather than half-applied', () {
      expect(
        () => readArchive(Uint8List.fromList([1, 2, 3, 4])),
        throwsA(
          isA<ArchiveInvalid>().having(
            (e) => e.problem,
            'problem',
            ArchiveProblem.unreadable,
          ),
        ),
      );
    });

    test('a zip without a workbook is not one of ours', () {
      // An empty zip: the shortest valid end-of-central-directory.
      final empty = Uint8List.fromList([
        0x50, 0x4b, 0x05, 0x06, 0, 0, 0, 0, 0, 0, //
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      ]);
      expect(
        () => readArchive(empty),
        throwsA(
          isA<ArchiveInvalid>().having(
            (e) => e.problem,
            'problem',
            ArchiveProblem.notHarvest,
          ),
        ),
      );
    });
  });

  group('preview', () {
    test('counts what would happen and writes nothing', () async {
      await CommitmentsRepository(source).create(
        type: CommitmentType.habit,
        title: 'Read',
        schedule: const DailySchedule(),
      );
      await NotesRepository(source).create(title: 'Reading', body: 'p. 40');

      final preview = await importer.preview(await bundle());

      expect(preview.tables[SheetNames.seeds]!.added, 1);
      expect(preview.tables[SheetNames.notes]!.added, 1);
      expect(await target.select(target.commitments).get(), isEmpty);
      expect(await target.select(target.notes).get(), isEmpty);
    });

    test('says nothing to do when it has all been seen', () async {
      await NotesRepository(source).create(title: 'Reading', body: 'p. 40');
      final archive = await bundle();

      await importer.apply(archive);
      final second = await importer.preview(archive);

      expect(totalOf(second).added, 0);
      expect(totalOf(second).updated, 0);
    });
  });

  group('the merge', () {
    test('brings a whole phone across', () async {
      final seed = await CommitmentsRepository(source).create(
        type: CommitmentType.habit,
        title: 'Read',
        schedule: const DailySchedule(),
      );
      await source
          .into(source.checkIns)
          .insert(
            CheckInsCompanion.insert(
              uuid: 'c1',
              commitmentUuid: seed.uuid,
              harvestDay: day.key,
            ),
          );
      await NotesRepository(source).create(title: 'Reading', body: 'p. 40');

      await importer.apply(await bundle());

      final seeds = await target.select(target.commitments).get();
      expect(seeds.single.title, 'Read');
      expect((await target.select(target.checkIns).get()).single.uuid, 'c1');
      expect((await target.select(target.notes).get()).single.body, 'p. 40');
    });

    test('rebuilds the link index from the bodies it brought', () async {
      final notes = NotesRepository(source);
      final sleep = await notes.create(title: 'Sleep');
      await notes.create(title: 'Log', body: 'see [[Sleep]]');

      await importer.apply(await bundle());

      final backlinks = await NotesRepository(
        target,
      ).watchBacklinks(sleep.uuid).first;
      expect(backlinks.single.title, 'Log');
    });

    test('a newer copy in the archive wins', () async {
      final notes = NotesRepository(source);
      final note = await notes.create(title: 'Reading', body: 'old');
      await importer.apply(await bundle());

      // Edited the next day. Timestamps land on the database's
      // second-resolution clock, so "newer" has to be genuinely later
      // rather than a few microseconds along.
      await notes.update(note.uuid, body: 'new');
      await (source.update(
        source.notes,
      )..where((n) => n.uuid.equals(note.uuid))).write(
        NotesCompanion(
          updatedAt: Value(DateTime.now().add(const Duration(days: 1))),
        ),
      );
      final result = await importer.apply(await bundle());

      expect(result.tables[SheetNames.notes]!.updated, 1);
      expect((await target.select(target.notes).get()).single.body, 'new');
    });

    test('an older copy in the archive is left alone', () async {
      final note = await NotesRepository(source).create(
        title: 'Reading',
        body: 'from the archive',
      );
      final archive = await bundle();

      // The same note, by uuid, edited here after the archive was taken.
      await target
          .into(target.notes)
          .insert(
            NotesCompanion.insert(
              uuid: note.uuid,
              title: 'Reading',
              body: const Value('written here, later'),
              updatedAt: Value(DateTime.now().add(const Duration(days: 1))),
            ),
          );

      final result = await importer.apply(archive);

      expect(result.tables[SheetNames.notes]!.updated, 0);
      expect(result.tables[SheetNames.notes]!.unchanged, 1);
      expect(
        (await target.select(target.notes).get()).single.body,
        'written here, later',
      );
    });

    test('never deletes what the archive does not mention', () async {
      await NotesRepository(source).create(title: 'From the archive');
      final mine = await NotesRepository(
        target,
      ).create(title: 'Only on this phone');

      await importer.apply(await bundle());

      final titles = (await target.select(target.notes).get())
          .map((row) => row.title)
          .toSet();
      expect(titles, {'From the archive', 'Only on this phone'});
      expect(
        (await target.select(target.notes).get())
            .firstWhere((row) => row.uuid == mine.uuid)
            .deletedAt,
        isNull,
      );
    });
  });

  group('the pictures', () {
    test('come back into storage with their rows pointing at them', () async {
      final gallery = GalleryRepository(source, sourceStorage);
      final gym = await gallery.createAlbum(name: 'Gym');
      await (await sourceStorage.fileOf('gym/a.jpg')).create(recursive: true);
      await (await sourceStorage.fileOf(
        'gym/a.jpg',
      )).writeAsBytes([7, 7, 7]);
      await gallery.addMemory(
        albumUuid: gym.uuid,
        path: 'gym/a.jpg',
        day: day,
      );

      final result = await importer.apply(await bundle());

      expect(result.newFiles, 1);
      final row = (await target.select(target.memories).get()).single;
      final restored = await targetStorage.fileOf(row.path);
      expect(restored.existsSync(), isTrue);
      expect(await restored.readAsBytes(), [7, 7, 7]);
    });

    test(
      'the album comes first, so the row has something to hang on',
      () async {
        final gallery = GalleryRepository(source, sourceStorage);
        final gym = await gallery.createAlbum(
          name: 'Gym',
          schedule: const DailySchedule(),
        );
        await (await sourceStorage.fileOf('a.jpg')).writeAsBytes([1]);
        await gallery.addMemory(albumUuid: gym.uuid, path: 'a.jpg', day: day);

        await importer.apply(await bundle());

        final album = (await GalleryRepository(
          target,
          targetStorage,
        ).albumsOnce()).single;
        expect(album.name, 'Gym');
        expect(album.isScheduled, isTrue);
      },
    );

    test('a second import of the same archive adds nothing', () async {
      final gallery = GalleryRepository(source, sourceStorage);
      final gym = await gallery.createAlbum(name: 'Gym');
      await (await sourceStorage.fileOf('a.jpg')).writeAsBytes([1]);
      await gallery.addMemory(albumUuid: gym.uuid, path: 'a.jpg', day: day);
      final archive = await bundle();

      await importer.apply(archive);
      final second = await importer.apply(archive);

      expect(second.tables[SheetNames.memories]!.added, 0);
      expect((await target.select(target.memories).get()).length, 1);
    });
  });

  group('the body', () {
    /// A program, a session and a night, put into the source database
    /// the way the app puts them there.
    Future<void> seedBody() async {
      final programs = ProgramsRepository(source);
      final sessions = SessionsRepository(source);
      final program = await programs.createProgram(name: 'nSuns');
      final programDay = await programs.addDay(program.uuid, name: 'Day 1');
      final slot = await programs.addSlot(
        programDay.uuid,
        exerciseId: '0025',
        restSeconds: 180,
      );
      await programs.addTargetSet(
        slot.uuid,
        reps: 5,
        weightGrams: 100 * gramsPerKg,
      );
      await programs.setTrainingMax(
        programUuid: program.uuid,
        exerciseId: '0025',
        grams: 120 * gramsPerKg,
      );

      final fresh = (await programs.once(program.uuid))!;
      final session = await sessions.start(
        day: fresh.days.single,
        programUuid: program.uuid,
        title: 'Day 1',
        on: day,
      );
      await sessions.logSet(
        session.exercises.single.sets.single.uuid,
        weightGrams: 102500,
        reps: 4,
      );
      await sessions.finish(session.uuid);

      await HealthRepository(source).logWeight(
        grams: 81100,
        measuredAt: DateTime(2026, 9, 5, 8),
      );
      await SleepRepository(source).log(
        day: day,
        fellAsleepAt: DateTime(2026, 9, 4, 23),
        wokeAt: DateTime(2026, 9, 5, 7),
        targetMinutes: 480,
        restedStars: 4,
      );
    }

    test('a whole program comes across, days and sets and all', () async {
      await seedBody();
      await importer.apply(await bundle());

      final program = (await ProgramsRepository(target).allOnce()).single;
      expect(program.name, 'nSuns');
      final imported = program.days.single;
      expect(imported.slots.single.exerciseId, '0025');
      expect(imported.slots.single.restSeconds, 180);
      expect(imported.slots.single.sets.single.reps, 5);
      expect(
        await ProgramsRepository(target).trainingMaxesOnce(program.uuid),
        {'0025': 120 * gramsPerKg},
      );
    });

    test('a finished session keeps every set it logged', () async {
      await seedBody();
      await importer.apply(await bundle());

      final sessions = SessionsRepository(target);
      final imported = (await sessions.finishedOnce()).single;
      expect(imported.day, day);
      final set = imported.exercises.single.sets.single;
      expect(set.weightGrams, 102500);
      expect(set.reps, 4);
      expect(set.done, isTrue);
      // And so the records come across with it, because they are read
      // off the sets rather than stored.
      expect((await sessions.records('0025')).heaviest?.weightGrams, 102500);
    });

    test('weights and nights come across', () async {
      await seedBody();
      await importer.apply(await bundle());

      expect(
        (await HealthRepository(target).watchWeights().first).single.grams,
        81100,
      );
      final night = (await SleepRepository(target).on(day))!;
      expect(night.sleptMinutes, 8 * 60);
      expect(night.restedStars, 4);
    });

    test('a second import of the same archive adds nothing', () async {
      await seedBody();
      final archive = await bundle();

      await importer.apply(archive);
      final second = await importer.apply(archive);

      for (final sheet in [
        SheetNames.programs,
        SheetNames.programDays,
        SheetNames.programSlots,
        SheetNames.targetSets,
        SheetNames.sessions,
        SheetNames.sets,
        SheetNames.weights,
        SheetNames.sleep,
      ]) {
        expect(second.tables[sheet]!.added, 0, reason: sheet);
        expect(second.tables[sheet]!.updated, 0, reason: sheet);
      }
    });

    test('nothing local is deleted for being missing from it', () async {
      // The target has a night the archive has never heard of.
      final mine = day.previous;
      await SleepRepository(target).log(
        day: mine,
        fellAsleepAt: DateTime(2026, 9, 3, 23),
        wokeAt: DateTime(2026, 9, 4, 6),
        targetMinutes: 480,
      );
      await seedBody();
      await importer.apply(await bundle());

      expect(await SleepRepository(target).on(mine), isNotNull);
      expect(await SleepRepository(target).recentOnce(), hasLength(2));
    });
  });

  group('a zip from a later version', () {
    test('is read by header, so a new column changes nothing', () async {
      await NotesRepository(source).create(title: 'Reading', body: 'p. 40');
      final archive = await bundle();

      // A column this build has never heard of.
      for (final row in archive.sheet(SheetNames.notes)) {
        row['SomethingNew'] = 'ignore me';
      }

      final result = await importer.apply(archive);

      expect(result.tables[SheetNames.notes]!.added, 1);
      expect((await target.select(target.notes).get()).single.body, 'p. 40');
    });
  });
}
