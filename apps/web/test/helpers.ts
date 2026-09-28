import { deriveSyncBase, fileNameKeyOf, fileNameOf, openRowV2, syncKeyBitsOf, type Me, type PulledRecord } from '@harvest/contracts';
import { createHarvest, type Harvest } from '@/app/context';
import { HarvestDB } from '@/app/data/db';
import type { SyncTransport } from '@/app/sync/engine';
import { testKeyShare } from './fake-server';

export const testUser: Me = {
  id: '0123456789abcdef01234567',
  email: 'farmer@example.com',
  displayName: 'Farmer',
  verifiedAt: '2026-09-01T10:00:00.000Z',
  // Sixteen bytes, base64, as the server makes them.
  syncSalt: 'c2FsdHNhbHRzYWx0c2FsdA==',
  createdAt: '2026-09-01T10:00:00.000Z',
};

let counter = 0;

/** A movable clock, so tests can say which write is newer. */
export function testClock(start = '2026-09-19T12:00:00.000Z') {
  let now = new Date(start).getTime();
  const clock = () => new Date(now);
  clock.advance = (ms: number) => {
    now += ms;
  };
  clock.set = (iso: string) => {
    now = new Date(iso).getTime();
  };
  return clock;
}

/** The sync PIN a test device enters when it is to sync ([[syncing]]). */
export const testPin = '482917';

/**
 * A fresh device: its own IndexedDB, its own clock, the shared server.
 * Since Phase 7 nothing syncs without the sync PIN; with [pin], the
 * device enters it first (one round, to be quick).
 */
export async function device(
  transport: SyncTransport,
  clock = testClock(),
  user: Me = testUser,
  { pin = null }: { pin?: string | null } = {},
): Promise<Harvest & { clock: ReturnType<typeof testClock> }> {
  const db = new HarvestDB(`test-${Date.now()}-${counter++}`);
  await db.open();
  const harvest = Object.assign(createHarvest(db, user, transport, clock), { clock });
  if (pin !== null && 'syncKey' in transport) await harvest.keyring.unlock(pin, undefined, 1);
  return harvest;
}

/** A fresh device that syncs: it has entered [testPin]. */
export function syncing(
  transport: SyncTransport,
  clock = testClock(),
  user: Me = testUser,
): Promise<Harvest & { clock: ReturnType<typeof testClock> }> {
  return device(transport, clock, user, { pin: testPin });
}

/** The key's bytes a fresh fake account makes from [secret], with one round. */
async function testBits(secret: string): Promise<Uint8Array> {
  return syncKeyBitsOf(await deriveSyncBase(secret, testUser.syncSalt, { iterations: 1 }), testKeyShare);
}

/**
 * The key a fresh fake account makes from [secret], as the keyring does
 * with one round (`unlock(secret, salt, 1)`): what a test seals a file
 * or a row with to play another device.
 */
export async function testKey(secret: string = testPin): Promise<CryptoKey> {
  const bits = await testBits(secret);
  return crypto.subtle.importKey('raw', bits as Uint8Array<ArrayBuffer>, { name: 'AES-GCM', length: 256 }, false, [
    'encrypt',
    'decrypt',
  ]);
}

/** The name key a device with [secret] draws file names and trail keys with. */
export async function testNameKey(secret: string = testPin): Promise<CryptoKey> {
  return fileNameKeyOf(await testBits(secret));
}

/** A file's name on the server, as a device with [secret] draws it. */
export async function testFileName(sha256: string, secret: string = testPin): Promise<string> {
  return fileNameOf(await fileNameKeyOf(await testBits(secret)), sha256);
}

/** What a row the fake server keeps says, opened as a device with [secret] would. */
export async function openStored(
  record: PulledRecord | undefined,
  secret: string = testPin,
): Promise<Record<string, unknown> | undefined> {
  if (!record?.enc) return undefined;
  return openRowV2(await testKey(secret), record.table, record.uuid, record, record.enc);
}

/**
 * Waits for every write already started to land: a transaction over
 * every table queues behind them. A test that checks a second click did
 * nothing waits on this, not on the wall clock.
 */
export async function writesSettled(h: Awaited<ReturnType<typeof device>>): Promise<void> {
  await h.writer.run(() => Promise.resolve());
}
