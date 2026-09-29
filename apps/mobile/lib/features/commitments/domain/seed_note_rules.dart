import 'package:harvest/core/db/database.dart';

/// One note per seed per Harvest Day ([[Audit-v3]] Q6-07): the newest
/// write is the day's note, a tie going to the greater uuid so every
/// device picks the same, and the others are extras to fold away. The
/// same rule as `packages/core/src/seed-notes.ts`, held to
/// `fixtures/seed-notes.json`.
bool _newer(SeedNoteRow a, SeedNoteRow b) {
  final diff = a.updatedAt.compareTo(b.updatedAt);
  return diff != 0 ? diff > 0 : a.uuid.compareTo(b.uuid) > 0;
}

/// The day's note among [rows] (one seed, one day, live), and the rest.
({SeedNoteRow? note, List<SeedNoteRow> extras}) seedNoteOfDay(
  Iterable<SeedNoteRow> rows,
) {
  SeedNoteRow? note;
  for (final row in rows) {
    if (row.deletedAt != null) continue;
    if (note == null || _newer(row, note)) note = row;
  }
  return (
    note: note,
    extras: [
      for (final row in rows)
        if (row.deletedAt == null && !identical(row, note)) row,
    ],
  );
}

/// The newest note of each seed-day in [rows], live ones only, in the
/// order they came.
List<SeedNoteRow> oneNotePerDay(Iterable<SeedNoteRow> rows) {
  final kept = <String, SeedNoteRow>{};
  final order = <String>[];
  for (final row in rows) {
    if (row.deletedAt != null) continue;
    final key = '${row.commitmentUuid}|${row.harvestDay}';
    final before = kept[key];
    if (before == null) order.add(key);
    if (before == null || _newer(row, before)) kept[key] = row;
  }
  return [for (final key in order) kept[key]!];
}
