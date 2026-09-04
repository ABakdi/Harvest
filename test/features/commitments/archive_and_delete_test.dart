import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/commitments/data/commitments_repository.dart';
import 'package:harvest/features/commitments/data/seed_notes_repository.dart';
import 'package:harvest/features/commitments/domain/check_in_service.dart';
import 'package:harvest/features/commitments/domain/commitment.dart';
import 'package:harvest/features/commitments/domain/schedule.dart';
import 'package:harvest/features/gamification/domain/streak_service.dart';

/// Checkpoints C3-4 and C3-5: the two ways a seed can leave the field.
///
/// Archiving is the ordinary one and keeps every row, with a note saying
/// why. Deleting is the mistake path and keeps nothing — the one place
/// the app is allowed to break the append-only rule, because the row
/// should never have existed.
void main() {
  late HarvestDatabase db;
  late CommitmentsRepository repo;
  late SeedNotesRepository notes;
  late CheckInService checkIns;
  late Commitment seed;

  final day = HarvestDay.parse('2026-09-07');

  setUp(() async {
    db = HarvestDatabase.forTesting(NativeDatabase.memory());
    repo = CommitmentsRepository(db);
    notes = SeedNotesRepository(db);
    checkIns = CheckInService(db, StreakService(db));
    seed = await repo.create(
      type: CommitmentType.habit,
      title: 'Read',
      schedule: const DailySchedule(),
      createdAt: DateTime(2026),
    );
    await checkIns.checkIn(seed, day: day);
    await notes.write(commitmentUuid: seed.uuid, day: day, body: 'p. 40');
  });

  tearDown(() => db.close());

  Future<int> count<T extends Table, R>(TableInfo<T, R> table) async =>
      (await db.select(table).get()).length;

  group('archive', () {
    test('keeps the history and records why', () async {
      await repo.archive(seed.uuid, note: 'Finished the book');

      final archived = await repo.watchArchived().first;
      expect(archived.single.title, 'Read');
      expect(archived.single.archiveNote, 'Finished the book');
      expect(archived.single.archivedAt, isNotNull);
      expect(await count(db.checkIns), 1);
      expect(await count(db.seedNotes), 1);
      // It is off the field, not gone.
      expect(await repo.watchActive().first, isEmpty);
    });

    test('a note is optional', () async {
      await repo.archive(seed.uuid);
      expect((await repo.watchArchived().first).single.archiveNote, isNull);
    });

    test('restoring puts it back and clears the note', () async {
      await repo.archive(seed.uuid, note: 'Paused for the summer');
      await repo.restore(seed.uuid);

      expect(await repo.watchArchived().first, isEmpty);
      final active = await repo.watchActive().first;
      expect(active.single.uuid, seed.uuid);
      expect(active.single.archiveNote, isNull);
    });
  });

  group('hard delete', () {
    test('takes the seed, its check-ins, its notes and its streak', () async {
      expect(await count(db.streaks), greaterThan(0));

      await repo.hardDelete(seed.uuid);

      expect(await count(db.commitments), 0);
      expect(await count(db.checkIns), 0);
      expect(await count(db.seedNotes), 0);
      final streaks = await db.select(db.streaks).get();
      expect(streaks.where((s) => s.scope == seed.uuid), isEmpty);
    });

    test('leaves a focus session behind, detached from the seed', () async {
      await db
          .into(db.pomodoroSessions)
          .insert(
            PomodoroSessionsCompanion.insert(
              uuid: 'focus-1',
              commitmentUuid: Value(seed.uuid),
              harvestDay: day.key,
              startedAt: day.startsAt,
            ),
          );

      await repo.hardDelete(seed.uuid);

      final session = (await db.select(db.pomodoroSessions).get()).single;
      expect(session.commitmentUuid, isNull);
    });

    test('tells the future sync the row is gone', () async {
      await repo.hardDelete(seed.uuid);
      final rows = await (db.select(
        db.outbox,
      )..where((o) => o.rowUuid.equals(seed.uuid))).get();
      expect(rows.last.op, 'delete');
    });
  });
}
