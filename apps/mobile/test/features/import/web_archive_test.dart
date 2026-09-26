import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/db/built_in_lists.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/features/export/data/export_repository.dart';
import 'package:harvest/features/export/domain/archive_service.dart';
import 'package:harvest/features/export/domain/harvest_workbook.dart';
import 'package:harvest/features/gallery/data/gallery_storage.dart';
import 'package:harvest/features/import/domain/archive_reader.dart';
import 'package:harvest/features/import/domain/import_service.dart';
import 'package:harvest/features/notes/data/note_attachments.dart';
import 'package:path/path.dart' as p;

import '../../support/temp_gallery_storage.dart';

/// The archive is one format on two clients (Business Rules #11,
/// ADR-007): a zip the web wrote comes back into a phone, and a zip a
/// phone wrote goes into the web.
///
/// `packages/contracts/fixtures/archive/web.zip` is written by the
/// web's own exporter (its vitest suite checks the file still matches
/// what it writes); `phone.zip` is written here, on request, with
/// `HARVEST_WRITE_FIXTURES=1`, and the web's suite imports it.
const _fixtures = '../../packages/contracts/fixtures/archive';

void main() {
  late HarvestDatabase db;
  late Directory root;
  late GalleryStorage storage;
  late AttachmentStorage attachments;

  setUp(() async {
    db = HarvestDatabase.forTesting(NativeDatabase.memory());
    root = await Directory.systemTemp.createTemp('harvest-web-archive');
    storage = TempGalleryStorage(Directory(p.join(root.path, 'gallery')));
    attachments = AttachmentStorage(documents: () async => root);
  });

  tearDown(() async {
    await db.close();
    if (root.existsSync()) await root.delete(recursive: true);
  });

  group('an archive the web wrote', () {
    Future<ImportPreview> importWeb() async {
      final bytes = File('$_fixtures/web.zip').readAsBytesSync();
      return ImportService(db, storage, attachments).apply(readArchive(bytes));
    }

    test('opens, and every sheet the phone writes is in it', () {
      final bundle = readArchive(File('$_fixtures/web.zip').readAsBytesSync());
      for (final sheet in harvestSheets(_empty()).skip(1)) {
        expect(bundle.sheets.containsKey(sheet.name), isTrue, reason: sheet.name);
      }
    });

    test('comes into an empty phone, rows and files both', () async {
      final preview = await importWeb();
      expect(totalOf(preview).added, greaterThan(10));

      final seed = await (db.select(
        db.commitments,
      )..where((t) => t.uuid.equals('seed-1'))).getSingle();
      expect(seed.title, 'Read 20 pages');
      expect(seed.scheduleJson, '{"type":"daily"}');
      expect(seed.updatedAt.toUtc(), DateTime.utc(2026, 9, 18, 8));

      // The trash comes across as the trash.
      final gone = await (db.select(
        db.checkIns,
      )..where((t) => t.uuid.equals('check-2'))).getSingle();
      expect(gone.deletedAt, isNotNull);

      final expense = await (db.select(
        db.expenses,
      )..where((t) => t.uuid.equals('expense-1'))).getSingle();
      expect(expense.amountMinor, 125050);
      expect(expense.currency, 'DZD');

      final note = await (db.select(
        db.notes,
      )..where((t) => t.uuid.equals('note-1'))).getSingle();
      expect(note.body, contains('![[2026-09-18 0712.m4a]]'));
      expect(note.folder, 'Health');

      final memory = await (db.select(
        db.memories,
      )..where((t) => t.uuid.equals('memory-1'))).getSingle();
      final picture = await storage.fileOf(memory.path);
      expect(picture.existsSync(), isTrue);
      expect(picture.readAsBytesSync(), hasLength(64));

      final recording = await (db.select(
        db.noteAttachments,
      )..where((t) => t.uuid.equals('rec-1'))).getSingle();
      expect(recording.storedPath, 'note-1/2026-09-18 0712.m4a');
      expect(
        (await attachments.fileOf(recording.storedPath)).existsSync(),
        isTrue,
      );

      final set = await (db.select(
        db.workoutSets,
      )..where((t) => t.uuid.equals('set-1'))).getSingle();
      expect(set.done, isTrue);
      expect(set.weightGrams, 60000);

      final place = await (db.select(
        db.savedPlaces,
      )..where((t) => t.uuid.equals('place-1'))).getSingle();
      expect(place.latitude, closeTo(36.7525, 1e-9));
      expect(place.notes, 'The good bench is by the window');

      final category = await (db.select(
        db.expenseCategories,
      )..where((t) => t.uuid.equals('cat-1'))).getSingle();
      expect(category.createdAt, isNotNull);
      expect(category.createdAt, category.updatedAt);

      final keys = {
        for (final row in await db.select(db.kvSettings).get()) row.key,
      };
      expect(keys, contains('themeMode'));

      // Lists: the web's own list, and a media item with every field.
      final list = await (db.select(
        db.lists,
      )..where((t) => t.uuid.equals('list-1'))).getSingle();
      expect((list.name, list.kind), ('Packing', 'plain'));
      final book = await (db.select(
        db.wishlistItems,
      )..where((t) => t.uuid.equals('read-1'))).getSingle();
      expect(book.listUuid, BuiltInList.read.uuid);
      expect(book.mediaType, 'book');
      expect(book.creator, 'Ursula K. Le Guin');
      expect(book.rating, 5);
      expect(book.startedAt, isNotNull);
    });

    test('a second import of it changes nothing', () async {
      await importWeb();
      final again = await importWeb();
      expect(totalOf(again).added, 0);
      expect(totalOf(again).updated, 0);
    });
  });

  test(
    'the phone fixture still has the headers this phone writes',
    () async {
      final file = File('$_fixtures/phone.zip');
      if (Platform.environment['HARVEST_WRITE_FIXTURES'] == '1') {
        await _seed(db, storage, attachments);
        final bytes = await ArchiveService(
          ExportRepository(db),
          storage,
          attachments,
        ).build(now: DateTime.utc(2026, 9, 19, 12));
        file.parent.createSync(recursive: true);
        file.writeAsBytesSync(bytes);
      }
      final bundle = readArchive(file.readAsBytesSync());
      for (final sheet in harvestSheets(_empty()).skip(1)) {
        final rows = bundle.sheet(sheet.name);
        expect(rows, isNotEmpty, reason: '${sheet.name} has a row to check');
        // Read by header: every stored header is one the sheet carries.
        final seen = {for (final row in rows) ...row.keys};
        expect(
          sheet.headers.toSet().containsAll(seen),
          isTrue,
          reason: '${sheet.name}: $seen',
        );
      }
    },
  );
}

