import type { SyncedTable } from '@harvest/contracts';
import { instantOf } from '../archive';
import type { Row } from '../db';
import type { SheetKey } from '../export-sheets';

/*
 * How one sheet of an archive becomes rows of one table, and the
 * small readers every sheet shares. The sheets themselves are grouped
 * by the part of the app they belong to, beside this file.
 */

/** A rating the contract takes, 1–5; anything else reads as none, as on the phone. */
export function ratingOf(stars: number | null): number | null {
  return stars !== null && stars >= 1 && stars <= 5 ? stars : null;
}

export type SheetRow = Record<string, string>;

export interface Context {
  now: string;
  /** Note bodies from the vault, by archive path. */
  bodies: Map<string, string>;
}

/** How one sheet merges into one table. */
export interface Spec<T extends SyncedTable> {
  sheet: SheetKey;
  table: T;
  keyOf: (row: SheetRow) => string | null | undefined;
  /**
   * The column that says how new the row is, and the local column it is
   * compared with. Null for a child row that has no clock of its own —
   * it is added when missing and otherwise left alone.
   */
  stamp: { sheet: string; local: keyof Row<T> & string } | null;
  build: (row: SheetRow, context: Context, existing: Row<T> | undefined) => Record<string, unknown>;
  accept?: (row: SheetRow) => boolean;
}

export function spec<T extends SyncedTable>(value: Spec<T>): Spec<SyncedTable> {
  return value;
}

export const uuidOf = (row: SheetRow) => row.Uuid;
export const text = (value: string | undefined) => value ?? null;
export const at = (value: string | undefined) => instantOf(value);
export const updated = { sheet: 'UpdatedAt', local: 'updatedAt' } as const;
