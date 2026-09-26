import { HarvestDay } from './harvest-day.js';
import { dailySchedule, parseScheduleJson, scheduleIsDueOn, type Schedule } from './schedule.js';
import { Xp } from './xp.js';

export type CommitmentType = 'habit' | 'project' | 'todo';

/**
 * What the due rule needs to know about a seed. A structural subset of
 * the phone's `Commitment`, so a row from any store can be passed once
 * it is read with [commitmentFromRow].
 */
export interface DueCommitment {
  readonly type: CommitmentType;
  readonly createdAt: Date;
  /** Habits only; a habit without one is treated as daily. */
  readonly schedule: Schedule | null;
  readonly totalTarget: number | null;
  readonly dailyCommitment: number | null;
  /** To-dos only: the day it is planned for. */
  readonly dueDay: HarvestDay | null;
  readonly pausedAt: Date | null;
}

/** The columns of a `commitments` row that [commitmentFromRow] reads. */
export interface CommitmentRowLike {
  readonly type: string;
  readonly createdAt: string;
  readonly scheduleJson: string | null;
  readonly totalTarget: number | null;
  readonly dailyCommitment: number | null;
  readonly dueDay: string | null;
  readonly pausedAt: string | null;
}

export function commitmentFromRow(row: CommitmentRowLike): DueCommitment {
  if (row.type !== 'habit' && row.type !== 'project' && row.type !== 'todo') {
    throw new TypeError(`unknown commitment type: ${row.type}`);
  }
  return {
    type: row.type,
    createdAt: new Date(row.createdAt),
    schedule: row.scheduleJson === null ? null : parseScheduleJson(row.scheduleJson),
    totalTarget: row.totalTarget,
    dailyCommitment: row.dailyCommitment,
    dueDay: HarvestDay.tryParse(row.dueDay),
    pausedAt: row.pausedAt === null ? null : new Date(row.pausedAt),
  };
}

/**
 * The first Harvest Day a seed counts for: the day it was planted.
 * Business rule #12; the calendar must not invent a history the seed
 * never had.
 */
export function startDayOf(commitment: Pick<DueCommitment, 'createdAt'>): HarvestDay {
  return HarvestDay.of(commitment.createdAt);
}

export interface DueOptions {
  /** Distinct days already done in [day]'s week (times-per-week habits). */
  readonly doneDaysThisWeek?: number;
  /** Units ever logged (projects: progress; to-dos: done or not). */
  readonly totalLogged?: number;
}

/**
 * The one rule for "does this seed want attention on [day]?", used by
 * the field, the calendar and the reminder planner so they never
 * disagree. Ported from `due.dart`:
 * - nothing is ever due before the day it was planted;
 * - a habit is due when its schedule says so and it is not paused, and
 *   a times-per-week habit stops being due once the week's quota is met;
 * - a project is due every day until it reaches its target;
 * - a to-do is due on its planned day and every day after, until done.
 */
export function isDueOn(commitment: DueCommitment, day: HarvestDay, options: DueOptions = {}): boolean {
  const { doneDaysThisWeek = 0, totalLogged = 0 } = options;
  if (day.compareTo(startDayOf(commitment)) < 0) return false;
  switch (commitment.type) {
    case 'habit':
      return (
        commitment.pausedAt === null &&
        scheduleIsDueOn(commitment.schedule ?? dailySchedule, day, doneDaysThisWeek)
      );
    case 'project':
      return totalLogged < (commitment.totalTarget ?? 0);
    case 'todo':
      return totalLogged === 0 && (commitment.dueDay === null || commitment.dueDay.compareTo(day) <= 0);
  }
}

/** A to-do planned for a day that has passed and still not done. */
export function isOverdueOn(
  commitment: Pick<DueCommitment, 'type' | 'dueDay'>,
  day: HarvestDay,
  totalLogged = 0,
): boolean {
  return (
    commitment.type === 'todo' &&
    totalLogged === 0 &&
    commitment.dueDay !== null &&
    commitment.dueDay.compareTo(day) < 0
  );
}

// -------------------------------------------------------- over-log cap

/**
 * The most units a seed takes in one Harvest Day. Business rule #2: a
 * project caps at twice its daily commitment; a habit or a to-do is
 * done once.
 */
export function maxUnitsPerDay(commitment: Pick<DueCommitment, 'type' | 'dailyCommitment'>): number {
  return commitment.type === 'project' ? 2 * (commitment.dailyCommitment ?? 0) : 1;
}

/**
 * The most units a check-in can still write on this Harvest Day: a
 * project takes no more than twice its daily commitment on one day
 * (business rule #2) **and** no more than what is left of its total
 * target, so 100 of 100 is done and never 160 of 100 ([[Business-Rules]]
 * #2). A habit or a to-do has one unit, or none once it is in.
 * [totalLogged] is every live unit ever logged, today's included.
 */
export function roomToday(
  commitment: Pick<DueCommitment, 'type' | 'dailyCommitment'> & { readonly totalTarget?: number | null },
  loggedToday: number,
  totalLogged = 0,
): number {
  if (commitment.type !== 'project') return loggedToday > 0 ? 0 : 1;
  let room = maxUnitsPerDay(commitment) - loggedToday;
  if (commitment.totalTarget !== undefined && commitment.totalTarget !== null) {
    room = Math.min(room, commitment.totalTarget - totalLogged);
  }
  return Math.max(room, 0);
}

export interface CheckInPlan {
  /** Units that will actually be written; 0 means nothing is. */
  readonly quantityLogged: number;
  readonly xpEarned: number;
  /** Whether the cap refused some or all of what was asked. */
  readonly capped: boolean;
}

/**
 * What a check-in of [quantity] units does when [loggedToday] units are
 * already on the day and [totalLogged] on the seed ever. Mirrors
 * `CheckInService.checkIn`, including its quirks: a habit asked for
 * three units logs one and is not "capped", and a second tap on a done
 * habit is capped at zero. A project is cut to [roomToday].
 */
export function planCheckIn(
  commitment: Pick<DueCommitment, 'type' | 'dailyCommitment'> & { readonly totalTarget?: number | null },
  loggedToday: number,
  quantity = 1,
  totalLogged = 0,
): CheckInPlan {
  let toLog = quantity;
  let capped = false;
  if (commitment.type === 'project') {
    const room = roomToday(commitment, loggedToday, totalLogged);
    if (toLog > room) {
      toLog = Math.min(room, quantity);
      capped = true;
    }
  } else {
    if (loggedToday > 0) return { quantityLogged: 0, xpEarned: 0, capped: true };
    toLog = 1;
  }
  if (toLog <= 0) return { quantityLogged: 0, xpEarned: 0, capped: true };
  const xpEarned = commitment.type === 'project' ? Xp.perProjectUnit * toLog : Xp.habitOrTodo;
  return { quantityLogged: toLog, xpEarned, capped };
}