ExportData _empty() => (
  generatedAt: DateTime.utc(2026),
  seeds: const [],
  checkIns: const [],
  seedNotes: const [],
  goals: const [],
  goalItems: const [],
  lists: const [],
  wishlistItems: const [],
  expenses: const [],
  categories: const [],
  money: const [],
  debts: const [],
  debtPayments: const [],
  focus: const [],
  ledger: const [],
  streaks: const [],
  settings: const [],
  notes: const [],
  noteAttachments: const [],
  albums: const [],
  memories: const [],
  steps: const [],
  weights: const [],
  sleep: const [],
  exercises: const [],
  programs: const [],
  programDays: const [],
  programSlots: const [],
  targetSets: const [],
  trainingMaxes: const [],
  sessions: const [],
  sessionExercises: const [],
  sets: const [],
  savedPlaces: const [],
  locationPoints: const [],
  geotags: const [],
);

/// One row in every sheet, so the web's suite has something to read
/// back from each.
Future<void> _seed(
  HarvestDatabase db,
  GalleryStorage storage,
  AttachmentStorage attachments,
) async {
  final at = DateTime.utc(2026, 9, 18, 8);
  final later = DateTime.utc(2026, 9, 18, 9, 30);
  await db
      .into(db.commitments)
      .insert(
        CommitmentsCompanion.insert(
          uuid: 'p-seed-1',
          type: 'habit',
          title: 'Walk after lunch',
          scheduleJson: const Value('{"type":"daily"}'),
          createdAt: Value(at),
          updatedAt: Value(later),
        ),
      );
  await db
      .into(db.checkIns)
      .insert(
        CheckInsCompanion.insert(
          uuid: 'p-check-1',
          commitmentUuid: 'p-seed-1',
          harvestDay: '2026-09-18',
          loggedAt: Value(at),
          updatedAt: Value(at),
        ),
      );
  await db
      .into(db.checkIns)
      .insert(
        CheckInsCompanion.insert(
          uuid: 'p-check-2',
          commitmentUuid: 'p-seed-1',
          harvestDay: '2026-09-17',
          loggedAt: Value(at),
          updatedAt: Value(later),
          deletedAt: Value(later),
        ),
      );
  await db
      .into(db.seedNotes)
      .insert(
        SeedNotesCompanion.insert(
          uuid: 'p-seednote-1',
          commitmentUuid: 'p-seed-1',
          harvestDay: '2026-09-18',
          body: 'Slow one',
          loggedAt: Value(at),
          updatedAt: Value(at),
        ),
      );
  await db
      .into(db.goals)
      .insert(
        GoalsCompanion.insert(
          uuid: 'p-goal-1',
          title: 'Run 10k',
          createdAt: Value(at),
          updatedAt: Value(at),
        ),
      );
  await db
      .into(db.goalItems)
      .insert(
        GoalItemsCompanion.insert(
          uuid: 'p-item-1',
          goalUuid: 'p-goal-1',
          body: 'Shoes',
          kind: const Value('need'),
          createdAt: Value(at),
          updatedAt: Value(at),
        ),
      );
  await db
      .into(db.wishlistItems)
      .insert(
        WishlistItemsCompanion.insert(
          uuid: 'p-wish-1',
          title: 'Kettlebell',
          priceMinor: const Value(450000),
          listUuid: Value(BuiltInList.buy.uuid),
          createdAt: Value(at),
          updatedAt: Value(at),
        ),
      );
  await db
      .into(db.lists)
      .insert(
        ListsCompanion.insert(
          uuid: 'p-list-1',
          name: 'Podcasts',
          kind: const Value('media'),
          icon: const Value('headphones'),
          position: const Value(4),
          createdAt: Value(at),
          updatedAt: Value(at),
        ),
      );
  await db
      .into(db.wishlistItems)
      .insert(
        WishlistItemsCompanion.insert(
          uuid: 'p-read-1',
          title: 'Dune',
          list: const Value('wish'),
          listUuid: Value(BuiltInList.read.uuid),
          mediaType: const Value('book'),
          link: const Value('https://example.com/dune'),
          creator: const Value('Frank Herbert'),
          startedAt: Value(at),
          rating: const Value(4),
          seedUuid: const Value('p-seed-1'),
          noteUuid: const Value('p-note-1'),
          boughtAt: Value(at),
          createdAt: Value(at),
          updatedAt: Value(at),
        ),
      );
  await db
      .into(db.expenses)
      .insert(
        ExpensesCompanion.insert(
          uuid: 'p-expense-1',
          harvestDay: '2026-09-18',
          category: 'food',
          amountMinor: 35000,
          note: const Value('Lunch'),
          loggedAt: Value(at),
          updatedAt: Value(at),
        ),
      );
  await db
      .into(db.expenseCategories)
      .insert(
        ExpenseCategoriesCompanion.insert(
          uuid: 'p-cat-1',
          name: 'Books',
          icon: 'book',
          createdAt: Value(at),
          updatedAt: Value(at),
        ),
      );
  await db
      .into(db.moneyTxns)
      .insert(
        MoneyTxnsCompanion.insert(
          uuid: 'p-money-1',
          harvestDay: '2026-09-18',
          account: 'wallet',
          deltaMinor: 500000,
          loggedAt: Value(at),
          updatedAt: Value(at),
        ),
      );
  await db
      .into(db.debts)
      .insert(
        DebtsCompanion.insert(
          uuid: 'p-debt-1',
          person: 'Karim',
          amountMinor: 100000,
          createdAt: Value(at),
          updatedAt: Value(at),
        ),
      );
  await db
      .into(db.debtPayments)
      .insert(
        DebtPaymentsCompanion.insert(
          uuid: 'p-pay-1',
          debtUuid: 'p-debt-1',
          harvestDay: '2026-09-18',
          amountMinor: 20000,
          loggedAt: Value(at),
        ),
      );
  await db
      .into(db.pomodoroSessions)
      .insert(
        PomodoroSessionsCompanion.insert(
          uuid: 'p-focus-1',
          commitmentUuid: const Value('p-seed-1'),
          harvestDay: '2026-09-18',
          focusBlocks: const Value(2),
          startedAt: at,
          endedAt: Value(later),
        ),
      );
  await db
      .into(db.ledger)
      .insert(
        LedgerCompanion.insert(
          uuid: 'p-xp-1',
          kind: 'xp',
          delta: 10,
          reason: 'check_in:p-check-1',
          harvestDay: '2026-09-18',
          loggedAt: Value(at),
        ),
      );
  await db
      .into(db.streaks)
      .insert(
        StreaksCompanion.insert(
          scope: 'global',
          current: const Value(3),
          best: const Value(5),
          lastEarnedDay: const Value('2026-09-18'),
          updatedAt: Value(at),
        ),
      );
  await db
      .into(db.kvSettings)
      .insert(
        KvSettingsCompanion.insert(
          key: 'themeMode',
          valueJson: '"dark"',
          updatedAt: Value(at),
        ),
      );
  await db
      .into(db.notes)
      .insert(
        NotesCompanion.insert(
          uuid: 'p-note-1',
          title: 'Sleep log',
          folder: const Value('Health'),
          body: const Value('Slept well.\n\n![[2026-09-18 0600.m4a]]\n'),
          createdAt: Value(at),
          updatedAt: Value(at),
        ),
      );
  final recording = await attachments.reserve('p-note-1', '2026-09-18 0600.m4a');
  await recording.file.writeAsBytes(List.filled(32, 7));
  await db
      .into(db.noteAttachments)
      .insert(
        NoteAttachmentsCompanion.insert(
          uuid: 'p-rec-1',
          noteUuid: 'p-note-1',
          fileName: '2026-09-18 0600.m4a',
          storedPath: recording.relative,
          durationMs: const Value(4000),
          sizeBytes: const Value(32),
          createdAt: Value(at),
          updatedAt: Value(at),
        ),
      );
  await db
      .into(db.albums)
      .insert(
        AlbumsCompanion.insert(
          uuid: 'p-album-1',
          name: 'Gym',
          createdAt: Value(at),
          updatedAt: Value(at),
        ),
      );
  const picturePath = 'p-album-1/2026-09-18-p-memory.jpg';
  await storage.write(List.filled(48, 9), picturePath);
  await db
      .into(db.memories)
      .insert(
        MemoriesCompanion.insert(
          uuid: 'p-memory-1',
          albumUuid: 'p-album-1',
          harvestDay: '2026-09-18',
          path: picturePath,
          note: const Value('After'),
          capturedAt: Value(at),
          updatedAt: Value(at),
        ),
      );
  await db
      .into(db.stepDays)
      .insert(
        StepDaysCompanion.insert(
          harvestDay: '2026-09-18',
          steps: const Value(8042),
          updatedAt: Value(at),
        ),
      );
  await db
      .into(db.bodyWeights)
      .insert(
        BodyWeightsCompanion.insert(
          uuid: 'p-weight-1',
          harvestDay: '2026-09-18',
          grams: 74500,
          measuredAt: Value(at),
          updatedAt: Value(at),
        ),
      );
  await db
      .into(db.sleepSessions)
      .insert(
        SleepSessionsCompanion.insert(
          uuid: 'p-sleep-1',
          harvestDay: '2026-09-17',
          fellAsleepAt: DateTime.utc(2026, 9, 17, 22),
          wokeAt: DateTime.utc(2026, 9, 18, 6),
          targetMinutes: 480,
          restedStars: const Value(4),
          createdAt: Value(at),
          updatedAt: Value(at),
        ),
      );
  await db
      .into(db.exercises)
      .insert(
        ExercisesCompanion.insert(
          uuid: 'p-ex-1',
          name: 'Tempo squat',
          createdAt: Value(at),
          updatedAt: Value(at),
        ),
      );
  await db
      .into(db.programs)
      .insert(
        ProgramsCompanion.insert(
          uuid: 'p-program-1',
          name: 'Three days',
          createdAt: Value(at),
          updatedAt: Value(at),
        ),
      );
  await db
      .into(db.programDays)
      .insert(
        ProgramDaysCompanion.insert(
          uuid: 'p-day-1',
          programUuid: 'p-program-1',
          name: 'A',
          position: 0,
        ),
      );
  await db
      .into(db.programSlots)
      .insert(
        ProgramSlotsCompanion.insert(
          uuid: 'p-slot-1',
          dayUuid: 'p-day-1',
          exerciseId: 'p-ex-1',
          position: 0,
        ),
      );
  await db
      .into(db.targetSets)
      .insert(
        TargetSetsCompanion.insert(
          uuid: 'p-target-1',
          slotUuid: 'p-slot-1',
          position: 0,
          reps: const Value(5),
          openEnded: const Value(true),
        ),
      );
  await db
      .into(db.trainingMaxes)
      .insert(
        TrainingMaxesCompanion.insert(
          programUuid: 'p-program-1',
          exerciseId: 'p-ex-1',
          grams: 100000,
          updatedAt: Value(at),
        ),
      );
  await db
      .into(db.workoutSessions)
      .insert(
        WorkoutSessionsCompanion.insert(
          uuid: 'p-session-1',
          programUuid: const Value('p-program-1'),
          dayUuid: const Value('p-day-1'),
          harvestDay: '2026-09-18',
          startedAt: Value(at),
          endedAt: Value(later),
          updatedAt: Value(later),
        ),
      );
  await db
      .into(db.sessionExercises)
      .insert(
        SessionExercisesCompanion.insert(
          uuid: 'p-se-1',
          sessionUuid: 'p-session-1',
          position: 0,
          exerciseId: 'p-ex-1',
          slotUuid: const Value('p-slot-1'),
        ),
      );
  await db
      .into(db.workoutSets)
      .insert(
        WorkoutSetsCompanion.insert(
          uuid: 'p-set-1',
          sessionExerciseUuid: 'p-se-1',
          position: 0,
          weightGrams: const Value(80000),
          reps: const Value(5),
          done: const Value(true),
          loggedAt: Value(at),
        ),
      );
  await db
      .into(db.savedPlaces)
      .insert(
        SavedPlacesCompanion.insert(
          uuid: 'p-place-1',
          name: 'Gym',
          latitude: 36.7525,
          longitude: 3.04197,
          notes: const Value('Opens at six'),
          createdAt: Value(at),
          updatedAt: Value(at),
        ),
      );
  await db
      .into(db.locationPoints)
      .insert(
        LocationPointsCompanion.insert(
          uuid: 'p-point-1',
          harvestDay: '2026-09-18',
          recordedAt: at,
          latitude: 36.7525,
          longitude: 3.04197,
          accuracyM: const Value(8.5),
          updatedAt: Value(at),
        ),
      );
  await db
      .into(db.geotags)
      .insert(
        GeotagsCompanion.insert(
          uuid: 'p-geo-1',
          targetTable: 'expenses',
          targetUuid: 'p-expense-1',
          harvestDay: '2026-09-18',
          at: at,
          latitude: const Value(36.7525),
          longitude: const Value(3.04197),
          state: const Value('fixed'),
          updatedAt: Value(at),
        ),
      );
}
