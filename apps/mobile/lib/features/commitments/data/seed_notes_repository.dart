import 'package:drift/drift.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/db/database_provider.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/commitments/domain/seed_note.dart';
import 'package:harvest/features/commitments/domain/seed_note_rules.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

part 'seed_notes_repository.g.dart';

/// The day-keyed notes on a seed (schema v9).
///
/// One row per seed per Harvest Day: writing today's note twice edits
/// it rather than stacking duplicates, and a new day always opens on a
/// blank one.
class SeedNotesRepository {
  SeedNotesRepository(this._db);

  final HarvestDatabase _db;
  static const _uuid = Uuid();

  /// The longest a note may be — the same cap the seed's own note has.
  static const maxLength = 500;

  /// Every note on a seed, newest day first: one per day.
  Stream<List<SeedNote>> watchFor(String commitmentUuid) {
    final query = _db.select(_db.seedNotes)
      ..where(
        (n) => n.commitmentUuid.equals(commitmentUuid) & n.deletedAt.isNull(),
      )
      ..orderBy([(n) => OrderingTerm.desc(n.harvestDay)]);
    return query.watch().map(
      (rows) => oneNotePerDay(rows).map(_toDomain).nonNulls.toList(),
    );
  }

  /// Every note written on [day] — what the field's cards show; one per
  /// seed.
  Stream<List<SeedNote>> watchNotesOn(HarvestDay day) {
    final query = _db.select(_db.seedNotes)
      ..where((n) => n.harvestDay.equals(day.key) & n.deletedAt.isNull());
    return query.watch().map(
      (rows) => oneNotePerDay(rows).map(_toDomain).nonNulls.toList(),
    );
  }

  Future<SeedNote?> noteOn(String commitmentUuid, HarvestDay day) async {
    final row = seedNoteOfDay(await _rowsOn(commitmentUuid, day)).note;
    return row == null ? null : _toDomain(row);
  }

  Future<List<SeedNoteRow>> _rowsOn(String commitmentUuid, HarvestDay day) =>
      (_db.select(_db.seedNotes)..where(
            (n) =>
                n.commitmentUuid.equals(commitmentUuid) &
                n.harvestDay.equals(day.key) &
                n.deletedAt.isNull(),
          ))
          .get();

  /// Writes [body] as the note for [day]; an empty body removes it.
  ///
  /// Read and written in one transaction, so two quick saves cannot both
  /// find no note and make two. A day that already has two (written on
  /// two devices before they met) keeps the newest, which takes this
  /// body, and the others go ([[Audit-v3]] Q6-07).
  Future<void> write({
    required String commitmentUuid,
    required HarvestDay day,
    required String body,
  }) {
    final trimmed = body.trim();
    final capped = trimmed.length > maxLength
        ? trimmed.substring(0, maxLength)
        : trimmed;
    return _db.transaction(() async {
      final found = seedNoteOfDay(await _rowsOn(commitmentUuid, day));
      for (final extra in found.extras) {
        await _remove(extra.uuid);
      }
      final existing = found.note;
      if (capped.isEmpty) {
        if (existing != null) await _remove(existing.uuid);
        return;
      }
      if (existing != null) {
        await (_db.update(
          _db.seedNotes,
        )..where((n) => n.uuid.equals(existing.uuid))).write(
          SeedNotesCompanion(
            body: Value(capped),
            updatedAt: Value(DateTime.now()),
          ),
        );
        await _appendOutbox(existing.uuid, 'update');
        return;
      }
      final uuid = _uuid.v4();
      await _db
          .into(_db.seedNotes)
          .insert(
            SeedNotesCompanion.insert(
              uuid: uuid,
              commitmentUuid: commitmentUuid,
              harvestDay: day.key,
              body: capped,
            ),
          );
      await _appendOutbox(uuid, 'insert');
    });
  }

  Future<void> _remove(String uuid) async {
    await (_db.delete(_db.seedNotes)..where((n) => n.uuid.equals(uuid))).go();
    await _appendOutbox(uuid, 'delete');
  }

  Future<void> delete(String uuid) => _db.transaction(() async {
    await (_db.delete(_db.seedNotes)..where((n) => n.uuid.equals(uuid))).go();
    await _appendOutbox(uuid, 'delete');
  });

  Future<void> _appendOutbox(String rowUuid, String op) =>
      _db.logChange('seed_notes', rowUuid, op);

  static SeedNote? _toDomain(SeedNoteRow row) {
    final day = HarvestDay.tryParse(row.harvestDay);
    if (day == null) return null;
    return SeedNote(
      uuid: row.uuid,
      commitmentUuid: row.commitmentUuid,
      day: day,
      body: row.body,
      loggedAt: row.loggedAt,
    );
  }
}

@Riverpod(keepAlive: true)
SeedNotesRepository seedNotesRepository(Ref ref) =>
    SeedNotesRepository(ref.watch(databaseProvider));
