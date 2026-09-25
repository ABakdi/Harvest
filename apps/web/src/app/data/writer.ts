import { isPortableSetting, tables, type SyncedTable } from '@harvest/contracts';
import type { IndexableType, Table, Transaction } from 'dexie';
import type { HarvestDB, OutboxRow, Row } from './db';
import { primaryKeyOf, recordKeyOf } from './db';

/**
 * The one way the app changes a row: the row and its outbox entry in
 * one IndexedDB transaction, so a change can never be saved without
 * being queued, or queued without being saved. The phone's
 * `logChange` does the same job ([[Sync-Strategy]]).
 *
 * Every row is checked against the contract before it is stored. A row
 * the server would refuse is a bug here, and it is cheaper to find it
 * on this device than as an `invalid` in someone's settings.
 */

export type Clock = () => Date;

export interface LedgerEntry {
  kind: 'xp' | 'coin';
  delta: number;
  reason: string;
  harvestDay: string;
}

/**
 * What a fresh insert into one of [tables] owes, written in the same
 * transaction: the geotag of an action ([[Places]] PL2), as the
 * phone's `logChange` writes it.
 */
export interface InsertHook {
  readonly tables: ReadonlySet<string>;
  inserted(tx: Tx, table: SyncedTable, key: string): Promise<void>;
}

export class Tx {
  constructor(
    private readonly trans: Transaction,
    private readonly clock: Clock,
    private readonly queuedAt: string,
    private readonly hook: InsertHook | null = null,
  ) {}

  /**
   * A table bound to this transaction. Dexie's implicit binding follows
   * the transaction through a few native `await`s and then loses it, and
   * a lost operation runs in a transaction of its own while this one
   * commits half-done. Explicitly bound tables cannot get lost.
   */
  rows<T extends SyncedTable>(table: T): Table<Row<T>, IndexableType> {
    return this.trans.table(table) as Table<Row<T>, IndexableType>;
  }

  private get outbox(): Table<OutboxRow, number> {
    return this.trans.table('outbox');
  }

  /** Now, as every row stores it. */
  now(): string {
    return this.clock().toISOString();
  }

  /** Now, as a moment, for the Harvest Day it falls on. */
  clockNow(): Date {
    return this.clock();
  }

  get<T extends SyncedTable>(table: T, key: string): Promise<Row<T> | undefined> {
    return this.rows(table).get(primaryKeyOf(table, key));
  }

  async put<T extends SyncedTable>(table: T, row: Row<T>): Promise<void> {
    const checked = tables[table].data.parse(row) as Row<T>;
    const key = recordKeyOf(table, checked);
    const hook = this.hook?.tables.has(table) ? this.hook : null;
    const fresh = hook !== null && (await this.rows(table).get(primaryKeyOf(table, key))) === undefined;
    await this.rows(table).put(checked);
    // Device bookkeeping never leaves the device; only preferences do.
    if (table === 'kv_settings' && !isPortableSetting(key)) return;
    await this.outbox.add({ table, key, op: 'upsert', queuedAt: this.queuedAt });
    if (fresh && hook) await hook.inserted(this, table, key);
  }

  /** Changes some columns of a stored row; a missing row is left missing. */
  async patch<T extends SyncedTable>(table: T, key: string, changes: Partial<Row<T>>): Promise<Row<T> | undefined> {
    const row = await this.get(table, key);
    if (!row) return undefined;
    const next = { ...row, ...changes } as Row<T>;
    await this.put(table, next);
    return next;
  }

  /** A hard delete, which travels as a purged record. */
  async purge(table: SyncedTable, key: string): Promise<void> {
    await this.rows(table).delete(primaryKeyOf(table, key));
    await this.outbox.add({ table, key, op: 'delete', queuedAt: this.queuedAt });
  }

  /**
   * Ledger rows with any of [reasons], one indexed lookup per reason.
   */
  async ledgerFor(...reasons: string[]): Promise<Row<'ledger'>[]> {
    const found: Row<'ledger'>[] = [];
    for (const reason of reasons) found.push(...(await this.rows('ledger').where('reason').equals(reason).toArray()));
    return found;
  }

  /** One XP or coin movement (`insertLedger`). */
  async ledger(entry: LedgerEntry): Promise<void> {
    await this.put('ledger', {
      uuid: crypto.randomUUID(),
      kind: entry.kind,
      delta: entry.delta,
      reason: entry.reason,
      harvestDay: entry.harvestDay,
      loggedAt: this.now(),
    });
  }
}

export class Writer {
  private readonly listeners = new Set<() => void>();

  /** Set by the geotagger; null leaves every insert as it is. */
  insertHook: InsertHook | null = null;

  constructor(
    readonly db: HarvestDB,
    readonly clock: Clock = () => new Date(),
  ) {}

  /**
   * Runs [work] in one read-write transaction over every table.
   *
   * Only something the person does here and now is geotagged ([[Places]]
   * PL2): rows carried in from elsewhere, an archive say, pass
   * `{ local: false }` and skip the insert hook, so they are never stamped
   * with where this device happens to be today.
   */
  async run<T>(work: (tx: Tx) => Promise<T>, { local = true }: { local?: boolean } = {}): Promise<T> {
    const queuedAt = this.clock().toISOString();
    const hook = local ? this.insertHook : null;
    const result = await this.db.transaction('rw', this.db.tables, (trans) => work(new Tx(trans, this.clock, queuedAt, hook)));
    for (const listener of this.listeners) listener();
    return result;
  }

  /** Hears every committed local write: the sync's two-second debounce. */
  onWrite(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }
}
