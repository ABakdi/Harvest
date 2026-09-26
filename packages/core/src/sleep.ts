/**
 * Sleep: how long a night was, what it was meant to be, and what is
 * owed. A port of `apps/mobile/lib/features/health/domain/sleep.dart`
 * and the bits of `daily_cycle.dart` the target depends on, held to
 * `fixtures/sleep.json`.
 *
 * Business rule #3: the debt is minute for minute, it never goes below
 * zero, it looks back fourteen **calendar** nights, and an unlogged
 * night counts for nothing in either direction.
 */

import { HarvestDay } from './harvest-day.js';

/** One night, as the `sleep_sessions` row stores it. */
export interface SleepNightLike {
  /** The Harvest Day I woke up on: a night is filed under its morning. */
  readonly harvestDay: string;
  readonly fellAsleepAt: string | Date;
  readonly wokeAt: string | Date;
  /** What the night was supposed to be, copied in when it was written. */
  readonly targetMinutes: number;
}

/** How far back the debt looks. */
export const debtWindowNights = 14;

function moment(value: string | Date): Date {
  return typeof value === 'string' ? new Date(value) : value;
}

/** Dart's `Duration.inMinutes`: whole minutes, truncated toward zero. */
export function sleptMinutes(night: SleepNightLike): number {
  return Math.trunc((moment(night.wokeAt).getTime() - moment(night.fellAsleepAt).getTime()) / 60_000);
}

/** Short of target, in minutes; negative is a surplus. */
export function shortfallMinutes(night: SleepNightLike): number {
  return night.targetMinutes - sleptMinutes(night);
}

/**
 * The running balance over the window ending on [upTo] (the latest
 * night logged when nobody says). Every short night adds its shortfall,
 * every long night pays it down, and the balance never goes below zero:
 * one twelve-hour Sunday clears what is owed and does not put me in
 * credit.
 */
export function sleepDebtMinutes(
  nights: Iterable<SleepNightLike>,
  options: { window?: number; upTo?: HarvestDay | null } = {},
): number {
  const window = options.window ?? debtWindowNights;
  const sorted = [...nights].sort((a, b) => a.harvestDay.localeCompare(b.harvestDay));
  if (sorted.length === 0) return 0;
  const end = options.upTo?.key ?? sorted[sorted.length - 1]!.harvestDay;
  const start = startKey(end, window);
  let balance = 0;
  for (const night of sorted) {
    if (night.harvestDay < start || night.harvestDay > end) continue;
    balance += shortfallMinutes(night);
    if (balance < 0) balance = 0;
  }
  return balance;
}

/** The first morning of a window of [window] nights ending on [end]. */
function startKey(end: string, window: number): string {
  const day = HarvestDay.tryParse(end);
  return day ? day.addDays(-(window - 1)).key : end;
}

export interface SleepDebt {
  readonly minutes: number;
  /** The debt in nights, so the gauge reads "how far behind am I". */
  readonly nights: number;
}

export function sleepDebt(
  nights: Iterable<SleepNightLike>,
  options: { targetMinutes: number; window?: number; upTo?: HarvestDay | null },
): SleepDebt {
  const minutes = sleepDebtMinutes(nights, options);
  return { minutes, nights: options.targetMinutes <= 0 ? 0 : minutes / options.targetMinutes };
}

/** The average of what was actually slept, over the logged nights only. */
export function averageSleepMinutes(nights: Iterable<SleepNightLike>): number {
  const logged = [...nights];
  if (logged.length === 0) return 0;
  return Math.trunc(logged.reduce((sum, night) => sum + sleptMinutes(night), 0) / logged.length);
}

// -------------------------------------------------------- the target

/** A time of day as `(hour, minute)`, the way the settings store it. */
export interface Clock {
  readonly hour: number;
  readonly minute: number;
}

/** The night I mean to have: when I go to bed, and when I get up. */
export interface Cycle {
  readonly bedTime: Clock;
  readonly wakeTime: Clock;
}

/** 11 PM to 7 AM, before anyone says otherwise (`DailyCycle.fallback`). */
export const fallbackCycle: Cycle = { bedTime: { hour: 23, minute: 0 }, wakeTime: { hour: 7, minute: 0 } };

/** `SettingsRepository.parseTime`: "HH:mm", tolerant of a missing zero pad. */
export function parseClock(raw: string | null | undefined): Clock | null {
  const parts = (raw ?? '').split(':');
  if (parts.length !== 2) return null;
  const hour = Number(parts[0]);
  const minute = Number(parts[1]);
  if (!Number.isInteger(hour) || !Number.isInteger(minute)) return null;
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
  return { hour, minute };
}

export function formatClock(clock: Clock): string {
  return `${String(clock.hour).padStart(2, '0')}:${String(clock.minute).padStart(2, '0')}`;
}

/** `decodeCycle`: `23:30-07:00` from a stored weekday override. */
export function decodeCycle(value: string | null | undefined): Cycle | null {
  if (!value) return null;
  const parts = value.split('-');
  if (parts.length !== 2) return null;
  const bedTime = parseClock(parts[0]);
  const wakeTime = parseClock(parts[1]);
  return bedTime && wakeTime ? { bedTime, wakeTime } : null;
}

export function encodeCycle(cycle: Cycle): string {
  return `${formatClock(cycle.bedTime)}-${formatClock(cycle.wakeTime)}`;
}

const minutesInDay = 24 * 60;

function minutesOf(clock: Clock): number {
  return clock.hour * 60 + clock.minute;
}

/**
 * How long the night is, wrapping midnight. A window that starts and
 * ends on the same minute is a whole day asleep, not none
 * (`DailyCycle.sleep`).
 */
export function cycleMinutes(cycle: Cycle): number {
  const from = minutesOf(cycle.bedTime);
  const to = minutesOf(cycle.wakeTime);
  const span = to > from ? to - from : to + minutesInDay - from;
  return span === 0 ? minutesInDay : span;
}

/**
 * The target for the morning of [day]: the daily cycle, unless that
 * weekday has a night of its own (`SleepTargets.targetMinutesFor`).
 * Saturday is a different night from Tuesday for nearly everyone.
 */
export function targetMinutesFor(
  day: HarvestDay,
  cycle: Cycle = fallbackCycle,
  overrides: Readonly<Record<number, Cycle>> = {},
): number {
  return cycleMinutes(overrides[day.weekday] ?? cycle);
}
