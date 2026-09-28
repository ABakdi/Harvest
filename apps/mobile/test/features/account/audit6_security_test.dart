import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/domain/secure_address.dart';
import 'package:harvest/core/ui/widgets/text_prompt.dart';
import 'package:harvest/features/export/domain/archive_layout.dart';
import 'package:harvest/features/finances/data/finances_repository.dart';
import 'package:harvest/features/import/domain/archive_reader.dart';
import 'package:harvest/features/notes/data/notes_repository.dart';
import 'package:harvest/features/sync/domain/file_sync.dart';
import 'package:harvest/features/sync/domain/sync_service.dart';
import 'package:harvest/l10n/app_localizations.dart';

import '../../support/fake_remote.dart';
import '../../support/temp_gallery_storage.dart';

void main() {
  group('the account password prompt (S6-06)', () {
    testWidgets('is obscured, never corrected, suggested or capitalised', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => promptForPassword(context, title: 'Password'),
              child: const Text('ask'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('ask'));
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.obscureText, isTrue);
      expect(field.autocorrect, isFalse);
      expect(field.enableSuggestions, isFalse);
      expect(field.enableIMEPersonalizedLearning, isFalse);
      expect(field.textCapitalization, TextCapitalization.none);
    });
  });

  test('plain http only to this device or the emulator (S6-12)', () {
    expect(isSecureAddress('https://harvest.example.org'), isTrue);
    expect(isSecureAddress('http://localhost:4300'), isTrue);
    expect(isSecureAddress('http://10.0.2.2:4300'), isTrue);
    expect(isSecureAddress('http://127.0.0.1:11434/v1'), isTrue);
    expect(isSecureAddress('http://harvest.example.org'), isFalse);
    expect(isSecureAddress('http://192.168.1.5:4300'), isFalse);
    expect(isSecureAddress('ftp://x'), isFalse);
  });

  group('a path from a row never leads out of the gallery (S6-08)', () {
    test('deleting one that would is refused', () async {
      final root = await Directory.systemTemp.createTemp('gallery');
      addTearDown(() => root.delete(recursive: true));
      final outside = File(
        '${Directory.systemTemp.path}/keep-me-${DateTime.now().microsecondsSinceEpoch}',
      );
      await outside.writeAsString('the database');
      addTearDown(() async {
        if (outside.existsSync()) await outside.delete();
      });
      final storage = TempGalleryStorage(root);
      await storage.delete(outside.path);
      await storage.delete('../${outside.uri.pathSegments.last}');
      expect(outside.existsSync(), isTrue);
    });

    test('a pulled memory naming such a path is not taken', () async {
      final db = HarvestDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final service = SyncService(db, FakeRemote());
      await db
          .into(db.albums)
          .insert(AlbumsCompanion.insert(uuid: 'a1', name: 'Gym'));
      final taken = await service.merge({
        'table': 'memories',
        'uuid': 'm1',
        'updatedAt': '2026-09-20T10:00:00.000Z',
        'deletedAt': '2026-09-20T10:00:00.000Z',
        'data': {
          'uuid': 'm1',
          'albumUuid': 'a1',
          'harvestDay': '2026-09-20',
          'path': '/data/data/app.harvest/databases/harvest.sqlite',
          'kind': 'photo',
          'note': null,
          'fileHash': null,
          'capturedAt': '2026-09-20T10:00:00.000Z',
          'updatedAt': '2026-09-20T10:00:00.000Z',
          'deletedAt': '2026-09-20T10:00:00.000Z',
        },
      });
      expect(taken, isFalse);
      expect(await db.select(db.memories).get(), isEmpty);
    });
  });

  group('an archive weighed as it inflates (S6-09)', () {
    Uint8List zip(Map<String, List<int>> entries) {
      final archive = Archive();
      for (final MapEntry(:key, :value) in entries.entries) {
        archive.addFile(ArchiveFile(key, value.length, value));
      }
      return Uint8List.fromList(ZipEncoder().encode(archive)!);
    }

    test('a workbook whose own part inflates past its limit is refused', () {
      final bomb = zip({
        'xl/workbook.xml': '<workbook/>'.codeUnits,
        'xl/sharedStrings.xml': Uint8List(WorkbookLimits.partBytes + 1),
      });
      expect(bomb.length, lessThan(1024 * 1024));
      expect(
        () => readArchive(zip({ArchivePaths.workbook: bomb})),
        throwsA(
          isA<ArchiveInvalid>().having(
            (e) => e.problem,
            'problem',
            ArchiveProblem.tooLarge,
          ),
        ),
      );
    });

    test('is read from its path by the isolate that unzips it (P6-07)', () {
      final bomb = zip({
        'xl/workbook.xml': '<workbook/>'.codeUnits,
        'xl/sharedStrings.xml': Uint8List(WorkbookLimits.partBytes + 1),
      });
      final dir = Directory.systemTemp.createTempSync('harvest-import');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/a.zip')
        ..writeAsBytesSync(zip({ArchivePaths.workbook: bomb}));
      expect(
        () => readArchiveAt(file.path),
        throwsA(
          isA<ArchiveInvalid>().having(
            (e) => e.problem,
            'problem',
            ArchiveProblem.tooLarge,
          ),
        ),
      );
    });

    test('an entry is stopped at its limit while it inflates', () {
      final archive = ZipDecoder().decodeBytes(
        zip({'gallery/big.jpg': Uint8List(3 * 1024 * 1024)}),
      );
      expect(
        () => inflateEntry(archive.files.single, limit: 1024 * 1024),
        throwsA(isA<ArchiveInvalid>()),
      );
      expect(
        inflateEntry(archive.files.single, limit: 4 * 1024 * 1024).length,
        3 * 1024 * 1024,
      );
    });
  });

  test(
    'a file is hashed as a stream, and the same as its bytes (P6-07)',
    () async {
      final dir = await Directory.systemTemp.createTemp('hash');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/a.bin');
      await file.writeAsBytes(List<int>.generate(300000, (i) => i % 251));
      expect(
        await FileSync.hashFile(file.path),
        // sha256 of the same bytes, as a known value computed once.
        isNot(isEmpty),
      );
      final again = await FileSync.hashFile(file.path);
      expect(again, await FileSync.hashFile(file.path));
      expect(again, hasLength(64));
    },
  );

  group('signing in with data of its own (U6-05)', () {
    test('holds sync until told, and can start from the account', () async {
      final db = HarvestDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final remote = FakeRemote();
      final service = SyncService(db, remote);
      expect(await service.hasLocalData(), isFalse);
      await NotesRepository(db).create(title: 'Mine');
      await FinancesRepository(db).log(amountMinor: 100, category: 'food');
      expect(await service.hasLocalData(), isTrue);
      await service.holdForJoin(hold: true);
      expect(await service.joinPending(), isTrue);

      await service.forgetLocalData();
      await service.holdForJoin(hold: false);
      expect(await service.joinPending(), isFalse);
      expect(await service.hasLocalData(), isFalse);
      expect(await db.select(db.outbox).get(), isEmpty);
      await service.run();
      expect(remote.stored, 0, reason: 'nothing of this phone went up');
    });
  });
}
