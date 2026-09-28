import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/security/file_vault.dart';

import '../../support/memory_secrets.dart';

/// Pictures and recordings sealed on disk (Phase 7, M7.4).
void main() {
  late Directory dir;
  late MemorySecrets secrets;
  late FileVault vault;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('harvest-vault');
    secrets = MemorySecrets();
    vault = FileVault(secrets, temporary: () async => dir);
  });
  tearDown(() => dir.delete(recursive: true));

  Uint8List bytesOf(int length) =>
      Uint8List.fromList(List.generate(length, (i) => (i * 7 + 3) % 256));

  Future<String> sha(List<int> bytes) async =>
      (await Sha256().hash(bytes)).bytes
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();

  test('what goes in comes out, and what is on disk is not it', () async {
    for (final length in [
      0,
      1,
      1000,
      FileVault.chunkBytes,
      FileVault.chunkBytes + 1,
      2 * FileVault.chunkBytes + 17,
    ]) {
      final plain = bytesOf(length);
      final file = File('${dir.path}/p-$length.jpg');
      await vault.write(file, plain);
      expect(FileVault.isSealed(file), isTrue);
      final disk = file.readAsBytesSync();
      expect(disk.length, greaterThan(length));
      if (length > 64) {
        expect(
          String.fromCharCodes(disk)
              .contains(String.fromCharCodes(plain.sublist(0, 64))),
          isFalse,
        );
      }
      expect(await vault.read(file), plain, reason: '$length bytes');
      expect(await vault.hashOf(file), await sha(plain));
    }
  });

  test('one key, made once and kept', () async {
    await vault.write(File('${dir.path}/a'), [1, 2, 3]);
    final kept = secrets.values[FileVault.keyName];
    expect(kept, isNotNull);
    // Another vault on the same Keystore opens it.
    final again = FileVault(secrets, temporary: () async => dir);
    expect(await again.read(File('${dir.path}/a')), [1, 2, 3]);
    expect(secrets.values[FileVault.keyName], kept);
  });

  test('a key the Keystore would not keep seals nothing', () async {
    secrets.dropWrites = true;
    await expectLater(
      vault.write(File('${dir.path}/a'), [1, 2, 3]),
      throwsA(isA<FileSystemException>()),
    );
    expect(File('${dir.path}/a').existsSync(), isFalse);
  });

  test('a file changed, cut short or keyed otherwise does not open', () async {
    final file = File('${dir.path}/a');
    await vault.write(file, bytesOf(FileVault.chunkBytes + 100));
    final disk = file.readAsBytesSync();

    final flipped = Uint8List.fromList(disk)..[40] ^= 1;
    File('${dir.path}/flipped').writeAsBytesSync(flipped);
    await expectLater(
      vault.read(File('${dir.path}/flipped')),
      throwsA(anything),
    );

    // Only the first chunk, which alone would pass for a whole file.
    File(
      '${dir.path}/cut',
    ).writeAsBytesSync(disk.sublist(0, 12 + FileVault.chunkBytes + 16));
    await expectLater(vault.read(File('${dir.path}/cut')), throwsA(anything));

    final other = FileVault(MemorySecrets(), temporary: () async => dir);
    await expectLater(other.read(file), throwsA(anything));
  });

  test('a plain file from before reads as it is', () async {
    final file = File('${dir.path}/old.jpg')..writeAsBytesSync([9, 8, 7]);
    expect(FileVault.isSealed(file), isFalse);
    expect(await vault.read(file), [9, 8, 7]);
    expect(await vault.hashOf(file), await sha([9, 8, 7]));
  });

  test('sealing every file in place: checked, resumable, and once', () async {
    final albums = Directory('${dir.path}/gallery/album')
      ..createSync(recursive: true);
    final a = File('${albums.path}/a.jpg')..writeAsBytesSync(bytesOf(3000));
    final b = File('${albums.path}/b.mp4')
      ..writeAsBytesSync(bytesOf(FileVault.chunkBytes * 2 + 5));
    // What a run killed half-way leaves, a while ago.
    final long = DateTime.now().subtract(staleLeftover * 2);
    File('${a.path}.sealed')
      ..writeAsBytesSync([1, 2])
      ..setLastModifiedSync(long);
    File('${b.path}.sealing')
      ..writeAsBytesSync([3, 4])
      ..setLastModifiedSync(long);
    // And a write going on right now, beside this start: left to finish.
    final writing = File('${albums.path}/c.jpg.sealing')
      ..writeAsBytesSync([5, 6]);
    final hashA = await sha(bytesOf(3000));

    expect(await vault.sealAll([Directory('${dir.path}/gallery')]), 2);
    expect(FileVault.isSealed(a), isTrue);
    expect(FileVault.isSealed(b), isTrue);
    expect(await vault.hashOf(a), hashA);
    expect(await vault.read(b), bytesOf(FileVault.chunkBytes * 2 + 5));
    expect(File('${a.path}.sealed').existsSync(), isFalse);
    expect(File('${b.path}.sealing').existsSync(), isFalse);
    expect(writing.existsSync(), isTrue);

    expect(await vault.sealAll([Directory('${dir.path}/gallery')]), 0);
  });

  test(
    'a plain copy to play, gone when released or at the next start',
    () async {
      final file = File('${dir.path}/voice.m4a');
      await vault.write(file, bytesOf(5000));
      final copy = await vault.openCopy(file);
      expect(copy.readAsBytesSync(), bytesOf(5000));
      await FileVault.release(copy);
      expect(copy.existsSync(), isFalse);

      // Never the file itself.
      await FileVault.release(file);
      expect(file.existsSync(), isTrue);

      final left = await vault.openCopy(file);
      await vault.clearCopies();
      expect(left.existsSync(), isFalse);
    },
  );

  test('seals a plain file into place from a stream of chunks', () async {
    final source = File('${dir.path}/staging.m4a')
      ..writeAsBytesSync(bytesOf(FileVault.chunkBytes + 3));
    final destination = File('${dir.path}/notes/n1/voice.m4a');
    await vault.sealFrom(source, destination);
    expect(FileVault.isSealed(destination), isTrue);
    expect(await vault.read(destination), bytesOf(FileVault.chunkBytes + 3));
  });
}
