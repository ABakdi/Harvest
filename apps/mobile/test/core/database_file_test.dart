import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/db/database_file.dart';
import 'package:harvest/core/db/database_key.dart';
import 'package:sqlite3/sqlite3.dart';

/// The file at rest ([[Local-Database]], S-04). The host tests link
/// SQLCipher through the same sqlite3 hook as the phone, so these run
/// the real export, the real key and the real header.
class _Keys implements DatabaseKeyStore {
  String? stored;
  bool failRead = false;
  bool dropWrites = false;

  @override
  Future<String?> read() async {
    if (failRead) throw StateError('keystore');
    return stored;
  }

  @override
  Future<void> write(String keyHex) async {
    if (!dropWrites) stored = keyHex;
  }
}

/// A v3.0.0 database: plain SQLite, schema v24, with rows in it.
Future<void> _plainV3(String path) async {
  final db = HarvestDatabase.forTesting(NativeDatabase(File(path)));
  await db
      .into(db.commitments)
      .insert(
        CommitmentsCompanion.insert(
          uuid: 'c1',
          type: 'habit',
          title: 'Read',
          createdAt: Value(DateTime.utc(2026, 9)),
        ),
      );
  await db
      .into(db.kvSettings)
      .insert(
        KvSettingsCompanion.insert(
          key: 'finance.currency',
          valueJson: '"DZD"',
        ),
      );
  await db.close();
}

void main() {
  late Directory dir;
  late String path;
  late _Keys keys;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('harvest-db');
    path = '${dir.path}/harvest.sqlite';
    keys = _Keys();
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('the host links SQLCipher', () {
    expect(cipherLinked(), isTrue);
  });

  test('a key is 32 random bytes as 64 hex digits', () {
    final key = newDatabaseKey(Random(1));
    expect(isDatabaseKey(key), isTrue);
    expect(newDatabaseKey(), isNot(newDatabaseKey()));
    expect(isDatabaseKey('x'), isFalse);
    expect(() => keyPragma("'; DROP TABLE x; --"), throwsArgumentError);
  });

  test('the header tells a plain file from an encrypted one', () async {
    expect(databaseFileState(path), DatabaseFileState.absent);
    File(path).createSync();
    expect(databaseFileState(path), DatabaseFileState.absent);
    File(path).deleteSync();

    await _plainV3(path);
    expect(databaseFileState(path), DatabaseFileState.plaintext);

    expect(encryptInPlace(path, newDatabaseKey()), isTrue);
    expect(databaseFileState(path), DatabaseFileState.encrypted);
  });

  test('a v3.0.0 file is encrypted in place, rows and version kept', () async {
    await _plainV3(path);
    final key = await prepareDatabaseFile(path, keys, primary: true);

    expect(key, keys.stored);
    expect(databaseFileState(path), DatabaseFileState.encrypted);
    expect(File(encryptingPathOf(path)).existsSync(), isFalse);
    for (final name in companionsOf(path)) {
      expect(File(name).existsSync(), isFalse);
    }
    // No trace of the rows in the bytes.
    final bytes = String.fromCharCodes(File(path).readAsBytesSync());
    expect(bytes.contains('finance.currency'), isFalse);
    expect(bytes.contains('Read'), isFalse);

    // Without the key it is not a database.
    final bare = sqlite3.open(path);
    expect(
      () => bare.select('SELECT count(*) FROM sqlite_master'),
      throwsA(isA<SqliteException>()),
    );
    bare.close();

    // With it, drift sees the same rows at the same schema version, and
    // opens without running a migration.
    final db = HarvestDatabase.forTesting(
      NativeDatabase(File(path), setup: (raw) => unlockDatabase(raw, key!)),
    );
    expect((await db.select(db.commitments).get()).single.title, 'Read');
    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.data.values.single, db.schemaVersion);
    await db.close();
  });

  test('the outbox sequence survives the export', () async {
    await _plainV3(path);
    sqlite3.open(path)
      ..execute(
        "INSERT INTO sqlite_sequence (name, seq) SELECT 'outbox', 41 "
        "WHERE NOT EXISTS (SELECT 1 FROM sqlite_sequence WHERE name = 'outbox')",
      )
      ..execute("UPDATE sqlite_sequence SET seq = 41 WHERE name = 'outbox'")
      ..close();
    final key = newDatabaseKey();
    expect(encryptInPlace(path, key), isTrue);
    final db = sqlite3.open(path);
    unlockDatabase(db, key);
    expect(
      db
          .select("SELECT seq FROM sqlite_sequence WHERE name = 'outbox'")
          .single['seq'],
      41,
    );
    db.close();
  });

  test(
    'a failed export keeps the plain file, and the next start retries',
    () async {
      await _plainV3(path);
      // A leftover from an interrupted run is not mistaken for the result.
      File(encryptingPathOf(path)).writeAsStringSync('half');
      final plainBytes = File(path).readAsBytesSync();

      // A read-only directory: the export cannot create its file.
      Process.runSync('chmod', ['a-w', dir.path]);
      try {
        expect(encryptInPlace(path, newDatabaseKey()), isFalse);
      } finally {
        Process.runSync('chmod', ['u+w', dir.path]);
      }
      expect(File(path).readAsBytesSync(), plainBytes);

      final key = await prepareDatabaseFile(path, keys, primary: true);
      expect(key, isNotNull);
      expect(databaseFileState(path), DatabaseFileState.encrypted);
    },
  );

  test('a key that does not stick leaves the file plain', () async {
    await _plainV3(path);
    keys.dropWrites = true;
    expect(await prepareDatabaseFile(path, keys, primary: true), isNull);
    expect(databaseFileState(path), DatabaseFileState.plaintext);
  });

  test('a new install is born with a key', () async {
    final key = await prepareDatabaseFile(path, keys, primary: true);
    expect(isDatabaseKey(key), isTrue);
    expect(keys.stored, key);
  });

  test('background isolates never encrypt or create a key', () async {
    await _plainV3(path);
    expect(await prepareDatabaseFile(path, keys, primary: false), isNull);
    expect(keys.stored, isNull);
    expect(databaseFileState(path), DatabaseFileState.plaintext);
  });

  test(
    'a lost key sets the file aside instead of failing every start',
    () async {
      await _plainV3(path);
      final first = await prepareDatabaseFile(path, keys, primary: true);
      keys.stored = null; // the Keystore forgot it

      // A background job just skips.
      await expectLater(
        prepareDatabaseFile(path, keys, primary: false),
        throwsA(isA<DatabaseLockedException>()),
      );
      expect(File(path).existsSync(), isTrue);

      final second = await prepareDatabaseFile(path, keys, primary: true);
      expect(second, isNot(first));
      expect(File(path).existsSync(), isFalse);
      expect(File('$path.unreadable').existsSync(), isTrue);

      // And the start after that is an ordinary one.
      expect(await prepareDatabaseFile(path, keys, primary: true), second);
    },
  );

  test('a Keystore that fails to answer never replaces the key', () async {
    await _plainV3(path);
    final key = await prepareDatabaseFile(path, keys, primary: true);
    keys.failRead = true;
    await expectLater(
      prepareDatabaseFile(path, keys, primary: true),
      throwsA(isA<StateError>()),
    );
    keys.failRead = false;
    expect(keys.stored, key);
    expect(File(path).existsSync(), isTrue);
  });
}
