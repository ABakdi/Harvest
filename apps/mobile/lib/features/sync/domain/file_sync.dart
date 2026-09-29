import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart' show DartSha256;
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:harvest/core/db/database.dart';
import 'package:harvest/core/security/file_vault.dart';
import 'package:harvest/features/account/data/api_client.dart'
    show ApiException;
import 'package:harvest/features/gallery/data/gallery_storage.dart';
import 'package:harvest/features/sync/domain/sync_cipher.dart';
import 'package:harvest/features/sync/domain/sync_service.dart';
import 'package:meta/meta.dart';

/// The biggest single file, before sealing, that the server takes
/// (`maxFileBytes` in `packages/contracts/src/files.ts`).
const int maxFileBytes = 25 * 1024 * 1024;

/// How many hashes one "do you have these?" question may carry
/// (`maxFileQuery`).
const int maxFileQuery = 500;

/// The file routes, as the phone needs them ([[Sync-API]]). Every name
/// here is the file's name on the server ([[SyncCipher.nameOf]]), never
/// the plaintext's SHA-256.
abstract interface class FileRemote {
  /// Which of [names] the server does not have.
  Future<List<String>> missing(List<String> names);

  /// Uploads sealed bytes under their server name, saying which key
  /// epoch sealed them.
  Future<void> upload(
    String name,
    Uint8List sealed,
    String iv, {
    required int keyEpoch,
  });

  /// Downloads sealed bytes, with the nonce they were sealed with.
  Future<({Uint8List sealed, String iv})> download(String name);
}

/// One local file a row points at.
@immutable
class SyncableFile {
  const SyncableFile({
    required this.table,
    required this.rowUuid,
    required this.file,
    required this.hash,
    this.updatedAt,
  });

  final String table;
  final String rowUuid;
  final File file;

  /// The row's own clock, so naming the file comes after it.
  final DateTime? updatedAt;

  /// The hash already stored on the row, or null while it has none.
  final String? hash;
}

/// What one file pass did.
@immutable
class FileReport {
  const FileReport({
    this.uploaded = 0,
    this.downloaded = 0,
    this.missing = 0,
    this.tooLarge = 0,
    this.failed = 0,
  });

  final int uploaded;
  final int downloaded;

  /// Files a row names that neither this phone nor the server has.
  final int missing;

  /// Files over [maxFileBytes]: kept on this phone, never sent.
  final int tooLarge;

  /// Files that could not be read, sealed or sent this time; the next
  /// run tries them again.
  final int failed;
}

/// Pictures and recordings, up and down ([[Sync-API]]).
///
/// A file is known here by the SHA-256 of its own bytes, and on the
/// server by a keyed hash of that ([[SyncCipher.nameOf]]), so the same
/// picture on two phones is one file on the server and travels once,
/// and the server cannot tell which picture it is. The bytes go padded
/// and sealed with the private tier's key, which is why this runs only
/// once a passphrase is set: a picture is as personal as an expense.
///
/// Nothing here blocks a row. A file that fails to upload is tried
/// again on the next sync, and a row whose file has not arrived yet
/// shows as a picture on another device ([[Gallery]]).
class FileSync {
  FileSync(
    this._db,
    this._remote,
    this._cipher, {
    this.batch = 20,
    this.vault,
  });

  final HarvestDatabase _db;
  final FileRemote _remote;
  final SyncCipher _cipher;

  /// Where the files are sealed on this phone ([FileVault]): read and
  /// written through it. Null only in a test with no Keystore.
  final FileVault? vault;

  Future<Uint8List> _read(File file) => vault?.read(file) ?? file.readAsBytes();

  Future<String> _hash(File file) => vault?.hashOf(file) ?? hashFile(file.path);

  /// How many files one sync carries, so a year of pictures is spread
  /// over several runs rather than one very long one.
  final int batch;

  static final _sha = Sha256();

  Future<FileReport> run({
    required Future<File?> Function(String relative) gallery,
    required Future<File?> Function(String relative) attachments,
  }) async {
    final locals = await _locals(gallery: gallery, attachments: attachments);
    final up = await _upload(locals.where((one) => one.hash == null));
    var uploaded = up.sent;
    var tooLarge = up.tooLarge;
    var failed = up.failed;
    if (await _checkAsked()) {
      final check = await _recheck(locals.where((one) => one.hash != null));
      uploaded += check.sent;
      tooLarge += check.tooLarge;
      failed += check.failed;
      if (check.done) await _checkDone();
    }
    // Downloads run whatever the uploads did: a file that will not go
    // up never keeps the others from coming down (Q5-06).
    final downloaded = await _download(
      gallery: gallery,
      attachments: attachments,
    );
    return FileReport(
      uploaded: uploaded,
      downloaded: downloaded.downloaded,
      missing: downloaded.missing,
      tooLarge: tooLarge,
      failed: failed,
    );
  }

