/**
 * One note per seed per Harvest Day ([[Productivity-Engine]]: the seed's
 * day notes). Two devices writing the same day's note offline each make
 * a row, and sync brings both: the newest write is the day's note, and
 * the next write folds the others into it ([[Audit-v3]] Q6-07). Both
 * apps read the same rule, held to `fixtures/seed-notes.json`.
 */

export interface SeedNoteLike {
  readonly uuid: string;
  readonly commitmentUuid: string;
  readonly harvestDay: string;
  readonly updatedAt: string | Date;
  readonly deletedAt?: string | Date | null;
}

const epoch = (at: string | Date) => (at instanceof Date ? at.getTime() : Date.parse(at));

/** Whether [a] is the newer write: the later `updatedAt`, then the greater uuid, so every device picks the same. */
function newer(a: SeedNoteLike, b: SeedNoteLike): boolean {
  const diff = epoch(a.updatedAt) - epoch(b.updatedAt);
  return diff !== 0 ? diff > 0 : a.uuid > b.uuid;
}

/** The note of [seedUuid] on [dayKey] among [rows], and the live others that duplicate it. */
export function seedNoteOfDay<T extends SeedNoteLike>(
  rows: readonly T[],
  seedUuid: string,
  dayKey: string,
): { note: T | null; extras: T[] } {
  const live = rows.filter(
    (row) =>
      row.commitmentUuid === seedUuid &&
      row.harvestDay === dayKey &&
      (row.deletedAt === null || row.deletedAt === undefined),
  );
  let note: T | null = null;
  for (const row of live) if (note === null || newer(row, note)) note = row;
  return { note, extras: live.filter((row) => row !== note) };
}

/** One note per seed-day out of [rows], the newest of each; the live ones only. */
export function oneNotePerDay<T extends SeedNoteLike>(rows: readonly T[]): T[] {
  const byDay = new Map<string, T>();
  for (const row of rows) {
    if (row.deletedAt !== null && row.deletedAt !== undefined) continue;
    const key = `${row.commitmentUuid}|${row.harvestDay}`;
    const kept = byDay.get(key);
    if (kept === undefined || newer(row, kept)) byDay.set(key, row);
  }
  return [...byDay.values()];
}
