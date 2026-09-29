import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';
import { westernDigits } from '../src/digits.js';
import { parseToMinor } from '../src/money.js';

const spec = JSON.parse(readFileSync(new URL('../fixtures/digits.json', import.meta.url), 'utf8')) as {
  cases: { input: string; expected: string }[];
};

describe('digits.json', () => {
  it.each(spec.cases)('$input → $expected', ({ input, expected }) => {
    expect(westernDigits(input)).toBe(expected);
  });

  it('is what an amount is read through, Persian digits too', () => {
    expect(parseToMinor('۱۲٫')).toBeNull();
    expect(parseToMinor('۱۲.۵')).toBe(1250);
    expect(parseToMinor('١٢٥٠')).toBe(125000);
  });
});
