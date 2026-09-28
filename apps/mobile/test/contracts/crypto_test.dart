import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/features/sync/domain/sync_cipher.dart';

/// The phone opens what the web seals, and the other way round
/// (`packages/contracts/fixtures/crypto-v2.json`).
void main() {
  final fixtures = Directory('../../packages/contracts/fixtures');
  final spec = jsonDecode(
    File('${fixtures.path}/crypto-v2.json').readAsStringSync(),
  ) as Map<String, Object?>;
  final keyHex = spec['keyHex']! as String;
  final keyBytes = [
    for (var i = 0; i < keyHex.length; i += 2)
      int.parse(keyHex.substring(i, i + 2), radix: 16),
  ];
  final keyShare = base64Decode(spec['keyShare']! as String);
  List<Map<String, Object?>> list(String name) => [
    for (final item in spec[name]! as List<Object?>)
      item! as Map<String, Object?>,
  ];
  RowClocks clocksOf(Map<String, Object?> c) => (
    updatedAt: c['updatedAt']! as String,
    deletedAt: c['deletedAt'] as String?,
  );

  test('derives the pinned key from the secret, the salt and the key '
      'share', () async {
    final key = await SyncCipher.deriveKey(
      spec['secret']! as String,
      spec['syncSalt']! as String,
      keyShare,
    );
    expect(key, keyBytes);
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('makes the pinned PIN proof and verifier (S6-04)', () async {
    final cases = [
      {
        'secret': spec['secret'],
        'iterations': spec['iterations'],
        'baseKeyHex': spec['baseKeyHex'],
        'proof': spec['proof'],
        'verifierHex': spec['verifierHex'],
      },
      ...list('proofs'),
    ];
    for (final c in cases) {
      final base = await SyncCipher.deriveBase(
        c['secret']! as String,
        spec['syncSalt']! as String,
        iterations: (c['iterations']! as num).toInt(),
      );
      expect(
        base.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
        c['baseKeyHex'],
      );
      final proof = await SyncCipher.proofOf(base);
      expect(base64Encode(proof), c['proof']);
      expect(await SyncCipher.verifierOf(proof), c['verifierHex']);
    }
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('binds each row to its clocks, and opens it', () async {
    final cipher = SyncCipher(keyBytes);
    for (final c in list('rows')) {
      final table = c['table']! as String;
      final uuid = c['uuid']! as String;
      expect(SyncCipher.rowAad(table, uuid, clocksOf(c)), c['aad']);
      final data = await cipher.open(
        table,
        uuid,
        clocksOf(c),
        c['enc']! as Map<String, Object?>,
      );
      expect(data, jsonDecode(c['plaintext']! as String), reason: table);
    }
  });

  test('refuses what the fixture refuses', () async {
    final cipher = SyncCipher(keyBytes);
    for (final c in list('refused')) {
      Future<bool> opens() async {
        try {
          final data = await cipher.open(
            c['table']! as String,
            c['uuid']! as String,
            clocksOf(c),
            c['enc']! as Map<String, Object?>,
          );
          // The sync compares the row's own clocks with the record's.
          return sameInstant(
            data['updatedAt'] as String?,
            c['updatedAt']! as String,
          );
        } on UnreadableRow {
          return false;
        }
      }

      expect(await opens(), isFalse, reason: c['why'] as String?);
    }
  });

  test('opens the pinned key check, and only with the right key', () async {
    final check = spec['keyCheck']! as Map<String, Object?>;
    expect(await SyncCipher(keyBytes).opensCheck(check), isTrue);
    expect(
      await SyncCipher(List<int>.filled(32, 7)).opensCheck(check),
      isFalse,
    );
    expect(
      await SyncCipher(keyBytes).opensCheck({...check, 'v': 1}),
      isFalse,
    );
  });

  test('what the phone seals opens, and only for its own row and '
      'clocks', () async {
    final cipher = SyncCipher(keyBytes);
    const clocks = (updatedAt: '2026-09-18T13:10:00.000Z', deletedAt: null);
    final sealed = await cipher.seal('expenses', 'a', clocks, {
      'amountMinor': 500,
    });
    expect(sealed['v'], 2);
    expect(await cipher.open('expenses', 'a', clocks, sealed), {
      'amountMinor': 500,
    });
    // The same instant, spelled otherwise, is the same clock.
    expect(
      await cipher.open('expenses', 'a', (
        updatedAt: '2026-09-18T13:10:00Z',
        deletedAt: null,
      ), sealed),
      {'amountMinor': 500},
    );
    for (final (table, uuid, other) in [
      ('expenses', 'b', clocks),
      ('debts', 'a', clocks),
      (
        'expenses',
        'a',
        (updatedAt: '2026-09-18T13:10:00.000001Z', deletedAt: null),
      ),
      (
        'expenses',
        'a',
        (
          updatedAt: '2026-09-18T13:10:00.000Z',
          deletedAt: '2026-09-18T13:10:00.000Z',
        ),
      ),
    ]) {
      await expectLater(
        cipher.open(table, uuid, other, sealed),
        throwsA(isA<UnreadableRow>()),
      );
    }
  });

  test('a key check sealed here opens with its own key only', () async {
    final mine = SyncCipher(keyBytes);
    final check = await mine.sealCheck();
    expect(check['v'], 2);
    expect(await mine.opensCheck(check), isTrue);
    expect(
      await SyncCipher(List<int>.filled(32, 1)).opensCheck(check),
      isFalse,
    );
  });

  test('reads a clock to the microsecond, as contracts does', () {
    expect(
      instantMicros('2026-09-18T13:10:00.123456Z'),
      DateTime.utc(2026, 9, 18, 13, 10, 0, 123, 456).microsecondsSinceEpoch,
    );
    expect(
      instantMicros('2026-09-18T13:10:00.5Z'),
      instantMicros('2026-09-18T13:10:00.500000Z'),
    );
    // Digits past the sixth are dropped, not rounded.
    expect(
      instantMicros('2026-09-18T13:10:00.1234569Z'),
      instantMicros('2026-09-18T13:10:00.123456Z'),
    );
    expect(() => instantMicros('2026-09-18 13:10'), throwsFormatException);
  });

  group('Phase 7 (fixtures/crypto-v3.json)', () {
    final v3 = jsonDecode(
      File('${fixtures.path}/crypto-v3.json').readAsStringSync(),
    ) as Map<String, Object?>;
    final cipher = SyncCipher(keyBytes);
    String hex(List<int> bytes) =>
        bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

    test('uses the version 2 key', () {
      expect(v3['keyHex'], keyHex);
    });

    test('derives the pinned name key, and names files as pinned', () async {
      expect(hex(await cipher.nameKeyBytes()), v3['nameKeyHex']);
      for (final item in v3['names']! as List<Object?>) {
        final one = item! as Map<String, Object?>;
        final name = await cipher.nameOf(one['sha256']! as String);
        expect(name, one['name']);
        expect(name, isNot(one['sha256']));
      }
      final other = SyncCipher(List<int>.filled(32, 7));
      final first = (v3['names']! as List<Object?>).first! as Map;
      expect(
        await other.nameOf(first['sha256']! as String),
        isNot(first['name']),
      );
    });

    test('keys each day of the trail as pinned', () async {
      for (final item in v3['trailKeys']! as List<Object?>) {
        final one = item! as Map<String, Object?>;
        expect(await cipher.trailKeyOf(one['day']! as String), one['key']);
      }
    });

    test('pads lengths as pinned', () {
      for (final item in v3['padding']! as List<Object?>) {
        final one = item! as Map<String, Object?>;
        expect(
          paddedLength((one['n']! as num).toInt()),
          (one['padded']! as num).toInt(),
          reason: 'n = ${one['n']}',
        );
      }
    });

    test(
      'seals the pinned row to the same bytes, padded, and opens it',
      () async {
        final row = v3['row']! as Map<String, Object?>;
        final enc = row['enc']! as Map<String, Object?>;
        final data =
            jsonDecode(row['plaintext']! as String) as Map<String, Object?>;
        final sealed = await cipher.seal(
          row['table']! as String,
          row['uuid']! as String,
          clocksOf(row),
          data,
          iv: base64Decode(enc['iv']! as String),
        );
        expect(sealed, enc);
        final opened = await cipher.open(
          row['table']! as String,
          row['uuid']! as String,
          clocksOf(row),
          enc,
        );
        expect(opened, data);
      },
    );

    test('opens and seals the pinned file, padded, under its name', () async {
      final file = v3['file']! as Map<String, Object?>;
      final name = file['name']! as String;
      final plain = base64Decode(file['plaintextBase64']! as String);
      final sealedBytes = base64Decode(file['sealedBase64']! as String);
      final iv = base64Decode(file['iv']! as String);
      expect(await cipher.openFile(name, iv, sealedBytes), plain);
      final sealed = await cipher.sealFile(name, plain, iv: iv);
      expect(sealed.bytes, sealedBytes);
      expect(sealed.bytes.length, paddedLength(plain.length + 1) + 16);
      await expectLater(
        cipher.openFile('0$name'.substring(0, 64), iv, sealedBytes),
        throwsA(anything),
      );
    });

    test('pads and unpads a file of any length, and refuses one never '
        'padded', () {
      for (final length in [0, 1, 255, 256, 1000, 70000]) {
        final bytes = List<int>.generate(length, (i) => i * 31 % 256);
        final padded = padFile(bytes);
        expect(padded.length, paddedLength(length + 1));
        expect(unpadFile(padded), bytes);
      }
      expect(
        () => unpadFile(List<int>.filled(16, 0)),
        throwsA(isA<UnreadableRow>()),
      );
      expect(() => unpadFile([1, 2, 3]), throwsA(isA<UnreadableRow>()));
    });
  });

  test('a file sealed before Phase 7 still opens under its name', () async {
    final cipher = SyncCipher(keyBytes);
    final plain = utf8.encode('an old picture');
    // As 3.1 sealed it: `file/<name>`, unpadded (crypto-v2.json).
    final aes = AesGcm.with256bits();
    final box = await aes.encrypt(
      plain,
      secretKey: SecretKey(keyBytes),
      nonce: aes.newNonce(),
      aad: utf8.encode('file/abc'),
    );
    expect(
      await cipher.openFile('abc', box.nonce, [
        ...box.cipherText,
        ...box.mac.bytes,
      ]),
      plain,
    );
  });
}
