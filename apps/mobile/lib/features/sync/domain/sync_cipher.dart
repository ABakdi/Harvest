import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:meta/meta.dart';

/// A sealed row this key cannot read: sealed with another key, for
/// another row or other clocks, or in the version 1 envelope 3.0.0 wrote.
/// It is counted as locked, never fatal ([[Sync-API]]).
class UnreadableRow implements Exception {
  const UnreadableRow([this.reason = 'does not open with this key']);

  final String reason;

  @override
  String toString() => 'UnreadableRow($reason)';
}

/// The clocks a record carries in the clear, which a version 2 row binds.
typedef RowClocks = ({String updatedAt, String? deletedAt});

/// The private tier's envelope, byte for byte what the web writes
/// (`packages/contracts/src/crypto.ts`, pinned by
/// `fixtures/crypto-v2.json`), version 2:
///
/// - the base is PBKDF2-HMAC-SHA256(secret, the account's `syncSalt`,
///   600,000 iterations); the key is HKDF-SHA256 over it, salted with the
///   account's key share — handed out only after the PIN proof, also
///   HKDF over the base, is shown to the server — and the info
///   `harvest/sync-key/v2`, 32 bytes;
/// - a row is AES-256-GCM over the JSON of its data, a fresh 12-byte IV,
///   the 128-bit tag appended to the ciphertext, `v: 2`;
/// - the additional data is
///   `row/<table>/<uuid>/<updatedAt micros>/<deletedAt micros or "">`,
///   so a ciphertext moved to another row, or offered under a newer
///   clock, fails to open instead of becoming that row;
/// - the account's key check is `harvest-key-check` sealed with the
///   additional data `key-check`.
///
/// Phase 7 adds (`fixtures/crypto-v3.json`):
///
/// - a row's JSON is padded with spaces to [paddedLength] before sealing,
///   which JSON ignores, so a row's size says little about what it is;
/// - a file is named on the server by [nameOf], an HMAC of its plaintext's
///   SHA-256 under a key drawn from this one, so a server holding a known
///   picture cannot tell whether an account has it;
/// - a file's bytes are padded (`0x80`, then zeros) and sealed with the
///   additional data `file/v3/<name>`; one sealed before, under
///   `file/<name>` and unpadded, still opens.
class SyncCipher {
  SyncCipher(List<int> keyBytes, {this.epoch = 1})
    : _key = SecretKey(keyBytes),
      _keyBytes = List.unmodifiable(keyBytes);

  final SecretKey _key;
  final List<int> _keyBytes;

  /// The key epoch this key belongs to (`contracts/sync-key.ts`): every
  /// sealed push and file upload names it, and the server refuses a stale
  /// one, so nothing is ever stored under a key started over elsewhere.
  final int epoch;
  static final _aes = AesGcm.with256bits();

  static const iterations = 600000;
  static const version = 2;
  static const keyInfo = 'harvest/sync-key/v2';
  static const checkPlaintext = 'harvest-key-check';
  static const checkAad = 'key-check';
  static const nameInfo = 'harvest/file-name/v1';
  static const _tag = 16;

