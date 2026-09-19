import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';
import {
  HarvestDay,
  Xp,
  defaultDailyHarvestGoal,
  farmerRankForXp,
  freezeCost,
  goalProgress,
  isDueOn,
  isOverdueOn,
  maxFreezesStored,
  parseSchedule,
  planCheckIn,
  scheduleIsDueOn,
  streakMilestoneCoins,
  type DueCommitment,
  type GoalItemLike,
} from '../src/index.js';

/**
 * The shared fixtures. The Dart suite reads the same files
 * (`apps/mobile/test/contracts/fixtures_test.dart`); when a rule
 * changes, the fixture changes, and whichever side was not updated
 * fails.
 */
function fixture<T>(name: string): T {
  return JSON.parse(readFileSync(new URL(`../fixtures/${name}`, import.meta.url), 'utf8')) as T;
}

const day = (key: string) => HarvestDay.parse(key);
const label = (why: string | undefined, fallback: string) => (why ? `${fallback}: ${why}` : fallback);

describe('harvest-day.json', () => {
  const data = fixture<{
    of: { local: string; day: string; why?: string }[];
    parse: { key: string; day: string | null; why?: string }[];
    addDays: { day: string; n: number; result: string }[];
    daysUntil: { from: string; to: string; days: number; why?: string }[];
    weekday: { day: string; weekday: number }[];
    weekStart: { day: string; weekStart: string; why?: string }[];
  }>('harvest-day.json');

  it.each(data.of)('of($local) is $day', ({ local, day: expected }) => {
    expect(HarvestDay.of(new Date(local)).key).toBe(expected);
  });

  it.each(data.parse)('tryParse($key) is $day', ({ key, day: expected }) => {
    expect(HarvestDay.tryParse(key)?.key ?? null).toBe(expected);
  });

  it.each(data.addDays)('$day + $n is $result', ({ day: start, n, result }) => {
    expect(day(start).addDays(n).key).toBe(result);
  });

  it.each(data.daysUntil)('$from → $to is $days days', ({ from, to, days }) => {
    expect(day(from).daysUntil(day(to))).toBe(days);
  });

  it.each(data.weekday)('$day is weekday $weekday', ({ day: key, weekday }) => {
    expect(day(key).weekday).toBe(weekday);
  });

  it.each(data.weekStart)('$day starts its week on $weekStart', ({ day: key, weekStart }) => {
    expect(day(key).weekStart.key).toBe(weekStart);
    expect(day(key).weekDays.map((d) => d.key)[0]).toBe(weekStart);
    expect(day(key).weekDays).toHaveLength(7);
  });
});

describe('schedules.json', () => {
  const data = fixture<{
    cases: { schedule: unknown; day: string; doneDaysThisWeek?: number; due: boolean; why?: string }[];
  }>('schedules.json');

  it.each(data.cases.map((c, i) => ({ ...c, name: label(c.why, `#${i} ${JSON.stringify(c.schedule)} on ${c.day}`) })))(
    '$name',
    ({ schedule, day: key, doneDaysThisWeek, due }) => {
      expect(scheduleIsDueOn(parseSchedule(schedule), day(key), doneDaysThisWeek ?? 0)).toBe(due);
    },
  );
});

interface DueFixture {
  commitment: {
    type: DueCommitment['type'];
    createdAt: string;
    schedule?: unknown;
    totalTarget?: number;
    dailyCommitment?: number;
    dueDay?: string;
    paused?: boolean;
  };
  day: string;
  doneDaysThisWeek?: number;
  totalLogged?: number;
  due: boolean;
  overdue: boolean;
  why?: string;
}

function commitmentOf(raw: DueFixture['commitment']): DueCommitment {
  return {
    type: raw.type,
    createdAt: new Date(raw.createdAt),
    schedule: raw.schedule === undefined ? null : parseSchedule(raw.schedule),
    totalTarget: raw.totalTarget ?? null,
    dailyCommitment: raw.dailyCommitment ?? null,
    dueDay: raw.dueDay === undefined ? null : day(raw.dueDay),
    pausedAt: raw.paused ? new Date('2026-09-01T00:00:00Z') : null,
  };
}

describe('due.json', () => {
  const data = fixture<{ cases: DueFixture[] }>('due.json');

  it.each(data.cases.map((c, i) => ({ ...c, name: label(c.why, `#${i} ${c.commitment.type} on ${c.day}`) })))(
    '$name',
    (c) => {
      const commitment = commitmentOf(c.commitment);
      const options = { doneDaysThisWeek: c.doneDaysThisWeek ?? 0, totalLogged: c.totalLogged ?? 0 };
      expect(isDueOn(commitment, day(c.day), options)).toBe(c.due);
      expect(isOverdueOn(commitment, day(c.day), options.totalLogged)).toBe(c.overdue);
    },
  );
});

describe('over-log.json', () => {
  const data = fixture<{
    cases: {
      type: DueCommitment['type'];
      dailyCommitment?: number;
      loggedToday: number;
      quantity: number;
      quantityLogged: number;
      xpEarned: number;
      capped: boolean;
    }[];
  }>('over-log.json');

  it.each(data.cases)(
    '$type: $quantity on top of $loggedToday logs $quantityLogged',
    ({ type, dailyCommitment, loggedToday, quantity, quantityLogged, xpEarned, capped }) => {
      expect(planCheckIn({ type, dailyCommitment: dailyCommitment ?? null }, loggedToday, quantity)).toEqual({
        quantityLogged,
        xpEarned,
        capped,
      });
    },
  );
});

describe('xp.json', () => {
  const data = fixture<{
    xp: Record<string, number>;
    streakMilestoneCoins: Record<string, number>;
    freezeCost: number;
    maxFreezesStored: number;
    defaultDailyHarvestGoal: number;
    ranks: { xp: number; rank: string }[];
  }>('xp.json');

  it('pays what the table says, and nothing the table does not name', () => {
    expect({ ...Xp }).toEqual(data.xp);
  });

  it('keeps the coin economy', () => {
    expect(Object.fromEntries(Object.entries(streakMilestoneCoins).map(([k, v]) => [k, v]))).toEqual(
      data.streakMilestoneCoins,
    );
    expect(freezeCost).toBe(data.freezeCost);
    expect(maxFreezesStored).toBe(data.maxFreezesStored);
    expect(defaultDailyHarvestGoal).toBe(data.defaultDailyHarvestGoal);
  });

  it.each(data.ranks)('$xp XP is $rank', ({ xp, rank }) => {
    expect(farmerRankForXp(xp)).toBe(rank);
  });
});

describe('goals.json', () => {
  const data = fixture<{ cases: { items: GoalItemLike[]; progress: unknown; why?: string }[] }>('goals.json');

  it.each(data.cases.map((c, i) => ({ ...c, name: label(c.why, `#${i}`) })))('$name', ({ items, progress }) => {
    expect(goalProgress(items)).toEqual(progress);
  });
});
