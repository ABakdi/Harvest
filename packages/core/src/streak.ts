import { HarvestDay } from './harvest-day.js';
import { scheduleIsDueOn, type Schedule } from './schedule.js';
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

/**
 * Closed days between the last earned day and [dayKey] that nothing
 * counted: 0 when [dayKey] follows it, or when there is no run to judge.
 * A check-in made on another device before this one judged those days
 * must not hide them ([[Audit-v3]] Q5-02).
 */
export function daysMissedBefore(streak: StreakState, dayKey: string): number {
  if (streak.current <= 0 || streak.lastEarnedDay === null) return 0;
  const last = HarvestDay.tryParse(streak.lastEarnedDay);
  if (last === null) return 0;
  return Math.max(0, last.daysUntil(HarvestDay.parse(dayKey)) - 1);
}

/** What the phone's judging needs to know about a habit's missed days. */
export interface HabitCalendar {
  /** Its schedule; null reads as daily, as the phone does. */
  readonly schedule: Schedule | null;
  /** The Harvest Day it was paused on, if it is paused: days from then on are excused. */
  readonly pausedDay?: string | null;
}

/**
 * Whether a fixed-schedule habit was due on a day between its last
 * earned day and [dayKey], which breaks it the way the 3 AM judging
 * would. A times-a-week habit is judged when its week closes, never here.
 */
function habitMissedBefore(streak: StreakState, dayKey: string, habit: HabitCalendar): boolean {
  const gap = daysMissedBefore(streak, dayKey);
  if (gap === 0) return false;
  const schedule = habit.schedule ?? { type: 'daily' };
  if (schedule.type === 'timesPerWeek') return false;
  const paused = HarvestDay.tryParse(habit.pausedDay ?? null);
  let day = HarvestDay.parse(dayKey).addDays(-gap);
  for (let i = 0; i < gap; i++, day = day.next) {
    if (paused !== null && paused.compareTo(day) <= 0) return false;
    if (scheduleIsDueOn(schedule, day)) return true;
  }
  return false;
}

/**
 * A habit checked in on [dayKey]: its own streak counts the day, once.
 * With [habit], a due day missed since the last earned one starts the
 * run again at 1 instead of extending it.
 */
export function earnHabitDay(streak: StreakState, dayKey: string, habit?: HabitCalendar): StreakState | null {
  if (streak.lastEarnedDay === dayKey) return null;
  const current = habit !== undefined && habitMissedBefore(streak, dayKey, habit) ? 1 : streak.current + 1;
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

/** A milestone already paid: a `streak:N` ledger row and its day. */
export interface MilestonePaid {
  readonly reason: string;
  readonly harvestDay: string;
}

/**
 * Whether `streak:[length]` was already paid in this run. A run that
 * broke needs more than [length] days to reach the same length again,
 * so a payment that recent can only be this run's, taken back by an
 * undo and earned again ([[Audit-v3]] Q5-29).
 */
function paidThisRun(paid: readonly MilestonePaid[], length: number, dayKey: string): boolean {
  const day = HarvestDay.parse(dayKey);
  const reason = `streak:${length}`;
  return paid.some((entry) => {
    if (entry.reason !== reason) return false;
    const on = HarvestDay.tryParse(entry.harvestDay);
    return on !== null && on.daysUntil(day) <= length;
  });
}

/**
 * Extends or retracts the global streak on [dayKey] from its actions
 * (`_refreshGlobal`). Reaching the goal counts the day once and may pay
 * a milestone; a same-day undo that drops below it takes the day back.
 * The milestone is never taken back, and never paid twice in one run:
 * [paid] holds the `streak:` rows of the coin ledger.
 *
 * Days missed since the last earned one (closed days no device has
 * judged yet) are judged here as the 3 AM reset would: stored freezes
 * cover them one each, and if there are too few the run starts again
 * at 1 with the freezes spent.
 */
export function refreshGlobalStreak(
  streak: StreakState,
  actions: number,
  goal: number,
  dayKey: string,
  previousDayKey: string,
  paid: readonly MilestonePaid[] = [],
): GlobalRefresh {
  if (actions >= goal && streak.lastEarnedDay !== dayKey) {
    const missed = daysMissedBefore(streak, dayKey);
    const covered = missed <= streak.freezesStored;
    const current = covered ? streak.current + 1 : 1;
    const coins = streakMilestoneCoins[current];
    return {
      next: {
        current,
        best: Math.max(streak.best, current),
        lastEarnedDay: dayKey,
        freezesStored: Math.max(0, streak.freezesStored - missed),
      },
      milestone:
        coins === undefined || paidThisRun(paid, current, dayKey) ? null : { coins, reason: `streak:${current}` },
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
