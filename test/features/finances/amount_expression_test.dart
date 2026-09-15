import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/features/finances/domain/amount_expression.dart';

/// Checkpoint 6: the amount box takes a sum.
void main() {
  test('a plain number is still a plain number', () {
    expect(evaluateAmountToMinor('12.5'), 1250);
    expect(evaluateAmountToMinor('1,234'), 123400, reason: 'grouping comma');
    expect(evaluateAmountToMinor(''), isNull);
  });

  test('adds a receipt up', () {
    expect(evaluateAmountToMinor('12+3.5*2'), 1900);
    expect(evaluateAmountToMinor('100-25'), 7500);
    expect(evaluateAmountToMinor('(4+6)/4'), 250);
    expect(evaluateAmountToMinor('3 × 4 ÷ 2'), 600);
    expect(evaluateAmountToMinor(' 10 + 5 '), 1500);
  });

  test('a comma inside a sum is a decimal point', () {
    expect(evaluateAmountToMinor('1,5+2'), 350);
  });

  test('rounds to the cent', () {
    expect(evaluateAmountToMinor('10/3'), 333);
    expect(evaluateAmountToMinor('0.1+0.2'), 30);
  });

  test('refuses what it cannot add up', () {
    expect(evaluateAmountToMinor('12+'), isNull);
    expect(evaluateAmountToMinor('+12'), isNull);
    expect(evaluateAmountToMinor('(12'), isNull);
    expect(evaluateAmountToMinor('12/0'), isNull);
    expect(evaluateAmountToMinor('5-5'), isNull, reason: 'nothing to log');
    expect(evaluateAmountToMinor('2-5'), isNull, reason: 'not an expense');
    expect(evaluateAmountToMinor('1e3+1'), isNull);
  });

  test('knows a sum from a number', () {
    expect(isAmountExpression('12'), isFalse);
    expect(isAmountExpression('12+1'), isTrue);
    expect(isAmountExpression('(12)'), isTrue);
  });
}
