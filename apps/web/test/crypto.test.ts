// @vitest-environment node
import { readFileSync } from 'node:fs';
import {
  checkRecord,
  deriveSyncKey,
  openRow,
  privateTables,
  sealRow,
  type EncEnvelope,
  type SyncedTable,
} from '@harvest/contracts';
import { beforeAll, describe, expect, it } from 'vitest';
import { HarvestDB } from '@/app/data/db';
import { Keyring } from '@/app/sync/keyring';
import { FakeServer } from './fake-server';

/**
 * The private tier, held to the contract's pinned scheme
 * (`fixtures/crypto.json`): the key derived from the fixture passphrase
 * and salt is the fixture's key, every fixture envelope opens to its
 * fixture row, and sealing that row again with the fixture's nonce
 * gives the fixture's bytes. The phone's tests read the same files.
 */

const fixtures = new URL('../../../packages/contracts/fixtures/', import.meta.url);
const readFixture = <T>(path: string): T => JSON.parse(readFileSync(new URL(path, fixtures), 'utf8')) as T;

interface CryptoFixture {
  passphrase: string;
  syncSalt: string;
  iterations: number;
  keyHex: string;
  cases: { table: SyncedTable; uuid: string; plaintext: string }[];
}

interface FixtureRecord {
  table: SyncedTable;
  uuid: string;
  updatedAt: string;
  deletedAt: string | null;
  enc: EncEnvelope;
}

const pinned = readFixture<CryptoFixture>('crypto.json');
const fromBase64 = (text: string) => Uint8Array.from(atob(text), (c) => c.charCodeAt(0));

let key: CryptoKey;

beforeAll(async () => {
  // The browser keeps its key the way the keyring does: non-extractable.
  key = await deriveSyncKey(pinned.passphrase, pinned.syncSalt, { iterations: pinned.iterations });
});

describe('the pinned key', () => {
  it('derives the fixture key from the fixture passphrase and salt', async () => {
    const exportable = await deriveSyncKey(pinned.passphrase, pinned.syncSalt, {
      iterations: pinned.iterations,
      extractable: true,
    });
    const raw = new Uint8Array(await crypto.subtle.exportKey('raw', exportable));
    expect(Buffer.from(raw).toString('hex')).toBe(pinned.keyHex);
  });

  it('covers every private table', () => {
    expect(pinned.cases.map((c) => c.table).sort()).toEqual([...privateTables].sort());
  });
});

describe.each(pinned.cases)('$table', ({ table, uuid, plaintext }) => {
  const record = readFixture<FixtureRecord>(`records/${table}.json`);
  const data = readFixture<Record<string, unknown>>(`private-data/${table}.json`);

  it('opens the fixture envelope to the fixture row', async () => {
    expect(record.uuid).toBe(uuid);
    const opened = await openRow(key, table, uuid, record.enc);
    expect(opened).toEqual(JSON.parse(plaintext));
    expect(opened).toEqual(data);
  });

  it('seals the row to the same bytes with the same nonce', async () => {
    const envelope = await sealRow(key, table, uuid, JSON.parse(plaintext) as Record<string, unknown>, fromBase64(record.enc.iv));
    expect(envelope).toEqual(record.enc);
    expect(checkRecord({ ...record, enc: envelope }).ok).toBe(true);
  });

  it('refuses the envelope on another row or another table', async () => {
    await expect(openRow(key, table, `${uuid}x`, record.enc)).rejects.toThrow();
    const elsewhere = table === 'expenses' ? 'money_txns' : 'expenses';
    await expect(openRow(key, elsewhere, uuid, record.enc)).rejects.toThrow();
  });
});

describe('the keyring', () => {
  it('keeps a non-extractable key with its epoch in IndexedDB', async () => {
    const db = new HarvestDB('keyring-test');
    await db.open();
    const server = new FakeServer();
    await new Keyring(db, server).unlock('482917', undefined, 1);

    // A fresh keyring on the same store: the key survived, still sealed away.
    const keyring = new Keyring(db, server);
    const stored = await keyring.key(server.salt);
    expect(stored).not.toBeNull();
    expect(stored!.extractable).toBe(false);
    await expect(crypto.subtle.exportKey('raw', stored!)).rejects.toThrow();
    expect(await keyring.epoch()).toBe(1);
    // Another account's salt is another key: this one is not offered.
    expect(await new Keyring(db, server).key('another-salt')).toBeNull();
    db.close();
  });

  it('never uses a key kept by an older version', async () => {
    const db = new HarvestDB('keyring-legacy');
    await db.open();
    const old = await deriveSyncKey(pinned.passphrase, pinned.syncSalt);
    await db.meta.put({ key: 'privateKey', value: { key: old, salt: pinned.syncSalt } });
    await db.meta.put({ key: 'privateKeyV2', value: { key: old, salt: pinned.syncSalt, v: 2 } });
    expect(await new Keyring(db, new FakeServer()).key(pinned.syncSalt)).toBeNull();
    db.close();
  });
});
