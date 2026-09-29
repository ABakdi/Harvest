import type { HarvestDay } from './harvest-day.js';
import { productiveActions, type ActionCommitment } from './streak.js';

/**
 * The activity heat-map ([[Gamification]], Web W2): one rule for what a
 * day's square counts, over which window, and how it is shaded, so the
 * phone and the web draw the same map. Pinned by `fixtures/activity.json`.
 */

/** How many whole weeks the heat-map shows, the current one included. */
export const activityWeeks = 26;

/** The heat-map's days: whole weeks, Monday to Sunday, the last being [today]'s week. */
export function activityWindow(today: HarvestDay, weeks = activityWeeks): { start: HarvestDay; end: HarvestDay } {
  const end = today.weekStart.addDays(6);
  return { start: end.addDays(-(weeks * 7 - 1)), end };
}

export interface ActivityCheckIn {
  readonly commitmentUuid: string;
  readonly harvestDay: string;
  readonly quantity: number;
  readonly deletedAt: string | null;
}

export interface ActivitySeed extends ActionCommitment {
  readonly deletedAt: string | null;
}

export interface ActivityAlbum {
  readonly uuid: string;
  readonly scheduled: boolean;
  readonly deletedAt: string | null;
}

export interface ActivityMemory {
  readonly albumUuid: string;
  readonly harvestDay: string;
  readonly deletedAt: string | null;
}

/**
 * Each day's height between [start] and [end]: its productive actions,
 * the count the Daily Harvest Goal is judged by (`productiveActions`),
 * so a square means what the streak means. A project counts once its
 * daily amount is met; a scheduled album with a picture counts one. A
 * seed or album that was deleted, and whatever is in the trash, counts
 * nothing; an archived seed's past effort still counts. Days with
 * nothing are left out.
 */
export function dayActivity(
  input: {
    readonly checkIns: readonly ActivityCheckIn[];
    readonly seeds: readonly ActivitySeed[];
    readonly albums?: readonly ActivityAlbum[];
    readonly memories?: readonly ActivityMemory[];
  },
  start: HarvestDay,
  end: HarvestDay,
): Record<string, number> {
  const inWindow = (key: string) => key >= start.key && key <= end.key;
  const seeds = input.seeds.filter((seed) => seed.deletedAt === null);
  const units = new Map<string, Map<string, number>>();
  for (const row of input.checkIns) {
    if (row.deletedAt !== null || !inWindow(row.harvestDay)) continue;
    const day = units.get(row.harvestDay) ?? new Map<string, number>();
    day.set(row.commitmentUuid, (day.get(row.commitmentUuid) ?? 0) + row.quantity);
    units.set(row.harvestDay, day);
  }
  const scheduled = new Set(
    (input.albums ?? []).filter((album) => album.deletedAt === null && album.scheduled).map((album) => album.uuid),
  );
  const pictured = new Map<string, Set<string>>();
  for (const memory of input.memories ?? []) {
    if (memory.deletedAt !== null || !scheduled.has(memory.albumUuid) || !inWindow(memory.harvestDay)) continue;
    const albums = pictured.get(memory.harvestDay) ?? new Set<string>();
    albums.add(memory.albumUuid);
    pictured.set(memory.harvestDay, albums);
  }
  const heights: Record<string, number> = {};
  for (const key of [...new Set([...units.keys(), ...pictured.keys()])].sort()) {
    const actions = productiveActions(units.get(key) ?? new Map(), seeds, pictured.get(key)?.size ?? 0);
    if (actions > 0) heights[key] = actions;
  }
  return heights;
}

/**
 * How strongly a day's square is filled, 0 to 1. A day of the current
 * streak is simply on; a quiet day is off; any other day is faded to how
 * close it came to the goal, kept well short of solid so a busy day off
 * the streak never passes for a streak square.
 */
export function activityShade(actions: number, goal: number, inStreak: boolean): number {
  if (inStreak) return 1;
  if (actions <= 0) return 0;
  return Math.min(0.4, Math.max(0.2, goal > 0 ? actions / goal : 0.4));
}
