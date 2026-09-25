import { type DueCommitment, HarvestDay, commitmentFromRow, isDueOn } from '@harvest/core';
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
  const keys = new Set(days.map((day) => day.key));

  const [rows, checkIns, memories, albums, expenses, sessions] = await Promise.all([
    db.rows('commitments').toArray(),
    db.rows('check_ins').toArray(),
    db.rows('memories').toArray(),
    db.rows('albums').toArray(),
    db.rows('expenses').toArray(),
    db.rows('workout_sessions').toArray(),
  ]);

  const doneOn = new Map<string, Set<string>>();
  for (const row of checkIns) {
    if (row.deletedAt !== null || !keys.has(row.harvestDay)) continue;
    const set = doneOn.get(row.harvestDay) ?? new Set<string>();
    set.add(row.commitmentUuid);
    doneOn.set(row.harvestDay, set);
  }

  const weekDone = new Map<string, Map<string, Set<string>>>();
  for (const row of checkIns) {
    if (row.deletedAt !== null) continue;
    const day = HarvestDay.tryParse(row.harvestDay);
    if (day === null) continue;
    const week = weekDone.get(day.weekStart.key) ?? new Map<string, Set<string>>();
    const seen = week.get(row.commitmentUuid) ?? new Set<string>();
    seen.add(row.harvestDay);
    week.set(row.commitmentUuid, seen);
    weekDone.set(day.weekStart.key, week);
  }

  const totals = new Map<string, number>();
  for (const row of checkIns) {
    if (row.deletedAt !== null) continue;
    totals.set(row.commitmentUuid, (totals.get(row.commitmentUuid) ?? 0) + row.quantity);
  }

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
  for (const day of days) {
    const done = doneOn.get(day.key) ?? new Set<string>();
    const entries: DayEntry[] = [];
    for (const { row, commitment } of seeds) {
      // A project is due every day by nature; showing it would fill
      // the month with one seed.
      if (row.type === 'todo') {
        // A to-do sits on the day it was planned for, done or not, as on
        // the phone; the field carries it forward, the calendar does not.
        if (row.dueDay === day.key) entries.push({ row, commitment, deadline: false, done: done.has(row.uuid) });
      } else if (row.type !== 'project') {
        const doneDaysThisWeek = weekDone.get(day.weekStart.key)?.get(row.uuid)?.size ?? 0;
        if (isDueOn(commitment, day, { doneDaysThisWeek, totalLogged: totals.get(row.uuid) ?? 0 })) {
          entries.push({ row, commitment, deadline: false, done: done.has(row.uuid) });
        }
      }
      if (row.deadline === day.key) {
        entries.push({ row, commitment, deadline: true, done: done.has(row.uuid) });
      }
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
