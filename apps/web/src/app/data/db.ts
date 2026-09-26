import type { EncEnvelope, Issue, SyncedTable, TableData } from '@harvest/contracts';
import { builtInLists, builtInListsStampedAt, listUuidOfItem } from '@harvest/contracts';
import Dexie, { type IndexableType, type Table, type Transaction } from 'dexie';

/**
 * The browser's copy of Harvest ([[ADR-012-Web-Client]]): one IndexedDB
 * store per synced table, named as the contract names them, each row
 * stored exactly as a record's `data` carries it (camelCase, ISO-8601
 * UTC instants, money in minor units). A row can therefore go to the
 * wire and come back without a mapping layer that could drop a column.
 *
 * The first key of each schema string is the record key: `uuid` for
 * most tables, and the few natural keys the contract lists.
 */
export const tableSchemas: Record<SyncedTable, string> = {
  commitments: 'uuid, goalUuid, type',
  check_ins: 'uuid, commitmentUuid, harvestDay, [commitmentUuid+harvestDay]',
  seed_notes: 'uuid, commitmentUuid, harvestDay',
  notes: 'uuid, title, folder',
  note_links: 'uuid, fromUuid, toUuid',
  note_attachments: 'uuid, noteUuid',
  albums: 'uuid',
  memories: 'uuid, albumUuid, harvestDay',
  step_days: 'harvestDay',
  body_weights: 'uuid, harvestDay',
  sleep_sessions: 'uuid, harvestDay',
  exercises: 'uuid',
  programs: 'uuid',
  program_days: 'uuid, programUuid',
  program_slots: 'uuid, dayUuid',
  target_sets: 'uuid, slotUuid',
  training_maxes: '[programUuid+exerciseId]',
  workout_sessions: 'uuid, harvestDay',
  session_exercises: 'uuid, sessionUuid',
  workout_sets: 'uuid, sessionExerciseUuid',
  streaks: 'scope',
  ledger: 'uuid, reason, harvestDay, kind',
  pomodoro_sessions: 'uuid, harvestDay',
  goals: 'uuid',
  goal_items: 'uuid, goalUuid, commitmentUuid',
  lists: 'uuid',
  wishlist_items: 'uuid',
  kv_settings: 'key',
  expenses: 'uuid, harvestDay',
  expense_categories: 'uuid',
  money_txns: 'uuid, linkUuid, account',
  debts: 'uuid',
  debt_payments: 'uuid, debtUuid',
  location_points: 'uuid, harvestDay',
  geotags: 'uuid, [targetTable+targetUuid], harvestDay',
  saved_places: 'uuid',
};

/**
 * One queued change: which row, and when. The row itself is read when
 * the push is built, so ten edits to one note travel as one record.
 */
export interface OutboxRow {
  seq?: number;
  table: SyncedTable;
  /** The record key (`uuid`, or the table's natural key). */
  key: string;
  /** `delete` when the row was hard-deleted and must travel as purged. */
  op: 'upsert' | 'delete';
  /** Also the clock of rows that have none of their own ([[Sync-API]]). */
  queuedAt: string;
  /** Set when the server answered `invalid`; the row is not sent again until it changes. */
  invalid?: Issue[] | null;
}

export interface MetaRow {
  key: string;
  value: unknown;
}

/**
 * A private-tier record pulled before this browser had the passphrase.
 * It waits here, still sealed, and is opened the moment the key exists,
 * so entering the passphrase never means pulling everything again.
 */
export interface SealedRow {
  table: SyncedTable;
  uuid: string;
  updatedAt: string;
  deletedAt: string | null;
  enc: EncEnvelope;
}

/**
 * A picture or a recording this browser has fetched and opened, kept
 * by the name of its own bytes so it is fetched once.
 */
export interface CachedFile {
  sha256: string;
  blob: Blob;
  fetchedAt: string;
}

export type Row<T extends SyncedTable> = TableData<T>;

export class HarvestDB extends Dexie {
  outbox!: Table<OutboxRow, number>;
  meta!: Table<MetaRow, string>;
  sealed!: Table<SealedRow, [string, string]>;
  files!: Table<CachedFile, string>;

