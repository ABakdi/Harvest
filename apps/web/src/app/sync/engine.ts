import {
  hasColumn,
  instantMicros,
  isPortableSetting,
  openRowV2,
  sealRowV2,
  isSyncedTable,
  maxPushBytes,
  maxPushRecords,
  tables,
  tierOf,
  type EncEnvelope,
  type Issue,
  type PulledRecord,
  type PullResult,
  type PushBody,
  type PushResult,
  type SyncedTable,
  type SyncRecord,
} from '@harvest/contracts';
import type { IndexableType, Table } from 'dexie';
import {
  deviceIdOf,
  getMeta,
  metaKeys,
  primaryKeyOf,
  setMeta,
  type HarvestDB,
  type MetaRow,
  type OutboxRow,
  type ParkedRow,
  type SealedRow,
} from '../data/db';
import type { Keyring } from './keyring';
import { background } from '@/lib/actions';

/** The two verbs of [[Sync-API]]; the real one is `api`, the tests bring a fake. */
export interface SyncTransport {
  push(body: PushBody): Promise<PushResult>;
  /** With [deviceId], the server leaves out what this device wrote itself. */
  pull(after: number, limit: number, deviceId?: string): Promise<PullResult>;
}

/**
 * A sealed write the server refused for a stale key epoch: the PIN was
 * started over on another device, and the key here was the old one (S6-07).
 */
export class KeyChangedError extends Error {
  override readonly name = 'KeyChangedError';
}

/** A record's JSON size in bytes, as the push body carries it. */
const encoder = new TextEncoder();
function sizeOf(record: unknown): number {
  return encoder.encode(JSON.stringify(record)).length + 1;
}

/** Room a push body keeps beside its records. */
const bodyOverhead = 1024;

/** Lets the page breathe between two pull pages (P6-01). */
const breathe = () => new Promise<void>((resolve) => setTimeout(resolve, 0));

export type SyncPhase = 'idle' | 'syncing' | 'offline' | 'signedOut' | 'unverified' | 'error';

export interface SyncStatus {
  phase: SyncPhase;
  lastSyncedAt: string | null;
  /** Rows waiting to go up. */
  pending: number;
  /** Rows the server refused; shown in Settings, never retried blindly. */
  invalid: number;
  /** Why they were refused, by issue code (`quota_exceeded`, `clock_ahead`, …). */
  refusedFor: string[];
  /** Private-tier rows that came down before this browser had the passphrase. */
  sealed: number;
  /**
   * Sealed rows the key here cannot open: sealed by 3.0.0, or not what
   * they claim to be. Counted, never fatal ([[Sync-API]]).
   */
  unreadable: number;
  /** Private-tier rows written here and waiting for the passphrase to leave. */
  locked: number;
  /** No sync has finished yet: whatever the phone sent is still on its way. */
  firstSync: boolean;
  /** The PIN was started over on another device; the key here was forgotten. */
  pinChanged: boolean;
  error: string | null;
}

/** An error from the transport, as the engine reads it. */
function errorPhase(error: unknown): SyncPhase {
  const candidate = error as { code?: unknown; status?: unknown };
  if (candidate.code === 'network') return 'offline';
  if (candidate.status === 401) return 'signedOut';
  if (candidate.status === 403) return 'unverified';
  return 'error';
}

/**
 * A row's own clock, the one the conflict rule compares: `updatedAt`
 * where the table has it, `loggedAt` on the append-only ledger, and
 * nothing for the children that have no clock at all.
 */
export function clockOfRow(table: SyncedTable, row: Record<string, unknown>): string | null {
  if (hasColumn(table, 'updatedAt')) return row.updatedAt as string;
  if (table === 'ledger') return row.loggedAt as string;
  return null;
}

/** A millisecond after [iso]: later than it, whatever its spelling. */
export function justAfter(iso: string): string {
  return new Date(Math.floor(instantMicros(iso) / 1000) + 1).toISOString();
}

/** The later of two instants. */
function later(a: string, b: string): string {
  return instantMicros(a) >= instantMicros(b) ? a : b;
}

/**
 * What the contract this app was built with can read: every table and
 * its columns. When it changes — an update — rows parked by an older
 * version are read again.
 */
export const contractFingerprint = Object.entries(tables)
  .map(([name, spec]) => `${name}:${Object.keys((spec.data as unknown as { shape: object }).shape).join(',')}`)
  .join('|');

