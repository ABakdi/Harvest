import 'package:drift/drift.dart';
import 'package:harvest/core/db/built_in_lists.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/db/database_provider.dart';
import 'package:harvest/core/db/portable_settings.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/export/domain/harvest_workbook.dart';
import 'package:harvest/features/gallery/data/gallery_storage.dart';
import 'package:harvest/features/goals/data/goals_repository.dart';
import 'package:harvest/features/import/domain/archive_reader.dart';
import 'package:harvest/features/notes/data/note_attachments.dart';
import 'package:harvest/features/notes/data/notes_repository.dart';
import 'package:harvest/features/notes/domain/note.dart';
import 'package:harvest/features/sync/domain/sync_service.dart' show SyncKeys;
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'import_service.g.dart';
part 'import_tables.dart';

/// What an import would do to one table.
typedef ImportCount = ({int added, int updated, int unchanged});

/// What an import would do, in full, before anything is written.
typedef ImportPreview = ({
  Map<String, ImportCount> tables,

  /// Files in the archive, and how many are not on this phone yet.
  int files,
  int newFiles,

  /// Files the archive holds that were too large to take in, left out
  /// rather than refusing the archive (Q5-06).
  int skippedFiles,
});

/// A totals row for the preview, so a screen does not have to add up.
ImportCount totalOf(ImportPreview preview) {
  var added = 0;
  var updated = 0;
  var unchanged = 0;
  for (final count in preview.tables.values) {
    added += count.added;
    updated += count.updated;
    unchanged += count.unchanged;
  }
  return (added: added, updated: updated, unchanged: unchanged);
}

/// Which table each sheet fills, for the change log.
const Map<String, String> _syncedTables = {
  SheetNames.seeds: 'commitments',
  SheetNames.checkIns: 'check_ins',
  SheetNames.seedNotes: 'seed_notes',
  SheetNames.goals: 'goals',
  SheetNames.goalItems: 'goal_items',
  SheetNames.lists: 'lists',
  SheetNames.wishlist: 'wishlist_items',
  SheetNames.expenses: 'expenses',
  SheetNames.categories: 'expense_categories',
  SheetNames.money: 'money_txns',
  SheetNames.debts: 'debts',
  SheetNames.debtPayments: 'debt_payments',
  SheetNames.focus: 'pomodoro_sessions',
  SheetNames.ledger: 'ledger',
  SheetNames.streaks: 'streaks',
  SheetNames.notes: 'notes',
  SheetNames.noteAttachments: 'note_attachments',
  SheetNames.albums: 'albums',
  SheetNames.steps: 'step_days',
  SheetNames.weights: 'body_weights',
  SheetNames.sleep: 'sleep_sessions',
  SheetNames.exercises: 'exercises',
  SheetNames.programs: 'programs',
  SheetNames.programDays: 'program_days',
  SheetNames.programSlots: 'program_slots',
  SheetNames.targetSets: 'target_sets',
  SheetNames.trainingMaxes: 'training_maxes',
  SheetNames.sessions: 'workout_sessions',
  SheetNames.sessionExercises: 'session_exercises',
  SheetNames.sets: 'workout_sets',
  SheetNames.settings: 'kv_settings',
  SheetNames.savedPlaces: 'saved_places',
  SheetNames.locationPoints: 'location_points',
  SheetNames.geotags: 'geotags',
};

/// One row of a sheet, keyed by header.
typedef _Row = Map<String, String>;

/// Merges a Harvest archive back into the database.
///
/// Three rules, all from ADR-007 and none of them negotiable:
///
/// * **Merge by uuid.** A row already here is updated only when the
///   incoming copy is newer.
/// * **Nothing local is deleted for being missing.** An archive is a
///   second copy, not an authority.
/// * **Previewed first.** [preview] and [apply] read the same archive
///   the same way, so what was shown is what happens.
///
/// And a fourth, from the second audit: **an archive is data, never
/// instructions.** It does not choose where a file goes, which
/// bookkeeping the app believes, or how much memory it may have.
class ImportService {
  ImportService(this._db, this._storage, this._attachments);

  final HarvestDatabase _db;
  final GalleryStorage _storage;
  final AttachmentStorage _attachments;

  /// What [bundle] would change, without changing it.
  Future<ImportPreview> preview(ArchiveBundle bundle) =>
      _run(bundle, write: false);

