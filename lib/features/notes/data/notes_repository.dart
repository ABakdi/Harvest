import 'package:drift/drift.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/db/database_provider.dart';
import 'package:harvest/features/notes/domain/note.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

part 'notes_repository.g.dart';

/// The notes vault (schema v10).
///
/// The body is the source of truth: every write re-derives the link
/// index from it, so `note_links` can be thrown away and rebuilt
/// without losing anything (rule N2).
class NotesRepository {
  NotesRepository(this._db);

  final HarvestDatabase _db;
  static const _uuid = Uuid();

  /// Long enough for a note, short enough that a runaway paste cannot
  /// fill the database.
  static const maxBody = 100000;
  static const maxTitle = 200;

  // ---------------------------------------------------------------- reads

  Stream<List<Note>> watchAll() {
    final query = _db.select(_db.notes)
      ..where((n) => n.deletedAt.isNull())
      ..orderBy([(n) => OrderingTerm.desc(n.updatedAt)]);
    return query.watch().map((rows) => rows.map(_toDomain).toList());
  }

  Stream<Note?> watchOne(String uuid) {
    final query = _db.select(_db.notes)
      ..where((n) => n.uuid.equals(uuid) & n.deletedAt.isNull());
    return query.watchSingleOrNull().map(
      (row) => row == null ? null : _toDomain(row),
    );
  }

