import { HarvestDay, currencyOf, globalStreakScope, productiveActions, sumInDefault, type Rates } from '@harvest/core';
import type { HarvestDB } from './db';
import { readRates } from './vault';

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

export interface ProjectProgress {
  uuid: string;
  title: string;
  total: number;
  target: number;
}

/** The Weekly Harvest Report: XP, the best and the quietest day, top spending. */
export interface WeekReport {
  xp: number;
  best: HarvestDay;
  /** Null on a Monday, when there is only one day to compare. */
  worst: HarvestDay | null;
  topCategory: string | null;
}

export interface StatsView {
  /** Oldest first, a whole number of weeks ending on [today]. */
  heat: HeatDay[];
  busiest: number;
  seeds: SeedStreak[];
  checkIns: number;
  activeDays: number;
  /** The Harvest Days the current global streak is made of. */
  streakDays: Set<string>;
  currentStreak: number;
  bestStreak: number;
  week: WeekReport;
  projects: ProjectProgress[];
}

/**
 * The days of the current global streak: counted back from the day it
 * was last earned by how long it is, freeze-covered days included
 * (`streakDays`).
 */
function streakDaysOf(row: { current: number; lastEarnedDay: string | null } | undefined): Set<string> {
  const last = HarvestDay.tryParse(row?.lastEarnedDay);
  if (!row || last === null || row.current <= 0) return new Set();
  return new Set(Array.from({ length: row.current }, (_, index) => last.addDays(-index).key));
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
  const [rows, checkIns, streaks, albums, memories, ledger, expenses, rates] = await Promise.all([
    db.rows('commitments').toArray(),
    db.rows('check_ins').toArray(),
    db.rows('streaks').toArray(),
    db.rows('albums').toArray(),
    db.rows('memories').toArray(),
    db.rows('ledger').toArray(),
    db.rows('expenses').toArray(),
    readRates(db),
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

  const global = streakBy.get(globalStreakScope);
  const totals = new Map<string, number>();
  for (const row of checkIns) {
    if (row.deletedAt === null) totals.set(row.commitmentUuid, (totals.get(row.commitmentUuid) ?? 0) + row.quantity);
  }
  const projects = rows
    .filter((row) => row.deletedAt === null && row.archivedAt === null && row.type === 'project')
    .sort((a, b) => a.createdAt.localeCompare(b.createdAt))
    .map((row) => ({ uuid: row.uuid, title: row.title, total: totals.get(row.uuid) ?? 0, target: row.totalTarget ?? 0 }));

  return {
    heat: days,
    busiest: days.reduce((most, day) => Math.max(most, day.actions), 0),
    seeds,
    checkIns: liveCheckIns,
    activeDays: [...byDay.keys()].length,
    streakDays: streakDaysOf(global),
    currentStreak: global?.current ?? 0,
    bestStreak: global?.best ?? 0,
    week: weekReport(today, checkIns, ledger, expenses, rates),
    projects,
  };
}

/**
 * The week so far, as the phone's report reads it: XP since Monday,
 * and each elapsed day's activity as the seeds checked in on it — the
 * first best and the first quietest win a tie. The top category is
 * the week's spending in the default currency, where this browser can
 * read the private tier at all.
 */
export function weekReport(
  today: HarvestDay,
  checkIns: readonly { commitmentUuid: string; harvestDay: string; deletedAt: string | null }[],
  ledger: readonly { kind: string; delta: number; harvestDay: string }[],
  expenses: readonly { harvestDay: string; deletedAt: string | null; category: string; currency: string; amountMinor: number }[],
  rates: Rates,
): WeekReport {
  const start = today.weekStart;
  const xp = ledger.reduce(
    (sum, entry) => (entry.kind === 'xp' && entry.harvestDay >= start.key ? sum + entry.delta : sum),
    0,
  );
  const seedsOn = new Map<string, Set<string>>();
  for (const row of checkIns) {
    if (row.deletedAt !== null || row.harvestDay < start.key) continue;
    const seen = seedsOn.get(row.harvestDay) ?? new Set<string>();
    seen.add(row.commitmentUuid);
    seedsOn.set(row.harvestDay, seen);
  }
  const elapsed: { day: HarvestDay; count: number }[] = [];
  for (let day = start; day.compareTo(today) <= 0; day = day.next) {
    elapsed.push({ day, count: seedsOn.get(day.key)?.size ?? 0 });
  }
  const best = elapsed.reduce((a, b) => (b.count > a.count ? b : a));
  const worst = elapsed.reduce((a, b) => (b.count < a.count ? b : a));

  const week = new Set(start.weekDays.map((day) => day.key));
  const byCategory = new Map<string, number>();
  for (const row of expenses) {
    if (row.deletedAt !== null || !week.has(row.harvestDay)) continue;
    const minor = sumInDefault(rates, [[currencyOf(row.currency), row.amountMinor]]);
    byCategory.set(row.category, (byCategory.get(row.category) ?? 0) + minor);
  }
  let topCategory: string | null = null;
  let topAmount = -1;
  for (const [category, amount] of byCategory) {
    if (amount > topAmount) {
      topAmount = amount;
      topCategory = category;
    }
  }
  return { xp, best: best.day, worst: elapsed.length > 1 ? worst.day : null, topCategory };
}
