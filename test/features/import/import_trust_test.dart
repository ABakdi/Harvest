import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/export/data/export_repository.dart';
import 'package:harvest/features/export/domain/archive_layout.dart';
import 'package:harvest/features/export/domain/archive_service.dart';
import 'package:harvest/features/export/domain/harvest_workbook.dart';
import 'package:harvest/features/finances/data/finances_repository.dart';
import 'package:harvest/features/gallery/data/gallery_repository.dart';
import 'package:harvest/features/gallery/data/gallery_storage.dart';
import 'package:harvest/features/gamification/domain/streak_service.dart';
import 'package:harvest/features/import/domain/archive_reader.dart';
import 'package:harvest/features/import/domain/import_service.dart';
import 'package:path/path.dart' as p;

import '../../support/temp_gallery_storage.dart';

/// The second audit's rule for the importer: **an archive is data,
/// never instructions.** It does not choose where a file goes
/// (S2-01), how much memory it may have (S2-02), or which of the
/// app's own bookkeeping to overwrite (S2-04) — and what it does
/// carry, it carries whole: a deletion (B-05) and the streaks (B-02).
void main() {
  late HarvestDatabase source;
  late HarvestDatabase target;
  late Directory sourceRoot;
  late Directory targetRoot;
  late GalleryStorage sourceStorage;
  late GalleryStorage targetStorage;
  late ImportService importer;

  setUp(() async {
    source = HarvestDatabase.forTesting(NativeDatabase.memory());
    target = HarvestDatabase.forTesting(NativeDatabase.memory());
    sourceRoot = await Directory.systemTemp.createTemp('harvest-trust-src');
    targetRoot = await Directory.systemTemp.createTemp('harvest-trust-dst');
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

  Future<Uint8List> archiveBytes() => ArchiveService(
    ExportRepository(source),
    sourceStorage,
  ).build();

  /// A zip holding a workbook with exactly the sheets given, one
  /// picture, and nothing the exporter would have written itself.
  Uint8List craftedZip({
    required Map<String, List<List<String>>> sheets,
    Map<String, List<int>> files = const {},
  }) {
    final excel = Excel.createExcel();
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
      ..addFile(
        ArchiveFile(ArchivePaths.workbook, workbook.length, workbook),
      );
    for (final entry in files.entries) {
      zip.addFile(ArchiveFile(entry.key, entry.value.length, entry.value));
    }
    return Uint8List.fromList(ZipEncoder().encode(zip)!);
  }

  group('where a picture lands (S2-01)', () {
    const memoryHeaders = [
      'Uuid',
      'AlbumUuid',
      'HarvestDay',
      'File',
      'StoredPath',
      'Kind',
      'Note',
      'CapturedAt',
      'UpdatedAt',
      'DeletedAt',
    ];

    Future<void> importWithStoredPath(String storedPath) async {
      final zip = craftedZip(
        sheets: {
          SheetNames.albums: [
            ['Uuid', 'Name', 'Folder', 'CreatedAt', 'UpdatedAt'],
            ['a1', 'Gym', 'gallery/Gym', '2026-09-01', '2026-09-01'],
          ],
          SheetNames.memories: [
            memoryHeaders,
            [
              'm1',
              'a1',
              '2026-09-05',
              'gallery/Gym/2026-09-05.jpg',
              storedPath,
              'photo',
              '',
              '2026-09-05T10:00:00',
              '2026-09-05T10:00:00',
              '',
            ],
          ],
        },
        files: {
          'gallery/Gym/2026-09-05.jpg': [1, 2, 3],
        },
      );
      await importer.apply(readArchive(zip));
    }

    Future<String> storedPathOf(String uuid) async => (await (target.select(
      target.memories,
    )..where((m) => m.uuid.equals(uuid))).getSingle()).path;

    test('a plain relative path inside the gallery is honoured', () async {
      await importWithStoredPath('a1/2026-09-05-abcd1234.jpg');
      expect(await storedPathOf('m1'), 'a1/2026-09-05-abcd1234.jpg');
      expect(
        File(p.join(targetRoot.path, 'a1/2026-09-05-abcd1234.jpg'))
            .existsSync(),
        isTrue,
      );
    });

    test('a path that walks out of the gallery is not written there', () async {
      final outside = File(p.join(targetRoot.parent.path, 'harvest-escaped'));
      addTearDown(() {
        if (outside.existsSync()) outside.deleteSync();
      });
      await importWithStoredPath('../harvest-escaped');

      expect(outside.existsSync(), isFalse, reason: 'nothing outside');
      final path = await storedPathOf('m1');
      expect(GalleryStorage.isSafeRelative(path), isTrue);
      expect(File(p.join(targetRoot.path, path)).existsSync(), isTrue);
    });

    test('an absolute path is not written there either', () async {
      final absolute = File(p.join(targetRoot.parent.path, 'harvest-abs.jpg'));
      addTearDown(() {
        if (absolute.existsSync()) absolute.deleteSync();
      });
      await importWithStoredPath(absolute.path);

      expect(absolute.existsSync(), isFalse);
      final path = await storedPathOf('m1');
      expect(GalleryStorage.isSafeRelative(path), isTrue);
      expect(File(p.join(targetRoot.path, path)).existsSync(), isTrue);
    });

    test('the rule itself', () {
      expect(GalleryStorage.isSafeRelative('a1/2026-09-05-x.jpg'), isTrue);
      expect(GalleryStorage.isSafeRelative(''), isFalse);
      expect(GalleryStorage.isSafeRelative('../x.jpg'), isFalse);
      expect(GalleryStorage.isSafeRelative('a/../../x.jpg'), isFalse);
      expect(GalleryStorage.isSafeRelative('/etc/passwd'), isFalse);
      expect(GalleryStorage.isSafeRelative(r'C:\x.jpg'), isFalse);
      expect(GalleryStorage.isSafeRelative('a/./b.jpg'), isFalse);
      expect(GalleryStorage.isSafeRelative('.'), isFalse);
    });
  });

  group('how much an archive may weigh (S2-02)', () {
    test('a zip whose directory promises too much is refused unread', () {
      // A header claiming a 100 MB entry with three bytes behind it: the
      // reader must refuse on the label without inflating anything.
      final zip = Archive()
        ..addFile(ArchiveFile(ArchivePaths.workbook, 1, [0]))
        ..addFile(
          ArchiveFile('gallery/big.jpg', ArchiveLimits.entryBytes + 1, [
            1,
            2,
            3,
          ]),
        );
      final bytes = Uint8List.fromList(ZipEncoder().encode(zip)!);
      expect(
        () => readArchive(bytes),
        throwsA(
          isA<ArchiveInvalid>().having(
            (e) => e.problem,
            'problem',
            ArchiveProblem.tooLarge,
          ),
        ),
      );
    });

    test('a file bigger than the cap is refused before decoding', () {
      final bytes = Uint8List(ArchiveLimits.archiveBytes + 1);
      expect(
        () => readArchive(bytes),
        throwsA(
          isA<ArchiveInvalid>().having(
            (e) => e.problem,
            'problem',
            ArchiveProblem.tooLarge,
          ),
        ),
      );
    });
  });

  group('which settings an archive may set (S2-04)', () {
    test('preferences come across; the bookkeeping does not', () async {
      final zip = craftedZip(
        sheets: {
          SheetNames.settings: [
            ['Key', 'Value', 'UpdatedAt'],
            ['themeMode', '"dark"', '2026-09-05T10:00:00'],
            ['health.stepGoal', '"8000"', '2026-09-05T10:00:00'],
            ['security.appLock', '"true"', '2026-09-05T10:00:00'],
            ['streak.lastJudgedDay', '"2026-09-04"', '2026-09-05T10:00:00'],
            ['reminders.taskIds', '[2100,2101]', '2026-09-05T10:00:00'],
            ['pomodoro.active', '{"x":1}', '2026-09-05T10:00:00'],
          ],
        },
      );
      final preview = await importer.apply(readArchive(zip));

      final keys = {
        for (final row in await target.select(target.kvSettings).get()) row.key,
      };
      expect(keys, containsAll(['themeMode', 'health.stepGoal']));
      expect(keys, isNot(contains('security.appLock')));
      expect(keys, isNot(contains('streak.lastJudgedDay')));
      expect(keys, isNot(contains('reminders.taskIds')));
      expect(keys, isNot(contains('pomodoro.active')));
      expect(preview.tables[SheetNames.settings]!.added, 2);
      expect(preview.tables[SheetNames.settings]!.unchanged, 4);
    });

    test('the list is the list', () {
      expect(isImportableSetting('cycle.bedTime'), isTrue);
      expect(isImportableSetting('reminders.morningTime'), isTrue);
      expect(isImportableSetting('reminders.snoozes'), isFalse);
      expect(isImportableSetting('reminders.comebackIds'), isFalse);
      expect(isImportableSetting('security.appLock'), isFalse);
      expect(isImportableSetting('streak.lastJudgedDay'), isFalse);
      expect(isImportableSetting('pomodoro.active'), isFalse);
      expect(isImportableSetting('pomodoro.focusMinutes'), isTrue);
    });
  });

  group('a deletion carried by an archive (B-05)', () {
    test('wins over a live copy of the same row', () async {
      final finances = FinancesRepository(source);
      final uuid = await finances.log(amountMinor: 1200, category: 'food');
      // The target has the expense, live, from an earlier archive.
      await importer.apply(readArchive(await archiveBytes()));
      var row = await (target.select(
        target.expenses,
      )..where((e) => e.uuid.equals(uuid))).getSingle();
      expect(row.deletedAt, isNull);

      // Then it is deleted at the source, and a newer archive follows.
      // Timestamps are stored to the second, so the deletion is stamped
      // a minute on rather than waiting for the clock.
      await finances.remove(uuid);
      await (source.update(
        source.expenses,
      )..where((e) => e.uuid.equals(uuid))).write(
        ExpensesCompanion(
          updatedAt: Value(DateTime.now().add(const Duration(minutes: 1))),
        ),
      );
      final preview = await importer.apply(readArchive(await archiveBytes()));

      row = await (target.select(
        target.expenses,
      )..where((e) => e.uuid.equals(uuid))).getSingle();
      expect(row.deletedAt, isNotNull, reason: 'the deletion came across');
      expect(preview.tables[SheetNames.expenses]!.updated, 1);
    });

    test('an archive from before the column reads the row as logged', () async {
      final zip = craftedZip(
        sheets: {
          SheetNames.expenses: [
            [
              'Uuid',
              'HarvestDay',
              'Category',
              'Currency',
              'AmountMinor',
              'Note',
              'LoggedAt',
              'DeletedAt',
            ],
            [
              'e1',
              '2026-09-05',
              'food',
              'DZD',
              '500',
              '',
              '2026-09-05T10:00:00',
              '',
            ],
          ],
        },
      );
      await importer.apply(readArchive(zip));
      final row = await (target.select(
        target.expenses,
      )..where((e) => e.uuid.equals('e1'))).getSingle();
      expect(row.updatedAt, DateTime(2026, 9, 5, 10));
    });
  });

  group('the streaks (B-02)', () {
    test('come back with the archive', () async {
      final streaks = StreakService(source);
      await source
          .into(source.streaks)
          .insert(
            StreaksCompanion.insert(
              scope: StreakService.globalScope,
              current: const Value(12),
              best: const Value(30),
              lastEarnedDay: const Value('2026-09-05'),
              freezesStored: const Value(1),
            ),
          );
      expect(await streaks.currentGlobal(), 12);

      await importer.apply(readArchive(await archiveBytes()));

      final restored = await StreakService(target).currentGlobal();
      expect(restored, 12);
      final row = await (target.select(
        target.streaks,
      )..where((s) => s.scope.equals(StreakService.globalScope))).getSingle();
      expect(row.best, 30);
      expect(row.freezesStored, 1);
      expect(row.lastEarnedDay, '2026-09-05');
    });

    test(
      'a newer local streak is not overwritten by an older archive',
      () async {
        await source
            .into(source.streaks)
            .insert(
              StreaksCompanion.insert(
                scope: StreakService.globalScope,
                current: const Value(3),
                best: const Value(3),
                updatedAt: Value(DateTime(2026, 9)),
              ),
            );
        await target
            .into(target.streaks)
            .insert(
              StreaksCompanion.insert(
                scope: StreakService.globalScope,
                current: const Value(9),
                best: const Value(9),
                updatedAt: Value(DateTime(2026, 9, 8)),
              ),
            );
        await importer.apply(readArchive(await archiveBytes()));
        expect(await StreakService(target).currentGlobal(), 9);
      },
    );
  });

  group('a date cell (Q2-07)', () {
    test('reads as its date, not as now', () async {
      final excel = Excel.createExcel();
      final sheet = excel[SheetNames.seeds];
      final headers = [
        'Uuid',
        'Type',
        'Title',
        'Schedule',
        'CreatedAt',
        'UpdatedAt',
      ];
      for (final (c, header) in headers.indexed) {
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0))
            .value = TextCellValue(
          header,
        );
      }
      final values = <CellValue>[
        TextCellValue('s1'),
        TextCellValue('habit'),
        TextCellValue('Read'),
        TextCellValue('{"type":"daily"}'),
        const DateTimeCellValue(
          year: 2024,
          month: 3,
          day: 9,
          hour: 8,
          minute: 30,
        ),
        const DateTimeCellValue(
          year: 2024,
          month: 3,
          day: 9,
          hour: 8,
          minute: 30,
        ),
      ];
      for (final (c, value) in values.indexed) {
        sheet
                .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 1))
                .value =
            value;
      }
      excel.delete('Sheet1');
      final workbook = excel.encode()!;
      final zip = Archive()
        ..addFile(
          ArchiveFile(ArchivePaths.workbook, workbook.length, workbook),
        );
      await importer.apply(
        readArchive(Uint8List.fromList(ZipEncoder().encode(zip)!)),
      );
      final row = await (target.select(
        target.commitments,
      )..where((c) => c.uuid.equals('s1'))).getSingle();
      expect(HarvestDay.of(row.createdAt), HarvestDay.parse('2024-03-09'));
    });
  });

  test('the whole phone still comes across, streaks and all', () async {
    final gallery = GalleryRepository(source, sourceStorage);
    await gallery.createAlbum(name: 'Face');
    await FinancesRepository(
      source,
    ).log(amountMinor: 300, category: 'food');
    final preview = await importer.apply(readArchive(await archiveBytes()));
    expect(preview.tables[SheetNames.albums]!.added, 1);
    expect(preview.tables[SheetNames.expenses]!.added, 1);
    expect(preview.tables.containsKey(SheetNames.streaks), isTrue);
  });
}
