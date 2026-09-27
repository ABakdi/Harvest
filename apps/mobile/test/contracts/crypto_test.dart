import 'dart:convert';
import 'dart:io';

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
}
