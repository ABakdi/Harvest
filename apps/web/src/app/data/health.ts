import {
  type Cycle,
  HarvestDay,
  type SleepNightLike,
  type WeightLike,
  Xp,
  averageSleepMinutes,
  cycleMinutes,
  decodeCycle,
  sleepDebt,
  trendWindow,
  weightSeries,
  weightTrend,
} from '@harvest/core';
import type { HarvestDB, Row } from './db';
import { readCycle, settingText } from './settings';
import type { Tx, Writer } from './writer';

export type SleepRow = Row<'sleep_sessions'>;
export type WeightRow = Row<'body_weights'>;
export type StepRow = Row<'step_days'>;
export type WeightUnit = 'kg' | 'lb';

/** Settings keys the Body tab reads (`HealthKeys`, `SleepKeys`). */
export const healthKeys = {
  weightUnit: 'health.weightUnit',
  targetGrams: 'health.targetWeightGrams',
  stepGoal: 'health.stepGoal',
  strideCm: 'health.strideCm',
  trendDays: 'health.trendDays',
} as const;

/** `sleep.night.1` … `sleep.night.7`, Monday to Sunday: a weekday's own night. */
export function sleepNightKey(weekday: number): string {
  return `sleep.night.${weekday}`;
}

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

export function sleptMinutesOf(night: Pick<SleepRow, 'fellAsleepAt' | 'wokeAt'>): number {
  return Math.trunc((Date.parse(night.wokeAt) - Date.parse(night.fellAsleepAt)) / 60_000);
}

// ------------------------------------------------------------- targets

/**
 * The night I mean to have, per weekday, over the daily cycle
 * (`SleepTargets`): a weekday with its own night overrides it.
 */
export interface SleepTargets {
  cycle: Cycle;
  overrides: Record<number, Cycle>;
}

export async function readSleepTargets(db: HarvestDB): Promise<SleepTargets> {
  const cycle = await readCycle(db);
  const rows = await db.rows('kv_settings').bulkGet([1, 2, 3, 4, 5, 6, 7].map(sleepNightKey));
  const overrides: Record<number, Cycle> = {};
  rows.forEach((row, index) => {
    const own = decodeCycle(settingText(row?.valueJson));
    if (own) overrides[index + 1] = own;
  });
  return { cycle, overrides };
}

/** The night that ends on the morning of [day] (`forMorning`). */
export function cycleForMorning(targets: SleepTargets, day: HarvestDay): Cycle {
  return targets.overrides[day.weekday] ?? targets.cycle;
}

/**
 * Minutes from the morning's midnight to the target bedtime and the
 * alarm (`bedtimeFor`, `alarmFor`): the sheet's likeliest answer, so a
 * normal night is one tap. The bedtime is usually negative — the
 * evening before.
 */
export function defaultNight(targets: SleepTargets, day: HarvestDay): { asleep: number; woke: number } {
  const cycle = cycleForMorning(targets, day);
  const woke = cycle.wakeTime.hour * 60 + cycle.wakeTime.minute;
  return { asleep: woke - cycleMinutes(cycle), woke };
}

/** The moment [minutes] past the morning's local midnight, which may be negative. */
export function atMinutes(day: HarvestDay, minutes: number): Date {
  return new Date(day.year, day.month - 1, day.day, 0, minutes);
}

/** How far past the morning's local midnight [moment] is. */
export function minutesFrom(day: HarvestDay, moment: string): number {
  return Math.round((Date.parse(moment) - atMinutes(day, 0).getTime()) / 60_000);
}

/**
 * What the sleep card says, worked out with the same rules the phone
 * uses — `packages/core`, from the nights themselves (W2). The debt
 * looks back fourteen calendar nights ending today, measured against
 * today's target (Business rule 3).
 */
export function sleepSummary(rows: readonly SleepRow[], targets: SleepTargets, today: HarvestDay) {
  const nights: SleepNightLike[] = rows.map((row) => ({
    harvestDay: row.harvestDay,
    fellAsleepAt: row.fellAsleepAt,
    wokeAt: row.wokeAt,
    targetMinutes: row.targetMinutes,
  }));
  const recent = nights.slice(0, 30);
  return {
    last: rows[0] ?? null,
    unlogged: !rows.some((row) => row.harvestDay === today.key),
    debt: sleepDebt(nights, { targetMinutes: cycleMinutes(cycleForMorning(targets, today)), upTo: today }),
    averageMinutes: averageSleepMinutes(recent),
    averageOver: recent.length,
  };
}