  /// Fetches one file now, for a picture on screen that has not come
  /// down yet ([[Gallery]] G9). False when the server does not have it
  /// or it would not open.
  Future<bool> fetch(String hash, File destination) async {
    try {
      return await _fetch(hash, destination);
    } on Object catch (error) {
      debugPrint('[sync] could not fetch a file: ${error.runtimeType}');
      return false;
    }
  }

  /// Every file this phone holds that a live row points at.
  Future<List<SyncableFile>> _locals({
    required Future<File?> Function(String relative) gallery,
    required Future<File?> Function(String relative) attachments,
  }) async {
    final out = <SyncableFile>[];
    final memories = await (_db.select(
      _db.memories,
    )..where((m) => m.deletedAt.isNull())).get();
    for (final row in memories) {
      final file = await gallery(row.path);
      if (file != null && file.existsSync()) {
        out.add(
          SyncableFile(
            table: 'memories',
            rowUuid: row.uuid,
            file: file,
            hash: row.fileHash,
            updatedAt: row.updatedAt,
          ),
        );
      }
    }
    final recordings = await (_db.select(
      _db.noteAttachments,
    )..where((a) => a.deletedAt.isNull())).get();
    for (final row in recordings) {
      final file = await attachments(row.storedPath);
      if (file != null && file.existsSync()) {
        out.add(
          SyncableFile(
            table: 'note_attachments',
            rowUuid: row.uuid,
            file: file,
            hash: row.fileHash,
            updatedAt: row.updatedAt,
          ),
        );
      }
    }
    return out;
  }

  /// Hashes what has no hash, asks what the server lacks, and sends it.
  ///
  /// A file over [maxFileBytes] is left out, and a file that fails is
  /// counted and left for the next run: neither holds up the rest.
  Future<({int sent, int tooLarge, int failed})> _upload(
    Iterable<SyncableFile> candidates,
  ) async {
    var tooLarge = 0;
    var failed = 0;
    final taken = <SyncableFile>[];
    for (final one in candidates) {
      if (taken.length >= batch) break;
      if (_tooLarge(one.file)) {
        tooLarge += 1;
        continue;
      }
      taken.add(one);
    }
    if (taken.isEmpty) return (sent: 0, tooLarge: tooLarge, failed: 0);

    // Hashed as a stream, off the UI isolate, one file at a time: no
    // batch of pictures is ever held in memory at once (P6-07).
    final named = <String, List<SyncableFile>>{};
    for (final one in taken) {
      try {
        final hash = await _hash(one.file);
        (named[hash] ??= []).add(one);
      } on Object catch (error) {
        debugPrint('[sync] could not read a file: ${error.runtimeType}');
        failed += 1;
      }
    }
    if (named.isEmpty) return (sent: 0, tooLarge: tooLarge, failed: failed);

    final names = {
      for (final hash in named.keys) await _cipher.nameOf(hash): hash,
    };
    final wanted = {
      for (final name in await _remote.missing(names.keys.toList()))
        if (names[name] != null) names[name]!,
    };
    var sent = 0;
    for (final hash in wanted) {
      final one = named[hash]?.first;
      if (one == null) continue;
      // Read only for the files the server lacks, and only one at a time.
      final Uint8List plain;
      try {
        plain = await _read(one.file);
      } on Object {
        failed += 1;
        named.remove(hash);
        continue;
      }
      if (await _send(hash, plain)) {
        sent += 1;
      } else {
        failed += 1;
        named.remove(hash);
      }
    }
    // Rows are stamped whether or not this phone did the sending: the
    // server has the file either way, and the hash is what says so.
    for (final entry in named.entries) {
      for (final one in entry.value) {
        await _stamp(one, entry.key);
      }
    }
    return (sent: sent, tooLarge: tooLarge, failed: failed);
  }

