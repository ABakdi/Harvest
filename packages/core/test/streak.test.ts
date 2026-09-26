import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';
import {
  HarvestDay,
  dailyGoalFromJson,
  earnHabitDay,
  productiveActions,
  refreshGlobalStreak,
  retractHabitDay,
  type ActionCommitment,
  type StreakState,
} from '../src/index.js';

interface Fixture {
  productiveActions: {
    units: Record<string, number>;
    commitments: ActionCommitment[];
    albums: number;
    actions: number;
  }[];
  dailyGoal: { valueJson: string | null; goal: number }[];
  earnHabitDay: { streak: StreakState; day: string; next: StreakState | null }[];
  retractHabitDay: { streak: StreakState; day: string; next: StreakState | null }[];
  refreshGlobal: {
    streak: StreakState;
    actions: number;
    goal: number;
    day: string;
    next: StreakState | null;
    milestone: { coins: number; reason: string } | null;
  }[];
}

const data = JSON.parse(
  readFileSync(new URL('../fixtures/streaks.json', import.meta.url), 'utf8'),
) as Fixture;

const previous = (key: string) => HarvestDay.parse(key).previous.key;

describe('streaks.json', () => {
  it.each(data.productiveActions)('productiveActions is $actions', ({ units, commitments, albums, actions }) => {
    expect(productiveActions(new Map(Object.entries(units)), commitments, albums)).toBe(actions);
  });

  it.each(data.dailyGoal)('dailyGoal($valueJson) is $goal', ({ valueJson, goal }) => {
    expect(dailyGoalFromJson(valueJson)).toBe(goal);
  });

  it.each(data.earnHabitDay)('earnHabitDay on $day', ({ streak, day, next }) => {
    expect(earnHabitDay(streak, day)).toEqual(next);
  });

  it.each(data.retractHabitDay)('retractHabitDay on $day', ({ streak, day, next }) => {
    expect(retractHabitDay(streak, day, previous(day))).toEqual(next);
  });

  it.each(data.refreshGlobal)('refreshGlobal with $actions of $goal', ({ streak, actions, goal, day, next, milestone }) => {
    expect(refreshGlobalStreak(streak, actions, goal, day, previous(day))).toEqual({ next, milestone });
  });
});
