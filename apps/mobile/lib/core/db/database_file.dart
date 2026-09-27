import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:harvest/core/db/database_key.dart';
import 'package:sqlite3/common.dart' show CommonDatabase;
import 'package:sqlite3/sqlite3.dart';

/// The database file on disk, encrypted at rest with SQLCipher
/// ([[Local-Database]], S-04).
///
/// The private tier is sealed on the server, but the phone keeps it
/// decrypted: money and places sit in this file as plain rows. SQLCipher
/// encrypts every page with a key only the Keystore holds, so a copy of
/// the file alone is noise.
///
/// Everything here is plain file and sqlite3 work, synchronous and free
/// of plugins, so it runs in [Isolate.run] on the phone and directly in
/// the host tests (which link SQLCipher too, through the same hook).

/// What the file at a path is, judged by its first 16 bytes.
enum DatabaseFileState { absent, plaintext, encrypted }

/// Every plain SQLite file starts with these 16 bytes. A SQLCipher file
/// starts with its random salt instead, so the header never matches.
const sqliteHeader = 'SQLite format 3\u0000';

DatabaseFileState databaseFileState(String path) {
  final file = File(path);
  if (!file.existsSync()) return DatabaseFileState.absent;
  final raf = file.openSync();
  try {
    final head = raf.readSync(16);
    // An empty file is what sqlite leaves when it created the file and
    // wrote nothing yet: no pages, nothing to protect.
    if (head.isEmpty) return DatabaseFileState.absent;
    return isPlaintextHeader(head)
        ? DatabaseFileState.plaintext
        : DatabaseFileState.encrypted;
  } finally {
    raf.closeSync();
  }
}

bool isPlaintextHeader(List<int> head) =>
    head.length >= 16 &&
    String.fromCharCodes(head.sublist(0, 16)) == sqliteHeader;

/// The statement that unlocks a connection with a raw key.
String keyPragma(String keyHex) {
  if (!isDatabaseKey(keyHex)) throw ArgumentError('not a database key');
  return 'PRAGMA key = "x\'$keyHex\'"';
}

/// SQLCipher's version, or null when the linked library is plain SQLite
/// (the pragma is unknown there and returns no row).
String? cipherVersion(CommonDatabase db) {
  final rows = db.select('PRAGMA cipher_version');
  if (rows.isEmpty) return null;
  final value = rows.first.values.first;
  return value is String && value.isNotEmpty ? value : null;
}

/// Whether this build links SQLCipher at all.
bool cipherLinked() {
  final db = sqlite3.openInMemory();
  try {
    return cipherVersion(db) != null;
  } finally {
    db.close();
  }
}

/// Unlocks [db] with [keyHex] and proves it: the cipher must be active
/// and the first page must decrypt. Used as drift's `setup`, so it runs
/// on every connection before the first query.
void unlockDatabase(CommonDatabase db, String keyHex) {
  db.execute(keyPragma(keyHex));
  if (cipherVersion(db) == null) {
    throw StateError('SQLCipher is not linked: the file would stay plain');
  }
  // A wrong key only shows on the first read: SQLITE_NOTADB (26).
  db.select('SELECT count(*) FROM sqlite_master');
}

/// Whether [keyHex] opens the file at [path]. False only for "not a
/// database" (a wrong key, or a file that is not SQLite at all); any
/// other failure — a busy lock, a full disk — is thrown, because it says
/// nothing about the key.
bool opensWith(String path, String keyHex) {
  final db = sqlite3.open(path, mode: OpenMode.readOnly);
  try {
    unlockDatabase(db, keyHex);
    return true;
  } on SqliteException catch (e) {
    if (e.resultCode == 26) return false;
    rethrow;
  } finally {
    db.close();
  }
}

/// The user tables and their row counts, for comparing two files.
Map<String, int> rowCounts(CommonDatabase db, {String schema = 'main'}) {
  final names = db
      .select(
        "SELECT name FROM $schema.sqlite_master WHERE type = 'table' "
        "AND name NOT LIKE 'sqlite_%' ORDER BY name",
      )
      .map((row) => row['name'] as String);
  return {
    for (final name in names)
      name:
          db.select('SELECT count(*) AS n FROM $schema."$name"').first['n']
              as int,
  };
}

/// The file names that belong to the database at [path].
List<String> companionsOf(String path) => [
  '$path-wal',
  '$path-shm',
  '$path-journal',
];

String encryptingPathOf(String path) => '$path.encrypting';

