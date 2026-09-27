import { westernDigits } from '@harvest/core';
import digits from '../../../packages/core/fixtures/digits.json';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { pinDigits } from '@/app/components/passphrase-prompt';
import { api, longestPaceMs, resetApiForTests, setPauseForTests } from '@/lib/api';
import { parseAmount } from '@/lib/format';

const spec = digits as { cases: { input: string; expected: string }[] };

describe('one digit normaliser (Q5-36, core/fixtures/digits.json)', () => {
  it.each(spec.cases)('$input → $expected', ({ input, expected }) => {
    expect(westernDigits(input)).toBe(expected);
  });

  it('is what an amount and the PIN are read through, Persian digits too', () => {
    expect(parseAmount('۱۲۵۰')).toBe(125_000);
    expect(parseAmount('١٢.٥')).toBe(1250);
    expect(pinDigits('۲۴٦8')).toBe('2468');
  });
});

describe('a paced route (429)', () => {
  afterEach(() => {
    vi.restoreAllMocks();
    resetApiForTests();
  });

  const json = (status: number, body: unknown, headers: Record<string, string> = {}) =>
    new Response(JSON.stringify(body), { status, headers: { 'content-type': 'application/json', ...headers } });

  it('waits as long as Retry-After says, a minute at most, then asks again', async () => {
    const waited: number[] = [];
    setPauseForTests((ms) => {
      waited.push(ms);
      return Promise.resolve();
    });
    const fetch = vi
      .spyOn(globalThis, 'fetch')
      .mockResolvedValueOnce(json(200, { accessToken: 't', expiresIn: 900, user: { id: 'u' } }))
      .mockResolvedValueOnce(json(429, { error: { code: 'rate_limited', message: 'slow' } }, { 'retry-after': '7' }))
      .mockResolvedValueOnce(json(429, { error: { code: 'rate_limited', message: 'slow' } }, { 'retry-after': '3600' }))
      .mockResolvedValueOnce(json(200, { records: [], cursor: 0, more: false }));
    const page = await api.pull(0, 10);
    expect(page.more).toBe(false);
    expect(waited).toEqual([7_000, longestPaceMs]);
    expect(fetch).toHaveBeenCalledTimes(4);
  });
});