  /// Asks the server about files that already carry a name, and sends
  /// what it lacks: after an archive is restored, or on a new account
  /// or server, a named file is not a file the server has (Q5-05).
  Future<({int sent, int tooLarge, int failed, bool done})> _recheck(
    Iterable<SyncableFile> named,
  ) async {
    final byHash = <String, SyncableFile>{};
    for (final one in named) {
      byHash.putIfAbsent(one.hash!, () => one);
    }
    final hashOf = {
      for (final hash in byHash.keys) await _cipher.nameOf(hash): hash,
    };
    final names = hashOf.keys.toList();
    final missing = <String>[];
    for (var i = 0; i < names.length; i += maxFileQuery) {
      final end = i + maxFileQuery > names.length
          ? names.length
          : i + maxFileQuery;
      for (final name in await _remote.missing(names.sublist(i, end))) {
        final hash = hashOf[name];
        if (hash != null) missing.add(hash);
      }
    }
    var sent = 0;
    var tooLarge = 0;
    var failed = 0;
    var tried = 0;
    for (final hash in missing) {
      final one = byHash[hash];
      if (one == null) continue;
      if (_tooLarge(one.file)) {
        tooLarge += 1;
        continue;
      }
      if (tried >= batch) {
        // The rest go on the next run.
        return (sent: sent, tooLarge: tooLarge, failed: failed, done: false);
      }
      tried += 1;
      try {
        final plain = await _read(one.file);
        // A file that is no longer what its name says is not sent under
        // that name.
        if (await _hashOf(plain) != hash) continue;
        if (await _send(hash, plain)) {
          sent += 1;
        } else {
          failed += 1;
        }
      } on Object catch (error) {
        debugPrint('[sync] could not read a file: ${error.runtimeType}');
        failed += 1;
      }
    }
    return (sent: sent, tooLarge: tooLarge, failed: failed, done: failed == 0);
  }

  Future<bool> _send(String hash, Uint8List plain) async {
    try {
      final name = await _cipher.nameOf(hash);
      final sealed = await _cipher.sealFile(name, plain);
      await _remote.upload(
        name,
        sealed.bytes,
        _base64(sealed.iv),
        keyEpoch: _cipher.epoch,
      );
      return true;
    } on ApiException catch (error) {
      // The PIN was started over elsewhere: nothing more goes up under
      // this key (S6-07).
      if (error.code == 'key_changed') throw const SyncKeyChanged();
      debugPrint('[sync] could not send a file: ${error.code}');
      return false;
    } on Object catch (error) {
      debugPrint('[sync] could not send a file: ${error.runtimeType}');
      return false;
    }
  }

  static bool _tooLarge(File file) {
    try {
      return file.lengthSync() > maxFileBytes;
    } on FileSystemException {
      return false;
    }
  }

  Future<bool> _checkAsked() async {
    final row = await (_db.select(
      _db.kvSettings,
    )..where((s) => s.key.equals(SyncKeys.checkFiles))).getSingleOrNull();
    return row != null && row.valueJson.contains('true');
  }

  Future<void> _checkDone() => (_db.delete(
    _db.kvSettings,
  )..where((s) => s.key.equals(SyncKeys.checkFiles))).go();

  /// Fetches files this phone does not have but a row names.
  Future<({int downloaded, int missing})> _download({
    required Future<File?> Function(String relative) gallery,
    required Future<File?> Function(String relative) attachments,
  }) async {
    var got = 0;
    var absent = 0;
    final memories = await (_db.select(
      _db.memories,
    )..where((m) => m.deletedAt.isNull() & m.fileHash.isNotNull())).get();
    for (final row in memories) {
      if (got >= batch) break;
      final file = await gallery(row.path);
      if (file == null || file.existsSync()) continue;
      if (await fetch(row.fileHash!, file)) {
        got += 1;
      } else {
        absent += 1;
      }
    }
    final recordings = await (_db.select(
      _db.noteAttachments,
    )..where((a) => a.deletedAt.isNull() & a.fileHash.isNotNull())).get();
    for (final row in recordings) {
      if (got >= batch) break;
      final file = await attachments(row.storedPath);
      if (file == null || file.existsSync()) continue;
      if (await fetch(row.fileHash!, file)) {
        got += 1;
      } else {
        absent += 1;
      }
    }
    return (downloaded: got, missing: absent);
  }