/// Encrypts the plain database at [path] in place.
///
/// 1. `sqlcipher_export` copies every table, index and trigger into a new
///    encrypted file next to it; `user_version` (drift's schema version)
///    is copied by hand, the export leaves it at 0.
/// 2. The copy is reopened with the key and every table's row count is
///    compared with the original.
/// 3. The plain file's journal and WAL files go (the export closed it
///    cleanly, so they hold nothing), and the copy is renamed over it:
///    one atomic rename, so the path always holds a whole database.
///
/// Returns false and leaves the plain file untouched when any step
/// fails; the next start tries again. The rename unlinks the plain
/// file, but flash storage may keep its old blocks until they are reused.
bool encryptInPlace(String path, String keyHex) {
  final target = encryptingPathOf(path);
  try {
    // A leftover of an interrupted run is never mistaken for the result.
    _deleteIfPresent(target);
    final Map<String, int> before;
    final plain = sqlite3.open(path);
    try {
      if (cipherVersion(plain) == null) return false;
      before = rowCounts(plain);
      final version = plain.userVersion;
      plain
        ..execute('ATTACH DATABASE ? AS encrypted KEY ?', [
          target,
          "x'$keyHex'",
        ])
        ..select("SELECT sqlcipher_export('encrypted')")
        ..execute('PRAGMA encrypted.user_version = $version')
        ..execute('DETACH DATABASE encrypted');
    } finally {
      plain.close();
    }

    final copy = sqlite3.open(target);
    try {
      unlockDatabase(copy, keyHex);
      if (!mapEquals(rowCounts(copy), before)) return false;
    } finally {
      copy.close();
    }
    if (databaseFileState(target) != DatabaseFileState.encrypted) return false;

    companionsOf(path).forEach(_deleteIfPresent);
    File(target).renameSync(path);
    return true;
  } on Object catch (error) {
    debugPrint('[db] encryption postponed: ${error.runtimeType}');
    return false;
  } finally {
    try {
      _deleteIfPresent(target);
    } on FileSystemException {
      // Tried again, first thing, on the next run.
    }
  }
}

/// Moves an unreadable file (and its companions) out of the way, to
/// `<path>.unreadable`, replacing an older one.
void setAside(String path) {
  final aside = '$path.unreadable';
  [aside, ...companionsOf(aside)].forEach(_deleteIfPresent);
  File(path).renameSync(aside);
  for (final name in companionsOf(path)) {
    if (File(name).existsSync()) {
      File(name).renameSync(name.replaceFirst(path, aside));
    }
  }
}

void _deleteIfPresent(String path) {
  final file = File(path);
  if (file.existsSync()) file.deleteSync();
}

/// Thrown when a background isolate finds a file its key does not open.
/// Only the app itself sets such a file aside; a 3 AM job just skips.
class DatabaseLockedException implements Exception {
  const DatabaseLockedException();

  @override
  String toString() => 'DatabaseLockedException';
}

/// Decides how to open the file at [path] and gets it ready: returns the
/// key to unlock it with, or null to open it as plain SQLite.
///
/// [primary] is the app's own connection. Only it creates the key,
/// encrypts a plain file and sets an unreadable one aside; the
/// background isolates (the 3 AM job, a snooze tap, the trail recorder)
/// open whatever is there and leave the rest to the next app start.
///
/// - no file: a new key, and the file is born encrypted.
/// - a plain file (v3.0.0 and older): encrypted in place; if that fails
///   it opens plain, as before, and the next start tries again.
/// - an encrypted file the key opens: the normal case.
/// - an encrypted file with no key, or one the key does not open (the
///   Keystore lost it): it cannot be read by anyone, so it is set aside
///   and the app starts empty, like a fresh install, rather than failing
///   on every start.
Future<String?> prepareDatabaseFile(
  String path,
  DatabaseKeyStore keys, {
  required bool primary,
  bool? linked,
}) async {
  final hasCipher = linked ?? await Isolate.run<bool>(cipherLinked);
  if (!hasCipher) {
    // A build without SQLCipher is a build mistake, not a state to live
    // with quietly.
    assert(false, 'SQLCipher is not linked: the database stays plain');
    debugPrint('[db] SQLCipher is not linked: the database stays plain');
    return null;
  }

  final state = await Isolate.run(() => databaseFileState(path));
  String? key;
  try {
    key = await keys.read();
  } on Object {
    // The Keystore failed to answer. A plain file still opens without
    // it; an encrypted one cannot, and a new key would lose it for good.
    if (state == DatabaseFileState.plaintext) return null;
    rethrow;
  }
  if (key != null && !isDatabaseKey(key)) key = null;

  switch (state) {
    case DatabaseFileState.absent:
      if (!primary) return key;
      return key ?? await _createKey(keys);
    case DatabaseFileState.plaintext:
      if (!primary) return null;
      final newKey = key ?? await _createKey(keys);
      if (newKey == null) return null;
      final encrypted = await Isolate.run(() => encryptInPlace(path, newKey));
      return encrypted ? newKey : null;
    case DatabaseFileState.encrypted:
      if (key != null) {
        final current = key;
        if (await Isolate.run(() => opensWith(path, current))) return current;
      }
      if (!primary) throw const DatabaseLockedException();
      debugPrint('[db] the key does not open the file: starting empty');
      await Isolate.run(() => setAside(path));
      return key ?? await _createKey(keys);
  }
}

/// Makes and stores a key, and reads it back: a key that did not stick
/// would encrypt a file nobody can open next time. Null when it did not.
Future<String?> _createKey(DatabaseKeyStore keys) async {
  final key = newDatabaseKey();
  try {
    await keys.write(key);
    if (await keys.read() == key) return key;
  } on Object catch (error) {
    debugPrint('[db] key not stored: ${error.runtimeType}');
  }
  return null;
}
