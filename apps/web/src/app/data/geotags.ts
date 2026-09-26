import type { SyncedTable } from '@harvest/contracts';
import { HarvestDay } from '@harvest/core';
import type { HarvestDB, Row } from './db';
import { settingText } from './settings';
import type { Clock, InsertHook, Tx, Writer } from './writer';

/**
 * The tables whose inserts are *things I did*, and so get a geotag when
 * geotagging is on ([[Places]] PL2). The same list as the phone's
 * `actionTables`; a new feature joins by being added to both.
 */
export const actionTables: ReadonlySet<string> = new Set([
  'commitments',
  'check_ins',
  'seed_notes',
  'notes',
  'note_attachments',
  'memories',
  'albums',
  'expenses',
  'money_txns',
  'debts',
  'debt_payments',
  'body_weights',
  'sleep_sessions',
  'workout_sessions',
  'goals',
  'goal_items',
]);

/** This browser's own switch: off until I turn it on, and it never syncs. */
export const webGeotaggingKey = 'web.geotagging';

/** The shared Places switch (PL1): with it off, nothing is tagged anywhere. */
export const placesFeatureKey = 'features.places';

/** How old a trail point may be and still say where an action happened. */
export const trailPointFreshnessMs = 2 * 60_000;

/** How vague a trail point may be and still stand in for a fresh fix. */
export const trailPointAccuracyM = 100;

/** How long a fresh fix is waited for. */
export const freshFixTimeoutMs = 10_000;

/** How old the browser's last known position may be and still stand in. */
export const lastKnownFreshnessMs = 10 * 60_000;

// ------------------------------------------------------------ geotag ids

/** SHA-1, synchronously: a digest awaited on `crypto.subtle` would end the IndexedDB transaction. */
function sha1(bytes: Uint8Array): Uint8Array {
  const length = bytes.length;
  const blocks = ((length + 8) >> 6) + 1;
  const words = new Uint32Array(blocks * 16);
  for (let i = 0; i < length; i++) words[i >> 2]! |= bytes[i]! << (24 - (i % 4) * 8);
  words[length >> 2]! |= 0x80 << (24 - (length % 4) * 8);
  words[blocks * 16 - 1] = length * 8;

  let h0 = 0x67452301;
  let h1 = 0xefcdab89;
  let h2 = 0x98badcfe;
  let h3 = 0x10325476;
  let h4 = 0xc3d2e1f0;
  const w = new Uint32Array(80);
  const rotl = (x: number, n: number) => (x << n) | (x >>> (32 - n));
  for (let block = 0; block < blocks; block++) {
    for (let i = 0; i < 16; i++) w[i] = words[block * 16 + i]!;
    for (let i = 16; i < 80; i++) w[i] = rotl(w[i - 3]! ^ w[i - 8]! ^ w[i - 14]! ^ w[i - 16]!, 1);
    let a = h0;
    let b = h1;
    let c = h2;
    let d = h3;
    let e = h4;
    for (let i = 0; i < 80; i++) {
      const [f, k] =
        i < 20
          ? [(b & c) | (~b & d), 0x5a827999]
          : i < 40
            ? [b ^ c ^ d, 0x6ed9eba1]
            : i < 60
              ? [(b & c) | (b & d) | (c & d), 0x8f1bbcdc]
              : [b ^ c ^ d, 0xca62c1d6];
      const next = (rotl(a, 5) + f + e + k + w[i]!) >>> 0;
      e = d;
      d = c;
      c = rotl(b, 30) >>> 0;
      b = a;
      a = next;
    }
    h0 = (h0 + a) >>> 0;
    h1 = (h1 + b) >>> 0;
    h2 = (h2 + c) >>> 0;
    h3 = (h3 + d) >>> 0;
    h4 = (h4 + e) >>> 0;
  }
  const out = new Uint8Array(20);
  [h0, h1, h2, h3, h4].forEach((h, i) => {
    out[i * 4] = h >>> 24;
    out[i * 4 + 1] = (h >>> 16) & 0xff;
    out[i * 4 + 2] = (h >>> 8) & 0xff;
    out[i * 4 + 3] = h & 0xff;
  });
  return out;
}

