import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart' show DartSha256;
import 'package:flutter/foundation.dart';
import 'package:harvest/core/platform/secret_store.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'file_vault.g.dart';

/// Pictures, videos and recordings, sealed on disk ([[Phase-7-Privacy-and-Currencies]],
/// M7.4), like the database is: a copy of the app's folder, taken off the
/// phone, shows nothing without the key the Keystore keeps.
///
/// The key is 32 random bytes, made once and kept by [SecretStore] (the
/// Keystore). A sealed file is:
///
/// - `HVF1`, four bytes that say what it is;
/// - 8 random bytes, the file's own prefix;
/// - its bytes in chunks of [chunkBytes], each AES-256-GCM with the nonce
///   `prefix ‖ chunk number (4 bytes, big-endian)`, the 16-byte tag after
///   it, and one byte of additional data: 1 for the last chunk, 0 for the
///   others — so a chunk cannot move, move to another file, or be cut
///   off the end without the file failing to open.
///
/// A file without the four bytes is one from before, not sealed yet: it
/// reads as it is, and [FileVault.sealAll] seals it on the next start.
///
/// Everything that reads or writes one of these files goes through here.
/// What leaves the phone on purpose (an export, a share) is opened first:
/// it is mine to take elsewhere.
class FileVault {
  FileVault(this._secrets, {Future<Directory> Function()? temporary})
    : _temporary = temporary ?? getTemporaryDirectory;

  final SecretStore _secrets;
  final Future<Directory> Function() _temporary;

  static const String keyName = 'files.key';
  static const int chunkBytes = 1 << 20;
  static final List<int> _magic = ascii.encode('HVF1');
  static const int _prefixBytes = 8;
  static const int _tagBytes = 16;
  static const int _headerBytes = 4 + _prefixBytes;

  Future<List<int>>? _key;

  /// The key, made on first use. One that could not be kept is never
  /// used: a file sealed with it could never be opened again.
  Future<List<int>> key() async {
    final pending = _key ??= _loadKey();
    try {
      return await pending;
    } on Object {
      // Asked again next time rather than failing for good.
      if (identical(_key, pending)) _key = null;
      rethrow;
    }
  }

  Future<List<int>> _loadKey() async {
    final stored = await _secrets.read(keyName);
    if (stored != null) return base64Decode(stored);
    final fresh = List<int>.generate(32, (_) => Random.secure().nextInt(256));
    await _secrets.write(keyName, base64Encode(fresh));
    final kept = await _secrets.read(keyName);
    if (kept != base64Encode(fresh)) {
      throw const FileSystemException('The file key could not be kept');
    }
    return fresh;
  }

  /// Whether [file] is sealed.
  static bool isSealed(File file) {
    if (!file.existsSync()) return false;
    final handle = file.openSync();
    try {
      final head = handle.readSync(4);
      return head.length == 4 && listEquals(head, _magic);
    } finally {
      handle.closeSync();
    }
  }

  /// [file]'s bytes, opened.
  Future<Uint8List> read(File file) async {
    final key = await this.key();
    return Isolate.run(() => openFileNow(key, file.path));
  }

  /// Writes [bytes] to [file], sealed; through a temporary file beside
  /// it, so a file half-written is never taken for a whole one.
  Future<void> write(File file, List<int> bytes) async {
    final key = await this.key();
    await file.parent.create(recursive: true);
    final plain = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
    await Isolate.run(() => sealBytesNow(key, plain, file.path));
  }

  /// Seals [source], a plain file, into [destination] (which may be the
  /// same file), reading it a chunk at a time.
  Future<void> sealFrom(File source, File destination) async {
    final key = await this.key();
    await destination.parent.create(recursive: true);
    await Isolate.run(() => sealFileNow(key, source.path, destination.path));
  }

  /// The SHA-256 of [file]'s bytes as they are, opened, in lowercase hex:
  /// the name a picture goes by, whether sealed here or not.
  Future<String> hashOf(File file) async {
    final key = await this.key();
    return Isolate.run(() => hashFileNow(key, file.path));
  }

