import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';
import { isSyncPin, syncSecretProblem } from '../src/sync-secret.js';

const spec = JSON.parse(readFileSync(new URL('../fixtures/sync-secret.json', import.meta.url), 'utf8')) as {
  cases: { input: string; expected: string | null }[];
};

describe('the sync secret (fixtures/sync-secret.json)', () => {
  it.each(spec.cases)('$input → $expected', ({ input, expected }) => {
    expect(syncSecretProblem(input)).toBe(expected);
  });

  it('pins every answer the rule can give', () => {
    const answers = new Set(spec.cases.map((c) => c.expected));
    expect(answers).toEqual(new Set(['empty', 'pinTooShort', 'pinTooLong', 'passphraseTooShort', null]));
  });

  it('reads only ASCII digits as a PIN', () => {
    expect(isSyncPin('0123')).toBe(true);
    expect(isSyncPin('١٢٣٤')).toBe(false);
    expect(isSyncPin('')).toBe(false);
  });
});
