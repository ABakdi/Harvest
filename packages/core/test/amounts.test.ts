import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';
import { evaluateAmountToMinor, isAmountExpression } from '../src/index.js';

/**
 * The amount box's arithmetic, held to the fixture the phone's
 * `amount_fixture_test.dart` reads too: a sum typed on one device comes
 * to the same cents on the other.
 */
const spec = JSON.parse(readFileSync(new URL('../fixtures/amounts.json', import.meta.url), 'utf8')) as {
  cases: { why: string; input: string; minor: number | null }[];
};

describe('amounts.json', () => {
  for (const entry of spec.cases) {
    it(entry.why, () => {
      expect(evaluateAmountToMinor(entry.input)).toBe(entry.minor);
    });
  }

  it('tells a sum from a number', () => {
    expect(isAmountExpression('1,250.50')).toBe(false);
    expect(isAmountExpression('12+3')).toBe(true);
    expect(isAmountExpression('(3)')).toBe(true);
  });
});