  /// Carries the merge out. Every table is its own transaction, so a
  /// failure part-way leaves whole tables rather than half of one.
  Future<ImportPreview> apply(ArchiveBundle bundle) async {
    final result = await _run(bundle, write: true);
    // The link index is derived from the bodies (rule N2), so it is
    // rebuilt rather than imported.
    await NotesRepository(_db).reindexAll();
    // A parent's tick is drawn from its subtasks (GL3), whichever copy
    // of each the merge kept (Q5-44).
    await GoalsRepository(_db).settleAllParents();
    return result;
  }

  Future<ImportPreview> _run(
    ArchiveBundle bundle, {
    required bool write,
  }) async {
    final tables = <String, ImportCount>{};
    _bodies = _noteBodies(bundle);

    // Parents before children: an album before its memories, a seed
    // before its check-ins, or a foreign key refuses the row. The list
    // is in that order.
    final int newFiles;
    try {
      newFiles = await _mergeAll(bundle, tables, write: write);
    } finally {
      _bodies = const {};
    }

    if (write && bundle.files.isNotEmpty) {
      // Restored files already carry their names, and a name is not a
      // file the server has: the next file pass asks about all of them.
      await _db
          .into(_db.kvSettings)
          .insertOnConflictUpdate(
            KvSettingsCompanion.insert(
              key: SyncKeys.checkFiles,
              valueJson: '"true"',
            ),
          );
    }
    return (
      tables: tables,
      files: bundle.files.length,
      newFiles: newFiles,
      skippedFiles: bundle.skipped,
    );
  }

  /// The `.md` files the notes sheet points at, decoded once.
  static Map<String, String> _noteBodies(ArchiveBundle bundle) {
    final bodies = <String, String>{};
    for (final row in bundle.sheet(SheetNames.notes)) {
      final file = row['File'];
      if (file == null) continue;
      final body = bundle.noteBody(file);
      if (body != null) bodies[file] = body;
    }
    return bodies;
  }

  /// Every sheet, in order. Returns how many files are new to this
  /// phone, for the preview.
  Future<int> _mergeAll(
    ArchiveBundle bundle,
    Map<String, ImportCount> tables, {
    required bool write,
  }) async {
    var newFiles = 0;
    for (final table in _tables) {
      tables[table.sheet] = await _mergeRows(
        table,
        bundle.sheet(table.sheet),
        write: write,
      );
      if (table.sheet == SheetNames.notes) {
        // Recordings carry a file each, so, like memories, they are
        // merged by hand, right after the notes they belong to.
        final attachments = await _mergeAttachments(bundle, write: write);
        tables[SheetNames.noteAttachments] = attachments.count;
        newFiles += attachments.newFiles;
      }
      if (table.sheet == SheetNames.albums) {
        // Memories carry a file each, so they are merged by hand: the
        // picture has to land in storage before the row can point at
        // it. They sit here, right after their albums.
        final memories = await _mergeMemories(bundle, write: write);
        tables[SheetNames.memories] = memories.count;
        newFiles += memories.newFiles;
      }
    }
    return newFiles;
  }

  /// Merge one sheet. Counts what it would do whether or not [write].
  Future<ImportCount> _mergeRows(
    _Table table,
    SheetRows rows, {
    required bool write,
  }) async {
    var added = 0;
    var updated = 0;
    var unchanged = 0;
    final pending = <_Row>[];
    final local = await table.localStamps(_db);

    for (final row in rows) {
      final key = table.keyOf(row);
      if (key == null || key.isEmpty) continue;
      if (table.accept != null && !table.accept!(row)) {
        unchanged++;
        continue;
      }
      final stamp = local[key];
      if (stamp == null) {
        added++;
        pending.add(row);
        continue;
      }
      final column = table.stampColumn;
      final incoming = column == null ? null : _time(row[column]);
      // Same timestamp is not newer: an archive taken from this phone
      // and put straight back must be a no-op.
      if (incoming != null && incoming.isAfter(stamp)) {
        updated++;
        pending.add(row);
      } else {
        unchanged++;
      }
    }

    if (write && pending.isNotEmpty) {
      await _db.transaction(() async {
        for (final row in pending) {
          await table.insert(_db, row);
          // An imported row is a change like any other: sync must hear
          // of it ([[Audit-v2]] Q3-01).
          final synced = _syncedTables[table.sheet];
          final key = table.keyOf(row);
          if (synced != null && key != null) {
            await _db.logChange(synced, key, 'update');
          }
        }
      });
    }
    return (added: added, updated: updated, unchanged: unchanged);
  }