/** The RFC 4122 URL namespace, as the phone's `Namespace.url`. */
const urlNamespace = '6ba7b811-9dad-11d1-80b4-00c04fd430c8';

/** A version-5 UUID of [name] in [namespace]. */
export function uuidV5(namespace: string, name: string): string {
  const ns = namespace.replace(/-/g, '');
  const nsBytes = Uint8Array.from({ length: 16 }, (_, i) => parseInt(ns.slice(i * 2, i * 2 + 2), 16));
  const nameBytes = new TextEncoder().encode(name);
  const input = new Uint8Array(16 + nameBytes.length);
  input.set(nsBytes);
  input.set(nameBytes, 16);
  const hash = sha1(input).slice(0, 16);
  hash[6] = (hash[6]! & 0x0f) | 0x50;
  hash[8] = (hash[8]! & 0x3f) | 0x80;
  const hex = [...hash].map((byte) => byte.toString(16).padStart(2, '0')).join('');
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
}

/**
 * A geotag's id, derived from what it tags, so the same action can
 * never be tagged twice — not by a retry, not by an undo, and not by
 * the phone and the browser both. The phone's `geotagUuid`.
 */
export function geotagUuid(table: string, rowUuid: string): string {
  return uuidV5(urlNamespace, `harvest:geotag:${table}:${rowUuid}`);
}

// --------------------------------------------------------------- fixes

export interface WebFix {
  latitude: number;
  longitude: number;
  accuracyM: number | null;
  at: Date;
}

/** Where the browser is, asked the two ways the filler needs. */
export interface Locator {
  /** One fresh fix, or null when none came within [timeoutMs]. */
  current(timeoutMs: number): Promise<WebFix | null>;
  /** Whatever position the browser still holds, if it is at most [maxAgeMs] old. */
  lastKnown(maxAgeMs: number): Promise<WebFix | null>;
}

function ask(options: PositionOptions): Promise<WebFix | null> {
  if (typeof navigator === 'undefined' || !('geolocation' in navigator)) return Promise.resolve(null);
  return new Promise((resolve) => {
    navigator.geolocation.getCurrentPosition(
      (position) =>
        resolve({
          latitude: position.coords.latitude,
          longitude: position.coords.longitude,
          accuracyM: Number.isFinite(position.coords.accuracy) ? position.coords.accuracy : null,
          at: new Date(position.timestamp),
        }),
      () => resolve(null),
      options,
    );
  });
}

/**
 * The browser's own geolocation: it runs on this device and asks no
 * third party, so it adds no outbound request of the app's own
 * ([[Business-Rules]] #13).
 */
export const browserLocator: Locator = {
  current: (timeoutMs) => ask({ enableHighAccuracy: false, timeout: timeoutMs, maximumAge: 0 }),
  // A zero timeout with a maximum age hands back the cached position, or nothing.
  lastKnown: (maxAgeMs) => ask({ maximumAge: maxAgeMs, timeout: 0 }),
};

/** Whether actions made in this browser are geotagged now: Places on, and this browser's own switch on. */
export async function geotaggingOn(read: (key: string) => Promise<Row<'kv_settings'> | undefined>): Promise<boolean> {
  const [mine, feature] = await Promise.all([read(webGeotaggingKey), read(placesFeatureKey)]);
  return settingText(mine?.valueJson) === 'true' && settingText(feature?.valueJson) === 'true';
}

// ------------------------------------------------------------- the tagger

/** An action waiting for its place: what it is, and when it happened. */
interface Waiting {
  table: SyncedTable;
  key: string;
  at: Date;
}

/**
 * Gives the actions made in this browser the place they happened, the
 * way the phone does ([[Places]] PL2, PL3).
 *
 * The writer tells it about every fresh insert into an action table;
 * when the switch is on, the action waits here, in memory. After the
 * commit it finds the place, cheapest first: the trail's last point if
 * it is recent and sharp enough, then one fresh fix, then the browser's
 * last known position if it is from the last ten minutes, then nothing.
 * Only then is the geotag written, already `fixed` or `unavailable`, in
 * a transaction of its own, with the id and row shape the phone's
 * `logChange` gives it and the action's own moment as its `at`.
 *
 * A pending geotag never leaves the browser: the phone fills any pending
 * tag it holds with its own position, so one synced from here would be
 * stamped with wherever the phone is. A tab closed before the fix loses
 * only the place; the action itself was saved long before, and a missing
 * place never reaches back to it.
 */
