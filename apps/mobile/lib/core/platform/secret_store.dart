import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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

  static const _storage = FlutterSecureStorage();

  @override
  Future<String?> read(String key) async {
    try {
      return await _storage.read(key: key);
    } on PlatformException {
      return null;
    }
  }

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