  /// Memories, and the files behind them.
  Future<({ImportCount count, int newFiles})> _mergeMemories(
    ArchiveBundle bundle, {
    required bool write,
  }) async {
    final local = {
      for (final row in await _db.select(_db.memories).get())
        row.uuid: row.updatedAt,
    };

    var added = 0;
    var updated = 0;
    var unchanged = 0;
    var newFiles = 0;
    final pending = <(_Row, Uint8List?)>[];

    for (final row in bundle.sheet(SheetNames.memories)) {
      final uuid = row['Uuid'];
      if (uuid == null || uuid.isEmpty) continue;
      final bytes = bundle.files[row['File'] ?? ''];
      final at = local[uuid];
      if (at == null) {
        added++;
        if (bytes != null) newFiles++;
        pending.add((row, bytes));
        continue;
      }
      final incoming = _time(row['UpdatedAt']);
      if (incoming != null && incoming.isAfter(at)) {
        updated++;
        pending.add((row, bytes));
      } else {
        unchanged++;
      }
    }

    if (write) {
      // The files land first, then the rows that point at them, and
      // the rows go in together. A failure part-way can leave a file
      // nothing references — an orphan, which costs space and nothing
      // else — but never a row pointing at a picture that is not there.
      final written = <(_Row, String)>[];
      for (final (row, bytes) in pending) {
        var path = _destinationFor(row);
        if (bytes != null && path.isNotEmpty) {
          path = await _storage.write(bytes, path);
        }
        written.add((row, path));
      }
      await _db.transaction(() async {
        for (final (row, path) in written) {
          await _db
              .into(_db.memories)
              .insertOnConflictUpdate(
                MemoriesCompanion.insert(
                  uuid: row['Uuid']!,
                  albumUuid: row['AlbumUuid'] ?? '',
                  harvestDay: row['HarvestDay'] ?? '',
                  path: path,
                  kind: Value(row['Kind'] ?? 'photo'),
                  note: Value(row['Note']),
                  fileHash: Value(row['FileHash']),
                  capturedAt: Value(_time(row['CapturedAt']) ?? DateTime.now()),
                  updatedAt: Value(_time(row['UpdatedAt']) ?? DateTime.now()),
                  deletedAt: Value(_time(row['DeletedAt'])),
                ),
              );
          // Like every other restored row, it travels (Q5-05).
          await _db.logChange('memories', row['Uuid']!, 'update');
        }
      });
    }

    return (
      count: (added: added, updated: updated, unchanged: unchanged),
      newFiles: newFiles,
    );
  }

  /// Recordings, and the files behind them ([[Notes]] N7).
  ///
  /// The archive's `File` column is only ever a key into the zip; where
  /// the file lands is decided here, from the note's uuid and the name
  /// the body embeds, both made safe first. `StoredPath` is not read at
  /// all: every recording lives at `<noteUuid>/<fileName>`, so there is
  /// nothing an archive could usefully say about it.
  Future<({ImportCount count, int newFiles})> _mergeAttachments(
    ArchiveBundle bundle, {
    required bool write,
  }) async {
    final rows = await _db.select(_db.noteAttachments).get();
    final local = {for (final row in rows) row.uuid: row.updatedAt};
    // The file name is unique, because it is how an embed finds its
    // file. A name already answering for another recording stays with
    // the one this phone has; the incoming one is left out rather than
    // made to break the constraint and take the whole table with it.
    final owners = {for (final row in rows) row.fileName: row.uuid};

    var added = 0;
    var updated = 0;
    var unchanged = 0;
    var newFiles = 0;
    final pending = <({_Row row, String name, Uint8List? bytes})>[];

    for (final row in bundle.sheet(SheetNames.noteAttachments)) {
      final uuid = row['Uuid'];
      final note = row['NoteUuid'];
      if (uuid == null || uuid.isEmpty || note == null || note.isEmpty) {
        continue;
      }
      final name = _attachmentName(row);
      final owner = owners[name];
      if (owner != null && owner != uuid) {
        unchanged++;
        continue;
      }
      var bytes = bundle.files[row['File'] ?? ''];
      if (bytes != null && bytes.length > ArchiveLimits.entryBytes) {
        bytes = null;
      }
      final at = local[uuid];
      if (at == null) {
        added++;
        if (bytes != null) newFiles++;
        owners[name] = uuid;
        pending.add((row: row, name: name, bytes: bytes));
        continue;
      }
      final incoming = _time(row['UpdatedAt']);
      if (incoming != null && incoming.isAfter(at)) {
        updated++;
        owners[name] = uuid;
        pending.add((row: row, name: name, bytes: bytes));
      } else {
        unchanged++;
      }
    }

    if (write) {
      // Files first, then the rows, for the same reason as memories: an
      // orphaned file costs space, a row pointing at nothing costs the
      // recording.
      final written = <({_Row row, String name, String path, int? size})>[];
      for (final (:row, :name, :bytes) in pending) {
        final folder = _safeSegment(row['NoteUuid']!);
        final path = p.posix.join(folder, name);
        if (bytes != null && GalleryStorage.isSafeRelative(path)) {
          final reserved = await _attachments.reserve(folder, name);
          await _attachments.write(reserved.relative, bytes);
        }
        written.add((row: row, name: name, path: path, size: bytes?.length));
      }
      await _db.transaction(() async {
        for (final (:row, :name, :path, :size) in written) {
          await _db
              .into(_db.noteAttachments)
              .insertOnConflictUpdate(
                NoteAttachmentsCompanion.insert(
                  uuid: row['Uuid']!,
                  noteUuid: row['NoteUuid']!,
                  kind: Value(row['Kind'] ?? 'audio'),
                  fileName: name,
                  storedPath: path,
                  durationMs: Value(_int(row['DurationMs'])),
                  sizeBytes: Value(size ?? _int(row['SizeBytes']) ?? 0),
                  fileHash: Value(row['FileHash']),
                  createdAt: Value(_time(row['CreatedAt']) ?? _now()),
                  updatedAt: Value(_time(row['UpdatedAt']) ?? _now()),
                  deletedAt: Value(_time(row['DeletedAt'])),
                ),
              );
          await _db.logChange('note_attachments', row['Uuid']!, 'update');
        }
      });
    }

    return (
      count: (added: added, updated: updated, unchanged: unchanged),
      newFiles: newFiles,
    );
  }

