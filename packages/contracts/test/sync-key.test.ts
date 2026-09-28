import { randomBytes } from 'node:crypto';
import { describe, expect, it } from 'vitest';
import {
  checkRecord,
  checkRow,
  clockIssues,
  deleteSyncKeyBodySchema,
  errorStatus,
  keyCheckSchema,
  latestInstant,
  maxClockLeadMs,
  maxEnvelopeCtLength,
  maxPushBytes,
  maxTextLength,
  pullQuerySchema,
  pushBodySchema,
  sealKeyCheck,
  setSyncKeyBodySchema,
  syncKeySetSchema,
  syncKeyStateSchema,
  unlockBodySchema,
  unlockResultSchema,
  wrongPinSchema,
} from '../src/index.js';

const b64 = (n: number) => randomBytes(n).toString('base64');
const check = () => ({ v: 2 as const, iv: b64(12), ct: b64(33) });
const verifier = () => randomBytes(32).toString('hex');

describe('the sync key routes', () => {
  it('hands out the key share only while no PIN is set', () => {
    const none = syncKeyStateSchema.parse({ state: 'none', salt: b64(16), epoch: 1, keyShare: b64(32) });
    expect(none.state === 'none' && none.keyShare).toBeTruthy();
    // Set: the share never travels in the state, and a state 'none' needs one.
    const set = syncKeyStateSchema.parse({ state: 'set', salt: b64(16), epoch: 3, keyShare: b64(32) });
    expect('keyShare' in set).toBe(false);
    expect(syncKeyStateSchema.safeParse({ state: 'none', salt: b64(16), epoch: 1 }).success).toBe(false);
    expect(syncKeyStateSchema.safeParse({ state: 'set', salt: b64(16), epoch: 0 }).success).toBe(false);
  });

  it('takes a 32-byte proof to unlock, and answers the share, the check and the epoch', () => {
    expect(unlockBodySchema.safeParse({ proof: b64(32) }).success).toBe(true);
    expect(unlockBodySchema.safeParse({ proof: b64(31) }).success).toBe(false);
    expect(unlockBodySchema.safeParse({ proof: b64(32), pin: '1234' }).success).toBe(false);
    expect(unlockResultSchema.safeParse({ keyShare: b64(32), check: check(), epoch: 2 }).success).toBe(true);
    const wrong = { error: { code: 'wrong_pin', message: 'Not this PIN' }, triesLeft: 3 };
    expect(wrongPinSchema.parse(wrong).triesLeft).toBe(3);
    expect(errorStatus.wrong_pin).toBe(403);
    expect(errorStatus.key_changed).toBe(409);
  });

  it('sets a PIN with a verifier and a version 2 check, and nothing else', () => {
    expect(setSyncKeyBodySchema.safeParse({ verifier: verifier(), check: check() }).success).toBe(true);
    expect(setSyncKeyBodySchema.safeParse({ verifier: verifier().toUpperCase(), check: check() }).success).toBe(false);
    expect(setSyncKeyBodySchema.safeParse({ verifier: verifier(), check: { ...check(), v: 1 } }).success).toBe(false);
    expect(setSyncKeyBodySchema.safeParse({ verifier: verifier(), check: { ...check(), iv: b64(16) } }).success).toBe(
      false,
    );
    expect(setSyncKeyBodySchema.safeParse({ verifier: verifier(), check: { ...check(), ct: b64(300) } }).success).toBe(
      false,
    );
    expect(setSyncKeyBodySchema.safeParse({ verifier: verifier(), check: check(), more: 1 }).success).toBe(false);
    expect(keyCheckSchema.safeParse({ ...check(), extra: 1 }).success).toBe(false);
    expect(syncKeySetSchema.parse({ epoch: 1 })).toEqual({ epoch: 1 });
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

  it('carries the key epoch on a push and the device on a pull', () => {
    expect(pushBodySchema.parse({ deviceId: 'd', keyEpoch: 2, records: [] }).keyEpoch).toBe(2);
    expect(pushBodySchema.safeParse({ deviceId: 'd', keyEpoch: 0, records: [] }).success).toBe(false);
    expect(pullQuerySchema.parse({ after: '5', deviceId: 'd' })).toMatchObject({ after: 5, deviceId: 'd' });
    expect(maxPushBytes).toBeLessThan(5 * 1024 * 1024);
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
    const record = { table: 'notes' as const, uuid: 'n1', updatedAt: '2026-09-19T10:00:00Z', deletedAt: null };
    const note = (body: string) => ({
      uuid: 'n1',
      title: 'T',
      folder: '',
      body,
      createdAt: '2026-09-19T10:00:00Z',
      updatedAt: '2026-09-19T10:00:00Z',
      deletedAt: null,
    });
    expect(checkRow(record, note('x'.repeat(maxTextLength))).ok).toBe(true);
    expect(checkRow(record, note('x'.repeat(maxTextLength + 1))).ok).toBe(false);

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
