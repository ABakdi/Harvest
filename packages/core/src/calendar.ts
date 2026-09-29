import { commitmentFromRow, isDueOn, type CommitmentRowLike } from './due.js';
import type { HarvestDay } from './harvest-day.js';

/**
 * What a calendar day carries ([[Productivity-Engine]]: the calendar):
 * one rule for both clients, pinned by `fixtures/calendar.json`.
 */

/** A seed as the calendar reads it: its row. */
export interface CalendarSeed extends CommitmentRowLike {
  readonly uuid: string;
  readonly deadline: string | null;
  readonly archivedAt: string | null;
  readonly deletedAt: string | null;
}

export interface CalendarCheckIn {
  readonly commitmentUuid: string;
  readonly harvestDay: string;
  readonly quantity: number;
  readonly deletedAt: string | null;
}

export interface CalendarEntry {
  readonly uuid: string;
  /** The seed's deadline falls on the day, rather than the seed being due. */
  readonly deadline: boolean;
  readonly done: boolean;
}

/**
 * The seeds a calendar day lists, in the seeds' order, each with whether
 * it was done:
 * - a habit on the days it is due (`isDueOn`). A times-a-week habit
 *   counts only the days before the cell in its week, so meeting the
 *   quota on Wednesday takes it off Thursday to Sunday, never off
 *   Monday to Wednesday; done is a check-in that day;
 * - a to-do on the day it was planned for, done once it was ever
 *   checked in, a day late included;
 * - a project never (it is due every day), but its deadline shows;
 * - a deadline on its day, done when the project reached its target
 *   (a to-do: once done; a habit: checked in that day).
 * Archived and deleted seeds, and one whose schedule cannot be read,
 * are left out.
 */
export function calendarEntries(
  seeds: readonly CalendarSeed[],
  checkIns: readonly CalendarCheckIn[],
  day: HarvestDay,
): CalendarEntry[] {
  const weekStart = day.weekStart.key;
  const onDay = new Set<string>();
  const daysBefore = new Map<string, Set<string>>();
  const logged = new Map<string, number>();
  for (const row of checkIns) {
    if (row.deletedAt !== null) continue;
    logged.set(row.commitmentUuid, (logged.get(row.commitmentUuid) ?? 0) + row.quantity);
    if (row.harvestDay === day.key) onDay.add(row.commitmentUuid);
    if (row.harvestDay >= weekStart && row.harvestDay < day.key) {
      const days = daysBefore.get(row.commitmentUuid) ?? new Set<string>();
      days.add(row.harvestDay);
      daysBefore.set(row.commitmentUuid, days);
    }
  }

  const entries: CalendarEntry[] = [];
  for (const seed of seeds) {
    if (seed.deletedAt !== null || seed.archivedAt !== null) continue;
    let commitment;
    try {
      commitment = commitmentFromRow(seed);
    } catch {
      continue;
    }
    const ever = logged.get(seed.uuid) ?? 0;
    if (seed.type === 'habit') {
      const doneDaysThisWeek = daysBefore.get(seed.uuid)?.size ?? 0;
      if (isDueOn(commitment, day, { doneDaysThisWeek })) {
        entries.push({ uuid: seed.uuid, deadline: false, done: onDay.has(seed.uuid) });
      }
    } else if (seed.type === 'todo' && seed.dueDay === day.key) {
      entries.push({ uuid: seed.uuid, deadline: false, done: ever > 0 });
    }
    if (seed.deadline === day.key) {
      const done =
        seed.type === 'project'
          ? ever >= (seed.totalTarget ?? 0) && ever > 0
          : seed.type === 'todo'
            ? ever > 0
            : onDay.has(seed.uuid);
      entries.push({ uuid: seed.uuid, deadline: true, done });
    }
  }
  return entries;
}
