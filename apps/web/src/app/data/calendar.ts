import { type DueCommitment, type HarvestDay, calendarEntries, commitmentFromRow } from '@harvest/core';
import type { HarvestDB, Row } from './db';
import type { SeedRow } from './seeds';

/** One thing a day carries: a seed due, or a deadline falling on it. */
export interface DayEntry {
  row: SeedRow;
  commitment: DueCommitment;
  deadline: boolean;
  done: boolean;
}

export interface CalendarDay {
  day: HarvestDay;
  entries: DayEntry[];
  /** Seeds due and checked in, for the ring on the cell. */
  doneCount: number;
  /** Memories added to scheduled albums, which are seeds too (G3). */
  memories: number;
  expenses: number;
  sessions: number;
}

export type CalendarMonth = Map<string, CalendarDay>;

/**
 * Every day of a month, with what was due on it and what happened.
 *
 * Due-ness is `isDueOn` from `packages/core`, start-day rule and all
 * (#12), so the grid agrees with the field it is a month of. Projects
 * are implicitly daily and stay off the grid, as they do on the phone,
 * or every square would carry every project and the badge would stop
 * meaning anything.
 */
export async function readMonth(db: HarvestDB, anyDayInMonth: HarvestDay): Promise<CalendarMonth> {
  const first = anyDayInMonth.addDays(1 - anyDayInMonth.day);
  const length = new Date(Date.UTC(first.year, first.month, 0)).getUTCDate();
  const days = Array.from({ length }, (_, index) => first.addDays(index));

  const [rows, checkIns, memories, albums, expenses, sessions] = await Promise.all([
    db.rows('commitments').toArray(),
    db.rows('check_ins').toArray(),
    db.rows('memories').toArray(),
    db.rows('albums').toArray(),
    db.rows('expenses').toArray(),
    db.rows('workout_sessions').toArray(),
  ]);

  const scheduled = new Set(albums.filter((album) => album.deletedAt === null && album.scheduleJson !== null).map((album) => album.uuid));
  const countOn = (list: { harvestDay: string; deletedAt: string | null }[], key: string) =>
    list.filter((row) => row.deletedAt === null && row.harvestDay === key).length;

  const seeds = rows
    .filter((row): row is Row<'commitments'> => row.deletedAt === null && row.archivedAt === null)
    .map((row) => {
      try {
        return { row, commitment: commitmentFromRow(row) };
      } catch {
        return null;
      }
    })
    .filter((seed): seed is { row: SeedRow; commitment: DueCommitment } => seed !== null);

  const month: CalendarMonth = new Map();
  const bySeed = new Map(seeds.map((seed) => [seed.row.uuid, seed]));
  for (const day of days) {
    // One rule with the phone's calendar (G5-12): a times-a-week habit
    // counts only the days before the cell, and a to-do done a day
    // late is done.
    const entries: DayEntry[] = [];
    for (const entry of calendarEntries(
      seeds.map((seed) => seed.row),
      checkIns,
      day,
    )) {
      const seed = bySeed.get(entry.uuid);
      if (seed) entries.push({ ...seed, deadline: entry.deadline, done: entry.done });
    }
    month.set(day.key, {
      day,
      entries,
      doneCount: entries.filter((entry) => entry.done && !entry.deadline).length,
      memories: memories.filter((row) => row.deletedAt === null && row.harvestDay === day.key && scheduled.has(row.albumUuid)).length,
      expenses: countOn(expenses, day.key),
      sessions: sessions.filter((row) => row.deletedAt === null && row.endedAt !== null && row.harvestDay === day.key).length,
    });
  }
  return month;
}
