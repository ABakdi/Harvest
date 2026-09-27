import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart' show Sha256;
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/features/sync/domain/file_sync.dart';
import 'package:harvest/features/sync/domain/sync_cipher.dart';
import 'package:harvest/features/sync/domain/sync_service.dart' show SyncKeys;

/// The server as the file routes behave: it keeps bytes under the name
/// it is given, and has no key to check them with.
class FakeFiles implements FileRemote {
  final Map<String, ({Uint8List sealed, String iv})> held = {};
  int uploads = 0;

  /// Hashes whose upload fails, as a flaky network would.
  final failing = <String>{};

  @override
  Future<List<String>> missing(List<String> hashes) async =>
      hashes.where((hash) => !held.containsKey(hash)).toList();

  @override
  Future<void> upload(String sha256, Uint8List sealed, String iv) async {
    if (failing.contains(sha256)) throw StateError('connection reset');
    held[sha256] = (sealed: sealed, iv: iv);
    uploads += 1;
  }

  @override
  Future<({Uint8List sealed, String iv})> download(String sha256) async {
    final one = held[sha256];
    if (one == null) throw StateError('no such file');
    return one;
  }
}

void main() {
  late Directory phoneA;
  late Directory phoneB;
  late HarvestDatabase a;
  late HarvestDatabase b;
  late FakeFiles remote;
  late SyncCipher cipher;

  setUp(() async {
    phoneA = await Directory.systemTemp.createTemp('harvest-a');
    phoneB = await Directory.systemTemp.createTemp('harvest-b');
    a = HarvestDatabase.forTesting(NativeDatabase.memory());
    b = HarvestDatabase.forTesting(NativeDatabase.memory());
    remote = FakeFiles();
    cipher = SyncCipher(List<int>.generate(32, (index) => index));
  });

  tearDown(() async {
    await a.close();
    await b.close();
    await phoneA.delete(recursive: true);
    await phoneB.delete(recursive: true);
  });

  /// A memory row and the file it points at.
  Future<void> picture(
    HarvestDatabase db,
    Directory root,
    String uuid,
    List<int> bytes, {
    bool write = true,
    String? fileHash,
  }) async {
    await db
        .into(db.albums)
        .insertOnConflictUpdate(
          AlbumsCompanion.insert(uuid: 'album', name: 'Gym'),
        );
    await db
        .into(db.memories)
        .insertOnConflictUpdate(
          MemoriesCompanion.insert(
            uuid: uuid,
            albumUuid: 'album',
            harvestDay: '2026-09-20',
            path: '$uuid.jpg',
            fileHash: Value(fileHash),
          ),
        );
    if (write) await File('${root.path}/$uuid.jpg').writeAsBytes(bytes);
  }

  FileSync syncOf(HarvestDatabase db) => FileSync(db, remote, cipher);

  Future<FileReport> run(HarvestDatabase db, Directory root) => syncOf(db).run(
    gallery: (relative) async => File('${root.path}/$relative'),
    attachments: (relative) async => File('${root.path}/$relative'),
  );

  test('a picture goes up sealed, and comes down on the other phone', () async {
    final bytes = List<int>.generate(2048, (index) => index % 256);
    await picture(a, phoneA, 'm1', bytes);

    final up = await run(a, phoneA);
    expect(up.uploaded, 1);

    // What the server holds is not the picture.
    final stored = remote.held.values.single.sealed;
    expect(stored, isNot(equals(bytes)));

    // The row travels with its hash, as sync would carry it.
    final hash = (await a.select(a.memories).getSingle()).fileHash;
    expect(hash, isNotNull);
    await picture(b, phoneB, 'm1', bytes, write: false, fileHash: hash);

    final down = await run(b, phoneB);
    expect(down.downloaded, 1);
    expect(await File('${phoneB.path}/m1.jpg').readAsBytes(), bytes);
  });

  test('naming the file makes the row newer, so the server takes it', () async {
    await picture(a, phoneA, 'm1', List<int>.generate(64, (index) => index));
    final before = (await a.select(a.memories).getSingle()).updatedAt;
    await Future<void>.delayed(const Duration(milliseconds: 5));

    await run(a, phoneA);

    final after = await a.select(a.memories).getSingle();
    expect(after.fileHash, isNotNull);
    expect(after.updatedAt.isAfter(before), isTrue);
  });

  test('the same picture on two phones is one file on the server', () async {
    final bytes = List<int>.generate(512, (index) => index % 7);
    await picture(a, phoneA, 'm1', bytes);
    await picture(b, phoneB, 'm2', bytes);

    await run(a, phoneA);
    await run(b, phoneB);

    expect(remote.uploads, 1);
    expect(remote.held, hasLength(1));
    // Both rows carry the name, because both files are that file.
    final second = await b.select(b.memories).getSingle();
    expect(second.fileHash, remote.held.keys.single);
  });

  test('an upload happens once, however often sync runs', () async {
    await picture(a, phoneA, 'm1', List<int>.filled(64, 3));
    await run(a, phoneA);
    final second = await run(a, phoneA);

    expect(remote.uploads, 1);
    expect(second.uploaded, isZero);
  });

  test('bytes that do not hash to their name are not written', () async {
    final bytes = List<int>.generate(128, (index) => index);
    await picture(a, phoneA, 'm1', bytes);
    await run(a, phoneA);
    final hash = (await a.select(a.memories).getSingle()).fileHash!;

    // The server hands back something else under that name.
    final lie = await cipher.sealBytes(hash, List<int>.filled(128, 9));
    remote.held[hash] = (sealed: lie.bytes, iv: remote.held[hash]!.iv);
    await picture(b, phoneB, 'm1', bytes, write: false, fileHash: hash);

    final report = await run(b, phoneB);
    expect(report.downloaded, isZero);
    expect(report.missing, 1);
    expect(File('${phoneB.path}/m1.jpg').existsSync(), isFalse);
  });

  test('a file the server does not have leaves the row alone', () async {
    await picture(b, phoneB, 'm1', const [], write: false, fileHash: 'a' * 64);
    final report = await run(b, phoneB);
    expect(report.missing, 1);
    expect((await b.select(b.memories).getSingle()).fileHash, 'a' * 64);
  });

  test('a file too large for the server is left out, and the rest still '
      'go up and come down (Q5-06)', () async {
    await picture(a, phoneA, 'small', List<int>.filled(64, 1));
    await picture(a, phoneA, 'huge', const []);
    final huge = File('${phoneA.path}/huge.jpg');
    final sink = huge.openWrite();
    for (var i = 0; i <= maxFileBytes ~/ (1024 * 1024); i++) {
      sink.add(Uint8List(1024 * 1024));
    }
    await sink.close();

    // Something for the other direction too, waiting on the server.
    final bytes = List<int>.generate(256, (index) => index % 13);
    await picture(b, phoneB, 'there', bytes);
    await run(b, phoneB);
    final hash = (await b.select(b.memories).getSingle()).fileHash;
    await picture(a, phoneA, 'there', bytes, write: false, fileHash: hash);

    final report = await run(a, phoneA);
    expect(report.tooLarge, 1);
    expect(report.uploaded, 1);
    expect(report.downloaded, 1);
    final rows = {
      for (final row in await a.select(a.memories).get()) row.uuid: row,
    };
    expect(rows['huge']!.fileHash, isNull);
    expect(rows['small']!.fileHash, isNotNull);
  });

  test('one file that fails to go up never holds up the others '
      '(Q5-06)', () async {
    final bad = List<int>.filled(64, 5);
    await picture(a, phoneA, 'bad', bad);
    await picture(a, phoneA, 'good', List<int>.filled(64, 6));
    final sha = await Sha256().hash(bad);
    remote.failing.add(
      sha.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
    );

    final report = await run(a, phoneA);
    expect(report.uploaded, 1);
    expect(report.failed, 1);
    final rows = {
      for (final row in await a.select(a.memories).get()) row.uuid: row,
    };
    // Not named, so it is tried again next time.
    expect(rows['bad']!.fileHash, isNull);
    expect(rows['good']!.fileHash, isNotNull);

    remote.failing.clear();
    expect((await run(a, phoneA)).uploaded, 1);
  });

  test('after a restore, named files the server lacks go up too '
      '(Q5-05)', () async {
    final bytes = List<int>.generate(300, (index) => index % 17);
    await picture(a, phoneA, 'm1', bytes);
    await run(a, phoneA);
    final hash = (await a.select(a.memories).getSingle()).fileHash!;

    // A new server, or a new account: it has none of them.
    remote.held.clear();
    expect((await run(a, phoneA)).uploaded, 0, reason: 'nothing asked');

    await a
        .into(a.kvSettings)
        .insert(
          KvSettingsCompanion.insert(
            key: SyncKeys.checkFiles,
            valueJson: '"true"',
          ),
        );
    expect((await run(a, phoneA)).uploaded, 1);
    expect(remote.held.keys, [hash]);
    // Asked once: the flag goes when everything is there.
    expect(
      await (a.select(
        a.kvSettings,
      )..where((s) => s.key.equals(SyncKeys.checkFiles))).getSingleOrNull(),
      isNull,
    );
  });

  test('a purge lets go of its file, unless another row still names it '
      '(Q5-23)', () async {
    final forgotten = <String>[];
    final deleted = <String>[];
    final purged = PurgedFiles(
      a,
      gallery: (relative) async => deleted.add(relative),
      attachments: (relative) async => deleted.add(relative),
      forget: (hash) async => forgotten.add(hash),
    );
    await picture(a, phoneA, 'kept', const [], fileHash: 'c' * 64);
    await purged.release('memories', {
      'uuid': 'gone',
      'path': 'gone.jpg',
      'file_hash': 'd' * 64,
    });
    await purged.release('memories', {
      'uuid': 'twin',
      'path': 'kept.jpg',
      'file_hash': 'c' * 64,
    });
    await purged.release('memories', {'uuid': 'x', 'path': '../escape.jpg'});
    expect(deleted, ['gone.jpg']);
    expect(forgotten, ['d' * 64]);
  });
}
