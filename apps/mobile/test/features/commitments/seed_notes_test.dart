import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/commitments/data/commitments_repository.dart';
import 'package:harvest/features/commitments/data/seed_notes_repository.dart';
import 'package:harvest/features/commitments/domain/commitment.dart';
import 'package:harvest/features/commitments/domain/schedule.dart';
import 'package:harvest/features/commitments/domain/seed_note_rules.dart';

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

  group('one note per seed-day (Q6-07)', () {
    test('two saves at once make one note', () async {
      await Future.wait([
        notes.write(commitmentUuid: book.uuid, day: monday, body: 'a'),
        notes.write(commitmentUuid: book.uuid, day: monday, body: 'b'),
      ]);
      expect(await db.select(db.seedNotes).get(), hasLength(1));
    });

    test('two notes from two devices: the newest reads, and the next save '
        'folds them into one', () async {
      Future<void> put(String uuid, String body, DateTime at) => db
          .into(db.seedNotes)
          .insert(
            SeedNotesCompanion.insert(
              uuid: uuid,
              commitmentUuid: book.uuid,
              harvestDay: monday.key,
              body: body,
              updatedAt: Value(at),
            ),
          );
      await put('a', 'from the phone', DateTime(2026, 9, 7, 10));
      await put('b', 'from the web', DateTime(2026, 9, 7, 11));
      expect((await notes.noteOn(book.uuid, monday))!.body, 'from the web');
      expect(await notes.watchFor(book.uuid).first, hasLength(1));

      await notes.write(commitmentUuid: book.uuid, day: monday, body: 'both');
      final rows = await db.select(db.seedNotes).get();
      expect(rows.map((r) => (r.uuid, r.body)), [('b', 'both')]);
      final sent = await db.select(db.outbox).get();
      expect(
        sent.where((e) => e.rowUuid == 'a').map((e) => e.op),
        contains('delete'),
      );
    });

    final fixture = jsonDecode(
      File(
        '../../packages/core/fixtures/seed-notes.json',
      ).readAsStringSync(),
    ) as Map<String, dynamic>;
    for (final c in (fixture['cases'] as List).cast<Map<String, dynamic>>()) {
      test('core/seed-notes.json: ${c['why']}', () {
        final rows = [
          for (final r in (c['rows'] as List).cast<Map<String, dynamic>>())
            if (r['commitmentUuid'] == c['seed'] && r['harvestDay'] == c['day'])
              SeedNoteRow(
                uuid: r['uuid'] as String,
                commitmentUuid: r['commitmentUuid'] as String,
                harvestDay: r['harvestDay'] as String,
                body: '',
                loggedAt: DateTime(2026),
                updatedAt: DateTime.parse(r['updatedAt'] as String),
                deletedAt: DateTime.tryParse(r['deletedAt'] as String? ?? ''),
              ),
        ];
        final found = seedNoteOfDay(rows);
        expect(found.note?.uuid, c['note']);
        expect(
          found.extras.map((r) => r.uuid).toSet(),
          (c['extras'] as List).toSet(),
        );
      });
    }
  });
}
