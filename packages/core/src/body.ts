/**
 * Body weight: the dots, the line that means something, and which way
 * it is going. A port of
 * `apps/mobile/lib/features/health/domain/body_weight.dart`, held to
 * `fixtures/weight.json`.
 *
 * Storage is grams, always, for the reason money is stored in minor
 * units ([[Health]] H4). Raw daily weights are noise — water, salt, the
 * time of day — so the line is a moving average over a week.
 */

import { HarvestDay } from './harvest-day.js';

export interface WeightLike {
  /** The Harvest Day it was measured on. */
  readonly harvestDay: string;
  readonly grams: number;
}

export interface WeightPoint {
  readonly day: string;
  /** The day's own reading, or null on a day with none. */
  readonly entry: number | null;
  /** The moving average, or null before there is anything to average. */
  readonly average: number | null;
}

/** How many days of entries the average smooths over. */
export const trendWindow = 7;

/** The windows the summary can be read over. */
export const trendWindows = [30, 90, 365] as const;

export const gramsPerPound = 453.59237;

/** Grams as kilograms or pounds, for display only. */
export function weightIn(unit: 'kg' | 'lb', grams: number): number {
  return unit === 'kg' ? grams / 1000 : grams / gramsPerPound;
}

export function weightToGrams(unit: 'kg' | 'lb', value: number): number {
  return Math.round(unit === 'kg' ? value * 1000 : value * gramsPerPound);
}

/** The lightest and heaviest a body weight can be (`minBodyWeightGrams`, `maxBodyWeightGrams`): 20 kg to 400 kg. */
export const minBodyWeightGrams = 20_000;
export const maxBodyWeightGrams = 400_000;

/**
 * Whether [grams] is a weight a person can have (`isPlausibleBodyWeight`).
 * Outside 20–400 kg it is a typo — 900 kg, or 8.2 for 82 — and it is
 * refused rather than drawn into the line ([[Health]] H4, W6-15).
 */
export function isPlausibleBodyWeight(grams: number): boolean {
  return Number.isFinite(grams) && grams >= minBodyWeightGrams && grams <= maxBodyWeightGrams;
}

/**
 * One point per day between the first and last entry, so a gap in the
 * middle is drawn as a gap rather than closed silently. The average at
 * a day is the mean of every day's mean within [window] days back —
 * two weigh-ins on one day are one day's worth of evidence, not two.
 */
export function weightSeries(entries: readonly WeightLike[], window = trendWindow): WeightPoint[] {
  if (entries.length === 0) return [];
  const byDay = new Map<string, number[]>();
  for (const entry of entries) {
    const readings = byDay.get(entry.harvestDay);
    if (readings) readings.push(entry.grams);
    else byDay.set(entry.harvestDay, [entry.grams]);
  }
  const keys = [...byDay.keys()].sort();
  const first = HarvestDay.parse(keys[0]!);
  const last = HarvestDay.parse(keys[keys.length - 1]!);

  const mean = (values: number[]) => values.reduce((sum, value) => sum + value, 0) / values.length;
  const points: WeightPoint[] = [];
  for (let day = first; day.compareTo(last) <= 0; day = day.next) {
    const today = byDay.get(day.key);
    const recent: number[] = [];
    for (let back = 0; back < window; back++) {
      const readings = byDay.get(day.addDays(-back).key);
      if (readings && readings.length > 0) recent.push(mean(readings));
    }
    points.push({
      day: day.key,
      entry: today ? mean(today) : null,
      average: recent.length === 0 ? null : mean(recent),
    });
  }
  return points;
}

export interface WeightTrend {
  readonly gramsChanged: number;
  readonly days: number;
  readonly entries: number;
}

/**
 * The change over the last [days], measured on the trend line rather
 * than on two raw entries: comparing today's number with the one from a
 * month ago compares two pieces of noise.
 */
export function weightTrend(
  entries: readonly WeightLike[],
  days: number,
  window = trendWindow,
): WeightTrend | null {
  if (entries.length < 2) return null;
  const withAverage = weightSeries(entries, window).filter((point) => point.average !== null);
  if (withAverage.length < 2) return null;
  const last = withAverage[withAverage.length - 1]!;
  const cutoff = HarvestDay.parse(last.day).addDays(-(days - 1)).key;
  const from = withAverage.find((point) => point.day >= cutoff) ?? withAverage[0]!;
  if (from.day === last.day) return null;
  return {
    // Dart's `round()`: a half goes away from zero, not towards +∞.
    gramsChanged: Math.sign(last.average! - from.average!) * Math.round(Math.abs(last.average! - from.average!)),
    days: HarvestDay.parse(from.day).daysUntil(HarvestDay.parse(last.day)),
    entries: entries.filter((entry) => entry.harvestDay >= from.day).length,
  };
}
