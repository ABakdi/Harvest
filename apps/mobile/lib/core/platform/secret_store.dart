import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:harvest/core/db/database_key.dart' show secureStorageOptions;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'secret_store.g.dart';

/// Where secrets live: the Android Keystore, behind a small interface
/// so the tests keep theirs in a map.
///
/// Holds the assist's key and the account's refresh token: the two
/// secrets the app has, and the two things no export, archive or sync
/// ever carries.
abstract interface class SecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String? value);
}

class KeystoreSecretStore implements SecretStore {
  const KeystoreSecretStore();

  static const _storage = FlutterSecureStorage(aOptions: secureStorageOptions);

  /// A failed read throws ([secureStorageOptions]): "could not read the
  /// sync key" is not "there is no sync key", and must not be taken for
  /// one.
  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String? value) async {
    try {
      if (value == null || value.isEmpty) {
        await _storage.delete(key: key);
      } else {
        await _storage.write(key: key, value: value);
      }
    } on PlatformException {
      return;
    }
  }
}

@Riverpod(keepAlive: true)
SecretStore secretStore(Ref ref) => const KeystoreSecretStore();
