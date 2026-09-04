import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/commitments/data/commitments_repository.dart';
import 'package:harvest/features/commitments/data/seed_notes_repository.dart';
import 'package:harvest/features/commitments/domain/commitment.dart';
import 'package:harvest/features/commitments/domain/schedule.dart';

/// Checkpoint C3-7: one note per seed per Harvest Day. Today opens
/// blank, yesterday's is still readable, and writing twice on the same
/// day edits rather than stacking.
void main() {
  late HarvestDatabase db;
  late SeedNotesRepository notes;
  late CommitmentsRepository commitments;
  late Commitment book;

  final monday = HarvestDay.parse('2026-09-07');

  setUp(() async {
    db = HarvestDatabase.forTesting(NativeDatabase.memory());
    notes = SeedNotesRepository(db);
    commitments = CommitmentsRepository(db);
    book = await commitments.create(
      type: CommitmentType.habit,
      title: 'Read',
      schedule: const DailySchedule(),
      createdAt: DateTime(2026),
    );
  });

  tearDown(() => db.close());

  test('a day with no note has none', () async {
    expect(await notes.noteOn(book.uuid, monday), isNull);
  });

  test('writing twice on one day edits the same note', () async {
    await notes.write(commitmentUuid: book.uuid, day: monday, body: 'p. 40');
    await notes.write(commitmentUuid: book.uuid, day: monday, body: 'p. 61');

    final today = await notes.noteOn(book.uuid, monday);
    expect(today!.body, 'p. 61');
    expect(await notes.watchFor(book.uuid).first, hasLength(1));
  });

  test('each day keeps its own note, newest first', () async {
    await notes.write(commitmentUuid: book.uuid, day: monday, body: 'p. 40');
    await notes.write(
      commitmentUuid: book.uuid,
      day: monday.next,
      body: 'p. 78',
    );

    final all = await notes.watchFor(book.uuid).first;
    expect(all.map((n) => n.body), ['p. 78', 'p. 40']);
    // Yesterday's is what the sheet quotes when today's is still blank.
    expect(await notes.noteOn(book.uuid, monday.next.next), isNull);
    expect(all.first.day, monday.next);
  });

  test('an empty body removes the note rather than storing nothing', () async {
    await notes.write(commitmentUuid: book.uuid, day: monday, body: 'p. 40');
    await notes.write(commitmentUuid: book.uuid, day: monday, body: '   ');
    expect(await notes.noteOn(book.uuid, monday), isNull);
  });

  test('a note longer than the cap is trimmed, not refused', () async {
    await notes.write(
      commitmentUuid: book.uuid,
      day: monday,
      body: 'x' * (SeedNotesRepository.maxLength + 200),
    );
    final stored = await notes.noteOn(book.uuid, monday);
    expect(stored!.body.length, SeedNotesRepository.maxLength);
  });

  test('every write queues an outbox row for the future sync', () async {
    await notes.write(commitmentUuid: book.uuid, day: monday, body: 'p. 40');
    await notes.write(commitmentUuid: book.uuid, day: monday, body: 'p. 61');
    final rows = await (db.select(
      db.outbox,
    )..where((o) => o.targetTable.equals('seed_notes'))).get();
    expect(rows.map((r) => r.op), ['insert', 'update']);
  });
}
