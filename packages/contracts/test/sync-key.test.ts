import { randomBytes } from 'node:crypto';
import { describe, expect, it } from 'vitest';
import {
  checkRecord,
  clockIssues,
  deleteSyncKeyBodySchema,
  keyCheckConflictSchema,
  keyCheckSchema,
  keyCheckStoredSchema,
  latestInstant,
  maxClockLeadMs,
  maxEnvelopeCtLength,
  maxTextLength,
  putKeyCheckBodySchema,
  sealKeyCheck,
  syncKeyResultSchema,
} from '../src/index.js';

const b64 = (n: number) => randomBytes(n).toString('base64');
const check = () => ({ v: 2 as const, iv: b64(12), ct: b64(33) });

describe('the sync key routes', () => {
  it('parses what GET /v1/me/sync-key answers', () => {
    expect(syncKeyResultSchema.safeParse({ salt: b64(16), keyShare: b64(32), check: null }).success).toBe(true);
    expect(syncKeyResultSchema.safeParse({ salt: b64(16), keyShare: b64(32), check: check() }).success).toBe(true);
    // The share is 32 bytes, never another length.
    expect(syncKeyResultSchema.safeParse({ salt: b64(16), keyShare: b64(16), check: null }).success).toBe(false);
  });

  it('takes a version 2 check with a 12-byte nonce, and nothing else', () => {
    expect(putKeyCheckBodySchema.safeParse({ check: check() }).success).toBe(true);
    expect(putKeyCheckBodySchema.safeParse({ check: { ...check(), v: 1 } }).success).toBe(false);
    expect(putKeyCheckBodySchema.safeParse({ check: { ...check(), iv: b64(16) } }).success).toBe(false);
    expect(putKeyCheckBodySchema.safeParse({ check: { ...check(), ct: b64(300) } }).success).toBe(false);
    expect(putKeyCheckBodySchema.safeParse({ check: check(), more: true }).success).toBe(false);
    expect(keyCheckSchema.safeParse({ ...check(), extra: 1 }).success).toBe(false);
  });

  it('fits the check the clients seal', async () => {
    const key = await crypto.subtle.generateKey({ name: 'AES-GCM', length: 256 }, false, ['encrypt', 'decrypt']);
    expect(keyCheckSchema.safeParse(await sealKeyCheck(key)).success).toBe(true);
  });

  it('takes the password to start over, and nothing else', () => {
    expect(deleteSyncKeyBodySchema.safeParse({ password: 'correct horse' }).success).toBe(true);
    expect(deleteSyncKeyBodySchema.safeParse({ password: '' }).success).toBe(false);
    expect(deleteSyncKeyBodySchema.safeParse({ password: 'x', pin: '1234' }).success).toBe(false);
  });

  it('parses the 201 and the 409', () => {
    const stored = check();
    expect(keyCheckStoredSchema.parse({ check: stored })).toEqual({ check: stored });
    const conflict = { error: { code: 'conflict', message: 'Another device chose first' }, check: stored };
    expect(keyCheckConflictSchema.parse(conflict).check).toEqual(stored);
    expect(keyCheckConflictSchema.safeParse({ error: { code: 'conflict', message: '' } }).success).toBe(false);
  });
});

describe('record limits (audit S5-02, S5-11)', () => {
  const now = new Date('2026-09-27T12:00:00Z');
  const at = (ms: number) => new Date(now.getTime() + ms).toISOString();

  it('lets a clock a little ahead through, and refuses one a day ahead or past 2200', () => {
    expect(clockIssues({ updatedAt: at(60 * 60_000), deletedAt: null }, now)).toEqual([]);
    expect(clockIssues({ updatedAt: at(maxClockLeadMs + 1000), deletedAt: null }, now)[0]).toMatchObject({
      path: ['updatedAt'],
      code: 'clock_ahead',
    });
    expect(clockIssues({ updatedAt: '9999-12-31T23:59:59Z', deletedAt: null }, now)[0]).toMatchObject({
      code: 'clock_too_far',
    });
    expect(clockIssues({ updatedAt: at(0), deletedAt: latestInstant }, now)[0]).toMatchObject({
      path: ['deletedAt'],
      code: 'clock_too_far',
    });
  });

  it('caps a text column and a sealed row', () => {
    const note = (body: string) => ({
      table: 'notes',
      uuid: 'n1',
      updatedAt: '2026-09-19T10:00:00Z',
      deletedAt: null,
      data: {
        uuid: 'n1',
        title: 'T',
        folder: '',
        body,
        createdAt: '2026-09-19T10:00:00Z',
        updatedAt: '2026-09-19T10:00:00Z',
        deletedAt: null,
      },
    });
    expect(checkRecord(note('x'.repeat(maxTextLength))).ok).toBe(true);
    expect(checkRecord(note('x'.repeat(maxTextLength + 1))).ok).toBe(false);

    const sealed = (ct: string) => ({
      table: 'geotags',
      uuid: 'g1',
      updatedAt: '2026-09-19T10:00:00Z',
      deletedAt: null,
      enc: { v: 2, iv: b64(12), ct },
    });
    expect(checkRecord(sealed('A'.repeat(maxEnvelopeCtLength))).ok).toBe(true);
    expect(checkRecord(sealed('A'.repeat(maxEnvelopeCtLength + 4))).ok).toBe(false);
  });
});
