import {
  hasColumn,
  instantMicros,
  openRow,
  sealRow,
  isSyncedTable,
  maxPushRecords,
  tables,
  tierOf,
  type PulledRecord,
  type PullResult,
  type PushBody,
  type PushResult,
  type SyncedTable,
  type SyncRecord,
} from '@harvest/contracts';
import type { Table, Transaction } from 'dexie';
import {
  deviceIdOf,
  getMeta,
  metaKeys,
  primaryKeyOf,
  setMeta,
  type HarvestDB,
  type MetaRow,
  type OutboxRow,
  type SealedRow,
} from '../data/db';
import type { Keyring } from './keyring';

/** The two verbs of [[Sync-API]]; the real one is `api`, the tests bring a fake. */
export interface SyncTransport {
  push(body: PushBody): Promise<PushResult>;
  pull(after: number, limit: number): Promise<PullResult>;
}

export type SyncPhase = 'idle' | 'syncing' | 'offline' | 'signedOut' | 'unverified' | 'error';

export interface SyncStatus {
  phase: SyncPhase;
  lastSyncedAt: string | null;
  /** Rows waiting to go up. */
  pending: number;
  /** Rows the server refused; shown in Settings, never retried blindly. */
  invalid: number;
  /** Private-tier rows that came down before this browser had the passphrase. */
  sealed: number;
  /** Private-tier rows written here and waiting for the passphrase to leave. */
  locked: number;
  /** No sync has finished yet: whatever the phone sent is still on its way. */
  firstSync: boolean;
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

type Prepared =
  | { kind: 'row'; table: SyncedTable; uuid: string; stamp: number; data: Record<string, unknown> }
  | { kind: 'purge'; table: SyncedTable; uuid: string; stamp: number }
  | { kind: 'seal'; row: SealedRow; stamp: number };

export interface SyncEngineOptions {
  db: HarvestDB;
  transport: SyncTransport;
  keyring: Keyring;
  /** The account's salt; null before the account is known. */
  salt: () => string | null;
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
    sealed: 0,
    locked: 0,
    firstSync: true,
    error: null,
  };