  /// The secret's base: PBKDF2-HMAC-SHA256 of the secret with the
  /// account's salt, 32 bytes. Slow on purpose, and run once: both the PIN
  /// proof and the key are drawn from it.
  static Future<Uint8List> deriveBase(
    String secret,
    String syncSalt, {
    int iterations = iterations,
  }) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: 256,
    );
    final base = await pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(secret)),
      nonce: utf8.encode(syncSalt),
    );
    return Uint8List.fromList(await base.extractBytes());
  }

  static const proofInfo = 'harvest/sync-pin-proof/v1';

  /// What a device shows the server to be handed the key share
  /// (`POST /v1/me/sync-key/unlock`): HKDF over the base, empty salt. It
  /// is not the key, and the key cannot be had from it.
  static Future<Uint8List> proofOf(List<int> base) async {
    final proof = await Hkdf(hmac: Hmac.sha256(), outputLength: 32).deriveKey(
      secretKey: SecretKey(base),
      // The empty salt spelled as RFC 5869 defines it, 32 zero bytes:
      // the same HMAC key once padded, but Android's own HMAC refuses
      // an empty key outright.
      nonce: Uint8List(32),
      info: utf8.encode(proofInfo),
    );
    return Uint8List.fromList(await proof.extractBytes());
  }

  /// What the server keeps instead of the proof: SHA-256, lowercase hex.
  static Future<String> verifierOf(List<int> proof) async {
    final digest = await Sha256().hash(proof);
    return [
      for (final byte in digest.bytes) byte.toRadixString(16).padLeft(2, '0'),
    ].join();
  }

  /// The key, from a base and the account's key share.
  static Future<Uint8List> keyOf(List<int> base, List<int> keyShare) async {
    final key = await Hkdf(hmac: Hmac.sha256(), outputLength: 32).deriveKey(
      secretKey: SecretKey(base),
      nonce: keyShare,
      info: utf8.encode(keyInfo),
    );
    return Uint8List.fromList(await key.extractBytes());
  }

  /// The key straight from the secret, the salt and the key share.
  static Future<Uint8List> deriveKey(
    String secret,
    String syncSalt,
    List<int> keyShare, {
    int iterations = iterations,
  }) async => keyOf(
    await deriveBase(secret, syncSalt, iterations: iterations),
    keyShare,
  );

  /// A row's additional data: the table, the key and both clocks.
  static String rowAad(String table, String uuid, RowClocks clocks) {
    final deleted = clocks.deletedAt;
    return 'row/$table/$uuid/${instantMicros(clocks.updatedAt)}/'
        '${deleted == null ? '' : instantMicros(deleted)}';
  }

  Future<Map<String, Object?>> _sealText(
    List<int> plain,
    String aad, {
    List<int>? iv,
  }) async {
    final box = await _aes.encrypt(
      plain,
      secretKey: _key,
      nonce: iv ?? _aes.newNonce(),
      aad: utf8.encode(aad),
    );
    return {
      'v': version,
      'iv': base64Encode(box.nonce),
      'ct': base64Encode([...box.cipherText, ...box.mac.bytes]),
    };
  }

  Future<List<int>> _openText(Map<String, Object?> envelope, String aad) async {
    if (envelope['v'] != version) {
      throw const UnreadableRow('a version 1 envelope');
    }
    try {
      final all = base64Decode(envelope['ct']! as String);
      final box = SecretBox(
        all.sublist(0, all.length - _tag),
        nonce: base64Decode(envelope['iv']! as String),
        mac: Mac(all.sublist(all.length - _tag)),
      );
      return await _aes.decrypt(box, secretKey: _key, aad: utf8.encode(aad));
    } on SecretBoxAuthenticationError {
      throw const UnreadableRow();
    } on Object {
      throw const UnreadableRow('not an envelope');
    }
  }

  /// Seals one row's data for the wire, bound to the clocks it travels
  /// with: `{v: 2, iv, ct}`.
  Future<Map<String, Object?>> seal(
    String table,
    String uuid,
    RowClocks clocks,
    Map<String, Object?> data, {
    List<int>? iv,
  }) => _sealText(
    padRow(utf8.encode(jsonEncode(data))),
    rowAad(table, uuid, clocks),
    iv: iv,
  );

  /// Opens one row. Throws [UnreadableRow] when the key, the row, the
  /// table or the clocks are not the ones it was sealed for, or when it
  /// is not a version 2 envelope. The row's own clocks are compared with
  /// the record's by the caller, which knows the table's columns.
  Future<Map<String, Object?>> open(
    String table,
    String uuid,
    RowClocks clocks,
    Map<String, Object?> envelope,
  ) async {
    final plain = await _openText(envelope, rowAad(table, uuid, clocks));
    try {
      return jsonDecode(utf8.decode(plain)) as Map<String, Object?>;
    } on Object {
      throw const UnreadableRow('not a row');
    }
  }

  /// The account's key check, sealed under this key: what the first
  /// device stores on the server.
  Future<Map<String, Object?>> sealCheck({List<int>? iv}) =>
      _sealText(utf8.encode(checkPlaintext), checkAad, iv: iv);

  /// Whether this key opens the account's key check: whether the PIN it
  /// came from is the account's PIN.
  Future<bool> opensCheck(Map<String, Object?> check) async {
    try {
      final plain = await _openText(check, checkAad);
      return utf8.decode(plain) == checkPlaintext;
    } on Object {
      return false;
    }
  }

  /// The name key: HKDF-SHA256 over this key's bytes, the empty salt
  /// spelled as 32 zero bytes, the info `harvest/file-name/v1`. It only
  /// ever signs names.
  late final Future<SecretKey> _nameKey =
      Hkdf(
        hmac: Hmac.sha256(),
        outputLength: 32,
      ).deriveKey(
        secretKey: SecretKey(_keyBytes),
        nonce: Uint8List(32),
        info: utf8.encode(nameInfo),
      );

  /// The name key's bytes, for the tests that pin it.
  @visibleForTesting
  Future<List<int>> nameKeyBytes() async => (await _nameKey).extractBytes();

  /// A file's name on the server, from its plaintext's SHA-256 (lowercase
  /// hex): HMAC-SHA256 under the name key, lowercase hex. Every device
  /// with this key names a file the same; nobody without it can.
  Future<String> nameOf(String sha256) async {
    final mac = await Hmac.sha256().calculateMac(
      utf8.encode(sha256),
      secretKey: await _nameKey,
    );
    return _hex(mac.bytes);
  }

  /// The record key of a day of the trail (`trail_days`): the first 16
  /// bytes of HMAC-SHA256 of `trail/<day>` under the name key, in hex, so
  /// every device agrees on it and the server cannot tell which day it is.
  Future<String> trailKeyOf(String harvestDay) async {
    final mac = await Hmac.sha256().calculateMac(
      utf8.encode('trail/$harvestDay'),
      secretKey: await _nameKey,
    );
    return _hex(mac.bytes.sublist(0, 16));
  }

  /// Seals a file's bytes, padded, under its server [name]: the same
  /// cipher and key, with `file/v3/<name>` as the additional data, so
  /// ciphertext offered under another name fails to open ([[Sync-API]]).
  Future<({Uint8List iv, Uint8List bytes})> sealFile(
    String name,
    List<int> plain, {
    List<int>? iv,
  }) async {
    final box = await _aes.encrypt(
      padFile(plain),
      secretKey: _key,
      nonce: iv ?? _aes.newNonce(),
      aad: utf8.encode('file/v3/$name'),
    );
    return (
      iv: Uint8List.fromList(box.nonce),
      bytes: Uint8List.fromList([...box.cipherText, ...box.mac.bytes]),
    );
  }

  /// Opens a file's bytes stored under [name], however they were sealed:
  /// padded under `file/v3/<name>`, or as before Phase 7.
  Future<Uint8List> openFile(
    String name,
    List<int> iv,
    List<int> sealed,
  ) async {
    final box = SecretBox(
      sealed.sublist(0, sealed.length - _tag),
      nonce: iv,
      mac: Mac(sealed.sublist(sealed.length - _tag)),
    );
    try {
      final padded = await _aes.decrypt(
        box,
        secretKey: _key,
        aad: utf8.encode('file/v3/$name'),
      );
      return unpadFile(padded);
    } on SecretBoxAuthenticationError {
      return Uint8List.fromList(
        await _aes.decrypt(
          box,
          secretKey: _key,
          aad: utf8.encode('file/$name'),
        ),
      );
    }
  }
}