// -------------------------------------------------------------- weight

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

/**
 * Grams as the field shows them (`loadFieldValue`): plain digits and a
 * dot, rounded to two places, so a hundred kilos reads 220.46 lb.
 */
export function weightFieldValue(grams: number, unit: WeightUnit): string {
  const value = unit === 'kg' ? grams / 1000 : grams / 453.59237;
  const rounded = Math.round(value * 100) / 100;
  return Number.isInteger(rounded) ? rounded.toFixed(0) : rounded.toFixed(2).replace(/0+$/, '').replace(/\.$/, '');
}

/** A typed weight, comma or dot; null when it is not a positive number. */
export function parseWeight(text: string): number | null {
  const value = Number(text.trim().replace(',', '.'));
  return text.trim() !== '' && Number.isFinite(value) && value > 0 ? value : null;
}

// --------------------------------------------------------------- steps

/** A stride, when nobody has measured one (`defaultStrideCm`). */
export const defaultStrideCm = 75;
export const minStrideCm = 30;
export const maxStrideCm = 150;

/** Within reach of a human leg (`clampStride`). */
export function clampStride(cm: number | null): number {
  if (cm === null || !Number.isFinite(cm)) return defaultStrideCm;
  return Math.min(Math.max(Math.trunc(cm), minStrideCm), maxStrideCm);
}

/** The step goal; zero is no goal, and pays nothing (`StepGoal`). */
export function stepGoalOf(text: string | null | undefined): number {
  const goal = Number.parseInt(text ?? '', 10);
  return Number.isFinite(goal) && goal > 0 ? goal : 0;
}

/** A day the phone was off is not a zero-step day (`averageSteps`). */
export function averageSteps(rows: readonly StepRow[]): number | null {
  const counted = rows.filter((row) => row.steps > 0);
  if (counted.length === 0) return null;
  return Math.trunc(counted.reduce((sum, row) => sum + row.steps, 0) / counted.length);
}

/** Kilometres beside kilograms, miles beside pounds: one choice of units. */
export function stepsDistance(steps: number, strideCm: number, unit: WeightUnit): number {
  const metres = (steps * strideCm) / 100;
  return unit === 'kg' ? metres / 1000 : metres / 1609.344;
}

/**
 * The month of steps (`StepsHistory`): the thirty days ending today,
 * the fourteen most recent of them as bars, and the totals over the
 * finished days only — today is not over, and averaging it in would
 * drag the number down all morning.
 */
export function stepsHistory(rows: readonly StepRow[], today: HarvestDay) {
  const from = today.addDays(-29).key;
  const days = rows.filter((row) => row.harvestDay >= from && row.harvestDay <= today.key);
  const counted = days.filter((row) => row.steps > 0 && row.harvestDay !== today.key);
  if (counted.length === 0) return null;
  const best = counted.reduce((a, b) => (a.steps >= b.steps ? a : b));
  return {
    total: counted.reduce((sum, row) => sum + row.steps, 0),
    average: averageSteps(counted) ?? 0,
    best,
    bars: days.slice(-14),
  };
}

// ---------------------------------------------------------- repository

/** One ledger row per [reason], ever (`_payOnce`). Returns whether it paid. */
async function payOnce(tx: Tx, reason: string, xp: number, harvestDay: string): Promise<boolean> {
  if ((await tx.ledgerFor(reason)).length > 0) return false;
  await tx.ledger({ kind: 'xp', delta: xp, reason, harvestDay });
  return true;
}

/** What a night's XP nets to: the payment less any reversal. */
async function sleepXpNet(tx: Tx, uuid: string): Promise<number> {
  return (await tx.ledgerFor(`sleep:${uuid}`, `sleep-undo:${uuid}`)).reduce((sum, row) => sum + row.delta, 0);
}