  /// Fetches one file and writes it where its row says it lives.
  ///
  /// The bytes are checked against the hash the row names before they
  /// are written: a file that does not hash to it is not the file the
  /// row means, and is dropped rather than saved.
  Future<bool> _fetch(String hash, File destination) async {
    final Uint8List plain;
    try {
      var name = await _cipher.nameOf(hash);
      ({Uint8List sealed, String iv}) answer;
      try {
        answer = await _remote.download(name);
      } on ApiException catch (error) {
        // Sent before Phase 7, under the plaintext's own hash, and not
        // sent again or swept yet.
        if (error.status != 404) rethrow;
        name = hash;
        answer = await _remote.download(name);
      }
      plain = await _cipher.openFile(name, _bytes(answer.iv), answer.sealed);
    } on Object {
      return false;
    }
    if (await _hashOf(plain) != hash) return false;
    await destination.parent.create(recursive: true);
    final vault = this.vault;
    if (vault == null) {
      await destination.writeAsBytes(plain, flush: true);
    } else {
      await vault.write(destination, plain);
    }
    return true;
  }

  Future<void> _stamp(SyncableFile one, String hash) async {
    if (one.hash == hash) return;
    // A newer stamp, or the server keeps the copy it already has and
    // the name never reaches the other devices: after the row's own
    // clock, even when this phone's clock is behind it (Q5-10).
    final floor = one.updatedAt?.add(const Duration(microseconds: 1));
    final clock = DateTime.now();
    final now = Value(floor != null && floor.isAfter(clock) ? floor : clock);
    if (one.table == 'memories') {
      await (_db.update(_db.memories)..where((m) => m.uuid.equals(one.rowUuid)))
          .write(MemoriesCompanion(fileHash: Value(hash), updatedAt: now));
    } else {
      await (_db.update(
        _db.noteAttachments,
      )..where((a) => a.uuid.equals(one.rowUuid))).write(
        NoteAttachmentsCompanion(fileHash: Value(hash), updatedAt: now),
      );
    }
    // The row travels again so the other devices learn the name.
    await _db.logChange(one.table, one.rowUuid, 'update');
  }

  /// The SHA-256 of the file at [path], read as a stream in a
  /// background isolate.
  static Future<String> hashFile(String path) =>
      Isolate.run(() => _hashFileNow(path));

  static Future<String> _hashFileNow(String path) async {
    final sink = const DartSha256().newHashSink();
    await File(path).openRead().forEach(sink.add);
    sink.close();
    final digest = await sink.hash();
    return [
      for (final byte in digest.bytes) byte.toRadixString(16).padLeft(2, '0'),
    ].join();
  }

  static Future<String> _hashOf(List<int> bytes) async {
    final digest = await _sha.hash(bytes);
    return [
      for (final byte in digest.bytes) byte.toRadixString(16).padLeft(2, '0'),
    ].join();
  }

  static String _base64(Uint8List bytes) => base64Encode(bytes);

  static Uint8List _bytes(String base64) =>
      Uint8List.fromList(base64Decode(base64));
}

/// What a purge leaves on disk, let go of ([[Sync-API]]: tombstones).
///
/// A row another device purged is gone here too; its picture or
/// recording goes with it, unless another row still names the same
/// file. When no row names the file's hash any more, the server is told
/// it can let it go as well ([forget] takes the plaintext's hash, and
/// names it for the server itself).
class PurgedFiles {
  PurgedFiles(
    this._db, {
    required this.gallery,
    required this.attachments,
    this.forget,
  });

  final HarvestDatabase _db;
  final Future<void> Function(String relative) gallery;
  final Future<void> Function(String relative) attachments;
  final Future<void> Function(String sha256)? forget;

  Future<void> release(String table, Map<String, Object?> row) async {
    final (path, column, delete) = switch (table) {
      'memories' => (row['path'], 'path', gallery),
      'note_attachments' => (row['stored_path'], 'stored_path', attachments),
      _ => (null, '', null),
    };
    if (path is! String || delete == null) return;
    if (path.isEmpty || !GalleryStorage.isSafeRelative(path)) return;
    final others = await _db
        .customSelect(
          'SELECT 1 FROM "$table" WHERE "$column" = ? LIMIT 1',
          variables: [Variable(path)],
        )
        .get();
    if (others.isEmpty) await delete(path);

    final hash = row['file_hash'];
    final tell = forget;
    if (hash is! String || tell == null) return;
    final named = await _db
        .customSelect(
          'SELECT 1 FROM memories WHERE file_hash = ? '
          'UNION ALL SELECT 1 FROM note_attachments WHERE file_hash = ? '
          'LIMIT 1',
          variables: [Variable(hash), Variable(hash)],
        )
        .get();
    if (named.isEmpty) await tell(hash);
  }
}
