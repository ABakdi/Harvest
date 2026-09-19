import type { EncEnvelope, Issue, SyncedTable, TableData } from '@harvest/contracts';
import Dexie, { type IndexableType, type Table } from 'dexie';

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

export type Row<T extends SyncedTable> = TableData<T>;

export class HarvestDB extends Dexie {
  outbox!: Table<OutboxRow, number>;
  meta!: Table<MetaRow, string>;
  sealed!: Table<SealedRow, [string, string]>;

  constructor(name = 'harvest') {
    super(name);
    this.version(1).stores({
      ...tableSchemas,
      outbox: '++seq, [table+key], table',
      meta: 'key',
      sealed: '[table+uuid], table',
    });
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
