import 'package:drift/drift.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/db/database_provider.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/commitments/domain/seed_note.dart';
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

  /// Every note on a seed, newest day first.
  Stream<List<SeedNote>> watchFor(String commitmentUuid) {
    final query = _db.select(_db.seedNotes)
      ..where(
        (n) => n.commitmentUuid.equals(commitmentUuid) & n.deletedAt.isNull(),
      )
      ..orderBy([(n) => OrderingTerm.desc(n.harvestDay)]);
    return query.watch().map(
      (rows) => rows.map(_toDomain).nonNulls.toList(),
    );
  }

  /// Every note written on [day] — what the field's cards show.
  Stream<List<SeedNote>> watchNotesOn(HarvestDay day) {
    final query = _db.select(_db.seedNotes)
      ..where((n) => n.harvestDay.equals(day.key) & n.deletedAt.isNull());
    return query.watch().map(
      (rows) => rows.map(_toDomain).nonNulls.toList(),
    );
  }

  Future<SeedNote?> noteOn(String commitmentUuid, HarvestDay day) async {
    final row =
        await (_db.select(_db.seedNotes)..where(
              (n) =>
                  n.commitmentUuid.equals(commitmentUuid) &
                  n.harvestDay.equals(day.key) &
                  n.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  /// Writes [body] as the note for [day]; an empty body removes it.
  Future<void> write({
    required String commitmentUuid,
    required HarvestDay day,
    required String body,
  }) async {
    final trimmed = body.trim();
    final capped = trimmed.length > maxLength
        ? trimmed.substring(0, maxLength)
        : trimmed;
    final existing = await noteOn(commitmentUuid, day);
    await _db.transaction(() async {
      if (capped.isEmpty) {
        if (existing == null) return;
        await (_db.delete(
          _db.seedNotes,
        )..where((n) => n.uuid.equals(existing.uuid))).go();
        await _appendOutbox(existing.uuid, 'delete');
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

  Future<void> delete(String uuid) => _db.transaction(() async {
    await (_db.delete(_db.seedNotes)..where((n) => n.uuid.equals(uuid))).go();
    await _appendOutbox(uuid, 'delete');
  });

  Future<void> _appendOutbox(String rowUuid, String op) => _db
      .into(_db.outbox)
      .insert(
        OutboxCompanion.insert(
          targetTable: 'seed_notes',
          rowUuid: rowUuid,
          op: op,
        ),
      );

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
