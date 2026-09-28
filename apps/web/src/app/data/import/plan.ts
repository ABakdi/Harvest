import { instantMicros, tables, tierOf } from '@harvest/contracts';
import { instantOf } from '../archive';
import type { SheetRows } from '../archive-xlsx';
import { primaryKeyOf, recordKeyOf, type HarvestDB, type StoredTable } from '../db';
import type { PendingUpload } from '../files';
import type { Context, Spec } from './sheet-spec';
import type { ImportCount } from '../import';

/*
 * Planning a sheet: each row decided against what this browser holds,
 * by its own clock, before anything is written.
 */

/** Before every stamp there is: a row with no clock never wins over one here. */
const epoch = Number.NEGATIVE_INFINITY;

export function micros(iso: string | null | undefined): number | null {
  if (!iso) return null;
  try {
    return instantMicros(iso);
  } catch {
    return null;
  }
}

/**
 * Every local row's identity and clock. For the private tier, a row
 * this browser holds only sealed counts too: it is here, just not
 * opened yet, and the merge must not call it new.
 */
export async function localStamps(db: HarvestDB, table: StoredTable, column: string | null): Promise<Map<string, number>> {
  const stamps = new Map<string, number>();
  for (const row of (await db.rows(table).toArray()) as Record<string, unknown>[]) {
    stamps.set(recordKeyOf(table, row), column === null ? epoch : (micros(row[column] as string) ?? epoch));
  }
  if (tierOf(table) === 'private') {
    for (const sealed of await db.sealed.where('table').equals(table).toArray()) {
      if (!stamps.has(sealed.uuid)) stamps.set(sealed.uuid, column === null ? epoch : (micros(sealed.updatedAt) ?? epoch));
    }
  }
  return stamps;
}

interface Pending {
  table: StoredTable;
  row: Record<string, unknown>;
}

/** What one sheet would do, and the rows it would write. */
export interface Planned {
  count: ImportCount;
  pending: Pending[];
  /** Files to keep in this browser, by the name of their bytes. */
  files: Map<string, Uint8Array>;
  /** The same files, for the upload queue: the server may not have them. */
  uploads: PendingUpload[];
  newFiles: number;
}

export function emptyCount(): ImportCount {
  return { added: 0, updated: 0, unchanged: 0, skipped: 0 };
}

/**
 * Decides one row: new, newer, or neither. Counts it either way, and
 * leaves out a row the contract would refuse.
 */
export function decide(
  table: StoredTable,
  built: Record<string, unknown>,
  local: number | undefined,
  incoming: number | null,
  planned: Planned,
): boolean {
  const parsed = tables[table].data.safeParse(built);
  if (!parsed.success) {
    planned.count.skipped++;
    return false;
  }
  if (local === undefined) {
    planned.count.added++;
  } else if (incoming !== null && incoming > local) {
    // Same stamp is not newer: an archive taken here and put straight
    // back must be a no-op.
    planned.count.updated++;
  } else {
    planned.count.unchanged++;
    return false;
  }
  planned.pending.push({ table, row: parsed.data });
  return true;
}

export async function planRows(db: HarvestDB, item: Spec<StoredTable>, rows: SheetRows, context: Context): Promise<Planned> {
  const planned: Planned = { count: emptyCount(), pending: [], files: new Map(), uploads: [], newFiles: 0 };
  const local = await localStamps(db, item.table, item.stamp?.local ?? null);
  const store = db.rows(item.table);
  for (const row of rows) {
    const key = item.keyOf(row);
    if (!key) continue;
    if (item.accept && !item.accept(row)) {
      planned.count.unchanged++;
      continue;
    }
    const stamp = local.get(key);
    const incoming = item.stamp === null ? null : micros(instantOf(row[item.stamp.sheet]));
    // Only a row that would be written needs building against what is here.
    if (stamp !== undefined && (incoming === null || incoming <= stamp)) {
      planned.count.unchanged++;
      continue;
    }
    const existing = stamp === undefined ? undefined : await store.get(primaryKeyOf(item.table, key));
    decide(item.table, item.build(row, context, existing), stamp, incoming, planned);
  }
  return planned;
}
