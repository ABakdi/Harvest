import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// The private tier's envelope, byte for byte what the web writes
/// (`packages/contracts/src/crypto.ts`, pinned by `fixtures/crypto.json`):
///
/// - the key is PBKDF2-HMAC-SHA256 over the sync passphrase, salted with
///   the account's `syncSalt`, 600,000 iterations, 32 bytes;
/// - a row is AES-256-GCM over the JSON of its data, a fresh 12-byte IV,
///   the 128-bit tag appended to the ciphertext;
/// - the additional data is `<table>/<record uuid>`, so a ciphertext
///   moved to another row fails to open instead of becoming that row.
class SyncCipher {
  SyncCipher(List<int> keyBytes) : _key = SecretKey(keyBytes);

  final SecretKey _key;
  static final _aes = AesGcm.with256bits();

  static const iterations = 600000;

  /// The key, from the passphrase and the account's salt. Slow on
  /// purpose — it runs once, when the passphrase is set, and the result
  /// is kept in the keystore.
  static Future<Uint8List> deriveKey(
    String passphrase,
    String syncSalt, {
    int iterations = iterations,
  }) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: 256,
    );
    final key = await pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(passphrase)),
      nonce: utf8.encode(syncSalt),
    );
    return Uint8List.fromList(await key.extractBytes());
  }

  /// Seals one row's data for the wire: `{v, iv, ct}`.
  Future<Map<String, Object?>> seal(
    String table,
    String uuid,
    Map<String, Object?> data, {
    List<int>? iv,
  }) async {
    final box = await _aes.encrypt(
      utf8.encode(jsonEncode(data)),
      secretKey: _key,
      nonce: iv ?? _aes.newNonce(),
      aad: utf8.encode('$table/$uuid'),
    );
    return {
      'v': 1,
      'iv': base64Encode(box.nonce),
      'ct': base64Encode([...box.cipherText, ...box.mac.bytes]),
    };
  }

  /// Seals a file's bytes: the same cipher, the same key, and the
  /// file's own name as the additional data, so ciphertext offered
  /// under another name fails to open ([[Sync-API]]).
  Future<({Uint8List iv, Uint8List bytes})> sealBytes(
    String sha256,
    List<int> plain, {
    List<int>? iv,
  }) async {
    final box = await _aes.encrypt(
      plain,
      secretKey: _key,
      nonce: iv ?? _aes.newNonce(),
      aad: utf8.encode('file/$sha256'),
    );
    return (
      iv: Uint8List.fromList(box.nonce),
      bytes: Uint8List.fromList([...box.cipherText, ...box.mac.bytes]),
    );
  }

  /// Opens a file's bytes.
  Future<Uint8List> openBytes(
    String sha256,
    List<int> iv,
    List<int> sealed,
  ) async {
    const tag = 16;
    final box = SecretBox(
      sealed.sublist(0, sealed.length - tag),
      nonce: iv,
      mac: Mac(sealed.sublist(sealed.length - tag)),
    );
    return Uint8List.fromList(
      await _aes.decrypt(box, secretKey: _key, aad: utf8.encode('file/$sha256')),
    );
  }

  /// Opens one row. Throws [SecretBoxAuthenticationError] when the key,
  /// the row or the table is not the one it was sealed for.
  Future<Map<String, Object?>> open(
    String table,
    String uuid,
    Map<String, Object?> envelope,
  ) async {
    final all = base64Decode(envelope['ct']! as String);
    const tag = 16;
    final box = SecretBox(
      all.sublist(0, all.length - tag),
      nonce: base64Decode(envelope['iv']! as String),
      mac: Mac(all.sublist(all.length - tag)),
    );
    final plain = await _aes.decrypt(
      box,
      secretKey: _key,
      aad: utf8.encode('$table/$uuid'),
    );
    return jsonDecode(utf8.decode(plain)) as Map<String, Object?>;
  }
}
