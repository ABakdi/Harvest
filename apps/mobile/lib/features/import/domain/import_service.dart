import 'package:drift/drift.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/db/database_provider.dart';
import 'package:harvest/core/db/portable_settings.dart';
import 'package:harvest/core/domain/harvest_day.dart';
import 'package:harvest/features/export/domain/harvest_workbook.dart';
import 'package:harvest/features/gallery/data/gallery_storage.dart';
import 'package:harvest/features/import/domain/archive_reader.dart';
import 'package:harvest/features/notes/data/note_attachments.dart';
import 'package:harvest/features/notes/data/notes_repository.dart';
import 'package:harvest/features/notes/domain/note.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'import_service.g.dart';

/// What an import would do to one table.
typedef ImportCount = ({int added, int updated, int unchanged});

/// What an import would do, in full, before anything is written.
typedef ImportPreview = ({
  Map<String, ImportCount> tables,

  /// Files in the archive, and how many are not on this phone yet.
  int files,
  int newFiles,
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

/// How one sheet merges into one table.
///
/// The importer is this list and one loop over it. It used to be
/// twenty-six hand-written blocks, and the Streaks sheet went missing
/// among them for a whole release ([[Audit-v2-Beta]] B-02, Q2-04);
/// a table that is not in this list is now a sheet the preview
/// visibly ignores, not a silent omission.
class _Table {
  const _Table({
    required this.sheet,
    required this.keyOf,
    required this.localStamps,
    required this.insert,
    this.stampColumn,
    this.accept,
  });

  final String sheet;

  /// The row's identity: a uuid, a scope, a day, a key.
  final String? Function(_Row row) keyOf;

  /// The column that says how new the row is. Null for a child row
  /// that has no timestamp of its own — a target set is not edited, it
  /// is replaced — which is added when missing and otherwise left
  /// alone, the conservative half of the merge rule.
  final String? stampColumn;

  /// Every local row's identity and stamp.
  final Future<Map<String, DateTime>> Function(HarvestDatabase db) localStamps;

  final Future<void> Function(HarvestDatabase db, _Row row) insert;

  /// Rows the archive may not set at all; null accepts every row.
  final bool Function(_Row row)? accept;
}

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

    return (tables: tables, files: bundle.files.length, newFiles: newFiles);
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
          await reserved.file.writeAsBytes(bytes);
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

  // ------------------------------------------------------------ helpers

  static DateTime? _time(String? value) =>
      value == null || value.isEmpty ? null : DateTime.tryParse(value);

  static double? _double(String? value) {
    if (value == null || value.isEmpty) return null;
    return double.tryParse(value);
  }

  static int? _int(String? value) {
    if (value == null || value.isEmpty) return null;
    return int.tryParse(value) ?? double.tryParse(value)?.round();
  }

  /// A spreadsheet writes booleans half a dozen ways, and a person
  /// editing one writes them a seventh. Anything that is not plainly
  /// true is false.
  static bool _bool(String? value) {
    final text = value?.trim().toLowerCase();
    return text == 'true' || text == '1' || text == 'yes';
  }

  /// The stamp for a child row that has none of its own — always older
  /// than anything incoming, so an existing row is never overwritten
  /// by one that cannot prove it is newer.
  static final DateTime _epoch = DateTime.fromMillisecondsSinceEpoch(0);

  static DateTime _now() => DateTime.now();

  static String? _uuid(_Row row) => row['Uuid'];

  /// Every uuid-keyed table's local stamps, from a column of its own.
  static Future<Map<String, DateTime>> _stamps<T extends Table, R>(
    HarvestDatabase db,
    TableInfo<T, R> table,
    String Function(R row) key,
    DateTime Function(R row) stamp,
  ) async => {
    for (final row in await db.select(table).get()) key(row): stamp(row),
  };

  // ------------------------------------------------------------- tables

  /// Sheet by sheet, parents first. A stamp column of `UpdatedAt` is
  /// used wherever the table has one — a soft delete writes
  /// `updated_at` and never `logged_at`, so stamping on the latter let
  /// a deletion lose every merge ([[Audit-v2-Beta]] B-05).
  static final List<_Table> _tables = [
    _Table(
      sheet: SheetNames.seeds,
      keyOf: _uuid,
      stampColumn: 'UpdatedAt',
      localStamps: (db) =>
          _stamps(db, db.commitments, (r) => r.uuid, (r) => r.updatedAt),
      insert: (db, row) => db
          .into(db.commitments)
          .insertOnConflictUpdate(
            CommitmentsCompanion.insert(
              uuid: row['Uuid']!,
              type: row['Type'] ?? 'habit',
              title: row['Title'] ?? '',
              scheduleJson: Value(row['Schedule']),
              totalTarget: Value(_int(row['TotalTarget'])),
              dailyCommitment: Value(_int(row['DailyCommitment'])),
              dueDay: Value(row['DueDay']),
              note: Value(row['Note']),
              remindAt: Value(row['RemindAt']),
              deadline: Value(row['Deadline']),
              goalUuid: Value(row['GoalUuid']),
              pausedAt: Value(_time(row['PausedAt'])),
              archivedAt: Value(_time(row['ArchivedAt'])),
              archiveNote: Value(row['ArchiveNote']),
              deletedAt: Value(_time(row['DeletedAt'])),
              createdAt: Value(_time(row['CreatedAt']) ?? _now()),
              updatedAt: Value(_time(row['UpdatedAt']) ?? _now()),
            ),
          ),
    ),
    _Table(
      sheet: SheetNames.goals,
      keyOf: _uuid,
      stampColumn: 'UpdatedAt',
      localStamps: (db) =>
          _stamps(db, db.goals, (r) => r.uuid, (r) => r.updatedAt),
      insert: (db, row) => db
          .into(db.goals)
          .insertOnConflictUpdate(
            GoalsCompanion.insert(
              uuid: row['Uuid']!,
              title: row['Title'] ?? '',
              why: Value(row['Why'] ?? ''),
              targetDay: Value(row['TargetDay']),
              status: Value(row['Status'] ?? 'active'),
              statusNote: Value(row['StatusNote']),
              achievedAt: Value(_time(row['AchievedAt'])),
              position: Value(_int(row['Position']) ?? 0),
              createdAt: Value(_time(row['CreatedAt']) ?? _now()),
              updatedAt: Value(_time(row['UpdatedAt']) ?? _now()),
              deletedAt: Value(_time(row['DeletedAt'])),
            ),
          ),
    ),
    _Table(
      sheet: SheetNames.goalItems,
      keyOf: _uuid,
      stampColumn: 'UpdatedAt',
      localStamps: (db) =>
          _stamps(db, db.goalItems, (r) => r.uuid, (r) => r.updatedAt),
      insert: (db, row) => db
          .into(db.goalItems)
          .insertOnConflictUpdate(
            GoalItemsCompanion.insert(
              uuid: row['Uuid']!,
              goalUuid: row['GoalUuid'] ?? '',
              kind: Value(row['Kind'] ?? 'step'),
              body: row['Body'] ?? '',
              note: Value(row['Note']),
              doneAt: Value(_time(row['DoneAt'])),
              position: Value(_int(row['Position']) ?? 0),
              commitmentUuid: Value(row['CommitmentUuid']),
              createdAt: Value(_time(row['CreatedAt']) ?? _now()),
              updatedAt: Value(_time(row['UpdatedAt']) ?? _now()),
              deletedAt: Value(_time(row['DeletedAt'])),
            ),
          ),
    ),
    _Table(
      sheet: SheetNames.wishlist,
      keyOf: _uuid,
      stampColumn: 'UpdatedAt',
      localStamps: (db) =>
          _stamps(db, db.wishlistItems, (r) => r.uuid, (r) => r.updatedAt),
      insert: (db, row) => db
          .into(db.wishlistItems)
          .insertOnConflictUpdate(
            WishlistItemsCompanion.insert(
              uuid: row['Uuid']!,
              list: Value(row['List'] ?? 'buy'),
              title: row['Title'] ?? '',
              priceMinor: Value(_int(row['PriceMinor'])),
              currency: Value(row['Currency'] ?? 'DZD'),
              note: Value(row['Note']),
              targetDay: Value(row['TargetDay']),
              boughtAt: Value(_time(row['BoughtAt'])),
              position: Value(_int(row['Position']) ?? 0),
              createdAt: Value(_time(row['CreatedAt']) ?? _now()),
              updatedAt: Value(_time(row['UpdatedAt']) ?? _now()),
              deletedAt: Value(_time(row['DeletedAt'])),
            ),
          ),
    ),
    _Table(
      sheet: SheetNames.checkIns,
      keyOf: _uuid,
      stampColumn: 'UpdatedAt',
      localStamps: (db) =>
          _stamps(db, db.checkIns, (r) => r.uuid, (r) => r.updatedAt),
      insert: (db, row) => db
          .into(db.checkIns)
          .insertOnConflictUpdate(
            CheckInsCompanion.insert(
              uuid: row['Uuid']!,
              commitmentUuid: row['CommitmentUuid'] ?? '',
              harvestDay: row['HarvestDay'] ?? '',
              quantity: Value(_int(row['Quantity']) ?? 1),
              loggedAt: Value(_time(row['LoggedAt']) ?? _now()),
              // An archive from before the column existed carries no
              // UpdatedAt; the row is then as new as it was logged.
              updatedAt: Value(
                _time(row['UpdatedAt']) ?? _time(row['LoggedAt']) ?? _now(),
              ),
              deletedAt: Value(_time(row['DeletedAt'])),
            ),
          ),
    ),
    _Table(
      sheet: SheetNames.seedNotes,
      keyOf: _uuid,
      stampColumn: 'UpdatedAt',
      localStamps: (db) =>
          _stamps(db, db.seedNotes, (r) => r.uuid, (r) => r.updatedAt),
      insert: (db, row) => db
          .into(db.seedNotes)
          .insertOnConflictUpdate(
            SeedNotesCompanion.insert(
              uuid: row['Uuid']!,
              commitmentUuid: row['CommitmentUuid'] ?? '',
              harvestDay: row['HarvestDay'] ?? '',
              body: row['Body'] ?? '',
              loggedAt: Value(_time(row['LoggedAt']) ?? _now()),
              updatedAt: Value(
                _time(row['UpdatedAt']) ?? _time(row['LoggedAt']) ?? _now(),
              ),
              deletedAt: Value(_time(row['DeletedAt'])),
            ),
          ),
    ),
    _Table(
      sheet: SheetNames.expenses,
      keyOf: _uuid,
      stampColumn: 'UpdatedAt',
      localStamps: (db) =>
          _stamps(db, db.expenses, (r) => r.uuid, (r) => r.updatedAt),
      insert: (db, row) => db
          .into(db.expenses)
          .insertOnConflictUpdate(
            ExpensesCompanion.insert(
              uuid: row['Uuid']!,
              harvestDay: row['HarvestDay'] ?? '',
              category: row['Category'] ?? '',
              currency: Value(row['Currency'] ?? 'DZD'),
              amountMinor: _int(row['AmountMinor']) ?? 0,
              note: Value(row['Note']),
              loggedAt: Value(_time(row['LoggedAt']) ?? _now()),
              updatedAt: Value(
                _time(row['UpdatedAt']) ?? _time(row['LoggedAt']) ?? _now(),
              ),
              deletedAt: Value(_time(row['DeletedAt'])),
            ),
          ),
    ),
    // The categories I made, so a restored phone has a name and an icon
    // for every key its expenses use ([[Audit-v2]] Q3-02).
    _Table(
      sheet: SheetNames.categories,
      keyOf: _uuid,
      stampColumn: 'UpdatedAt',
      localStamps: (db) => _stamps(
        db,
        db.expenseCategories,
        (r) => r.uuid,
        (r) => r.updatedAt,
      ),
      insert: (db, row) => db
          .into(db.expenseCategories)
          .insertOnConflictUpdate(
            ExpenseCategoriesCompanion.insert(
              uuid: row['Uuid']!,
              name: row['Name'] ?? '',
              icon: row['Icon'] ?? '',
              // Missing from an archive made before v21; the list then
              // orders it by UpdatedAt, as it always had.
              createdAt: Value(_time(row['CreatedAt'])),
              updatedAt: Value(_time(row['UpdatedAt']) ?? _now()),
              deletedAt: Value(_time(row['DeletedAt'])),
            ),
          ),
    ),
    _Table(
      sheet: SheetNames.money,
      keyOf: _uuid,
      stampColumn: 'UpdatedAt',
      localStamps: (db) =>
          _stamps(db, db.moneyTxns, (r) => r.uuid, (r) => r.updatedAt),
      insert: (db, row) => db
          .into(db.moneyTxns)
          .insertOnConflictUpdate(
            MoneyTxnsCompanion.insert(
              uuid: row['Uuid']!,
              harvestDay: row['HarvestDay'] ?? '',
              account: row['Account'] ?? '',
              kind: Value(row['Kind'] ?? 'manual'),
              reference: Value(row['Reference']),
              currency: Value(row['Currency'] ?? 'DZD'),
              deltaMinor: _int(row['DeltaMinor']) ?? 0,
              note: Value(row['Note']),
              linkUuid: Value(row['LinkUuid']),
              loggedAt: Value(_time(row['LoggedAt']) ?? _now()),
              updatedAt: Value(
                _time(row['UpdatedAt']) ?? _time(row['LoggedAt']) ?? _now(),
              ),
              deletedAt: Value(_time(row['DeletedAt'])),
            ),
          ),
    ),
    _Table(
      sheet: SheetNames.debts,
      keyOf: _uuid,
      stampColumn: 'UpdatedAt',
      localStamps: (db) =>
          _stamps(db, db.debts, (r) => r.uuid, (r) => r.updatedAt),
      insert: (db, row) => db
          .into(db.debts)
          .insertOnConflictUpdate(
            DebtsCompanion.insert(
              uuid: row['Uuid']!,
              person: row['Person'] ?? '',
              currency: Value(row['Currency'] ?? 'DZD'),
              amountMinor: _int(row['AmountMinor']) ?? 0,
              payOffBy: Value(row['PayOffBy']),
              remindAt: Value(row['RemindAt']),
              note: Value(row['Note']),
              settledAt: Value(_time(row['SettledAt'])),
              createdAt: Value(_time(row['CreatedAt']) ?? _now()),
              deletedAt: Value(_time(row['DeletedAt'])),
              updatedAt: Value(_time(row['UpdatedAt']) ?? _now()),
            ),
          ),
    ),
    _Table(
      sheet: SheetNames.debtPayments,
      keyOf: _uuid,
      stampColumn: 'LoggedAt',
      localStamps: (db) =>
          _stamps(db, db.debtPayments, (r) => r.uuid, (r) => r.loggedAt),
      insert: (db, row) => db
          .into(db.debtPayments)
          .insertOnConflictUpdate(
            DebtPaymentsCompanion.insert(
              uuid: row['Uuid']!,
              debtUuid: row['DebtUuid'] ?? '',
              harvestDay: row['HarvestDay'] ?? '',
              amountMinor: _int(row['AmountMinor']) ?? 0,
              loggedAt: Value(_time(row['LoggedAt']) ?? _now()),
              deletedAt: Value(_time(row['DeletedAt'])),
            ),
          ),
    ),
    _Table(
      sheet: SheetNames.focus,
      keyOf: _uuid,
      stampColumn: 'StartedAt',
      localStamps: (db) =>
          _stamps(db, db.pomodoroSessions, (r) => r.uuid, (r) => r.startedAt),
      insert: (db, row) => db
          .into(db.pomodoroSessions)
          .insertOnConflictUpdate(
            PomodoroSessionsCompanion.insert(
              uuid: row['Uuid']!,
              commitmentUuid: Value(row['CommitmentUuid']),
              harvestDay: row['HarvestDay'] ?? '',
              focusBlocks: Value(_int(row['FocusBlocks']) ?? 0),
              startedAt: _time(row['StartedAt']) ?? _now(),
              endedAt: Value(_time(row['EndedAt'])),
            ),
          ),
    ),
    _Table(
      sheet: SheetNames.ledger,
      keyOf: _uuid,
      stampColumn: 'LoggedAt',
      localStamps: (db) =>
          _stamps(db, db.ledger, (r) => r.uuid, (r) => r.loggedAt),
      insert: (db, row) => db
          .into(db.ledger)
          .insertOnConflictUpdate(
            LedgerCompanion.insert(
              uuid: row['Uuid']!,
              kind: row['Kind'] ?? 'xp',
              delta: _int(row['Delta']) ?? 0,
              reason: row['Reason'] ?? '',
              harvestDay: row['HarvestDay'] ?? '',
              loggedAt: Value(_time(row['LoggedAt']) ?? _now()),
            ),
          ),
    ),
    // The streak rows: derived state, but derived from history this
    // phone may not have, so they come across like everything else
    // and the newer copy wins ([[Audit-v2-Beta]] B-02).
    _Table(
      sheet: SheetNames.streaks,
      keyOf: (row) => row['Scope'],
      stampColumn: 'UpdatedAt',
      localStamps: (db) =>
          _stamps(db, db.streaks, (r) => r.scope, (r) => r.updatedAt),
      insert: (db, row) => db
          .into(db.streaks)
          .insertOnConflictUpdate(
            StreaksCompanion.insert(
              scope: row['Scope']!,
              current: Value(_int(row['Current']) ?? 0),
              best: Value(_int(row['Best']) ?? 0),
              lastEarnedDay: Value(row['LastEarnedDay']),
              freezesStored: Value(_int(row['FreezesStored']) ?? 0),
              updatedAt: Value(_time(row['UpdatedAt']) ?? _now()),
            ),
          ),
    ),
    _Table(
      sheet: SheetNames.notes,
      keyOf: _uuid,
      stampColumn: 'UpdatedAt',
      localStamps: (db) =>
          _stamps(db, db.notes, (r) => r.uuid, (r) => r.updatedAt),
      insert: (db, row) => db
          .into(db.notes)
          .insertOnConflictUpdate(
            NotesCompanion.insert(
              uuid: row['Uuid']!,
              title: row['Title'] ?? '',
              folder: Value(row['Folder'] ?? ''),
              // The `.md` in the zip wins over the cell: someone may
              // have edited the vault in a text editor, and rule N4
              // says that has to survive. `_bodies` is filled per run.
              body: Value(_bodies[row['File'] ?? ''] ?? row['Body'] ?? ''),
              createdAt: Value(_time(row['CreatedAt']) ?? _now()),
              updatedAt: Value(_time(row['UpdatedAt']) ?? _now()),
              deletedAt: Value(_time(row['DeletedAt'])),
            ),
          ),
    ),
    _Table(
      sheet: SheetNames.albums,
      keyOf: _uuid,
      stampColumn: 'UpdatedAt',
      localStamps: (db) =>
          _stamps(db, db.albums, (r) => r.uuid, (r) => r.updatedAt),
      insert: (db, row) => db
          .into(db.albums)
          .insertOnConflictUpdate(
            AlbumsCompanion.insert(
              uuid: row['Uuid']!,
              name: row['Name'] ?? '',
              scheduleJson: Value(row['ScheduleJson']),
              remindAt: Value(row['RemindAt']),
              note: Value(row['Note']),
              createdAt: Value(_time(row['CreatedAt']) ?? _now()),
              updatedAt: Value(_time(row['UpdatedAt']) ?? _now()),
              deletedAt: Value(_time(row['DeletedAt'])),
            ),
          ),
    ),
    // (Recordings are merged by hand right after the notes, and
    // memories right after the albums: see _mergeAll.)
    _Table(
      sheet: SheetNames.steps,
      keyOf: (row) => row['HarvestDay'],
      stampColumn: 'UpdatedAt',
      localStamps: (db) =>
          _stamps(db, db.stepDays, (r) => r.harvestDay, (r) => r.updatedAt),
      insert: (db, row) => db
          .into(db.stepDays)
          .insertOnConflictUpdate(
            StepDaysCompanion.insert(
              harvestDay: row['HarvestDay']!,
              steps: Value(_int(row['Steps']) ?? 0),
              lastCounter: Value(_int(row['LastCounter'])),
              updatedAt: Value(_time(row['UpdatedAt']) ?? _now()),
            ),
          ),
    ),
    _Table(
      sheet: SheetNames.weights,
      keyOf: _uuid,
      stampColumn: 'UpdatedAt',
      localStamps: (db) =>
          _stamps(db, db.bodyWeights, (r) => r.uuid, (r) => r.updatedAt),
      insert: (db, row) => db
          .into(db.bodyWeights)
          .insertOnConflictUpdate(
            BodyWeightsCompanion.insert(
              uuid: row['Uuid']!,
              harvestDay: row['HarvestDay'] ?? '',
              grams: _int(row['Grams']) ?? 0,
              note: Value(row['Note']),
              measuredAt: Value(_time(row['MeasuredAt']) ?? _now()),
              updatedAt: Value(
                _time(row['UpdatedAt']) ?? _time(row['MeasuredAt']) ?? _now(),
              ),
              deletedAt: Value(_time(row['DeletedAt'])),
            ),
          ),
    ),
    _Table(
      sheet: SheetNames.sleep,
      keyOf: _uuid,
      stampColumn: 'UpdatedAt',
      localStamps: (db) =>
          _stamps(db, db.sleepSessions, (r) => r.uuid, (r) => r.updatedAt),
      insert: (db, row) => db
          .into(db.sleepSessions)
          .insertOnConflictUpdate(
            SleepSessionsCompanion.insert(
              uuid: row['Uuid']!,
              harvestDay: row['HarvestDay'] ?? '',
              fellAsleepAt: _time(row['FellAsleepAt']) ?? _now(),
              wokeAt: _time(row['WokeAt']) ?? _now(),
              targetMinutes: _int(row['TargetMinutes']) ?? 0,
              restedStars: Value(_int(row['RestedStars'])),
              note: Value(row['Note']),
              createdAt: Value(_time(row['CreatedAt']) ?? _now()),
              updatedAt: Value(_time(row['UpdatedAt']) ?? _now()),
              deletedAt: Value(_time(row['DeletedAt'])),
            ),
          ),
    ),
    _Table(
      sheet: SheetNames.exercises,
      keyOf: _uuid,
      stampColumn: 'UpdatedAt',
      localStamps: (db) =>
          _stamps(db, db.exercises, (r) => r.uuid, (r) => r.updatedAt),
      insert: (db, row) => db
          .into(db.exercises)
          .insertOnConflictUpdate(
            ExercisesCompanion.insert(
              uuid: row['Uuid']!,
              name: row['Name'] ?? '',
              bodyPart: Value(row['BodyPart']),
              equipment: Value(row['Equipment']),
              target: Value(row['Target']),
              note: Value(row['Note']),
              createdAt: Value(_time(row['CreatedAt']) ?? _now()),
              updatedAt: Value(_time(row['UpdatedAt']) ?? _now()),
              deletedAt: Value(_time(row['DeletedAt'])),
            ),
          ),
    ),
    _Table(
      sheet: SheetNames.programs,
      keyOf: _uuid,
      stampColumn: 'UpdatedAt',
      localStamps: (db) =>
          _stamps(db, db.programs, (r) => r.uuid, (r) => r.updatedAt),
      insert: (db, row) => db
          .into(db.programs)
          .insertOnConflictUpdate(
            ProgramsCompanion.insert(
              uuid: row['Uuid']!,
              name: row['Name'] ?? '',
              note: Value(row['Note']),
              weeks: Value(_int(row['Weeks'])),
              commitmentUuid: Value(row['CommitmentUuid']),
              albumUuid: Value(row['AlbumUuid']),
              photoPrompt: Value(row['PhotoPrompt'] ?? 'after'),
              createdAt: Value(_time(row['CreatedAt']) ?? _now()),
              updatedAt: Value(_time(row['UpdatedAt']) ?? _now()),
              deletedAt: Value(_time(row['DeletedAt'])),
            ),
          ),
    ),
    _Table(
      sheet: SheetNames.programDays,
      keyOf: _uuid,
      localStamps: (db) =>
          _stamps(db, db.programDays, (r) => r.uuid, (_) => _epoch),
      insert: (db, row) => db
          .into(db.programDays)
          .insertOnConflictUpdate(
            ProgramDaysCompanion.insert(
              uuid: row['Uuid']!,
              programUuid: row['ProgramUuid'] ?? '',
              name: row['Name'] ?? '',
              position: _int(row['Position']) ?? 0,
              week: Value(_int(row['Week'])),
              // Older archives have no column: keep what is here.
              accessories: row.containsKey('Accessories')
                  ? Value(row['Accessories'])
                  : const Value.absent(),
            ),
          ),
    ),
    _Table(
      sheet: SheetNames.programSlots,
      keyOf: _uuid,
      localStamps: (db) =>
          _stamps(db, db.programSlots, (r) => r.uuid, (_) => _epoch),
      insert: (db, row) => db
          .into(db.programSlots)
          .insertOnConflictUpdate(
            ProgramSlotsCompanion.insert(
              uuid: row['Uuid']!,
              dayUuid: row['DayUuid'] ?? '',
              exerciseId: row['ExerciseId'] ?? '',
              position: _int(row['Position']) ?? 0,
              restSeconds: Value(_int(row['RestSeconds'])),
              barGrams: Value(_int(row['BarGrams']) ?? 20000),
              note: Value(row['Note']),
            ),
          ),
    ),
    _Table(
      sheet: SheetNames.targetSets,
      keyOf: _uuid,
      localStamps: (db) =>
          _stamps(db, db.targetSets, (r) => r.uuid, (_) => _epoch),
      insert: (db, row) => db
          .into(db.targetSets)
          .insertOnConflictUpdate(
            TargetSetsCompanion.insert(
              uuid: row['Uuid']!,
              slotUuid: row['SlotUuid'] ?? '',
              position: _int(row['Position']) ?? 0,
              reps: Value(_int(row['Reps'])),
              weightGrams: Value(_int(row['WeightGrams'])),
              percentTenths: Value(_int(row['PercentTenths'])),
              openEnded: Value(_bool(row['OpenEnded'])),
            ),
          ),
    ),
    _Table(
      sheet: SheetNames.trainingMaxes,
      keyOf: (row) => row['ProgramUuid'] == null || row['ExerciseId'] == null
          ? null
          : '${row['ProgramUuid']}/${row['ExerciseId']}',
      stampColumn: 'UpdatedAt',
      localStamps: (db) => _stamps(
        db,
        db.trainingMaxes,
        (r) => '${r.programUuid}/${r.exerciseId}',
        (r) => r.updatedAt,
      ),
      insert: (db, row) => db
          .into(db.trainingMaxes)
          .insertOnConflictUpdate(
            TrainingMaxesCompanion.insert(
              programUuid: row['ProgramUuid']!,
              exerciseId: row['ExerciseId']!,
              grams: _int(row['Grams']) ?? 0,
              updatedAt: Value(_time(row['UpdatedAt']) ?? _now()),
            ),
          ),
    ),
    _Table(
      sheet: SheetNames.sessions,
      keyOf: _uuid,
      stampColumn: 'UpdatedAt',
      localStamps: (db) =>
          _stamps(db, db.workoutSessions, (r) => r.uuid, (r) => r.updatedAt),
      insert: (db, row) => db
          .into(db.workoutSessions)
          .insertOnConflictUpdate(
            WorkoutSessionsCompanion.insert(
              uuid: row['Uuid']!,
              programUuid: Value(row['ProgramUuid']),
              dayUuid: Value(row['DayUuid']),
              title: Value(row['Title']),
              harvestDay: row['HarvestDay'] ?? '',
              note: Value(row['Note']),
              startedAt: Value(_time(row['StartedAt']) ?? _now()),
              endedAt: Value(_time(row['EndedAt'])),
              pausedAt: Value(_time(row['PausedAt'])),
              pausedSeconds: Value(_int(row['PausedSeconds']) ?? 0),
              updatedAt: Value(
                _time(row['UpdatedAt']) ?? _time(row['StartedAt']) ?? _now(),
              ),
              deletedAt: Value(_time(row['DeletedAt'])),
            ),
          ),
    ),
    _Table(
      sheet: SheetNames.sessionExercises,
      keyOf: _uuid,
      localStamps: (db) =>
          _stamps(db, db.sessionExercises, (r) => r.uuid, (_) => _epoch),
      insert: (db, row) => db
          .into(db.sessionExercises)
          .insertOnConflictUpdate(
            SessionExercisesCompanion.insert(
              uuid: row['Uuid']!,
              sessionUuid: row['SessionUuid'] ?? '',
              position: _int(row['Position']) ?? 0,
              exerciseId: row['ExerciseId'] ?? '',
              plannedExerciseId: Value(row['PlannedExerciseId']),
              slotUuid: Value(row['SlotUuid']),
              skipped: Value(_bool(row['Skipped'])),
              skipReason: Value(row['SkipReason']),
              note: Value(row['Note']),
              restSeconds: Value(_int(row['RestSeconds'])),
              barGrams: Value(_int(row['BarGrams']) ?? 20000),
            ),
          ),
    ),
    _Table(
      sheet: SheetNames.sets,
      keyOf: _uuid,
      stampColumn: 'LoggedAt',
      localStamps: (db) =>
          _stamps(db, db.workoutSets, (r) => r.uuid, (r) => r.loggedAt),
      insert: (db, row) => db
          .into(db.workoutSets)
          .insertOnConflictUpdate(
            WorkoutSetsCompanion.insert(
              uuid: row['Uuid']!,
              sessionExerciseUuid: row['SessionExerciseUuid'] ?? '',
              position: _int(row['Position']) ?? 0,
              weightGrams: Value(_int(row['WeightGrams']) ?? 0),
              reps: Value(_int(row['Reps']) ?? 0),
              done: Value(_bool(row['Done'])),
              targetLabel: Value(row['TargetLabel']),
              openEnded: Value(_bool(row['OpenEnded'])),
              loggedAt: Value(_time(row['LoggedAt']) ?? _now()),
            ),
          ),
    ),
    _Table(
      sheet: SheetNames.settings,
      keyOf: (row) => row['Key'],
      stampColumn: 'UpdatedAt',
      accept: (row) => isImportableSetting(row['Key'] ?? ''),
      localStamps: (db) =>
          _stamps(db, db.kvSettings, (r) => r.key, (r) => r.updatedAt),
      insert: (db, row) => db
          .into(db.kvSettings)
          .insertOnConflictUpdate(
            KvSettingsCompanion.insert(
              key: row['Key']!,
              valueJson: row['Value'] ?? '',
              updatedAt: Value(_time(row['UpdatedAt']) ?? _now()),
            ),
          ),
    ),
    // Places. A point without both coordinates is not a point, so a
    // blank cell reads as 0,0 rather than failing the table; the
    // archive I wrote never has one. A place's notes came later (v20):
    // an older archive has no column, which reads as no notes.
    _Table(
      sheet: SheetNames.savedPlaces,
      keyOf: _uuid,
      stampColumn: 'UpdatedAt',
      localStamps: (db) =>
          _stamps(db, db.savedPlaces, (r) => r.uuid, (r) => r.updatedAt),
      insert: (db, row) => db
          .into(db.savedPlaces)
          .insertOnConflictUpdate(
            SavedPlacesCompanion.insert(
              uuid: row['Uuid']!,
              name: row['Name'] ?? '',
              latitude: _double(row['Latitude']) ?? 0,
              longitude: _double(row['Longitude']) ?? 0,
              radiusM: Value(_double(row['RadiusM']) ?? 100),
              notes: Value(row['Notes']),
              createdAt: Value(_time(row['CreatedAt']) ?? _now()),
              updatedAt: Value(_time(row['UpdatedAt']) ?? _now()),
              deletedAt: Value(_time(row['DeletedAt'])),
            ),
          ),
    ),
    _Table(
      sheet: SheetNames.locationPoints,
      keyOf: _uuid,
      stampColumn: 'UpdatedAt',
      localStamps: (db) =>
          _stamps(db, db.locationPoints, (r) => r.uuid, (r) => r.updatedAt),
      insert: (db, row) => db
          .into(db.locationPoints)
          .insertOnConflictUpdate(
            LocationPointsCompanion.insert(
              uuid: row['Uuid']!,
              harvestDay: row['HarvestDay'] ?? '',
              recordedAt: _time(row['RecordedAt']) ?? _now(),
              latitude: _double(row['Latitude']) ?? 0,
              longitude: _double(row['Longitude']) ?? 0,
              accuracyM: Value(_double(row['AccuracyM'])),
              speedMps: Value(_double(row['SpeedMps'])),
              altitudeM: Value(_double(row['AltitudeM'])),
              updatedAt: Value(
                _time(row['UpdatedAt']) ?? _time(row['RecordedAt']) ?? _now(),
              ),
              deletedAt: Value(_time(row['DeletedAt'])),
            ),
          ),
    ),
    _Table(
      sheet: SheetNames.geotags,
      keyOf: _uuid,
      stampColumn: 'UpdatedAt',
      localStamps: (db) =>
          _stamps(db, db.geotags, (r) => r.uuid, (r) => r.updatedAt),
      insert: (db, row) => db
          .into(db.geotags)
          .insertOnConflictUpdate(
            GeotagsCompanion.insert(
              uuid: row['Uuid']!,
              targetTable: row['TargetTable'] ?? '',
              targetUuid: row['TargetUuid'] ?? '',
              harvestDay: row['HarvestDay'] ?? '',
              at: _time(row['At']) ?? _now(),
              latitude: Value(_double(row['Latitude'])),
              longitude: Value(_double(row['Longitude'])),
              accuracyM: Value(_double(row['AccuracyM'])),
              state: Value(row['State'] ?? 'pending'),
              updatedAt: Value(_time(row['UpdatedAt']) ?? _now()),
              deletedAt: Value(_time(row['DeletedAt'])),
            ),
          ),
    ),
  ];

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