  /// [file] opened into a temporary file, for what can only play a path
  /// (a video, a recording). The caller deletes it when done
  /// ([release]); whatever is left is cleared at the next start.
  Future<File> openCopy(File file) async {
    final key = await this.key();
    final directory = Directory(p.join((await _temporary()).path, openFolder));
    await directory.create(recursive: true);
    final copy = File(
      p.join(
        directory.path,
        '${DateTime.now().microsecondsSinceEpoch}-${p.basename(file.path)}',
      ),
    );
    await Isolate.run(() => openFileToNow(key, file.path, copy.path));
    return copy;
  }

  /// Deletes a copy [openCopy] made, and nothing else: a file outside
  /// the copies' folder (the original, where there was no vault to open
  /// it with) is left alone.
  static Future<void> release(File? copy) async {
    if (copy == null) return;
    if (!p.split(copy.parent.path).contains(openFolder)) return;
    try {
      if (copy.existsSync()) await copy.delete();
    } on FileSystemException catch (error) {
      debugPrint('[vault] copy left behind: ${error.osError?.message}');
    }
  }

  static const openFolder = 'opened';

  /// Deletes every copy [openCopy] left behind.
  Future<void> clearCopies() async {
    final directory = Directory(p.join((await _temporary()).path, openFolder));
    if (directory.existsSync()) await directory.delete(recursive: true);
  }

  /// Seals every plain file under [roots] in place: sealed, opened again
  /// and checked against the plain bytes' hash, and only then put where
  /// the plain file was. Killed half-way, it starts again where it
  /// stopped: a file already sealed is skipped, and a temporary file
  /// left behind is thrown away. Answers how many were sealed.
  Future<int> sealAll(Iterable<Directory> roots) async {
    final key = await this.key();
    final paths = [
      for (final root in roots)
        if (root.existsSync())
          for (final entity in root.listSync(recursive: true))
            if (entity is File) entity.path,
    ];
    return Isolate.run(() => sealAllNow(key, paths));
  }
}

@Riverpod(keepAlive: true)
FileVault fileVault(Ref ref) => FileVault(ref.watch(secretStoreProvider));

// ------------------------------------------------- the isolate's own work

/// How old a temporary file must be before a start takes it for one a
/// killed run left behind, rather than a write going on now.
const staleLeftover = Duration(minutes: 10);

/// What one write of a sealed file leaves beside it until it is whole.
const _partial = '.sealing';

/// A plain file sealed beside itself, until it is checked and takes its
/// place.
const _staged = '.sealed';

final _aes = AesGcm.with256bits();

List<int> _nonce(List<int> prefix, int chunk) => [
  ...prefix,
  (chunk >> 24) & 0xff,
  (chunk >> 16) & 0xff,
  (chunk >> 8) & 0xff,
  chunk & 0xff,
];

Future<List<int>> _sealChunk(
  SecretKey key,
  List<int> prefix,
  int index,
  List<int> plain, {
  required bool last,
}) async {
  final box = await _aes.encrypt(
    plain,
    secretKey: key,
    nonce: _nonce(prefix, index),
    aad: [if (last) 1 else 0],
  );
  return [...box.cipherText, ...box.mac.bytes];
}

/// Seals [plain] into the file at [path].
Future<void> sealBytesNow(List<int> key, Uint8List plain, String path) async {
  final secret = SecretKey(key);
  final prefix = List<int>.generate(
    FileVault._prefixBytes,
    (_) => Random.secure().nextInt(256),
  );
  final temp = File('$path$_partial');
  final sink = temp.openWrite()
    ..add(FileVault._magic)
    ..add(prefix);
  var index = 0;
  var at = 0;
  do {
    final end = min(at + FileVault.chunkBytes, plain.length);
    final last = end == plain.length;
    sink.add(
      await _sealChunk(
        secret,
        prefix,
        index++,
        Uint8List.sublistView(plain, at, end),
        last: last,
      ),
    );
    at = end;
  } while (at < plain.length);
  await sink.flush();
  await sink.close();
  await temp.rename(path);
}

/// Seals the plain file at [source] into [destination], a chunk at a time.
Future<void> sealFileNow(
  List<int> key,
  String source,
  String destination,
) async {
  final secret = SecretKey(key);
  final prefix = List<int>.generate(
    FileVault._prefixBytes,
    (_) => Random.secure().nextInt(256),
  );
  final input = File(source).openSync();
  final temp = File('$destination$_partial');
  final sink = temp.openWrite()
    ..add(FileVault._magic)
    ..add(prefix);
  try {
    final length = input.lengthSync();
    var index = 0;
    var at = 0;
    do {
      final plain = input.readSync(FileVault.chunkBytes);
      at += plain.length;
      final last = at >= length;
      sink.add(await _sealChunk(secret, prefix, index++, plain, last: last));
    } while (at < length);
  } finally {
    input.closeSync();
    await sink.flush();
    await sink.close();
  }
  await temp.rename(destination);
}