  /// The name a recording is kept under: the one its row gives, when
  /// that is a plain file name, and made into one when it is not. A
  /// name with a slash or a `..` in it is a path, and an archive does
  /// not get to name a path on this phone.
  static String _attachmentName(_Row row) {
    final given = row['FileName']?.trim() ?? '';
    final name = given.isEmpty ? '' : safeFileName(given);
    if (name.isNotEmpty && name != 'untitled' && !name.startsWith('.')) {
      return name;
    }
    return '${_safeSegment(row['Uuid'] ?? 'recording')}'
        '${_extensionOf(row['File'] ?? '', fallback: '.m4a')}';
  }

  /// Where a memory's file lands on this phone.
  ///
  /// The row's own `StoredPath` is honoured when it is a plain relative
  /// path inside the gallery, because restoring a file at the path the
  /// row already names is what makes an archive taken from this phone
  /// and put back a no-op rather than a second copy of everything.
  /// Anything else — `..`, an absolute path, an empty cell — is not a
  /// place this app will write to, and the destination is regenerated
  /// from the row the way a fresh capture's would be
  /// ([[Audit-v2-Beta]] S2-01). The archive names its pictures; it
  /// does not name my files.
  String _destinationFor(_Row row) {
    final stored = row['StoredPath'] ?? '';
    if (GalleryStorage.isSafeRelative(stored)) return stored;
    final day = HarvestDay.tryParse(row['HarvestDay']) ?? HarvestDay.today();
    return _storage.pathFor(
      albumUuid: _safeSegment(row['AlbumUuid'] ?? 'album'),
      day: day,
      extension: _extensionOf(row['File'] ?? stored),
      uuid: _safeSegment(row['Uuid'] ?? 'memory').padRight(8, '0'),
    );
  }

  /// One path segment, with nothing in it that could make it two.
  static String _safeSegment(String value) {
    final cleaned = value.replaceAll(RegExp('[^A-Za-z0-9_-]'), '');
    return cleaned.isEmpty ? 'x' : cleaned;
  }

  static String _extensionOf(String path, {String fallback = '.jpg'}) {
    final extension = p.extension(path).toLowerCase();
    final plain = RegExp(r'^\.[a-z0-9]{1,4}$').hasMatch(extension);
    return plain ? extension : fallback;
  }

  /// The note bodies of the archive being merged, by path — filled in
  /// by [_run] before the notes table's turn and cleared after, since
  /// the descriptors are static and the bundle is not.
  static Map<String, String> _bodies = const {};
}

@Riverpod(keepAlive: true)
ImportService importService(Ref ref) => ImportService(
  ref.watch(databaseProvider),
  ref.watch(galleryStorageProvider),
  ref.watch(attachmentStorageProvider),
);
