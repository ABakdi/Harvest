import { useLiveQuery } from 'dexie-react-hooks';
import catalogue from './exercise-names.json';
import type { HarvestDB } from './db';

/**
 * The catalogue's names, id to name.
 *
 * The catalogue itself is reference data: borrowed, read-only, bundled,
 * and it never syncs ([[Business-Rules]] #14) — so a log that refers to
 * `0025` has no name to show until the reader has its own copy. This is
 * that copy, trimmed to the one field a reader needs, generated from
 * `apps/mobile/assets/exercises/exercises.json`. Regenerate it when the
 * catalogue moves.
 */
const names = catalogue as Record<string, string>;

export function catalogueName(id: string): string | null {
  return names[id] ?? null;
}

/**
 * Names for the exercises in a log: mine first, because an exercise I
 * wrote myself is a row that syncs, then the catalogue, then the id —
 * which at least says *something* did happen.
 */
export function useExerciseNames(db: HarvestDB): (id: string) => string {
  const mine = useLiveQuery(async () => {
    const rows = await db.rows('exercises').toArray();
    return new Map(rows.filter((row) => row.deletedAt === null).map((row) => [row.uuid, row.name]));
  }, [db]);
  return (id: string) => mine?.get(id) ?? catalogueName(id) ?? id;
}
