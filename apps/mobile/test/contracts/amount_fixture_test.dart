import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/features/finances/domain/amount_expression.dart';
import 'package:harvest/features/finances/presentation/money.dart';
import 'package:harvest/features/health/domain/body_weight.dart';

/// The amount box's arithmetic, read against the same numbers as the
/// web's port in `packages/core` (`fixtures/amounts.json`): a sum typed
/// on one device comes to the same cents on the other.
void main() {
  final spec = jsonDecode(
    File('../../packages/core/fixtures/amounts.json').readAsStringSync(),
  ) as Map<String, Object?>;

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

  test('the same amounts are plausible, or asked about (W6-15)', () {
    for (final item in spec['plausible']! as List<Object?>) {
      final entry = item! as Map<String, Object?>;
      expect(
        isPlausibleAmount(entry['minor']! as int),
        entry['plausible'],
        reason: entry['why'] as String?,
      );
    }
  });

  test('the same body weights are plausible (fixtures/body.json)', () {
    final body = jsonDecode(
      File('../../packages/core/fixtures/body.json').readAsStringSync(),
    ) as Map<String, Object?>;
    for (final item in body['plausibleWeights']! as List<Object?>) {
      final entry = item! as Map<String, Object?>;
      expect(
        isPlausibleBodyWeight(entry['grams']! as int),
        entry['plausible'],
        reason: entry['why'] as String?,
      );
    }
  });
}
