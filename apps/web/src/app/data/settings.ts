import { type Clock, type Cycle, fallbackCycle, formatClock, parseClock } from '@harvest/core';
import type { HarvestDB } from './db';
import type { Tx, Writer } from './writer';

/**
 * `kv_settings`, as the phone's SettingsRepository keeps it: every value
 * is JSON, and a string value is stored as a JSON string. Reads are as
 * tolerant as the phone's: a number or a bool written by an older
 * version still comes back as its text.
 *
 * Every key written here is a preference the phone reads too, and every
 * one of them is portable (`portableSettingPrefixes`), so a change made
 * in the browser reaches the phone. The phone's device bookkeeping —
 * the lock, the widget, which notifications are scheduled — is never
 * written from here.
 */
export const settingKeys = {
  dailyHarvestGoal: 'dailyHarvestGoal',
  defaultCurrency: 'finance.defaultCurrency',
  monthlyBudget: 'finance.monthlyBudgetMinor',
  noteFolders: 'notes.folders',
  onboardingDone: 'onboarding.done',
  bedTime: 'cycle.bedTime',
  wakeTime: 'cycle.wakeTime',
} as const;

/**
 * The parts of the app that stay out of the way until asked for
 * (`FeatureKeys`). Every one is off until switched on (N1, G1, H1, Y1,
 * PL1, [[Lists]]), and switching one off hides its tab and never deletes a thing.
 */
export const featureKeys = {
  notes: 'features.notes',
  gallery: 'features.gallery',
  health: 'features.health',
  gym: 'features.gym',
  places: 'features.places',
  lists: 'features.lists',
} as const;
export type Feature = keyof typeof featureKeys;
export const features = Object.keys(featureKeys) as Feature[];
export type FeatureSwitches = Record<Feature, boolean>;

/** The focus timer's four numbers (`PomodoroKeys`), with the phone's defaults and steppers. */
export const pomodoroSettings = [
  { key: 'pomodoro.focusMinutes', name: 'focus', fallback: 25, min: 10, max: 90, step: 5 },
  { key: 'pomodoro.shortBreakMinutes', name: 'shortBreak', fallback: 5, min: 1, max: 20, step: 1 },
  { key: 'pomodoro.longBreakMinutes', name: 'longBreak', fallback: 15, min: 5, max: 45, step: 5 },
  { key: 'pomodoro.blocksPerLongBreak', name: 'blocks', fallback: 4, min: 2, max: 8, step: 1 },
] as const;

/** Exchange rates (`RateKeys`): two by hand, one fetched with its moment. */
export const rateKeys = {
  dzdPerUsd: 'rate.dzdPerUsd',
  dzdPerEur: 'rate.dzdPerEur',
  usdPerEur: 'rate.usdPerEur',
  usdPerEurAt: 'rate.usdPerEurAt',
} as const;

export function settingText(valueJson: string | undefined | null): string | null {
  if (valueJson === undefined || valueJson === null) return null;
  try {
    const value: unknown = JSON.parse(valueJson);
    if (value === null || value === undefined) return null;
    if (typeof value === 'string') return value;
    return typeof value === 'number' || typeof value === 'boolean' ? String(value) : JSON.stringify(value);
  } catch {
    return valueJson;
  }
}

export async function readSetting(db: HarvestDB, key: string): Promise<string | null> {
  return settingText((await db.rows('kv_settings').get(key))?.valueJson);
}

export async function writeSetting(tx: Tx, key: string, value: string): Promise<void> {
  await tx.put('kv_settings', { key, valueJson: JSON.stringify(value), updatedAt: tx.now() });
}

/** A switch as the phone reads it: `true`, `false`, or the default (off). */
export function switchOn(text: string | null | undefined): boolean {
  return text === 'true';
}

export async function readFeatures(db: HarvestDB): Promise<FeatureSwitches> {
  const rows = await db.rows('kv_settings').bulkGet(features.map((feature) => featureKeys[feature]));
  return Object.fromEntries(features.map((feature, index) => [feature, switchOn(settingText(rows[index]?.valueJson))])) as FeatureSwitches;
}

/** The daily cycle as stored, or 11 PM to 7 AM (`dailyCycleProvider`). */
export async function readCycle(db: HarvestDB): Promise<Cycle> {
  const [bed, wake] = await Promise.all([readSetting(db, settingKeys.bedTime), readSetting(db, settingKeys.wakeTime)]);
  return { bedTime: parseClock(bed) ?? fallbackCycle.bedTime, wakeTime: parseClock(wake) ?? fallbackCycle.wakeTime };
}

// ------------------------------------------------------------- the cycle

const day = 24 * 60;

export function minutesOfClock(clock: Clock): number {
  return clock.hour * 60 + clock.minute;
}

export function clockOfMinutes(minutes: number): Clock {
  const wrapped = ((minutes % day) + day) % day;
  return { hour: Math.trunc(wrapped / 60), minute: wrapped % 60 };
}

/**
 * Whether [time] falls inside the night (`DailyCycle.covers`). The wake
 * minute itself is already morning.
 */
export function cycleCovers(cycle: Cycle, time: Clock): boolean {
  const at = minutesOfClock(time);
  const from = minutesOfClock(cycle.bedTime);
  const to = minutesOfClock(cycle.wakeTime);
  if (from === to) return true;
  return to > from ? at >= from && at < to : at >= from || at < to;
}

/**
 * The same reminder, kept at its own distance from waking
 * (`DailyCycle.shiftedWith`): move the alarm and it follows.
 */