/**
 * Refusals that can pass on their own — an account with room again, a
 * clock put right. A row refused only for these goes again an hour later.
 */
export const passingRefusals = new Set(['quota_exceeded', 'clock_ahead', 'clock_too_far']);
const retryRefusedAfterMs = 60 * 60_000;

/** How often the key's epoch is held against the account's when nothing sealed waits. */
const checkEveryMs = 30 * 60_000;

type Prepared =
  | { kind: 'row'; table: SyncedTable; uuid: string; stamp: number; updatedAt: string; data: Record<string, unknown> }
  | { kind: 'purge'; table: SyncedTable; uuid: string; stamp: number }
  | { kind: 'seal'; row: SealedRow; stamp: number }
  | { kind: 'park'; row: ParkedRow };

export interface SyncEngineOptions {
  db: HarvestDB;
  transport: SyncTransport;
  keyring: Keyring;
  /** The account's salt; null before the account is known. */
  salt: () => string | null;
  /** Told of each row a pulled purge removed, as it was: its file can go too. */
  onPurged?: (table: SyncedTable, row: Record<string, unknown>) => Promise<void>;
  /** Run once after a sync that took any goal item: a parent's tick is settled again (Q5-44). */
  onGoalItems?: () => Promise<void>;
  pullLimit?: number;
  pushBatch?: number;
  now?: () => Date;
  log?: (message: string, detail?: unknown) => void;
}

/**
 * The web's sync, the same protocol as the phone's ([[Sync-API]]):
 * 1. pull until there is no more, so a stale local edit loses to a
 *    newer remote one before it is even sent;
 * 2. push the outbox, oldest first, in batches of 500;
 * 3. pull once more, for whatever landed meanwhile.
 *
 * Merging follows the server's rule (last writer wins on `updatedAt`),
 * and never writes to the outbox: a pulled row is not a new change, and
 * echoing it back would loop. Derived state needs no recomputing step
 * here: every screen reads it live from the rows (W2).
 *
 * One run at a time. A request that arrives mid-run is folded into one
 * more run afterwards, so a write during a sync is never left behind.
 */
export class SyncEngine {
  private readonly db: HarvestDB;
  private readonly transport: SyncTransport;
  private readonly keyring: Keyring;
  private readonly pullLimit: number;
  private readonly pushBatch: number;
  private readonly now: () => Date;
  private readonly log: (message: string, detail?: unknown) => void;
  private running: Promise<void> | null = null;
  private again = false;
  private listeners = new Set<() => void>();
  private snapshot: SyncStatus = {
    phase: 'idle',
    lastSyncedAt: null,
    pending: 0,
    invalid: 0,
    refusedFor: [],
    sealed: 0,
    unreadable: 0,
    locked: 0,
    firstSync: true,
    pinChanged: false,
    error: null,
  };

  // The run's bookkeeping, read at its start and written as it goes.
  private ahead = new Map<string, string>();
  private stale = new Set<string>();
  private purged: { table: SyncedTable; row: Record<string, unknown> }[] = [];
  private goalItemsTaken = false;
  private checkedAt: number | null = null;
  private unreadableAtCheck = 0;

  constructor(private readonly options: SyncEngineOptions) {
    this.db = options.db;
    this.transport = options.transport;
    this.keyring = options.keyring;
    this.pullLimit = options.pullLimit ?? 500;
    this.pushBatch = Math.min(options.pushBatch ?? maxPushRecords, maxPushRecords);
    this.now = options.now ?? (() => new Date());
    this.log = options.log ?? ((message, detail) => console.warn(`[sync] ${message}`, detail ?? ''));
    // A key entered again clears the word that it was changed elsewhere.
    this.keyring.onUnlock(() => {
      background(
        this.keyring.key(this.options.salt()).then((key) => {
          if (key && this.snapshot.pinChanged) this.update({ pinChanged: false, error: null, phase: 'idle' });
        }),
      );
    });
  }

  // ------------------------------------------------------------- status

