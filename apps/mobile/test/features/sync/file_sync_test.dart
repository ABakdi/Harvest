import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/db/database.dart';
import 'package:harvest/features/sync/domain/file_sync.dart';
import 'package:harvest/features/sync/domain/sync_cipher.dart';

/// The server as the file routes behave: it keeps bytes under the name
/// it is given, and has no key to check them with.
class FakeFiles implements FileRemote {
  final held = <String, ({Uint8List sealed, String iv})>{};
  var uploads = 0;

  @override
  Future<List<String>> missing(List<String> hashes) async =>
      hashes.where((hash) => !held.containsKey(hash)).toList();

  @override
  Future<void> upload(String sha256, Uint8List sealed, String iv) async {
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
}