  constructor(name = 'harvest') {
    super(name);
    // A store that joins later gets a version of its own: a browser that
    // already opened an earlier version never re-reads the first one, so
    // a table added there would simply not exist for it.
    const { wishlist_items: wishlistItems, lists, ...firstTables } = tableSchemas;
    this.version(1).stores({
      ...firstTables,
      outbox: '++seq, [table+key], table',
      meta: 'key',
      sealed: '[table+uuid], table',
    });
    // Files arrived with the phone's own file sync ([[Sync-API]]).
    this.version(2).stores({ files: 'sha256' });
    // The Wishlist ([[Wishlist]]), v19 on the phone.
    this.version(3).stores({ wishlist_items: wishlistItems });
    // Lists ([[Lists]]), v23 on the phone: the Wishlist's items are told
    // which list they are in, and someone who kept a Wishlist finds the
    // feature on. The four built-in lists themselves are made on every
    // open ([[seedBuiltInLists]]), so a fresh store has them too.
    this.version(4)
      .stores({ lists })
      .upgrade((trans) => upgradeToLists(trans));
    this.on('ready', (db) => seedBuiltInLists(db as HarvestDB));
  }

  rows<T extends SyncedTable>(table: T): Table<Row<T>, IndexableType> {
    return this.table(table);
  }
}

/** The Dexie primary key for a record key. */
export function primaryKeyOf(table: SyncedTable, key: string): IndexableType {
  if (table === 'training_maxes') {
    const slash = key.indexOf('/');
    return [key.slice(0, slash), key.slice(slash + 1)];
  }
  return key;
}

/** The record key of a stored row, as the contract defines it. */
export function recordKeyOf(table: SyncedTable, row: Record<string, unknown>): string {
  switch (table) {
    case 'step_days':
      return row.harvestDay as string;
    case 'streaks':
      return row.scope as string;
    case 'kv_settings':
      return row.key as string;
    case 'training_maxes':
      return `${row.programUuid as string}/${row.exerciseId as string}`;
    default:
      return row.uuid as string;
  }
}

// ----------------------------------------------------------------- lists

/** `FeatureKeys.lists`: Records' fourth tab, off until switched on. */
export const listsFeatureKey = 'features.lists';

/**
 * Makes the built-in lists that are missing, and leaves the ones that
 * are there — renamed, reordered — alone ([[Lists]] L10). Their ids are
 * fixed and their stamp is old, so the same rows from another device
 * merge into these instead of beside them; nothing is queued, since
 * every device makes them itself (the phone's `seedBuiltInLists`).
 */
export async function seedBuiltInLists(db: HarvestDB): Promise<void> {
  await db.transaction('rw', db.rows('lists'), async () => {
    const table = db.rows('lists');
    for (const list of builtInLists) {
      if ((await table.get(list.uuid)) !== undefined) continue;
      await table.add({
        uuid: list.uuid,
        name: list.name,
        kind: list.kind,
        icon: null,
        position: list.position,
        builtIn: list.key,
        createdAt: builtInListsStampedAt,
        updatedAt: builtInListsStampedAt,
        deletedAt: null,
      });
    }
  });
}

/**
 * The store's v4, the phone's v23: each item gets the list its old
 * column names, and the new columns as empty — a local rewrite, not an
 * edit, so no stamp moves and nothing is queued. If any item is live,
 * `features.lists` starts on, and that preference is queued like any
 * other so the other devices hear it.
 */
async function upgradeToLists(trans: Transaction): Promise<void> {
  const items = trans.table('wishlist_items');
  let live = 0;
  await items.toCollection().modify((row: Record<string, unknown>) => {
    row.listUuid = listUuidOfItem(row as { list: string; listUuid?: string | null });
    for (const column of ['mediaType', 'link', 'creator', 'startedAt', 'rating', 'seedUuid', 'noteUuid']) {
      row[column] ??= null;
    }
    if (row.deletedAt === null) live++;
  });
  if (live === 0) return;
  const now = new Date().toISOString();
  const settings = trans.table('kv_settings');
  if ((await settings.get(listsFeatureKey)) !== undefined) return;
  await settings.put({ key: listsFeatureKey, valueJson: JSON.stringify('true'), updatedAt: now });
  await trans.table('outbox').add({ table: 'kv_settings', key: listsFeatureKey, op: 'upsert', queuedAt: now } satisfies OutboxRow);
}

// ------------------------------------------------------------------ meta

export const metaKeys = {
  deviceId: 'deviceId',
  cursor: 'cursor',
  user: 'user',
  lastSyncedAt: 'lastSyncedAt',
  privateKey: 'privateKey',
} as const;

export async function getMeta<T>(db: HarvestDB, key: string): Promise<T | undefined> {
  return (await db.meta.get(key))?.value as T | undefined;
}

export async function setMeta(db: HarvestDB, key: string, value: unknown): Promise<void> {
  await db.meta.put({ key, value });
}

/** This browser's id for the push body; made once and kept. */
export async function deviceIdOf(db: HarvestDB): Promise<string> {
  const known = await getMeta<string>(db, metaKeys.deviceId);
  if (known) return known;
  const id = crypto.randomUUID();
  await setMeta(db, metaKeys.deviceId, id);
  return id;
}
