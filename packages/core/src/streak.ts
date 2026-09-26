import { defaultDailyHarvestGoal, streakMilestoneCoins } from './xp.js';

/**
 * The live half of the streak engine: what a check-in and its undo do
 * to the stored streak rows, the moment they happen. Ported from
 * `onCheckIn`, `onUndo` and `_refreshGlobal` in
 * `apps/mobile/lib/features/gamification/domain/streak_service.dart`.
 *
 * The other half, `reconcile`, judges the days that have closed: it
 * spends freezes and breaks streaks at the 3 AM reset. That half stays
 * with the phone, which owns the reset job and its bookkeeping
 * (`streak.lastJudgedDay` is a device setting and never syncs). A
 * second device that also judged days would judge them twice.
 *
 * Every function here is pure: it takes the row as stored and answers
 * the row to write, or null when nothing changes. The caller writes it.
 */

/** A `streaks` row, without its key and clock. */
export interface StreakState {
  readonly current: number;
  readonly best: number;
  /** Harvest Day key of the last day this streak counted, if any. */
  readonly lastEarnedDay: string | null;
  readonly freezesStored: number;
}

export const globalStreakScope = 'global';

/** A scope that has never been written reads as all zeros (`_row`). */
export const emptyStreak: StreakState = Object.freeze({
  current: 0,
  best: 0,
  lastEarnedDay: null,
  freezesStored: 0,
});

/** What a seed contributes to the day's count. */
export interface ActionCommitment {
  readonly uuid: string;
  readonly type: string;
  readonly dailyCommitment: number | null;
}

/**
 * Productive actions on a day (`productiveActions`): each habit or to-do
 * checked in counts one; a project counts one once it reached its daily
 * commitment; each scheduled album that got a picture counts one.
 *
 * [unitsBySeed] is the day's live check-in units per commitment uuid.
 * A seed missing from [commitments] (its row is gone) does not count,
 * as on the phone, where the join finds nothing. Archived seeds are
 * passed like any other: effort on a seed archived later was real.
 */
export function productiveActions(
  unitsBySeed: ReadonlyMap<string, number>,
  commitments: readonly ActionCommitment[],
  albumActions = 0,
): number {
  let actions = albumActions;
  for (const seed of commitments) {
    if (!unitsBySeed.has(seed.uuid)) continue;
    if (seed.type === 'project') {
      const daily = seed.dailyCommitment ?? 0;
      if (daily > 0 && (unitsBySeed.get(seed.uuid) ?? 0) >= daily) actions++;
    } else {
      actions++;
    }
  }
  return actions;
}

/**
 * The Daily Harvest Goal from its stored JSON (`dailyGoal`): a number,
 * or text holding one; anything else is the default.
 */
export function dailyGoalFromJson(valueJson: string | null | undefined): number {
  if (valueJson === null || valueJson === undefined) return defaultDailyHarvestGoal;
  let value: unknown;
  try {
    value = JSON.parse(valueJson);
  } catch {
    return defaultDailyHarvestGoal;
  }
  if (typeof value === 'number' && Number.isFinite(value)) return Math.trunc(value);
  const parsed = /^\s*[+-]?\d+\s*$/.exec(String(value));
  return parsed ? Number.parseInt(String(value), 10) : defaultDailyHarvestGoal;
}

/**
 * After an undo on [day]: a streak that still stands is consecutive, so
 * its last earned day is the day before; one that fell to zero has no
 * earned day to point at (`_earnedBefore`).
 */
function earnedBefore(previousDayKey: string, remaining: number): string | null {
  return remaining > 0 ? previousDayKey : null;
}

/** A habit checked in on [dayKey]: its own streak counts the day, once. */
export function earnHabitDay(streak: StreakState, dayKey: string): StreakState | null {
  if (streak.lastEarnedDay === dayKey) return null;
  const current = streak.current + 1;
  return {
    current,
    best: Math.max(streak.best, current),
    lastEarnedDay: dayKey,
    freezesStored: streak.freezesStored,
  };
}

/** A habit's check-in on [dayKey] undone: the day is taken back. */
export function retractHabitDay(
  streak: StreakState,
  dayKey: string,
  previousDayKey: string,
): StreakState | null {
  if (streak.lastEarnedDay !== dayKey) return null;
  return {
    current: Math.max(0, streak.current - 1),
    best: streak.best,
    lastEarnedDay: earnedBefore(previousDayKey, streak.current - 1),
    freezesStored: streak.freezesStored,
  };
}

export interface GlobalRefresh {
  /** The row to write, or null when the day's verdict did not change. */
  readonly next: StreakState | null;
  /** Coins for a milestone the streak just reached, with its reason. */
  readonly milestone: { readonly coins: number; readonly reason: string } | null;
}

/**
 * Extends or retracts the global streak on [dayKey] from its actions
 * (`_refreshGlobal`). Reaching the goal counts the day once and may pay
 * a milestone; a same-day undo that drops below it takes the day back.
 * The milestone is never taken back, exactly as on the phone.
 */
export function refreshGlobalStreak(
  streak: StreakState,
  actions: number,
  goal: number,
  dayKey: string,
  previousDayKey: string,
): GlobalRefresh {
  if (actions >= goal && streak.lastEarnedDay !== dayKey) {
    const current = streak.current + 1;
    const coins = streakMilestoneCoins[current];
    return {
      next: {
        current,
        best: Math.max(streak.best, current),
        lastEarnedDay: dayKey,
        freezesStored: streak.freezesStored,
      },
      milestone: coins === undefined ? null : { coins, reason: `streak:${current}` },
    };
  }
  if (actions < goal && streak.lastEarnedDay === dayKey) {
    return {
      next: {
        current: Math.max(0, streak.current - 1),
        best: streak.best,
        lastEarnedDay: earnedBefore(previousDayKey, streak.current - 1),
        freezesStored: streak.freezesStored,
      },
      milestone: null,
    };
  }
  return { next: null, milestone: null };
}
