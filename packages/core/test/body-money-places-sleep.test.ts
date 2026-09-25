import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';
import {
  HarvestDay,
  averageSleepMinutes,
  budgetSnapshotFor,
  budgetStatus,
  computeBudget,
  cycleMinutes,
  decodeCycle,
  fallbackCycle,
  haversineMetres,
  sleepDebtMinutes,
  sleptMinutes,
  shortfallMinutes,
  stayRadiusM,
  staysIn,
  targetMinutesFor,
  toDefault,
  trailMetres,
  weightSeries,
  weightTrend,
  type BudgetSnapshot,
  type Cycle,
  type Rates,
  type SleepNightLike,
  type Stay,
  type WeightLike,
  type WeightPoint,
  type WeightTrend,
} from '../src/index.js';

/**
 * The rules the web needs for the body, the money and the map, held to
 * the same fixture files the phone's tests read. Two implementations of
 * one rule only stay one rule while both are checked against the same
 * numbers.
 */
function fixture<T>(name: string): T {
  return JSON.parse(readFileSync(new URL(`../fixtures/${name}.json`, import.meta.url), 'utf8')) as T;
}

/** A night as the fixture writes it: what was slept, not when. */
function nightOf(entry: { day: string; sleptMinutes: number; targetMinutes: number }): SleepNightLike {
  return {
    harvestDay: entry.day,
    fellAsleepAt: `${entry.day}T00:00:00`,
    wokeAt: new Date(Date.parse(`${entry.day}T00:00:00`) + entry.sleptMinutes * 60_000).toISOString(),
    targetMinutes: entry.targetMinutes,
  };
}

describe('sleep', () => {
  const spec = fixture<{
    lengths: { why: string; night: SleepNightLike; sleptMinutes: number; shortfallMinutes: number }[];
    debts: {
      why: string;
      nights: { day: string; sleptMinutes: number; targetMinutes: number }[];
      upTo: string | null;
      minutes: number;
    }[];
    average: {
      why: string;
      nights: { day: string; sleptMinutes: number; targetMinutes: number }[];
      averageMinutes: number;
    };
    cycles: { why: string; cycle: string; minutes: number | null }[];
    targets: {
      why: string;
      day: string;
      cycle: string;
      overrides: Record<string, string>;
      minutes: number;
    }[];
  }>('sleep');

  it.each(spec.lengths)('a night: $why', ({ night, sleptMinutes: slept, shortfallMinutes: short }) => {
    expect(sleptMinutes(night)).toBe(slept);
    expect(shortfallMinutes(night)).toBe(short);
  });

  it.each(spec.debts)('the debt: $why', ({ nights, upTo, minutes }) => {
    expect(
      sleepDebtMinutes(nights.map(nightOf), {
        upTo: upTo === null ? null : HarvestDay.parse(upTo),
      }),
    ).toBe(minutes);
  });

  it(`the average: ${spec.average.why}`, () => {
    expect(averageSleepMinutes(spec.average.nights.map(nightOf))).toBe(spec.average.averageMinutes);
  });

  it.each(spec.cycles)('a cycle: $why', ({ cycle, minutes }) => {
    const decoded = decodeCycle(cycle);
    // A cycle that does not decode has no length: nonsense in settings
    // falls back rather than becoming a number.
    expect(decoded === null ? null : cycleMinutes(decoded)).toBe(minutes);
  });

  it.each(spec.targets)('the target: $why', ({ day, cycle, overrides, minutes }) => {
    const byWeekday: Record<number, Cycle> = {};
    for (const [weekday, value] of Object.entries(overrides)) {
      byWeekday[Number(weekday)] = decodeCycle(value) as Cycle;
    }
    expect(
      targetMinutesFor(HarvestDay.parse(day), decodeCycle(cycle) ?? fallbackCycle, byWeekday),
    ).toBe(minutes);
  });
});

