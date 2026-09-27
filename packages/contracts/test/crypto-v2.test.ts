import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';
import {
  clocksMatch,
  deriveSyncKeyV2,
  openFile,
  opensKeyCheck,
  openRowV2,
  rowAadV2,
  sealFile,
  sealKeyCheck,
  sealRowV2,
  UnreadableRowError,
} from '../src/crypto.js';

interface Envelope {
  v: number;
  iv: string;
  ct: string;
}
interface Row {
  table: string;
  uuid: string;
  updatedAt: string;
  deletedAt: string | null;
}

const spec = JSON.parse(readFileSync(new URL('../fixtures/crypto-v2.json', import.meta.url), 'utf8')) as {
  secret: string;
  syncSalt: string;
  keyShare: string;
  iterations: number;
  keyHex: string;
  rows: (Row & { aad: string; plaintext: string; enc: Envelope })[];
  keyCheck: Envelope;
  refused: (Row & { why: string; enc: Envelope })[];
};

const key = () => deriveSyncKeyV2(spec.secret, spec.syncSalt, spec.keyShare);
const cheap = (secret: string, share: string | Uint8Array = spec.keyShare) =>
  deriveSyncKeyV2(secret, spec.syncSalt, share, { iterations: 1000 });

describe('the private tier, version 2 (fixtures/crypto-v2.json)', () => {
  it('derives the pinned key from the secret, the salt and the key share', async () => {
    const derived = await deriveSyncKeyV2(spec.secret, spec.syncSalt, spec.keyShare, { extractable: true });
    const raw = new Uint8Array(await crypto.subtle.exportKey('raw', derived));
    expect(Buffer.from(raw).toString('hex')).toBe(spec.keyHex);
  });

  it('takes the key share as bytes too', async () => {
    const bytes = new Uint8Array(Buffer.from(spec.keyShare, 'base64'));
    const a = await deriveSyncKeyV2('2468', spec.syncSalt, bytes, { iterations: 1000, extractable: true });
    const b = await deriveSyncKeyV2('2468', spec.syncSalt, spec.keyShare, { iterations: 1000, extractable: true });
    expect(await crypto.subtle.exportKey('raw', a)).toEqual(await crypto.subtle.exportKey('raw', b));
  });

  it.each(spec.rows)('binds $table to its clocks and opens it', async (row) => {
    expect(rowAadV2(row.table, row.uuid, row)).toBe(row.aad);
    expect(await openRowV2(await key(), row.table, row.uuid, row, row.enc)).toEqual(JSON.parse(row.plaintext));
  });

  it.each(spec.refused)('refuses $why', async (row) => {
    await expect(openRowV2(await key(), row.table, row.uuid, row, row.enc)).rejects.toBeInstanceOf(
      UnreadableRowError,
    );
  });

  it('opens the pinned key check, and only with the right key', async () => {
    expect(await opensKeyCheck(await key(), spec.keyCheck)).toBe(true);
    expect(await opensKeyCheck(await cheap(spec.secret), spec.keyCheck)).toBe(false);
    expect(await opensKeyCheck(await key(), { ...spec.keyCheck, v: 1 })).toBe(false);
  });

  it('seals a key check that opens with its own key only', async () => {
    const mine = await cheap('2468');
    const check = await sealKeyCheck(mine);
    expect(check.v).toBe(2);
    expect(await opensKeyCheck(mine, check)).toBe(true);
    expect(await opensKeyCheck(await cheap('1357'), check)).toBe(false);
    // The same secret on another account's key share is another key.
    expect(await opensKeyCheck(await cheap('2468', new Uint8Array(32)), check)).toBe(false);
  });

  it('round-trips a row it sealed, and refuses it under other clocks', async () => {
    const mine = await cheap('2468');
    const data = { uuid: 'a', amountMinor: 500, updatedAt: '2026-09-18T13:10:00.000Z', deletedAt: null };
    const clocks = { updatedAt: '2026-09-18T13:10:00Z', deletedAt: null };
    const sealed = await sealRowV2(mine, 'expenses', 'a', clocks, data);
    expect(sealed.v).toBe(2);
    expect(await openRowV2(mine, 'expenses', 'a', clocks, sealed)).toEqual(data);
    await expect(
      openRowV2(mine, 'expenses', 'a', { updatedAt: '2026-09-18T13:10:00.000001Z', deletedAt: null }, sealed),
    ).rejects.toBeInstanceOf(UnreadableRowError);
    await expect(openRowV2(mine, 'debts', 'a', clocks, sealed)).rejects.toBeInstanceOf(UnreadableRowError);
  });

  it("compares a row's clocks only where its table keeps them", () => {
    const clocks = { updatedAt: '2026-09-18T13:10:00Z', deletedAt: null };
    expect(clocksMatch('expenses', clocks, { updatedAt: '2026-09-18T13:10:00.000Z', deletedAt: null })).toBe(true);
    expect(clocksMatch('expenses', clocks, { updatedAt: '2026-09-18T13:10:01Z', deletedAt: null })).toBe(false);
    expect(clocksMatch('expenses', clocks, { updatedAt: 12, deletedAt: null })).toBe(false);
    expect(clocksMatch('debt_payments', clocks, { deletedAt: null })).toBe(true);
    expect(clocksMatch('not_a_table', clocks, {})).toBe(false);
  });

  it('seals files with the version 2 key as before', async () => {
    const mine = await cheap('2468');
    const bytes = new Uint8Array([1, 2, 3, 4]);
    const sealed = await sealFile(mine, 'abc', bytes);
    expect(await openFile(mine, 'abc', { iv: sealed.iv, ct: sealed.sealed })).toEqual(bytes);
  });
});