  constructor(private readonly options: SyncEngineOptions) {
    this.db = options.db;
    this.transport = options.transport;
    this.keyring = options.keyring;
    this.pullLimit = options.pullLimit ?? 500;
    this.pushBatch = Math.min(options.pushBatch ?? maxPushRecords, maxPushRecords);
    this.now = options.now ?? (() => new Date());
    this.log = options.log ?? ((message, detail) => console.warn(`[sync] ${message}`, detail ?? ''));
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

  /** Recounts what is waiting, for the status and the settings page. */
  async refreshCounts(): Promise<void> {
    const key = await this.keyring.key(this.options.salt());
    const entries = await this.db.outbox.toArray();
    const pending = new Set<string>();
    const invalid = new Set<string>();
    const locked = new Set<string>();
    for (const entry of entries) {
      const id = `${entry.table}/${entry.key}`;
      if (entry.invalid) invalid.add(id);
      else if (!key && tierOf(entry.table) === 'private') locked.add(id);
      else pending.add(id);
    }
    const lastSyncedAt = (await getMeta<string>(this.db, metaKeys.lastSyncedAt)) ?? null;
    this.update({
      pending: pending.size,
      invalid: invalid.size,
      locked: locked.size,
      sealed: await this.db.sealed.count(),
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
          await this.runOnce();
        } while (this.again && this.snapshot.phase === 'idle');
      } finally {
        this.running = null;
      }
    })();
    return this.running;
  }

  private async runOnce(): Promise<void> {
    this.update({ phase: 'syncing', error: null });
    try {
      await this.pullAll();
      await this.pushAll();
      await this.pullAll();
      await this.openSealed();
      const at = this.now().toISOString();
      await setMeta(this.db, metaKeys.lastSyncedAt, at);
      this.update({ phase: 'idle' });
    } catch (error) {
      this.update({ phase: errorPhase(error), error: error instanceof Error ? error.message : String(error) });
    }
    await this.refreshCounts();
  }

  // --------------------------------------------------------------- pull

  private async pullAll(): Promise<void> {
    let cursor = (await getMeta<number>(this.db, metaKeys.cursor)) ?? 0;
    for (;;) {
      const page = await this.transport.pull(cursor, this.pullLimit);
      const prepared = await this.prepare(page.records);
      cursor = page.cursor;
      const next = cursor;
      await this.db.transaction('rw', this.db.tables, async (trans) => {
        for (const item of prepared) await this.apply(trans, item);
        await (trans.table('meta') as Table<MetaRow, string>).put({ key: metaKeys.cursor, value: next });
      });
      if (!page.more) return;
    }
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
      if (!isSyncedTable(record.table)) continue;
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
            ? { kind: 'row', table: record.table, uuid: record.uuid, stamp, data }
            : { kind: 'seal', row: sealedRow, stamp },
        );
        continue;
      }
      const parsed = tables[record.table].data.safeParse(record.data);
      if (!parsed.success) {
        this.log(`skipped an unreadable ${record.table} row`, parsed.error.issues);
        continue;
      }
      prepared.push({
        kind: 'row',
        table: record.table,
        uuid: record.uuid,
        stamp,
        data: parsed.data,
      });
    }
    return prepared;
  }

  private async openRecord(key: CryptoKey, row: SealedRow): Promise<Record<string, unknown> | null> {
    try {
      const parsed = tables[row.table].data.safeParse(await openRow(key, row.table, row.uuid, row.enc));
      if (parsed.success) return parsed.data;
      this.log(`skipped an unreadable ${row.table} row`, parsed.error.issues);
      return null;
    } catch {
      // Sealed with another passphrase: it stays sealed, and says so.
      this.log(`could not open a ${row.table} row`);
      return null;
    }
  }

  /**
   * The merge rule, applied to one record inside the merge transaction.
   * Tables come from [trans] itself, bound to it, so no native `await`
   * can lead an operation out of the transaction.
   */
  private async apply(trans: Transaction, item: Prepared): Promise<void> {
    const sealed = trans.table('sealed') as Table<SealedRow, [string, string]>;
    if (item.kind === 'seal') {
      const existing = await sealed.get([item.row.table, item.row.uuid]);
      if (!existing || instantMicros(existing.updatedAt) < item.stamp) await sealed.put(item.row);
      return;
    }
    const store = trans.table(item.table);
    const primaryKey = primaryKeyOf(item.table, item.uuid);
    const local = (await store.get(primaryKey)) as Record<string, unknown> | undefined;
    const localClock = local ? clockOfRow(item.table, local) : null;
    // A row with no clock of its own cannot be compared; the server's
    // copy is the one every device converges on.
    const newer = !local || localClock === null || instantMicros(localClock) < item.stamp;
    if (!newer) return;
    if (item.kind === 'purge') await store.delete(primaryKey);
    else await store.put(item.data);
    if (tierOf(item.table) === 'private') await sealed.delete([item.table, item.uuid]);
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
      if (data) opened.push({ kind: 'row', table: row.table, uuid: row.uuid, stamp: instantMicros(row.updatedAt), data });
    }
    await this.db.transaction('rw', this.db.tables, async (trans) => {
      for (const item of opened) await this.apply(trans, item);
    });
    await this.refreshCounts();
    return opened.length;
  }

  // --------------------------------------------------------------- push

  private async pushAll(): Promise<void> {
    const deviceId = await deviceIdOf(this.db);
    const key = await this.keyring.key(this.options.salt());
    for (;;) {
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
      const batch = [...groups.values()].slice(0, this.pushBatch);
      if (batch.length === 0) return;

      const records: SyncRecord[] = [];
      for (const group of batch) records.push(await this.recordFor(group, key));
      const answer = await this.transport.push({ deviceId, records });

      await this.db.transaction('rw', this.db.outbox, async (trans) => {
        const outbox = trans.table('outbox') as Table<OutboxRow, number>;
        for (const [index, group] of batch.entries()) {
          const result = answer.results[index];
          const seqs = group.map((entry) => entry.seq!);
          if (!result) continue;
          if (result.status === 'invalid') {
            this.log(`the server refused ${group[0]!.table}/${group[0]!.key}`, result.issues);
            await outbox.bulkUpdate(seqs.map((seq) => ({ key: seq, changes: { invalid: result.issues ?? [] } })));
          } else {
            await outbox.bulkDelete(seqs);
          }
        }
      });
      if (batch.length < this.pushBatch) return;
    }
  }

  /** The record for a row as it is now; a row that is gone travels as purged. */
  private async recordFor(group: OutboxRow[], key: CryptoKey | null): Promise<SyncRecord> {
    const { table, key: uuid } = group[0]!;
    const queuedAt = group[group.length - 1]!.queuedAt;
    const row = (await this.db.rows(table).get(primaryKeyOf(table, uuid))) as Record<string, unknown> | undefined;
    if (!row) return { table, uuid, updatedAt: queuedAt, deletedAt: null, purged: true };
    const updatedAt = clockOfRow(table, row) ?? queuedAt;
    const deletedAt = hasColumn(table, 'deletedAt') ? ((row.deletedAt as string | null) ?? null) : null;
    if (tierOf(table) === 'private') {
      return { table, uuid, updatedAt, deletedAt, enc: await sealRow(key!, table, uuid, row) };
    }
    return { table, uuid, updatedAt, deletedAt, data: row };
  }
}
