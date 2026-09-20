import type { HarvestDay } from '@harvest/core';
import { productiveActions } from '@harvest/core';
import type { HarvestDB } from './db';

export interface HeatDay {
  key: string;
  day: HarvestDay;
  actions: number;
}

export interface SeedStreak {
  uuid: string;
  title: string;
  current: number;
  best: number;
}

export interface StatsView {
  /** Oldest first, a whole number of weeks ending on [today]. */
  heat: HeatDay[];
  busiest: number;
  seeds: SeedStreak[];
  checkIns: number;
  activeDays: number;
}

/**
 * The farmer's own numbers, all sums over the log (W2).
 *
 * A day's height is its **productive actions** — the same count the
 * Daily Harvest Goal is judged by, so a square on the heat-map means
 * what the streak means, rather than counting rows nobody promised
 * anything about.
 */
export async function readStats(db: HarvestDB, today: HarvestDay, weeks = 17): Promise<StatsView> {
  const [rows, checkIns, streaks, albums, memories] = await Promise.all([
    db.rows('commitments').toArray(),
    db.rows('check_ins').toArray(),
    db.rows('streaks').toArray(),
    db.rows('albums').toArray(),
    db.rows('memories').toArray(),
  ]);

  // Whole weeks, so the grid's columns are weeks and its rows weekdays.
  const end = today.weekStart.addDays(6);
  const start = end.addDays(-(weeks * 7 - 1));
  const days: HeatDay[] = [];
  const byDay = new Map<string, Map<string, number>>();
  let liveCheckIns = 0;
  for (const row of checkIns) {
    if (row.deletedAt !== null) continue;
    liveCheckIns += 1;
    const day = byDay.get(row.harvestDay) ?? new Map<string, number>();
    day.set(row.commitmentUuid, (day.get(row.commitmentUuid) ?? 0) + row.quantity);
    byDay.set(row.harvestDay, day);
  }

  const scheduled = new Set(albums.filter((album) => album.deletedAt === null && album.scheduleJson !== null).map((album) => album.uuid));
  const albumDays = new Map<string, Set<string>>();
  for (const memory of memories) {
    if (memory.deletedAt !== null || !scheduled.has(memory.albumUuid)) continue;
    const seen = albumDays.get(memory.harvestDay) ?? new Set<string>();
    seen.add(memory.albumUuid);
    albumDays.set(memory.harvestDay, seen);
  }

  for (let index = 0; index < weeks * 7; index += 1) {
    const day = start.addDays(index);
    const actions = productiveActions(byDay.get(day.key) ?? new Map(), rows, albumDays.get(day.key)?.size ?? 0);
    days.push({ key: day.key, day, actions });
  }

  const streakBy = new Map(streaks.map((row) => [row.scope, row]));
  const seeds = rows
    .filter((row) => row.deletedAt === null && row.archivedAt === null && row.type === 'habit')
    .map((row) => ({
      uuid: row.uuid,
      title: row.title,
      current: streakBy.get(row.uuid)?.current ?? 0,
      best: streakBy.get(row.uuid)?.best ?? 0,
    }))
    .sort((a, b) => b.current - a.current || b.best - a.best || a.title.localeCompare(b.title));

  return {
    heat: days,
    busiest: days.reduce((most, day) => Math.max(most, day.actions), 0),
    seeds,
    checkIns: liveCheckIns,
    activeDays: [...byDay.keys()].length,
  };
}
