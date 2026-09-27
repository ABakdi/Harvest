import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where the database file's key lives ([[Local-Database]], S-04).
///
/// 32 random bytes, kept as 64 hex digits in the Android Keystore next
/// to the account's refresh token. Never logged, never exported, never
/// synced: an archive carries rows, not the file, so it never needs it.
abstract interface class DatabaseKeyStore {
  /// The stored key, or null when there is none.
  ///
  /// Throws when the store could not be read. That is not the same as
  /// "no key": treating a failed read as absent would make a new key
  /// and lock the old file away.
  Future<String?> read();

  Future<void> write(String keyHex);
}

class KeystoreDatabaseKeys implements DatabaseKeyStore {
  const KeystoreDatabaseKeys();

  static const _storage = FlutterSecureStorage();
  static const _name = 'db.key';

  @override
  Future<String?> read() => _storage.read(key: _name);

  @override
  Future<void> write(String keyHex) =>
      _storage.write(key: _name, value: keyHex);
}

/// 32 bytes from the platform's secure generator, as 64 lowercase hex
/// digits: the form `PRAGMA key = "x'…'"` takes as a raw key, so
/// SQLCipher skips its passphrase derivation.
String newDatabaseKey([Random? random]) {
  final source = random ?? Random.secure();
  final buffer = StringBuffer();
  for (var i = 0; i < 32; i++) {
    buffer.write(source.nextInt(256).toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString();
}

final _keyShape = RegExp(r'^[0-9a-f]{64}$');

/// Whether [keyHex] is a key this app made. Anything else never reaches
/// a pragma: the key is spliced into SQL text.
bool isDatabaseKey(String? keyHex) =>
    keyHex != null && _keyShape.hasMatch(keyHex);