describe('money', () => {
  const spec = fixture<{
    conversions: { why: string; rates: Rates; minor: number; from: string; result: number | null }[];
    budgets: {
      why: string;
      monthlyBudget: number;
      spentBeforeToday: number;
      spentToday: number;
      day: string;
      snapshot: Partial<BudgetSnapshot>;
      status: string;
    }[];
    snapshotFromTotals: {
      why: string;
      monthlyBudget: number;
      today: string;
      totalsByDay: Record<string, number>;
      snapshot: Partial<BudgetSnapshot>;
    }[];
  }>('money');

  it.each(spec.conversions)('converting: $why', ({ rates, minor, from, result }) => {
    expect(toDefault(rates, minor, from as Rates['defaultCurrency'])).toBe(result);
  });

  it.each(spec.budgets)('the budget: $why', (entry) => {
    const snapshot = computeBudget({
      monthlyBudget: entry.monthlyBudget,
      spentBeforeToday: entry.spentBeforeToday,
      spentToday: entry.spentToday,
      day: HarvestDay.parse(entry.day),
    });
    expect(snapshot).toMatchObject(entry.snapshot);
    expect(budgetStatus(snapshot)).toBe(entry.status);
  });

  it.each(spec.snapshotFromTotals)('the month: $why', (entry) => {
    const snapshot = budgetSnapshotFor(
      Object.entries(entry.totalsByDay),
      entry.monthlyBudget,
      HarvestDay.parse(entry.today),
    );
    expect(snapshot).toMatchObject(entry.snapshot);
  });
});

describe('places', () => {
  const spec = fixture<{
    distances: {
      why: string;
      from: { latitude: number; longitude: number };
      to: { latitude: number; longitude: number };
      metres: number;
    }[];
    trail: { why: string; points: { latitude: number; longitude: number; at: string }[]; metres: number };
    stays: {
      why: string;
      points: { latitude: number; longitude: number; at: string }[];
      places: { uuid: string; name: string; latitude: number; longitude: number; radiusM?: number; notes?: string | null }[];

      result: (Omit<Stay, 'place'> & { minutes: number; place: string | null })[];
    }[];
  }>('places');

  it.each(spec.distances)('a distance: $why', ({ from, to, metres }) => {
    expect(haversineMetres(from.latitude, from.longitude, to.latitude, to.longitude)).toBeCloseTo(metres, 0);
  });

  it(`a trail: ${spec.trail.why}`, () => {
    expect(trailMetres(spec.trail.points)).toBeCloseTo(spec.trail.metres, 0);
  });

  it.each(spec.stays)('a stay: $why', ({ points, places, result }) => {
    // A fixture may leave the radius out; the default is the rule's own.
    const stays = staysIn(
      points,
      places.map((place) => ({
        ...place,
        radiusM: place.radiusM ?? stayRadiusM,
        notes: place.notes ?? null,
      })),
    );
    expect(stays).toHaveLength(result.length);
    stays.forEach((stay, i) => {
      const expected = result[i]!;
      expect(stay.latitude).toBeCloseTo(expected.latitude, 4);
      expect(stay.longitude).toBeCloseTo(expected.longitude, 4);
      expect(new Date(stay.from).toISOString()).toBe(new Date(expected.from).toISOString());
      expect(stay.place?.name ?? null).toBe(expected.place);
    });
  });
});

describe('the body', () => {
  const spec = fixture<{
    series: { why: string; window: number; entries: WeightLike[]; points: WeightPoint[] }[];
    trends: {
      why: string;
      window: number;
      days: number;
      entries: WeightLike[];
      trend: WeightTrend | null;
    }[];
  }>('body');

  it.each(spec.series)('the chart: $why', ({ entries, window, points }) => {
    expect(weightSeries(entries, window)).toEqual(points);
  });

  it.each(spec.trends)('the trend: $why', ({ entries, days, window, trend }) => {
    expect(weightTrend(entries, days, window)).toEqual(trend);
  });
});
