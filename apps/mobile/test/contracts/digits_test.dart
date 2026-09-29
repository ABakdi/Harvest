import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/core/domain/western_digits.dart';
import 'package:harvest/features/account/presentation/sync_pin_sheet.dart';
import 'package:harvest/features/finances/presentation/money.dart';

/// One digit normaliser, the web's and the phone's
/// (`packages/core/fixtures/digits.json`).
void main() {
  final spec = jsonDecode(
    File('../../packages/core/fixtures/digits.json').readAsStringSync(),
  ) as Map<String, Object?>;

  test('reads every pinned case as the web does', () {
    for (final item in spec['cases']! as List<Object?>) {
      final c = item! as Map<String, Object?>;
      expect(westernDigits(c['input']! as String), c['expected'], reason: '$c');
    }
  });

  test('amounts and the PIN both read through it', () {
    expect(parseToMinor('۱۲.۵'), 1250);
    expect(parseToMinor('١٢٥٠'), 125000);
    expect(PinDigitsFormatter.digitsOf('۲۴٦8'), '2468');
  });
}
