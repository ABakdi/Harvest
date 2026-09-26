import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/features/sync/domain/sync_cipher.dart';

/// The phone opens what the web seals, and the other way round
/// (`packages/contracts/fixtures/crypto.json`).
void main() {
  final fixtures = Directory('../../packages/contracts/fixtures');
  Map<String, Object?> read(String path) =>
      jsonDecode(File('${fixtures.path}/$path').readAsStringSync())
          as Map<String, Object?>;
  final spec = read('crypto.json');
  final keyHex = spec['keyHex']! as String;
  final keyBytes = [
    for (var i = 0; i < keyHex.length; i += 2)
      int.parse(keyHex.substring(i, i + 2), radix: 16),
  ];

  test('derives the pinned key from the passphrase and the salt', () async {
    final key = await SyncCipher.deriveKey(
      spec['passphrase']! as String,
      spec['syncSalt']! as String,
    );
    expect(key, keyBytes);
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('opens every private fixture to its plaintext row', () async {
    final cipher = SyncCipher(keyBytes);
    for (final item in spec['cases']! as List<Object?>) {
      final c = item! as Map<String, Object?>;
      final table = c['table']! as String;
      final record = read('records/$table.json');
      final data = await cipher.open(
        table,
        c['uuid']! as String,
        record['enc']! as Map<String, Object?>,
      );
      expect(data, read('private-data/$table.json'), reason: table);
    }
  });

  test('what the phone seals opens, and only for its own row', () async {
    final cipher = SyncCipher(keyBytes);
    final sealed = await cipher.seal('expenses', 'a', {'amountMinor': 500});
    expect(await cipher.open('expenses', 'a', sealed), {'amountMinor': 500});
    expect(() => cipher.open('expenses', 'b', sealed), throwsA(anything));
    expect(() => cipher.open('debts', 'a', sealed), throwsA(anything));
  });
}
