import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';
import { deriveSyncKey, openRow, sealRow } from '../src/crypto.js';
import type { EncEnvelope } from '../src/sync.js';

const fixtures = new URL('../fixtures/', import.meta.url);
const read = (path: string) => JSON.parse(readFileSync(new URL(path, fixtures), 'utf8')) as Record<string, unknown>;

const spec = read('crypto.json') as {
  passphrase: string;
  syncSalt: string;
  iterations: number;
  keyHex: string;
  cases: { table: string; uuid: string; plaintext: string }[];
};

describe('the private tier (fixtures/crypto.json)', () => {
  it('derives the pinned key from the passphrase and the salt', async () => {
    const key = await deriveSyncKey(spec.passphrase, spec.syncSalt, { extractable: true });
    const raw = new Uint8Array(await crypto.subtle.exportKey('raw', key));
    expect(Buffer.from(raw).toString('hex')).toBe(spec.keyHex);
  });

  it.each(spec.cases)('opens the $table fixture to its plaintext row', async ({ table, uuid, plaintext }) => {
    const key = await deriveSyncKey(spec.passphrase, spec.syncSalt);
    const record = read(`records/${table}.json`) as { uuid: string; enc: EncEnvelope };
    expect(record.uuid).toBe(uuid);
    expect(await openRow(key, table, uuid, record.enc)).toEqual(JSON.parse(plaintext));
    expect(await openRow(key, table, uuid, record.enc)).toEqual(read(`private-data/${table}.json`));
  });

  it('refuses a ciphertext moved to another row or table', async () => {
    const key = await deriveSyncKey(spec.passphrase, spec.syncSalt);
    const sealed = await sealRow(key, 'expenses', 'a', { amountMinor: 500 });
    await expect(openRow(key, 'expenses', 'b', sealed)).rejects.toThrow();
    await expect(openRow(key, 'debts', 'a', sealed)).rejects.toThrow();
    expect(await openRow(key, 'expenses', 'a', sealed)).toEqual({ amountMinor: 500 });
  });

  it('refuses the wrong passphrase', async () => {
    const right = await deriveSyncKey(spec.passphrase, spec.syncSalt);
    const wrong = await deriveSyncKey('not it', spec.syncSalt, { iterations: 1000 });
    const sealed = await sealRow(right, 'expenses', 'a', { amountMinor: 1 });
    await expect(openRow(wrong, 'expenses', 'a', sealed)).rejects.toThrow();
  });
});