export class Geotagger implements InsertHook {
  readonly tables = actionTables;
  private readonly queue = new Map<string, Waiting>();
  private running = false;
  private again = false;
  /** The pass in flight, for tests to wait on. */
  settled: Promise<void> = Promise.resolve();

  constructor(
    private readonly db: HarvestDB,
    private readonly writer: Writer,
    private readonly clock: Clock,
    private readonly locator: Locator = browserLocator,
  ) {
    writer.insertHook = this;
    writer.onWrite(() => {
      if (this.queue.size > 0) this.settled = this.fill();
    });
  }

  async inserted(tx: Tx, table: SyncedTable, key: string): Promise<void> {
    if (!(await geotaggingOn((setting) => tx.get('kv_settings', setting)))) return;
    const uuid = geotagUuid(table, key);
    if (await tx.get('geotags', uuid)) return;
    this.queue.set(uuid, { table, key, at: tx.clockNow() });
  }

  /** One pass over the queue; a pass already running picks up what arrives meanwhile. */
  async fill(): Promise<void> {
    if (this.running) {
      this.again = true;
      return;
    }
    this.running = true;
    try {
      do {
        this.again = false;
        const waiting = [...this.queue];
        this.queue.clear();
        // One fix serves every tag that arrived together: an expense and
        // its money movement are one place, not two requests.
        let fresh: WebFix | null | undefined;
        for (const [uuid, action] of waiting) {
          if (await this.db.rows('geotags').get(uuid)) continue;
          let fix = await this.fromTrail();
          if (!fix) {
            if (fresh === undefined) fresh = await this.fresh();
            fix = fresh;
          }
          await this.write(uuid, action, fix);
        }
      } while (this.again || this.queue.size > 0);
    } catch {
      // A place that could not be written is simply missing; the action stands (PL3).
    } finally {
      this.running = false;
    }
  }

  /** The resolved geotag, written once, never as pending. */
  private write(uuid: string, action: Waiting, fix: WebFix | null): Promise<void> {
    return this.writer.run(async (tx) => {
      // An undo or a sync may have got there first.
      if (await tx.get('geotags', uuid)) return;
      await tx.put('geotags', {
        uuid,
        targetTable: action.table,
        targetUuid: action.key,
        harvestDay: HarvestDay.of(action.at).key,
        at: action.at.toISOString(),
        latitude: fix?.latitude ?? null,
        longitude: fix?.longitude ?? null,
        accuracyM: fix?.accuracyM ?? null,
        state: fix ? 'fixed' : 'unavailable',
        updatedAt: tx.now(),
        deletedAt: null,
      });
    });
  }

  /** The newest trail point, if it is recent and sharp enough to stand in for a fix. */
  private async fromTrail(): Promise<WebFix | null> {
    const now = this.clock();
    const since = new Date(now.getTime() - trailPointFreshnessMs);
    const days = [...new Set([HarvestDay.of(since).key, HarvestDay.of(now).key])];
    const rows = await this.db.rows('location_points').where('harvestDay').anyOf(days).toArray();
    const newest = rows
      .filter((row) => row.deletedAt === null && Date.parse(row.recordedAt) >= since.getTime())
      .sort((a, b) => b.recordedAt.localeCompare(a.recordedAt))[0];
    if (!newest) return null;
    if (newest.accuracyM !== null && newest.accuracyM > trailPointAccuracyM) return null;
    return {
      latitude: newest.latitude,
      longitude: newest.longitude,
      accuracyM: newest.accuracyM,
      at: new Date(newest.recordedAt),
    };
  }

  private async fresh(): Promise<WebFix | null> {
    const fix = await this.locator.current(freshFixTimeoutMs);
    if (fix) return fix;
    const last = await this.locator.lastKnown(lastKnownFreshnessMs);
    if (!last) return null;
    return this.clock().getTime() - last.at.getTime() <= lastKnownFreshnessMs ? last : null;
  }
}