/// The opened chunks of the file at [path], in order; a plain file's
/// bytes as they are.
Stream<List<int>> openChunksNow(List<int> key, String path) async* {
  final file = File(path);
  final input = file.openSync();
  try {
    final head = input.readSync(FileVault._headerBytes);
    if (head.length < 4 || !listEquals(head.sublist(0, 4), FileVault._magic)) {
      // Not sealed yet: the bytes are the file.
      input.setPositionSync(0);
      for (;;) {
        final chunk = input.readSync(FileVault.chunkBytes);
        if (chunk.isEmpty) return;
        yield chunk;
      }
    }
    if (head.length < FileVault._headerBytes) {
      throw const FileSystemException('A sealed file cut short');
    }
    final secret = SecretKey(key);
    final prefix = head.sublist(4);
    final length = input.lengthSync();
    const sealed = FileVault.chunkBytes + FileVault._tagBytes;
    var index = 0;
    var at = FileVault._headerBytes;
    do {
      final chunk = input.readSync(sealed);
      at += chunk.length;
      if (chunk.length < FileVault._tagBytes) {
        throw const FileSystemException('A sealed file cut short');
      }
      final last = at >= length;
      final box = SecretBox(
        chunk.sublist(0, chunk.length - FileVault._tagBytes),
        nonce: _nonce(prefix, index++),
        mac: Mac(chunk.sublist(chunk.length - FileVault._tagBytes)),
      );
      yield await _aes.decrypt(
        box,
        secretKey: secret,
        aad: [if (last) 1 else 0],
      );
    } while (at < length);
  } finally {
    input.closeSync();
  }
}

/// The file at [path], opened, whole.
Future<Uint8List> openFileNow(List<int> key, String path) async {
  final out = BytesBuilder(copy: false);
  await openChunksNow(key, path).forEach(out.add);
  return out.takeBytes();
}

/// The file at [source], opened into [destination].
Future<void> openFileToNow(
  List<int> key,
  String source,
  String destination,
) async {
  final sink = File(destination).openWrite();
  try {
    await openChunksNow(key, source).forEach(sink.add);
  } finally {
    await sink.flush();
    await sink.close();
  }
}

/// The SHA-256 of the file at [path], opened, in lowercase hex.
Future<String> hashFileNow(List<int> key, String path) async {
  final sink = const DartSha256().newHashSink();
  await openChunksNow(key, path).forEach(sink.add);
  sink.close();
  return _hex((await sink.hash()).bytes);
}

/// Seals each plain file of [paths] in place, checked; see
/// [FileVault.sealAll].
Future<int> sealAllNow(List<int> key, List<String> paths) async {
  var sealed = 0;
  for (final path in paths) {
    // Left by a run killed half-way: the file it was for is still whole.
    // One written a moment ago may be a write going on right now, beside
    // this start, and is left to finish.
    if (path.endsWith(_partial) || path.endsWith(_staged)) {
      final leftover = File(path);
      final age = DateTime.now().difference(leftover.lastModifiedSync());
      if (age > staleLeftover) await leftover.delete();
      continue;
    }
    final file = File(path);
    if (!file.existsSync() || FileVault.isSealed(file)) continue;
    try {
      final plainHash = await hashFileNow(key, path);
      final staged = '$path$_staged';
      await sealFileNow(key, path, staged);
      if (await hashFileNow(key, staged) != plainHash) {
        await File(staged).delete();
        continue;
      }
      await File(staged).rename(path);
      sealed++;
    } on Object catch (error) {
      // One file that will not seal never stops the rest; it is tried
      // again on the next start.
      debugPrint('[vault] could not seal a file: ${error.runtimeType}');
    }
  }
  return sealed;
}

String _hex(List<int> bytes) => [
  for (final byte in bytes) byte.toRadixString(16).padLeft(2, '0'),
].join();