export interface NightInput {
  /** The morning the night is filed under ([[Health]] H8). */
  day: HarvestDay;
  fellAsleepAt: Date;
  wokeAt: Date;
  /**
   * Copied in, so changing my hours never rewrites last month (Business
   * rule 3); a night already written down keeps the target it has.
   */
  targetMinutes: number;
  restedStars: number | null;
  /** Absent or null keeps the note the night already has. */
  note?: string | null;
}

/**
 * Nights and weights, mirroring the phone's SleepRepository and
 * HealthRepository. Steps are not written here: they come from the
 * phone's own health store ([[Health]] H2), and so does their XP.
 */
export class HealthRepository {
  constructor(private readonly writer: Writer) {}

  /**
   * Writes the night, replacing any live night already filed under that
   * morning — I did not sleep twice — and pays [Xp.sleep] the first
   * time only (H6). Correcting it later corrects the record without
   * paying again. Returns whether it paid.
   */
  logNight(input: NightInput): Promise<boolean> {
    return this.writer.run(async (tx) => {
      const existing = (await tx.rows('sleep_sessions').where('harvestDay').equals(input.day.key).toArray()).find(
        (row) => row.deletedAt === null,
      );
      const now = tx.now();
      const uuid = existing?.uuid ?? crypto.randomUUID();
      await tx.put('sleep_sessions', {
        uuid,
        harvestDay: input.day.key,
        fellAsleepAt: input.fellAsleepAt.toISOString(),
        wokeAt: input.wokeAt.toISOString(),
        // A correction keeps the target the night was first written
        // against (Business rule 3), and a note it does not carry keeps
        // the one already there, as the phone's `logNight` does.
        targetMinutes: existing?.targetMinutes ?? input.targetMinutes,
        restedStars: input.restedStars,
        note: input.note ?? existing?.note ?? null,
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
        deletedAt: null,
      });
      if (existing || (await sleepXpNet(tx, uuid)) !== 0) return false;
      await tx.ledger({ kind: 'xp', delta: Xp.sleep, reason: `sleep:${uuid}`, harvestDay: input.day.key });
      return true;
    });
  }

  /**
   * Removes a night, and takes back what writing it down paid — with a
   * mirror row, so the ledger stays a sum of true events.
   */
  removeNight(uuid: string): Promise<void> {
    return this.writer.run(async (tx) => {
      const now = tx.now();
      const row = await tx.patch('sleep_sessions', uuid, { deletedAt: now, updatedAt: now });
      if (!row) return;
      const net = await sleepXpNet(tx, uuid);
      if (net > 0) await tx.ledger({ kind: 'xp', delta: -net, reason: `sleep-undo:${uuid}`, harvestDay: row.harvestDay });
    });
  }

  /**
   * One number off the scale. A second weigh-in the same day is a
   * second fact, not a second payment: [Xp.bodyWeight] once a day.
   */
  logWeight(input: { grams: number; note: string | null }): Promise<WeightRow> {
    return this.writer.run(async (tx) => {
      const at = tx.clockNow();
      const now = at.toISOString();
      const row: WeightRow = {
        uuid: crypto.randomUUID(),
        grams: input.grams,
        harvestDay: HarvestDay.of(at).key,
        note: input.note?.trim() || null,
        measuredAt: now,
        updatedAt: now,
        deletedAt: null,
      };
      await tx.put('body_weights', row);
      await payOnce(tx, `weight:${row.harvestDay}`, Xp.bodyWeight, row.harvestDay);
      return row;
    });
  }

  /** The number and the note; when it was measured stays. */
  updateWeight(uuid: string, input: { grams: number; note: string | null }): Promise<void> {
    return this.writer.run(async (tx) => {
      await tx.patch('body_weights', uuid, { grams: input.grams, note: input.note?.trim() || null, updatedAt: tx.now() });
    });
  }

  /** Off the chart, with an undo; the day's XP stays paid, as on the phone. */
  removeWeight(uuid: string): Promise<void> {
    return this.writer.run(async (tx) => {
      const now = tx.now();
      await tx.patch('body_weights', uuid, { deletedAt: now, updatedAt: now });
    });
  }

  restoreWeight(uuid: string): Promise<void> {
    return this.writer.run(async (tx) => {
      await tx.patch('body_weights', uuid, { deletedAt: null, updatedAt: tx.now() });
    });
  }
}