export function shiftedWith(from: Cycle, to: Cycle, time: Clock): Clock {
  return clockOfMinutes(minutesOfClock(time) + minutesOfClock(to.wakeTime) - minutesOfClock(from.wakeTime));
}

/** One reminder the new night would swallow (`SleepClash`). */
export interface SleepClash {
  kind: 'seed' | 'debt';
  uuid: string;
  title: string;
  at: Clock;
  movedTo: Clock;
}

/** A debt with no time of its own is reminded at 7 PM (`ReminderDefaults.debt`). */
const debtReminder: Clock = { hour: 19, minute: 0 };

/**
 * Every reminder the new night would swallow, with where it would go
 * (`DailyCycleService.clashes`): seeds that are still on the field and
 * debts still open. A debt this browser cannot read yet — no passphrase
 * — is simply not seen, and the phone's own check still stands.
 */
export async function cycleClashes(db: HarvestDB, from: Cycle, to: Cycle): Promise<SleepClash[]> {
  const found: SleepClash[] = [];
  const seeds = (await db.rows('commitments').toArray())
    .filter((seed) => seed.archivedAt === null && seed.deletedAt === null)
    .sort((a, b) => a.createdAt.localeCompare(b.createdAt));
  for (const seed of seeds) {
    const at = parseClock(seed.remindAt);
    if (at === null || !cycleCovers(to, at)) continue;
    found.push({ kind: 'seed', uuid: seed.uuid, title: seed.title, at, movedTo: shiftedWith(from, to, at) });
  }
  for (const debt of await db.rows('debts').toArray()) {
    if (debt.settledAt !== null || debt.deletedAt !== null) continue;
    const at = parseClock(debt.remindAt) ?? debtReminder;
    if (!cycleCovers(to, at)) continue;
    found.push({ kind: 'debt', uuid: debt.uuid, title: debt.person, at, movedTo: shiftedWith(from, to, at) });
  }
  return found;
}

// ------------------------------------------------------------- rates

/** A rate worth storing: finite, positive, and not absurd (`isSaneRate`). */
export function isSaneRate(value: number): boolean {
  return Number.isFinite(value) && value > 0 && value < 1e6;
}

/** A typed rate, with a comma allowed for the decimal point; null when unusable. */
export function parseRate(text: string): number | null {
  const value = Number(text.trim().replace(',', '.'));
  return text.trim() !== '' && isSaneRate(value) ? value : null;
}

/** The one request this screen makes, and only on a tap (Business rule 13). */
export const rateEndpoint = 'https://api.frankfurter.dev/v1/latest?base=EUR&symbols=USD';

/**
 * EUR→USD, as `RatesService.fetchEurUsd` checks it: a small body, a
 * number where the number goes, and a value inside the band EUR/USD has
 * lived in for decades. Null for anything else; never throws.
 */
export async function fetchEurUsd(get: typeof fetch = fetch): Promise<number | null> {
  try {
    const response = await get(rateEndpoint, { credentials: 'omit', signal: AbortSignal.timeout(10_000) });
    if (response.status !== 200) return null;
    const text = await response.text();
    if (text.length > 64 * 1024) return null;
    const body: unknown = JSON.parse(text);
    const raw = (body as { rates?: { USD?: unknown } } | null)?.rates?.USD;
    if (typeof raw !== 'number' || !isSaneRate(raw) || raw < 0.5 || raw > 2) return null;
    return raw;
  } catch {
    return null;
  }
}

export class SettingsRepository {
  constructor(private readonly writer: Writer) {}

  setString(key: string, value: string): Promise<void> {
    return this.writer.run((tx) => writeSetting(tx, key, value));
  }

  /** Stored as `'true'`/`'false'`, as the phone's `setBool` stores it. */
  setBool(key: string, value: boolean): Promise<void> {
    return this.setString(key, String(value));
  }

  setInt(key: string, value: number): Promise<void> {
    return this.setString(key, String(Math.trunc(value)));
  }

  /** Several at once, in one transaction: one change, one sync. */
  setMany(values: Record<string, string>): Promise<void> {
    return this.writer.run(async (tx) => {
      for (const [key, value] of Object.entries(values)) await writeSetting(tx, key, value);
    });
  }

  /** Forgets a setting; it travels as a purged record, as the phone's `remove` does. */
  remove(key: string): Promise<void> {
    return this.writer.run(async (tx) => {
      if (await tx.get('kv_settings', key)) await tx.purge('kv_settings', key);
    });
  }

  /** The daily cycle (`DailyCycleService.write`). */
  writeCycle(cycle: Cycle): Promise<void> {
    return this.writer.run(async (tx) => {
      await writeSetting(tx, settingKeys.bedTime, formatClock(cycle.bedTime));
      await writeSetting(tx, settingKeys.wakeTime, formatClock(cycle.wakeTime));
    });
  }

  /**
   * Moves the reminders a new night would have buried to where
   * [cycleClashes] said they would go (`DailyCycleService.shift`), and
   * only when asked to.
   */
  shiftReminders(clashes: readonly SleepClash[]): Promise<void> {
    return this.writer.run(async (tx) => {
      const now = tx.now();
      for (const clash of clashes) {
        const remindAt = formatClock(clash.movedTo);
        if (clash.kind === 'seed') await tx.patch('commitments', clash.uuid, { remindAt, updatedAt: now });
        else await tx.patch('debts', clash.uuid, { remindAt, updatedAt: now });
      }
    });
  }
}
