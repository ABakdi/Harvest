import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/features/finances/domain/amount_expression.dart';

/// The amount box's arithmetic, read against the same numbers as the
/// web's port in `packages/core` (`fixtures/amounts.json`): a sum typed
/// on one device comes to the same cents on the other.
void main() {
  final spec =
      jsonDecode(
            File('../../packages/core/fixtures/amounts.json').readAsStringSync(),
          )
          as Map<String, Object?>;

  test('every amount comes to the same minor units', () {
    for (final item in spec['cases']! as List<Object?>) {
      final entry = item! as Map<String, Object?>;
      expect(
        evaluateAmountToMinor(entry['input']! as String),
        entry['minor'],
        reason: entry['why'] as String?,
      );
    }
  });
}
