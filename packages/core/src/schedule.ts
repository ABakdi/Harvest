import { HarvestDay } from './harvest-day.js';

/**
 * When a habit is due. Projects are implicitly due daily and to-dos on
 * their planned day; schedules only apply to habits.
 *
 * Ported from `apps/mobile/lib/features/commitments/domain/schedule.dart`.
 * The JSON is the one the phone stores in `commitments.schedule_json`.
 */
export type Schedule =
  | { readonly type: 'daily' }
  /** Fixed days of the week, 1 (Monday) through 7 (Sunday). */
  | { readonly type: 'weekly'; readonly weekdays: ReadonlySet<number> }
  /** Every [everyDays] days, counted from [anchorDay]. */
  | { readonly type: 'interval'; readonly everyDays: number; readonly anchorDay: HarvestDay }
  /** [times] a week, on whichever days I pick as the week unfolds. */
  | { readonly type: 'timesPerWeek'; readonly times: number };

export const dailySchedule: Schedule = Object.freeze({ type: 'daily' });

function expectInt(value: unknown, what: string): number {
  if (typeof value !== 'number' || !Number.isInteger(value)) {
    throw new TypeError(`${what} must be an integer`);
  }
  return value;
}

/**
 * `Schedule.fromJson`. Throws on an unknown type or a missing field, as
 * the Dart original does; a schedule that cannot be read is a bug to
 * surface, not a habit to quietly make daily.
 */
export function parseSchedule(json: unknown): Schedule {
  if (typeof json !== 'object' || json === null) throw new TypeError('a schedule is an object');
  const raw = json as Record<string, unknown>;
  switch (raw.type) {
    case 'daily':
      return dailySchedule;
    case 'weekly': {
      if (!Array.isArray(raw.weekdays)) throw new TypeError('weekdays must be a list');
      return {
        type: 'weekly',
        weekdays: new Set(raw.weekdays.map((day) => expectInt(day, 'a weekday'))),
      };
    }
    case 'interval': {
      if (typeof raw.anchorDay !== 'string') throw new TypeError('anchorDay must be a day key');
      return {
        type: 'interval',
        everyDays: expectInt(raw.everyDays, 'everyDays'),
        anchorDay: HarvestDay.parse(raw.anchorDay),
      };
    }
    case 'timesPerWeek':
      return { type: 'timesPerWeek', times: expectInt(raw.times, 'times') };
    default:
      throw new TypeError(`unknown schedule type: ${String(raw.type)}`);
  }
}

/** `Schedule.fromJson(jsonDecode(text))`. */
export function parseScheduleJson(text: string): Schedule {
  return parseSchedule(JSON.parse(text));
}

/** `Schedule.toJson`, with the weekdays sorted as the phone writes them. */
export function scheduleToJson(schedule: Schedule): Record<string, unknown> {
  switch (schedule.type) {
    case 'daily':
      return { type: 'daily' };
    case 'weekly':
      return { type: 'weekly', weekdays: [...schedule.weekdays].sort((a, b) => a - b) };
    case 'interval':
      return { type: 'interval', everyDays: schedule.everyDays, anchorDay: schedule.anchorDay.key };
    case 'timesPerWeek':
      return { type: 'timesPerWeek', times: schedule.times };
  }
}

/**
 * Whether the schedule alone says [day] is due. This is not the rule the
 * field uses; that is `isDueOn` in `due.ts`, which adds the start day,
 * pausing and the other seed types on top.
 *
 * [doneDaysThisWeek] is the number of distinct days already completed in
 * [day]'s week; only the times-per-week schedule reads it.
 */
export function scheduleIsDueOn(schedule: Schedule, day: HarvestDay, doneDaysThisWeek = 0): boolean {
  switch (schedule.type) {
    case 'daily':
      return true;
    case 'weekly':
      return schedule.weekdays.has(day.weekday);
    case 'interval': {
      // Dart throws on a modulo by zero; NaN would quietly say "never".
      if (schedule.everyDays === 0) throw new RangeError('everyDays must not be zero');
      const distance = schedule.anchorDay.daysUntil(day);
      return distance >= 0 && distance % schedule.everyDays === 0;
    }
    case 'timesPerWeek':
      return doneDaysThisWeek < schedule.times;
  }
}