  get status(): SyncStatus {
    return this.snapshot;
  }

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }

  private update(patch: Partial<SyncStatus>): void {
    this.snapshot = { ...this.snapshot, ...patch };
    for (const listener of this.listeners) listener();
  }

  /** The key was found stale outside a run (a file upload): say so. */
  markPinChanged(): void {
    this.update({ phase: 'error', error: 'pinChanged', pinChanged: true });
  }

  /** Recounts what is waiting, for the status and the settings page. */
  async refreshCounts(): Promise<void> {
    const key = await this.keyring.key(this.options.salt());
    const entries = await this.db.outbox.toArray();
    const pending = new Set<string>();
    const invalid = new Set<string>();
    const locked = new Set<string>();
    const refusedFor = new Set<string>();
    for (const entry of entries) {
      const id = `${entry.table}/${entry.key}`;
      if (entry.invalid) {
        invalid.add(id);
        for (const issue of entry.invalid) if (issue.code) refusedFor.add(issue.code);
      } else if (!key && tierOf(entry.table) === 'private') locked.add(id);
      else pending.add(id);
    }
    const lastSyncedAt = (await getMeta<string>(this.db, metaKeys.lastSyncedAt)) ?? null;
    const sealed = await this.db.sealed.count();
    this.update({
      pending: pending.size,
      invalid: invalid.size,
      refusedFor: [...refusedFor].sort(),
      locked: locked.size,
      sealed,
      unreadable: key ? sealed : 0,
      lastSyncedAt,
      firstSync: lastSyncedAt === null,
    });
  }

  // --------------------------------------------------------------- runs

  /** Runs a sync, or joins the one already running and asks for one more. */
  sync(): Promise<void> {
    if (this.running) {
      this.again = true;
      return this.running;
    }
    this.running = (async () => {
      try {
        do {
          this.again = false;
          await this.oneAtATime(() => this.runOnce());
        } while (this.again && this.snapshot.phase === 'idle');
      } finally {
        this.running = null;
      }
    })();
    return this.running;
  }

  /**
   * One sync at a time across every tab of the browser (Q6-06): two tabs
   * pushing one outbox send each row twice and rewind each other's pull.
   */
  private oneAtATime(run: () => Promise<void>): Promise<void> {
    const locks = typeof navigator !== 'undefined' ? navigator.locks : undefined;
    if (!locks) return run();
    return locks.request('harvest-sync', run) as unknown as Promise<void>;
  }

  private async runOnce(): Promise<void> {
    this.update({ phase: 'syncing', error: null });
    try {
      await this.loadBook();
      if (await this.keyNoLongerFits(false)) return;
      await this.retryPassingRefusals();
      await this.retryParked();
      if (this.stale.size > 0) {
        // A push found the server's copy newer and no pull has brought it
        // since: it is behind the cursor, so the history comes again.
        await setMeta(this.db, metaKeys.cursor, 0);
        await setMeta(this.db, metaKeys.rebuild, true);
      }
      await this.pullAll();
      await this.pushAll();
      await this.pullAll();
      await this.openSealed();
      await this.saveBook();
      await this.releasePurged();
      if (this.goalItemsTaken) {
        this.goalItemsTaken = false;
        await this.options.onGoalItems?.();
      }
      // Rows that stopped opening say the key may be the old one, sooner.
      if ((await this.keyring.key(this.options.salt())) && (await this.db.sealed.count()) > this.unreadableAtCheck) {
        if (await this.keyNoLongerFits(true)) return;
      }
      const at = this.now().toISOString();
      await setMeta(this.db, metaKeys.lastSyncedAt, at);
      this.update({ phase: 'idle' });
    } catch (error) {
      if (error instanceof KeyChangedError) {
        this.update({ phase: 'error', error: 'pinChanged', pinChanged: true });
      } else {
        this.update({ phase: errorPhase(error), error: error instanceof Error ? error.message : String(error) });
      }
    } finally {
      await this.refreshCounts();
    }
  }

  /**
   * Holds the key's epoch against the account's — another device may have
   * started the PIN over — now and then, before every run that would send
   * a private row sealed with it (one small request), and when rows stop
   * opening ([[Accounts]]). A key that no longer fits is forgotten, and
   * the run ends saying so.
   */
  private async keyNoLongerFits(force: boolean): Promise<boolean> {
    const since = this.checkedAt === null ? null : this.now().getTime() - this.checkedAt;
    if (!force && since !== null && since < checkEveryMs && !(await this.privatePending())) return false;
    this.checkedAt = this.now().getTime();
    this.unreadableAtCheck = await this.db.sealed.count();
    if ((await this.keyring.stillTheAccounts(this.options.salt())) !== false) return false;
    this.update({ phase: 'error', error: 'pinChanged', pinChanged: true });
    return true;
  }

  private async privatePending(): Promise<boolean> {
    const privateTables = (Object.keys(tables) as SyncedTable[]).filter((table) => tierOf(table) === 'private');
    const entry = await this.db.outbox
      .where('table')
      .anyOf(privateTables)
      .filter((row) => !row.invalid)
      .first();
    return entry !== undefined;
  }

  private async loadBook(): Promise<void> {
    const ahead = (await getMeta<Record<string, string>>(this.db, metaKeys.ahead)) ?? {};
    // An entry goes when its row is sent or pulled again; one left a
    // month is a row nobody touched since, and is let go.
    const month = this.now().getTime() - 30 * 24 * 60 * 60_000;
    this.ahead = new Map(Object.entries(ahead).filter(([, at]) => Date.parse(at) > month));
    this.stale = new Set((await getMeta<string[]>(this.db, metaKeys.stale)) ?? []);
    this.purged = [];
  }

  private async saveBook(): Promise<void> {
    await setMeta(this.db, metaKeys.ahead, Object.fromEntries(this.ahead));
    await setMeta(this.db, metaKeys.stale, [...this.stale]);
  }

  // --------------------------------------------------------------- pull

  private async pullAll(): Promise<void> {
    let cursor = (await getMeta<number>(this.db, metaKeys.cursor)) ?? 0;
    const deviceId = await deviceIdOf(this.db);
    // What this browser wrote itself it has; only a history pulled again
    // from nothing asks for its own writes back.
    const rebuilding = (await getMeta<boolean>(this.db, metaKeys.rebuild)) === true;
    for (;;) {
      const page = await this.transport.pull(cursor, this.pullLimit, rebuilding ? undefined : deviceId);
      const prepared = await this.prepare(page.records);
      cursor = page.cursor;
      await this.applyPage(prepared, cursor);
      // A page may end early with more to come: keep pulling, and let the
      // screens have the thread between pages.
      if (!page.more) break;
      await breathe();
    }
    if (rebuilding) await this.db.meta.delete(metaKeys.rebuild);
  }

  /**
   * Everything that needs a promise outside IndexedDB (decrypting) is
   * done before the merge transaction opens, which must only ever wait
   * on IndexedDB itself.
   */
  private async prepare(records: PulledRecord[]): Promise<Prepared[]> {
    const key = await this.keyring.key(this.options.salt());
    const prepared: Prepared[] = [];
    for (const record of records) {
      if (!isSyncedTable(record.table)) {
        // A table this version does not know: kept for the one that will.
        prepared.push({ kind: 'park', row: { table: String(record.table), uuid: String(record.uuid), record } });
        continue;
      }
      // Device bookkeeping, and anything that says where a request goes
      // (S5-01), is never taken from another device.
      if (record.table === 'kv_settings' && !isPortableSetting(record.uuid)) continue;
      const stamp = instantMicros(record.updatedAt);
      if (record.purged) {
        prepared.push({ kind: 'purge', table: record.table, uuid: record.uuid, stamp });
        continue;
      }
      if (tierOf(record.table) === 'private') {
        const enc = record.enc;
        if (!enc) continue;
        const sealedRow: SealedRow = {
          table: record.table,
          uuid: record.uuid,
          updatedAt: record.updatedAt,
          deletedAt: record.deletedAt,
          enc,
        };
        if (!key) {
          prepared.push({ kind: 'seal', row: sealedRow, stamp });
          continue;
        }
        const data = await this.openRecord(key, sealedRow);
        prepared.push(
          data
            ? { kind: 'row', table: record.table, uuid: record.uuid, stamp, updatedAt: record.updatedAt, data }
            : { kind: 'seal', row: sealedRow, stamp },
        );
        continue;
      }
      const parsed = tables[record.table].data.safeParse(record.data);
      if (!parsed.success) {
        this.log(`parked an unreadable ${record.table} row`, parsed.error.issues);
        prepared.push({ kind: 'park', row: { table: record.table, uuid: record.uuid, record } });
        continue;
      }
      prepared.push({
        kind: 'row',
        table: record.table,
        uuid: record.uuid,
        stamp,
        updatedAt: record.updatedAt,
        data: parsed.data,
      });
    }
    return prepared;
  }

  private async openRecord(key: CryptoKey, row: SealedRow): Promise<Record<string, unknown> | null> {
    try {
      const opened = await openRowV2(key, row.table, row.uuid, row, row.enc);
      const parsed = tables[row.table].data.safeParse(opened);
      if (parsed.success) return parsed.data;
      this.log(`skipped an unreadable ${row.table} row`, parsed.error.issues);
      return null;
    } catch {
      // Sealed with another key, by 3.0.0, or for another clock: it stays
      // sealed and is counted, and never costs the key ([[Sync-API]]).
      this.log(`could not open a ${row.table} row`);
      return null;
    }
  }

  /**
   * Applies one page of prepared records by the merge rule, in one
   * transaction scoped to the tables the page touches (P6-01): the local
   * rows, the outbox's pending changes and the sealed entries are read
   * once for the whole page, decided in memory, and written back in bulk.
   *
   * - A row with its own clock takes the record when that clock is older
   *   (or only ties, for a row a push just found stale).
   * - A row with no clock of its own takes it unless this browser changed
   *   it after the record's stamp and has not sent that yet (Q5-07).
   * - A missing row takes it unless its delete is still waiting to go up,
   *   made after the record's stamp: a pending delete is a tombstone (Q5-09).
   */
  private async applyPage(prepared: Prepared[], cursor?: number): Promise<void> {
    if (prepared.length === 0 && cursor === undefined) return;
    const touched = new Set<SyncedTable>();
    for (const item of prepared) if (item.kind === 'row' || item.kind === 'purge') touched.add(item.table);
    const scope = [...touched].map((table) => this.db.table(table));
    await this.db.transaction('rw', [...scope, this.db.sealed, this.db.meta, this.db.outbox, this.db.parked], async (trans) => {
      const sealed = trans.table('sealed') as Table<SealedRow, [string, string]>;
      const outbox = trans.table('outbox') as Table<OutboxRow, number>;
      const merged = prepared.filter(
        (item): item is Extract<Prepared, { kind: 'row' | 'purge' }> => item.kind === 'row' || item.kind === 'purge',
      );

      // The rows here, per table, in one read each.
      const locals = new Map<string, Record<string, unknown> | undefined>();
      for (const table of touched) {
        const items = merged.filter((item) => item.table === table);
        const rows = (await trans.table(table).bulkGet(items.map((item) => primaryKeyOf(table, item.uuid)))) as (
          | Record<string, unknown>
          | undefined
        )[];
        items.forEach((item, index) => locals.set(`${table}/${item.uuid}`, rows[index]));
      }
      // The page's pending changes, in one read.
      const pending = new Map<string, number>();
      if (merged.length > 0) {
        const entries = await outbox
          .where('[table+key]')
          .anyOf(merged.map((item) => [item.table, item.uuid]))
          .toArray();
        for (const entry of entries) {
          if (entry.invalid) continue;
          const id = `${entry.table}/${entry.key}`;
          const at = instantMicros(entry.queuedAt);
          if ((pending.get(id) ?? -1) < at) pending.set(id, at);
        }
      }
      const seals = prepared.filter((item) => item.kind === 'seal');
      const sealedHere = seals.length
        ? await sealed.bulkGet(seals.map((item) => [item.row.table, item.row.uuid] as [string, string]))
        : [];

      const puts = new Map<SyncedTable, Record<string, unknown>[]>();
      const deletes = new Map<SyncedTable, IndexableType[]>();
      const sealedPuts: SealedRow[] = [];
      const sealedDeletes: [string, string][] = [];
      const parked: ParkedRow[] = [];

      seals.forEach((item, index) => {
        const existing = sealedHere[index];
        if (!existing || instantMicros(existing.updatedAt) < item.stamp) sealedPuts.push(item.row);
      });
      for (const item of prepared) if (item.kind === 'park') parked.push(item.row);

      for (const item of merged) {
        // Opened, or purged: nothing of it waits sealed any more, whether
        // or not it wins below (Q5-12).
        if (tierOf(item.table) === 'private') sealedDeletes.push([item.table, item.uuid]);
        if (item.table === 'goal_items') this.goalItemsTaken = true;
        const id = `${item.table}/${item.uuid}`;
        const takeTies = this.stale.delete(id);
        const local = locals.get(id);
        const localClock = local ? clockOfRow(item.table, local) : null;
        let newer: boolean;
        if (!local || localClock === null) {
          const since = pending.get(id);
          newer = since === undefined || item.stamp > since;
        } else {
          newer = takeTies ? instantMicros(localClock) <= item.stamp : instantMicros(localClock) < item.stamp;
        }
        if (!newer) continue;
        if (item.kind === 'purge') {
          if (!local) continue;
          (deletes.get(item.table) ?? deletes.set(item.table, []).get(item.table)!).push(primaryKeyOf(item.table, item.uuid));
          this.purged.push({ table: item.table, row: local });
          locals.set(id, undefined);
          continue;
        }
        (puts.get(item.table) ?? puts.set(item.table, []).get(item.table)!).push(item.data);
        locals.set(id, item.data);
        // A clock ahead of this browser's: an edit made here before this
        // browser's clock catches up must still come after it (Q5-10).
        if (item.stamp > this.now().getTime() * 1000) this.ahead.set(id, item.updatedAt);
        else this.ahead.delete(id);
      }

      for (const [table, rows] of puts) await trans.table(table).bulkPut(rows);
      for (const [table, keys] of deletes) await trans.table(table).bulkDelete(keys);
      if (sealedDeletes.length) await sealed.bulkDelete(sealedDeletes);
      if (sealedPuts.length) await sealed.bulkPut(sealedPuts);
      if (parked.length) {
        await (trans.table('parked') as Table<ParkedRow, [string, string]>).bulkPut(parked);
        await (trans.table('meta') as Table<MetaRow, string>).put({ key: metaKeys.parkedFor, value: contractFingerprint });
      }
      if (cursor !== undefined) {
        await (trans.table('meta') as Table<MetaRow, string>).put({ key: metaKeys.cursor, value: cursor });
      }
    });
  }

  /** Opens whatever came down sealed, once the key is here. */
  async openSealed(): Promise<number> {
    const key = await this.keyring.key(this.options.salt());
    if (!key) return 0;
    const waiting = await this.db.sealed.toArray();
    if (waiting.length === 0) return 0;
    const opened: Prepared[] = [];
    for (const row of waiting) {
      const data = await this.openRecord(key, row);
      if (data) {
        const stamp = instantMicros(row.updatedAt);
        opened.push({ kind: 'row', table: row.table, uuid: row.uuid, stamp, updatedAt: row.updatedAt, data });
      }
    }
    await this.applyPage(opened);
    await this.refreshCounts();
    return opened.length;
  }

  /**
   * Reads the rows an older version of the app had to park, once the
   * contract it reads them with has changed (an update, Q5-11).
   */
  private async retryParked(): Promise<void> {
    if ((await getMeta<string>(this.db, metaKeys.parkedFor)) === contractFingerprint) return;
    const parked = await this.db.parked.toArray();
    await setMeta(this.db, metaKeys.parkedFor, contractFingerprint);
    if (parked.length === 0) return;
    const prepared = await this.prepare(parked.map((row) => row.record as PulledRecord));
    await this.db.parked.clear();
    await this.applyPage(prepared);
  }

  private async releasePurged(): Promise<void> {
    const release = this.options.onPurged;
    const purged = this.purged;
    this.purged = [];
    if (!release) return;
    for (const { table, row } of purged) {
      try {
        await release(table, row);
      } catch (error) {
        this.log(`could not release a ${table} file`, error);
      }
    }
  }

  // --------------------------------------------------------------- push

  /**
   * Rows refused only for a reason that can pass go again once an hour
   * has gone by, rather than waiting for an edit that may never come.
   */
  private async retryPassingRefusals(): Promise<void> {
    const cutoff = this.now().getTime() - retryRefusedAfterMs;
    const entries = await this.db.outbox.filter((entry) => {
      const issues: Issue[] = entry.invalid ?? [];
      if (issues.length === 0 || !issues.every((issue) => passingRefusals.has(issue.code ?? ''))) return false;
      return entry.invalidAt ? Date.parse(entry.invalidAt) <= cutoff : true;
    }).toArray();
    if (entries.length === 0) return;
    await this.db.outbox.bulkUpdate(entries.map((entry) => ({ key: entry.seq!, changes: { invalid: null, invalidAt: null } })));
  }

  /**
   * Sends the outbox, oldest first. The outbox is read once for the run
   * (P6-02), and its changes go in batches filled up to [maxPushBytes] and
   * at most [pushBatch] records (Q6-03); a batch the server still finds
   * too large (413) is halved, and a single change too large for any push
   * is refused here, with a reason, instead of blocking every change
   * behind it. A sealed record refused for a stale key epoch ends the run:
   * the key goes, and the PIN is asked for again (S6-07).
   */
  private async pushAll(): Promise<void> {
    const deviceId = await deviceIdOf(this.db);
    const key = await this.keyring.key(this.options.salt());
    const keyId = await this.keyring.keyId();
    const keyEpoch = await this.keyring.epoch();
    const entries = await this.db.outbox.orderBy('seq').toArray();
    const groups = new Map<string, OutboxRow[]>();
    for (const entry of entries) {
      if (entry.invalid) continue;
      if (!key && tierOf(entry.table) === 'private') continue;
      const id = `${entry.table}/${entry.key}`;
      const group = groups.get(id);
      if (group) group.push(entry);
      else groups.set(id, [entry]);
    }
    const all = [...groups.values()];
    for (let start = 0; start < all.length; start += this.pushBatch) {
      const slice = all.slice(start, start + this.pushBatch);
      const records = await this.recordsFor(slice, key);
      let chunk: { group: OutboxRow[]; record: SyncRecord }[] = [];
      let bytes = bodyOverhead;
      for (const [index, group] of slice.entries()) {
        const record = records[index]!;
        const size = sizeOf(record);
        if (size + bodyOverhead > maxPushBytes) {
          await this.refuseHere(group);
          continue;
        }
        if (bytes + size > maxPushBytes) {
          await this.send(deviceId, chunk, keyEpoch, keyId);
          chunk = [];
          bytes = bodyOverhead;
        }
        chunk.push({ group, record });
        bytes += size;
      }
      await this.send(deviceId, chunk, keyEpoch, keyId);
    }
  }

  /** A change too large for any push: flagged here, with its reason. */
  private async refuseHere(group: OutboxRow[]): Promise<void> {
    const issues: Issue[] = [{ path: [], message: 'Too large for one push', code: 'too_large' }];
    const at = this.now().toISOString();
    this.log(`too large to send: ${group[0]!.table}/${group[0]!.key}`);
    await this.db.outbox.bulkUpdate(group.map((entry) => ({ key: entry.seq!, changes: { invalid: issues, invalidAt: at } })));
  }

  private async send(
    deviceId: string,
    chunk: { group: OutboxRow[]; record: SyncRecord }[],
    keyEpoch: number | null,
    keyId: string | null,
  ): Promise<void> {
    if (chunk.length === 0) return;
    const sealed = chunk.some((item) => item.record.enc !== undefined);
    let answer: PushResult;
    try {
      answer = await this.transport.push({
        deviceId,
        ...(sealed && keyEpoch !== null ? { keyEpoch } : {}),
        records: chunk.map((item) => item.record),
      });
    } catch (error) {
      if ((error as { status?: unknown }).status !== 413) throw error;
      if (chunk.length === 1) {
        await this.refuseHere(chunk[0]!.group);
        return;
      }
      const half = Math.ceil(chunk.length / 2);
      await this.send(deviceId, chunk.slice(0, half), keyEpoch, keyId);
      await this.send(deviceId, chunk.slice(half), keyEpoch, keyId);
      return;
    }
    const at = this.now().toISOString();
    let keyChanged = false;
    await this.db.transaction('rw', this.db.outbox, async (trans) => {
      const outbox = trans.table('outbox') as Table<OutboxRow, number>;
      const done: number[] = [];
      for (const [index, { group }] of chunk.entries()) {
        const result = answer.results[index];
        const seqs = group.map((entry) => entry.seq!);
        if (!result) continue;
        const id = `${group[0]!.table}/${group[0]!.key}`;
        if (result.status === 'invalid' && result.issues?.some((issue) => issue.code === 'key_changed')) {
          // Sealed under a key started over elsewhere: it stays queued,
          // and goes again under the new key.
          keyChanged = true;
          continue;
        }
        if (result.status === 'invalid') {
          this.log(`the server refused ${id}`, result.issues);
          await outbox.bulkUpdate(seqs.map((seq) => ({ key: seq, changes: { invalid: result.issues ?? [], invalidAt: at } })));
        } else {
          this.ahead.delete(id);
          // The server's copy won (Q5-10): the pull that follows takes
          // it, even on a tie, and the next run pulls again if it is
          // behind the cursor.
          if (result.status === 'stale') this.stale.add(id);
          done.push(...seqs);
        }
      }
      if (done.length) await outbox.bulkDelete(done);
    });
    if (keyChanged) {
      await this.saveBook();
      await this.keyring.forgetIfStill(keyId ?? undefined);
      throw new KeyChangedError('The PIN was changed on another device');
    }
  }

  /** The records for a batch of changes, each table's rows read in one go. */
  private async recordsFor(groups: OutboxRow[][], key: CryptoKey | null): Promise<SyncRecord[]> {
    const byTable = new Map<SyncedTable, OutboxRow[][]>();
    for (const group of groups) {
      const table = group[0]!.table;
      (byTable.get(table) ?? byTable.set(table, []).get(table)!).push(group);
    }
    const rows = new Map<OutboxRow[], Record<string, unknown> | undefined>();
    for (const [table, list] of byTable) {
      const found = (await this.db.rows(table).bulkGet(list.map((group) => primaryKeyOf(table, group[0]!.key)))) as (
        | Record<string, unknown>
        | undefined
      )[];
      list.forEach((group, index) => rows.set(group, found[index]));
    }
    const records: SyncRecord[] = [];
    for (const group of groups) records.push(await this.recordFor(group, key, rows.get(group)));
    return records;
  }

  /**
   * The record for a row as it is now; a row that is gone travels as
   * purged, stamped when it was deleted. A row last seen with a clock
   * ahead of this browser's is moved just after it first, quietly, so
   * the record and the row tell the same story (Q5-10).
   */
  private async recordFor(
    group: OutboxRow[],
    key: CryptoKey | null,
    found: Record<string, unknown> | undefined,
  ): Promise<SyncRecord> {
    const { table, key: uuid } = group[0]!;
    const seen = this.ahead.get(`${table}/${uuid}`);
    let queuedAt = group[group.length - 1]!.queuedAt;
    if (seen) queuedAt = later(queuedAt, justAfter(seen));
    const store = this.db.rows(table);
    let row = found;
    if (!row) return { table, uuid, updatedAt: queuedAt, deletedAt: null, purged: true };
    if (seen && hasColumn(table, 'updatedAt') && instantMicros(row.updatedAt as string) <= instantMicros(seen)) {
      row = { ...row, updatedAt: justAfter(seen) };
      await store.put(row as never);
    }
    const updatedAt = clockOfRow(table, row) ?? queuedAt;
    const deletedAt = hasColumn(table, 'deletedAt') ? ((row.deletedAt as string | null) ?? null) : null;
    if (tierOf(table) === 'private') {
      const enc: EncEnvelope = await sealRowV2(key!, table, uuid, { updatedAt, deletedAt }, row);
      return { table, uuid, updatedAt, deletedAt, enc };
    }
    return { table, uuid, updatedAt, deletedAt, data: row };
  }

  /**
   * A new key was just kept: every private row this browser holds goes
   * up again under it, each moved on by a millisecond so it wins over
   * its own copy sealed under the old key and loses to anything newer
   * ([[Accounts]], start over). The rows that waited sealed are opened
   * by the sync that follows.
   */
  async privateTierOpened(): Promise<void> {
    // A key entered again: the word that it was changed elsewhere goes.
    if (this.snapshot.pinChanged) this.update({ pinChanged: false, error: null, phase: 'idle' });
    const queuedAt = this.now().toISOString();
    const privateTables = (Object.keys(tables) as SyncedTable[]).filter((table) => tierOf(table) === 'private');
    await this.db.transaction('rw', this.db.tables, async (trans) => {
      const outbox = trans.table('outbox') as Table<OutboxRow, number>;
      for (const table of privateTables) {
        const store = trans.table(table);
        const rows = (await store.toArray()) as Record<string, unknown>[];
        for (const row of rows) {
          const key = String(row.uuid);
          if (hasColumn(table, 'updatedAt')) await store.put({ ...row, updatedAt: justAfter(row.updatedAt as string) });
          await outbox.add({ table, key, op: 'upsert', queuedAt });
        }
      }
    });
    await this.refreshCounts();
  }
}
