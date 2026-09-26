import type { Me } from '@harvest/contracts';
import { createHarvest, type Harvest } from '@/app/context';
import { HarvestDB } from '@/app/data/db';
import type { SyncTransport } from '@/app/sync/engine';

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

/** A fresh device: its own IndexedDB, its own clock, the shared server. */
export async function device(
  transport: SyncTransport,
  clock = testClock(),
  user: Me = testUser,
): Promise<Harvest & { clock: ReturnType<typeof testClock> }> {
  const db = new HarvestDB(`test-${Date.now()}-${counter++}`);
  await db.open();
  return Object.assign(createHarvest(db, user, transport, clock), { clock });
}