  Future<Note?> byTitle(String title) async {
    final row =
        await (_db.select(_db.notes)..where(
              (n) => n.title.equals(title) & n.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  /// Every folder that has a note in it, plus their parents, sorted.
  Stream<List<String>> watchFolders() => watchAll().map((notes) {
    final folders = <String>{};
    for (final note in notes) {
      if (note.folder.isEmpty) continue;
      final parts = note.folder.split('/');
      for (var i = 1; i <= parts.length; i++) {
        folders.add(parts.take(i).join('/'));
      }
    }
    return folders.toList()..sort();
  });

  /// The notes that link *here* — "what links here", as a list.
  Stream<List<Note>> watchBacklinks(String uuid) {
    final links = _db.select(_db.noteLinks)
      ..where((l) => l.toUuid.equals(uuid));
    return links.watch().asyncMap((rows) async {
      if (rows.isEmpty) return <Note>[];
      final from = rows.map((r) => r.fromUuid).toSet().toList();
      final notes =
          await (_db.select(_db.notes)..where(
                (n) => n.uuid.isIn(from) & n.deletedAt.isNull(),
              ))
              .get();
      return notes.map(_toDomain).toList();
    });
  }

  /// The `[[links]]` this note makes, resolved where possible.
  Stream<List<({String title, String? uuid})>> watchOutgoing(String uuid) {
    final query = _db.select(_db.noteLinks)
      ..where((l) => l.fromUuid.equals(uuid));
    return query.watch().map(
      (rows) => [
        for (final row in rows) (title: row.toTitle, uuid: row.toUuid),
      ],
    );
  }

  // --------------------------------------------------------------- writes

  Future<Note> create({
    String title = '',
    String folder = '',
    String body = '',
  }) async {
    final now = DateTime.now();
    final note = Note(
      uuid: _uuid.v4(),
      title: _capTitle(title),
      folder: folder,
      body: _capBody(body),
      createdAt: now,
      updatedAt: now,
    );
    await _db.transaction(() async {
      await _db
          .into(_db.notes)
          .insert(
            NotesCompanion.insert(
              uuid: note.uuid,
              title: note.title,
              folder: Value(note.folder),
              body: Value(note.body),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      await _appendOutbox(note.uuid, 'insert');
      await _reindex(note.uuid, note.body);
      // A note that has just been created may be what a dozen other
      // notes were already pointing at.
      await _resolveInbound(note.title, note.uuid);
    });
    return note;
  }

  Future<void> update(
    String uuid, {
    String? title,
    String? folder,
    String? body,
  }) => _db.transaction(() async {
    final before =
        await (_db.select(_db.notes)..where((n) => n.uuid.equals(uuid)))
            .getSingleOrNull();
    if (before == null) return;
    final now = DateTime.now();
    await (_db.update(_db.notes)..where((n) => n.uuid.equals(uuid))).write(
      NotesCompanion(
        title: title == null ? const Value.absent() : Value(_capTitle(title)),
        folder: folder == null ? const Value.absent() : Value(folder),
        body: body == null ? const Value.absent() : Value(_capBody(body)),
        updatedAt: Value(now),
      ),
    );
    await _appendOutbox(uuid, 'update');
    if (body != null) await _reindex(uuid, _capBody(body));
    if (title != null && title != before.title) {
      // Renaming a note re-points what pointed at the old title and
      // picks up whatever was waiting on the new one.
      await (_db.update(_db.noteLinks)
            ..where((l) => l.toUuid.equals(uuid)))
          .write(const NoteLinksCompanion(toUuid: Value(null)));
      await _resolveInbound(_capTitle(title), uuid);
    }
  });

  /// Soft delete, like every other row that is history. The links that
  /// pointed here go back to unresolved rather than vanishing, so the
  /// note that made them still shows the link it wrote.
  Future<void> remove(String uuid) => _db.transaction(() async {
    await (_db.update(_db.notes)..where((n) => n.uuid.equals(uuid))).write(
      NotesCompanion(
        deletedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );
    await (_db.update(_db.noteLinks)..where((l) => l.toUuid.equals(uuid)))
        .write(const NoteLinksCompanion(toUuid: Value(null)));
    await _appendOutbox(uuid, 'delete');
  });

  Future<void> restore(String uuid) => _db.transaction(() async {
    final row =
        await (_db.select(_db.notes)..where((n) => n.uuid.equals(uuid)))
            .getSingleOrNull();
    if (row == null) return;
    await (_db.update(_db.notes)..where((n) => n.uuid.equals(uuid))).write(
      NotesCompanion(
        deletedAt: const Value(null),
        updatedAt: Value(DateTime.now()),
      ),
    );
    await _resolveInbound(row.title, uuid);
    await _appendOutbox(uuid, 'update');
  });

  Future<void> purgeDeleted({required Duration olderThan}) async {
    final cutoff = DateTime.now().subtract(olderThan);
    await _db.transaction(() async {
      final gone =
          await (_db.select(_db.notes)
                ..where((n) => n.deletedAt.isSmallerThanValue(cutoff)))
              .get();
      for (final row in gone) {
        await (_db.delete(
          _db.noteLinks,
        )..where((l) => l.fromUuid.equals(row.uuid))).go();
      }
      await (_db.delete(
        _db.notes,
      )..where((n) => n.deletedAt.isSmallerThanValue(cutoff))).go();
    });
  }

  /// Rebuilds the link index for one note from its body.
  Future<void> _reindex(String uuid, String body) async {
    await (_db.delete(_db.noteLinks)..where((l) => l.fromUuid.equals(uuid)))
        .go();
    final seen = <String>{};
    for (final link in linksIn(body)) {
      if (!seen.add(link.title.toLowerCase())) continue;
      final target = await byTitle(link.title);
      await _db
          .into(_db.noteLinks)
          .insert(
            NoteLinksCompanion.insert(
              uuid: _uuid.v4(),
              fromUuid: uuid,
              toTitle: link.title,
              toUuid: Value(target?.uuid),
            ),
          );
    }
  }

  /// Points every unresolved link with this title at [uuid].
  Future<void> _resolveInbound(String title, String uuid) async {
    await (_db.update(_db.noteLinks)
          ..where((l) => l.toTitle.equals(title) & l.toUuid.isNull()))
        .write(NoteLinksCompanion(toUuid: Value(uuid)));
  }

  /// Throws the whole index away and builds it again from the bodies.
  /// Rule N2 says this must always be possible; the importer uses it.
  Future<void> reindexAll() async {
    final rows = await (_db.select(
      _db.notes,
    )..where((n) => n.deletedAt.isNull())).get();
    await _db.transaction(() async {
      await _db.delete(_db.noteLinks).go();
      for (final row in rows) {
        await _reindex(row.uuid, row.body);
      }
    });
  }

  static String _capTitle(String title) {
    final trimmed = title.trim();
    return trimmed.length > maxTitle
        ? trimmed.substring(0, maxTitle)
        : trimmed;
  }

  static String _capBody(String body) =>
      body.length > maxBody ? body.substring(0, maxBody) : body;

  Future<void> _appendOutbox(String rowUuid, String op) => _db
      .into(_db.outbox)
      .insert(
        OutboxCompanion.insert(
          targetTable: 'notes',
          rowUuid: rowUuid,
          op: op,
        ),
      );

  static Note _toDomain(NoteRow row) => Note(
    uuid: row.uuid,
    title: row.title,
    folder: row.folder,
    body: row.body,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
  );
}

@Riverpod(keepAlive: true)
NotesRepository notesRepository(Ref ref) =>
    NotesRepository(ref.watch(databaseProvider));