/// The smallest a sealed row's plaintext is: below it, every row looks
/// the same (`minPaddedRowBytes`).
const minPaddedBytes = 256;

/// The length [n] bytes are padded to, as `paddedLength` in the contract:
/// at least [minimum], and above it the Padmé rule, which rounds to a
/// number with few significant bits and costs at most about 12%.
int paddedLength(int n, {int minimum = minPaddedBytes}) {
  if (n <= minimum) return minimum;
  if (n < 4) return n;
  final e = n.bitLength - 1;
  final s = e.bitLength;
  final step = 1 << (e - s);
  return (n + step - 1) ~/ step * step;
}

/// A row's JSON, spaces after it up to [paddedLength].
Uint8List padRow(List<int> json) => Uint8List(paddedLength(json.length))
  ..fillRange(0, paddedLength(json.length), 0x20)
  ..setRange(0, json.length, json);

/// A file's bytes, then `0x80`, then zeros, up to [paddedLength] of one
/// byte more.
Uint8List padFile(List<int> bytes) => Uint8List(paddedLength(bytes.length + 1))
  ..setRange(0, bytes.length, bytes)
  ..[bytes.length] = 0x80;

/// The bytes [padFile] padded; throws [UnreadableRow] when the padding is
/// not there.
Uint8List unpadFile(List<int> padded) {
  var end = padded.length - 1;
  while (end >= 0 && padded[end] == 0) {
    end--;
  }
  if (end < 0 || padded[end] != 0x80) {
    throw const UnreadableRow('a file without its padding');
  }
  return Uint8List.fromList(padded.sublist(0, end));
}

String _hex(List<int> bytes) => [
  for (final byte in bytes) byte.toRadixString(16).padLeft(2, '0'),
].join();

final _instant = RegExp(
  r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})(?::(\d{2})(?:\.(\d+))?)?Z$',
);

/// Microseconds since the epoch of an ISO-8601 UTC instant, exactly as
/// contracts' `instantMicros` reads it: `.5Z` and `.500000Z` are one
/// clock, and digits past the sixth are dropped rather than rounded.
int instantMicros(String iso) {
  final match = _instant.firstMatch(iso);
  if (match == null) throw FormatException('Not an ISO-8601 UTC instant', iso);
  int at(int group) => int.parse(match.group(group) ?? '0');
  final millis = DateTime.utc(
    at(1),
    at(2),
    at(3),
    at(4),
    at(5),
    at(6),
  ).millisecondsSinceEpoch;
  final fraction = '${match.group(7) ?? ''}000000'.substring(0, 6);
  return millis * 1000 + int.parse(fraction);
}

/// Whether two ISO instants name the same moment, whatever their
/// spelling; null only matches null.
bool sameInstant(String? a, String? b) {
  if (a == null || b == null) return a == b;
  try {
    return instantMicros(a) == instantMicros(b);
  } on FormatException {
    return false;
  }
}
