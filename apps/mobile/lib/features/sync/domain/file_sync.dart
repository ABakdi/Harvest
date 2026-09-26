import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/features/sync/domain/sync_cipher.dart';
import 'package:meta/meta.dart';

/// The file routes, as the phone needs them ([[Sync-API]]).
abstract interface class FileRemote {
  /// Which of [hashes] the server does not have.
  Future<List<String>> missing(List<String> hashes);

  /// Uploads sealed bytes under their plaintext's name.
  Future<void> upload(String sha256, Uint8List sealed, String iv);

  /// Downloads sealed bytes, with the nonce they were sealed with.
  Future<({Uint8List sealed, String iv})> download(String sha256);
}

/// One local file a row points at.
@immutable
class SyncableFile {
  const SyncableFile({
    required this.table,
    required this.rowUuid,
    required this.file,
    required this.hash,
  });

  final String table;
  final String rowUuid;
  final File file;

  /// The hash already stored on the row, or null while it has none.
  final String? hash;
}

/// What one file pass did.
@immutable
class FileReport {
  const FileReport({this.uploaded = 0, this.downloaded = 0, this.missing = 0});

  final int uploaded;
  final int downloaded;

  /// Files a row names that neither this phone nor the server has.
  final int missing;
}

/// Pictures and recordings, up and down ([[Sync-API]]).
///
/// A file is named by the SHA-256 of its own bytes, so the same picture
/// on two phones is one file on the server and travels once. The bytes
/// go sealed with the private tier's key, which is why this runs only
/// once a passphrase is set: a picture is as personal as an expense.
///
/// Nothing here blocks a row. A file that fails to upload is tried
/// again on the next sync, and a row whose file has not arrived yet
/// shows as a picture on another device ([[Gallery]]).
class FileSync {
  FileSync(this._db, this._remote, this._cipher, {this.batch = 20});

  final HarvestDatabase _db;
  final FileRemote _remote;
  final SyncCipher _cipher;

  /// How many files one sync carries, so a year of pictures is spread
  /// over several runs rather than one very long one.
  final int batch;

  static final _sha = Sha256();

  Future<FileReport> run({
    required Future<File?> Function(String relative) gallery,
    required Future<File?> Function(String relative) attachments,
  }) async {
    final locals = await _locals(gallery: gallery, attachments: attachments);
    final uploaded = await _upload(locals.where((one) => one.hash == null));
    final downloaded = await _download(gallery: gallery, attachments: attachments);
    return FileReport(
      uploaded: uploaded,
      downloaded: downloaded.downloaded,
      missing: downloaded.missing,
    );
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
          ),
        );
      }
    }
    return out;
  }

  /// Hashes what has no hash, asks what the server lacks, and sends it.
  Future<int> _upload(Iterable<SyncableFile> candidates) async {
    final taken = candidates.take(batch).toList();
    if (taken.isEmpty) return 0;

    final bytes = <String, Uint8List>{};
    final named = <String, List<SyncableFile>>{};
    for (final one in taken) {
      final plain = await one.file.readAsBytes();
      final hash = await _hashOf(plain);
      bytes[hash] = plain;
      (named[hash] ??= []).add(one);
    }

    final wanted = await _remote.missing(named.keys.toList());
    var sent = 0;
    for (final hash in wanted) {
      final sealed = await _cipher.sealBytes(hash, bytes[hash]!);
      await _remote.upload(hash, sealed.bytes, _base64(sealed.iv));
      sent += 1;
    }
    // Rows are stamped whether or not this phone did the sending: the
    // server has the file either way, and the hash is what says so.
    for (final entry in named.entries) {
      for (final one in entry.value) {
        await _stamp(one, entry.key);
      }
    }
    return sent;
  }

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
      if (await _fetch(row.fileHash!, file)) {
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
      if (await _fetch(row.fileHash!, file)) {
        got += 1;
      } else {
        absent += 1;
      }
    }
    return (downloaded: got, missing: absent);
  }

  /// Fetches one file and writes it where its row says it lives.
  ///
  /// The bytes are checked against the name they came under before they
  /// are written: a file that does not hash to its own name is not the
  /// file the row means, and is dropped rather than saved.
  Future<bool> _fetch(String hash, File destination) async {
    final Uint8List plain;
    try {
      final answer = await _remote.download(hash);
      plain = await _cipher.openBytes(
        hash,
        _bytes(answer.iv),
        answer.sealed,
      );
    } on Object {
      return false;
    }
    if (await _hashOf(plain) != hash) return false;
    await destination.parent.create(recursive: true);
    await destination.writeAsBytes(plain, flush: true);
    return true;
  }

  Future<void> _stamp(SyncableFile one, String hash) async {
    if (one.hash == hash) return;
    // A newer stamp, or the server keeps the copy it already has and
    // the name never reaches the other devices.
    final now = Value(DateTime.now());
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
