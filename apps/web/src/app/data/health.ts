import {
  type SleepNightLike,
  type WeightLike,
  averageSleepMinutes,
  sleepDebt,
  trendWindow,
  weightSeries,
  weightTrend,
} from '@harvest/core';
import type { HarvestDB, Row } from './db';

export type SleepRow = Row<'sleep_sessions'>;
export type WeightRow = Row<'body_weights'>;
export type StepRow = Row<'step_days'>;

/** Live rows only, newest night first. */
export async function readNights(db: HarvestDB): Promise<SleepRow[]> {
  const rows = await db.rows('sleep_sessions').toArray();
  return rows
    .filter((row) => row.deletedAt === null)
    .sort((a, b) => b.harvestDay.localeCompare(a.harvestDay));
}

export async function readWeights(db: HarvestDB): Promise<WeightRow[]> {
  const rows = await db.rows('body_weights').toArray();
  return rows
    .filter((row) => row.deletedAt === null)
    .sort((a, b) => a.harvestDay.localeCompare(b.harvestDay) || a.measuredAt.localeCompare(b.measuredAt));
}

export async function readSteps(db: HarvestDB): Promise<StepRow[]> {
  const rows = await db.rows('step_days').toArray();
  return rows.sort((a, b) => a.harvestDay.localeCompare(b.harvestDay));
}

/**
 * What the sleep card says, worked out with the same rules the phone
 * uses — `packages/core`, from the nights themselves (W2).
 */
export function sleepSummary(rows: readonly SleepRow[], targetMinutes: number) {
  const nights: SleepNightLike[] = rows.map((row) => ({
    harvestDay: row.harvestDay,
    fellAsleepAt: row.fellAsleepAt,
    wokeAt: row.wokeAt,
    targetMinutes: row.targetMinutes,
  }));
  return {
    last: rows[0] ?? null,
    debt: sleepDebt(nights, { targetMinutes }),
    averageMinutes: averageSleepMinutes(nights.slice(0, 14)),
  };
}

/** The chart's points and the trend sentence, from the same port. */
export function weightSummary(rows: readonly WeightRow[], days: number) {
  const entries: WeightLike[] = rows.map((row) => ({
    grams: row.grams,
    harvestDay: row.harvestDay,
    measuredAt: row.measuredAt,
  }));
  return {
    latest: rows[rows.length - 1] ?? null,
    points: weightSeries(entries, trendWindow),
    trend: weightTrend(entries, days, trendWindow),
  };
}
