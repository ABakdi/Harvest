import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/features/export/data/export_repository.dart';
import 'package:harvest/features/export/domain/archive_layout.dart';
import 'package:harvest/features/export/domain/archive_service.dart';
import 'package:harvest/features/export/domain/harvest_workbook.dart';
import 'package:harvest/features/gallery/data/gallery_storage.dart';
import 'package:harvest/features/import/domain/archive_reader.dart';
import 'package:harvest/features/import/domain/import_service.dart';
import 'package:harvest/features/notes/data/note_attachments.dart';
import 'package:harvest/features/notes/data/notes_repository.dart';
import 'package:path/path.dart' as p;

import '../../support/temp_gallery_storage.dart';

/// The tables Phase 5 added, and the one the audit found missing
/// (Q3-02), carried by the archive and brought back whole
/// ([[Business-Rules]] #11, [[Goals]] GL6, [[Places]], [[Notes]] N7).
///
/// Each one is a round trip: written by the real exporter, read by the
/// real importer into an empty phone, and compared row for row.
void main() {
  late HarvestDatabase source;
  late HarvestDatabase target;
  late Directory sourceRoot;
  late Directory targetRoot;
  late AttachmentStorage sourceAttachments;
  late AttachmentStorage targetAttachments;
  late ImportService importer;

  // Whole seconds: the database keeps no finer than that, and a row
  // compared after the trip must be the row that went in.
  final at = DateTime(2026, 9, 18, 7, 12, 30);
  final later = DateTime(2026, 9, 19, 8);

  setUp(() async {
    source = HarvestDatabase.forTesting(NativeDatabase.memory());
    target = HarvestDatabase.forTesting(NativeDatabase.memory());
    sourceRoot = await Directory.systemTemp.createTemp('harvest-p5-src');
    targetRoot = await Directory.systemTemp.createTemp('harvest-p5-dst');
    sourceAttachments = AttachmentStorage(documents: () async => sourceRoot);
    targetAttachments = AttachmentStorage(documents: () async => targetRoot);
    importer = ImportService(
      target,
      TempGalleryStorage(targetRoot),
      targetAttachments,
    );
  });

  tearDown(() async {
    await source.close();
    await target.close();
    for (final directory in [sourceRoot, targetRoot]) {
      if (directory.existsSync()) await directory.delete(recursive: true);
    }
  });

  Future<Uint8List> archiveBytes() => ArchiveService(
    ExportRepository(source),
    TempGalleryStorage(sourceRoot),
    sourceAttachments,
  ).build();

  Future<ImportPreview> roundTrip() async =>
      importer.apply(readArchive(await archiveBytes()));

  Future<Set<String>> outboxTables() async => {
    for (final row in await target.select(target.outbox).get()) row.targetTable,
  };

  group('goals (GL6)', () {
    Future<void> seedGoals() async {
      await source
          .into(source.goals)
          .insert(
            GoalsCompanion.insert(
              uuid: 'g1',
              title: 'Run a half marathon',
              why: const Value('Because I said so in January'),
              targetDay: const Value('2027-04-01'),
              status: const Value('achieved'),
              statusNote: const Value('1:58'),
              achievedAt: Value(later),
              position: const Value(2),
              createdAt: Value(at),
              updatedAt: Value(later),
            ),
          );
      await source
          .into(source.goals)
          .insert(
            GoalsCompanion.insert(
              uuid: 'g2',
              title: 'Dropped',
              createdAt: Value(at),
              updatedAt: Value(at),
              deletedAt: Value(later),
            ),
          );
      await source
          .into(source.goalItems)
          .insert(
            GoalItemsCompanion.insert(
              uuid: 'i1',
              goalUuid: 'g1',
              kind: const Value('need'),
              body: 'Shoes',
              note: const Value('not the old ones'),
              doneAt: Value(at),
              position: const Value(1),
              commitmentUuid: const Value('c1'),
              createdAt: Value(at),
              updatedAt: Value(at),
            ),
          );
      // A subtask carries its parent across ([[Goals]] GL6, v24).
      await source
          .into(source.goalItems)
          .insert(
            GoalItemsCompanion.insert(
              uuid: 'i2',
              goalUuid: 'g1',
              kind: const Value('need'),
              body: 'Try them on',
              parentUuid: const Value('i1'),
              createdAt: Value(at),
              updatedAt: Value(at),
            ),
          );
      await source
          .into(source.commitments)
          .insert(
            CommitmentsCompanion.insert(
              uuid: 'c1',
              type: 'habit',
              title: 'Run',
              goalUuid: const Value('g1'),
              createdAt: Value(at),
              updatedAt: Value(at),
            ),
          );
    }

    test('goals and their items come back whole', () async {
      await seedGoals();
      final preview = await roundTrip();

      expect(
        await target.select(target.goals).get(),
        await source.select(source.goals).get(),
      );
      expect(
        await target.select(target.goalItems).get(),
        await source.select(source.goalItems).get(),
      );
      expect(preview.tables[SheetNames.goals]!.added, 2);
      expect(preview.tables[SheetNames.goalItems]!.added, 2);
      expect(await outboxTables(), containsAll(['goals', 'goal_items']));
    });

    test('an archive from before subtasks brings every item top-level', () async {
      await seedGoals();
      final bundle = readArchive(await archiveBytes());
      final older = ArchiveBundle(
        sheets: {
          ...bundle.sheets,
          SheetNames.goalItems: [
            for (final row in bundle.sheet(SheetNames.goalItems))
              {...row}..remove('ParentUuid'),
          ],
        },
        files: bundle.files,
      );
      expect(
        bundle.sheet(SheetNames.goalItems).map((r) => r['ParentUuid']),
        contains('i1'),
      );
      await importer.apply(older);

      final items = await target.select(target.goalItems).get();
      expect(items.map((i) => i.uuid), unorderedEquals(['i1', 'i2']));
      expect(items.every((i) => i.parentUuid == null), isTrue);
    });

    test("a seed's goal survives the trip", () async {
      await seedGoals();
      await roundTrip();

      final seed = await target.select(target.commitments).getSingle();
      expect(seed.goalUuid, 'g1');
      expect(seed, await source.select(source.commitments).getSingle());
    });

    test('a newer goal in the archive wins, an older one does not', () async {
      await seedGoals();
      await roundTrip();

      await (source.update(
        source.goals,
      )..where((g) => g.uuid.equals('g1'))).write(
        GoalsCompanion(
          title: const Value('Run a full marathon'),
          updatedAt: Value(later.add(const Duration(days: 1))),
        ),
      );
      await (target.update(
        target.goals,
      )..where((g) => g.uuid.equals('g2'))).write(
        GoalsCompanion(
          title: const Value('Kept here'),
          updatedAt: Value(later.add(const Duration(days: 1))),
        ),
      );
      final preview = await roundTrip();

      expect(preview.tables[SheetNames.goals]!.updated, 1);
      final titles = {
        for (final row in await target.select(target.goals).get())
          row.uuid: row.title,
      };
      expect(titles, {'g1': 'Run a full marathon', 'g2': 'Kept here'});
    });
  });

  group('expense categories (Q3-02)', () {
    test('come back with their names and icons', () async {
      await source
          .into(source.expenseCategories)
          .insert(
            ExpenseCategoriesCompanion.insert(
              uuid: 'k1',
              name: 'Coffee',
              icon: 'coffee',
              updatedAt: Value(at),
            ),
          );
      await source
          .into(source.expenseCategories)
          .insert(
            ExpenseCategoriesCompanion.insert(
              uuid: 'k2',
              name: 'Old',
              icon: 'box',
              updatedAt: Value(at),
              deletedAt: Value(later),
            ),
          );
      final preview = await roundTrip();

      expect(
        await target.select(target.expenseCategories).get(),
        await source.select(source.expenseCategories).get(),
      );
      expect(preview.tables[SheetNames.categories]!.added, 2);
      expect(await outboxTables(), contains('expense_categories'));
    });
  });

  group('places (PL6)', () {
    test('points, geotags and saved places come back exactly', () async {
      await source
          .into(source.savedPlaces)
          .insert(
            SavedPlacesCompanion.insert(
              uuid: 'p1',
              name: 'Home',
              latitude: 36.7538123,
              longitude: 3.0587561,
              radiusM: const Value(150.5),
              notes: const Value('Gate code 4412, second floor'),
              createdAt: Value(at),
              updatedAt: Value(at),
            ),
          );
      await source
          .into(source.locationPoints)
          .insert(
            LocationPointsCompanion.insert(
              uuid: 'l1',
              harvestDay: '2026-09-18',
              recordedAt: at,
              latitude: 36.7538123,
              longitude: -3.0587561,
              accuracyM: const Value(12.5),
              speedMps: const Value(1.25),
              altitudeM: const Value(-4),
              updatedAt: Value(at),
            ),
          );
      await source
          .into(source.locationPoints)
          .insert(
            LocationPointsCompanion.insert(
              uuid: 'l2',
              harvestDay: '2026-09-18',
              recordedAt: at,
              latitude: 0,
              longitude: 0,
              updatedAt: Value(later),
              deletedAt: Value(later),
            ),
          );
      await source
          .into(source.geotags)
          .insert(
            GeotagsCompanion.insert(
              uuid: 't1',
              targetTable: 'check_ins',
              targetUuid: 'x1',
              harvestDay: '2026-09-18',
              at: at,
              latitude: const Value(36.75),
              longitude: const Value(3.05),
              accuracyM: const Value(8),
              state: const Value('fixed'),
              updatedAt: Value(at),
            ),
          );
      await source
          .into(source.geotags)
          .insert(
            GeotagsCompanion.insert(
              uuid: 't2',
              targetTable: 'expenses',
              targetUuid: 'x2',
              harvestDay: '2026-09-18',
              at: at,
              state: const Value('unavailable'),
              updatedAt: Value(at),
            ),
          );

      final preview = await roundTrip();

      expect(
        await target.select(target.savedPlaces).get(),
        await source.select(source.savedPlaces).get(),
      );
      expect(
        await target.select(target.locationPoints).get(),
        await source.select(source.locationPoints).get(),
      );
      expect(
        await target.select(target.geotags).get(),
        await source.select(source.geotags).get(),
      );
      expect(preview.tables[SheetNames.locationPoints]!.added, 2);
      expect(
        await outboxTables(),
        containsAll(['saved_places', 'location_points', 'geotags']),
      );
    });
  });

  group('a recording (N7)', () {
    const name = '2026-09-18 0712.m4a';
    const audio = [0, 1, 2, 3, 250, 251, 252];

    Future<String> seedRecording() async {
      final note = await NotesRepository(source).create(
        title: 'Voice',
        folder: 'Health',
        body: '![[$name]]',
      );
      final reserved = await sourceAttachments.reserve(note.uuid, name);
      await reserved.file.writeAsBytes(audio);
      await NoteAttachmentsRepository(source, sourceAttachments).add(
        noteUuid: note.uuid,
        fileName: name,
        storedPath: reserved.relative,
        sizeBytes: audio.length,
        durationMs: 4200,
      );
      return note.uuid;
    }

    test("sits beside its note's .md, under the name it embeds", () async {
      await seedRecording();
      final zip = ZipDecoder().decodeBytes(await archiveBytes());
      final names = {
        for (final file in zip.files)
          if (file.isFile) file.name,
      };

      expect(names, contains('notes/Health/Voice.md'));
      expect(names, contains('notes/Health/$name'));
      final entry = zip.files.firstWhere(
        (file) => file.name == 'notes/Health/$name',
      );
      expect(entry.content, audio);

      final row = (await ExportRepository(
        source,
      ).readArchive()).data.noteAttachments.single;
      expect(row[3], name);
      expect(row[4], 'notes/Health/$name');
    });

    test('comes back into storage, row and file both', () async {
      final noteUuid = await seedRecording();
      final preview = await importer.preview(
        readArchive(await archiveBytes()),
      );
      expect(preview.tables[SheetNames.noteAttachments]!.added, 1);
      expect(preview.newFiles, 1);
      expect(preview.files, 2, reason: 'the .md and the recording');

      await roundTrip();

      final row = await target.select(target.noteAttachments).getSingle();
      expect(row, await source.select(source.noteAttachments).getSingle());
      expect(row.storedPath, '$noteUuid/$name');
      final file = await targetAttachments.fileOf(row.storedPath);
      expect(await file.readAsBytes(), audio);
      expect(await outboxTables(), contains('note_attachments'));
    });

    test('a second import of the same archive changes nothing', () async {
      await seedRecording();
      final archive = readArchive(await archiveBytes());
      await importer.apply(archive);
      final second = await importer.preview(archive);

      expect(second.tables[SheetNames.noteAttachments]!.unchanged, 1);
      expect(second.newFiles, 0);
      expect(totalOf(second).added, 0);
      expect(totalOf(second).updated, 0);
    });

    test('one in the trash keeps its row and leaves no file', () async {
      await seedRecording();
      await source
          .update(source.noteAttachments)
          .write(
            NoteAttachmentsCompanion(deletedAt: Value(later)),
          );
      final zip = ZipDecoder().decodeBytes(await archiveBytes());

      expect(
        zip.files.where((file) => file.name.endsWith('.m4a')),
        isEmpty,
      );
      final row = (await ExportRepository(
        source,
      ).readArchive()).data.noteAttachments.single;
      expect(row[4], isNull);
    });
  });

  group('an archive does not name my files', () {
    const headers = [
      'Uuid',
      'NoteUuid',
      'Kind',
      'FileName',
      'File',
      'StoredPath',
      'DurationMs',
      'SizeBytes',
      'CreatedAt',
      'UpdatedAt',
      'DeletedAt',
    ];

    Uint8List crafted({
      required String fileName,
      required String storedPath,
    }) {
      final excel = Excel.createExcel();
      final sheets = {
        SheetNames.notes: [
          ['Uuid', 'Title', 'Folder', 'File', 'Body', 'UpdatedAt'],
          ['n1', 'Voice', '', 'notes/Voice.md', 'x', '2026-09-18T07:00:00'],
        ],
        SheetNames.noteAttachments: [
          headers,
          [
            'a1',
            'n1',
            'audio',
            fileName,
            'notes/rec.m4a',
            storedPath,
            '1000',
            '3',
            '2026-09-18T07:00:00',
            '2026-09-18T07:00:00',
            '',
          ],
        ],
      };
      for (final entry in sheets.entries) {
        final sheet = excel[entry.key];
        for (final (r, row) in entry.value.indexed) {
          for (final (c, cell) in row.indexed) {
            sheet
                .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r))
                .value = TextCellValue(
              cell,
            );
          }
        }
      }
      excel.delete('Sheet1');
      final workbook = excel.encode()!;
      final zip = Archive()
        ..addFile(ArchiveFile(ArchivePaths.workbook, workbook.length, workbook))
        ..addFile(ArchiveFile('notes/Voice.md', 1, [120]))
        ..addFile(ArchiveFile('notes/rec.m4a', 3, [7, 8, 9]));
      return Uint8List.fromList(ZipEncoder().encode(zip)!);
    }

    Future<void> expectInside(File escaped) async {
      addTearDown(() {
        if (escaped.existsSync()) escaped.deleteSync();
      });
      final row = await target.select(target.noteAttachments).getSingle();
      expect(escaped.existsSync(), isFalse, reason: 'nothing outside');
      expect(GalleryStorage.isSafeRelative(row.storedPath), isTrue);
      expect(p.posix.split(row.storedPath), hasLength(2));
      expect(row.storedPath, startsWith('n1/'));
      final file = await targetAttachments.fileOf(row.storedPath);
      expect(await file.readAsBytes(), [7, 8, 9]);
    }

    test('a stored path that walks out is not read at all', () async {
      final escaped = File(p.join(targetRoot.parent.path, 'harvest-rec-out'));
      await importer.apply(
        readArchive(
          crafted(fileName: 'rec.m4a', storedPath: '../../harvest-rec-out'),
        ),
      );
      await expectInside(escaped);
      final row = await target.select(target.noteAttachments).getSingle();
      expect(row.storedPath, 'n1/rec.m4a');
    });

    test('a file name that is really a path is made a name', () async {
      final escaped = File(p.join(targetRoot.path, 'harvest-rec-name'));
      await importer.apply(
        readArchive(
          crafted(
            fileName: '../../harvest-rec-name',
            storedPath: '/etc/harvest-rec-abs',
          ),
        ),
      );
      await expectInside(escaped);
      final row = await target.select(target.noteAttachments).getSingle();
      expect(row.fileName, isNot(contains('/')));
    });
  });

  group('the settings sheet (S3-05)', () {
    test('carries my preferences and none of the bookkeeping', () async {
      for (final key in [
        'themeMode',
        'places.enabled',
        'security.appLock',
        'streak.lastJudgedDay',
        'pomodoro.active',
        'records.note',
      ]) {
        await source
            .into(source.kvSettings)
            .insert(KvSettingsCompanion.insert(key: key, valueJson: '1'));
      }

      final rows = (await ExportRepository(source).readArchive()).data.settings;
      expect(rows.map((row) => row.first).toSet(), {
        'themeMode',
        'places.enabled',
      });
    });
  });
}
