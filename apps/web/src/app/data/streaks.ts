import {
  dailyGoalFromJson,
  earnHabitDay,
  emptyStreak,
  freezeCost,
  globalStreakScope,
  HarvestDay as Day,
  maxFreezesStored,
  parseScheduleJson,
  productiveActions,
  refreshGlobalStreak,
  retractHabitDay,
  type HabitCalendar,
  type HarvestDay,
  type MilestonePaid,
  type StreakState,
} from '@harvest/core';
import { settingKeys } from './settings';
import type { Tx, Writer } from './writer';

/**
 * The live streak updates a check-in and its undo make, written through
 * [Tx] so they land in the check-in's own transaction. The rules are
 * `packages/core`'s port of the phone's StreakService; the 3 AM judging
 * of closed days stays with the phone (see `streak.ts` in core).
 */

async function streakOf(tx: Tx, scope: string): Promise<StreakState> {
  const row = await tx.get('streaks', scope);
  return row
    ? { current: row.current, best: row.best, lastEarnedDay: row.lastEarnedDay, freezesStored: row.freezesStored }
    : emptyStreak;
}

async function writeStreak(tx: Tx, scope: string, state: StreakState): Promise<void> {
  await tx.put('streaks', { scope, ...state, updatedAt: tx.now() });
}

/** Scheduled albums with a live picture on [day] (`albumActions`). */
async function albumActions(tx: Tx, dayKey: string): Promise<number> {
  const albums = (await tx.rows('albums').toArray()).filter(
    (album) => album.deletedAt === null && album.scheduleJson !== null,
  );
  if (albums.length === 0) return 0;
  const scheduled = new Set(albums.map((album) => album.uuid));
  const memories = await tx.rows('memories').where('harvestDay').equals(dayKey).toArray();
  return new Set(memories.filter((m) => m.deletedAt === null && scheduled.has(m.albumUuid)).map((m) => m.albumUuid))
    .size;
}

export async function actionsOn(tx: Tx, dayKey: string): Promise<number> {
  const checkIns = await tx.rows('check_ins').where('harvestDay').equals(dayKey).toArray();
  const units = new Map<string, number>();
  for (const row of checkIns) {
    if (row.deletedAt !== null) continue;
    units.set(row.commitmentUuid, (units.get(row.commitmentUuid) ?? 0) + row.quantity);
  }
  const seeds = await tx.rows('commitments').bulkGet([...units.keys()]);
  return productiveActions(
    units,
    seeds.filter((seed) => seed !== undefined),
    await albumActions(tx, dayKey),
  );
}

async function refreshGlobal(tx: Tx, day: HarvestDay): Promise<void> {
  const goal = dailyGoalFromJson((await tx.get('kv_settings', settingKeys.dailyHarvestGoal))?.valueJson);
  const actions = await actionsOn(tx, day.key);
  // The milestones already paid, so a run pays each one once (Q5-29).
  const paid: MilestonePaid[] = (await tx.rows('ledger').where('kind').equals('coin').toArray())
    .filter((entry) => entry.reason.startsWith('streak:'))
    .map((entry) => ({ reason: entry.reason, harvestDay: entry.harvestDay }));
  const refresh = refreshGlobalStreak(
    await streakOf(tx, globalStreakScope),
    actions,
    goal,
    day.key,
    day.previous.key,
    paid,
  );
  if (refresh.next) await writeStreak(tx, globalStreakScope, refresh.next);
  if (refresh.milestone) {
    await tx.ledger({ kind: 'coin', delta: refresh.milestone.coins, reason: refresh.milestone.reason, harvestDay: day.key });
  }
}

/**
 * What judging a habit's missed days needs (Q5-02): its schedule, daily
 * when it has none, and the first day it was paused or archived on,
 * from which days are excused as the phone's judging excuses them.
 */
export function habitCalendarOf(seed: {
  scheduleJson?: string | null;
  pausedAt?: string | null;
  archivedAt?: string | null;
}): HabitCalendar | undefined {
  let schedule;
  try {
    schedule = seed.scheduleJson ? parseScheduleJson(seed.scheduleJson) : null;
  } catch {
    return undefined; // an unreadable schedule is never judged
  }
  const excused = [seed.pausedAt, seed.archivedAt]
    .filter((at): at is string => typeof at === 'string')
    .map((at) => Day.of(new Date(at)).key)
    .sort()[0];
  return { schedule, pausedDay: excused ?? null };
}

export async function onCheckIn(
  tx: Tx,
  seed: { uuid: string; type: string; scheduleJson?: string | null; pausedAt?: string | null; archivedAt?: string | null },
  day: HarvestDay,
): Promise<void> {
  if (seed.type === 'habit') {
    const next = earnHabitDay(await streakOf(tx, seed.uuid), day.key, habitCalendarOf(seed));
    if (next) await writeStreak(tx, seed.uuid, next);
  }
  await refreshGlobal(tx, day);
}

export async function onUndo(tx: Tx, seed: { uuid: string; type: string }, day: HarvestDay): Promise<void> {
  if (seed.type === 'habit') {
    const next = retractHabitDay(await streakOf(tx, seed.uuid), day.key, day.previous.key);
    if (next) await writeStreak(tx, seed.uuid, next);
  }
  await refreshGlobal(tx, day);
}

/**
 * Buys one streak freeze for [freezeCost] coins, as the phone's
 * `buyFreeze` does: the balance and the shed are read inside the
 * transaction, so two clicks cannot both pass the check. Buying is
 * fine here; spending one on a missed day is the phone's 3 AM judging.
 */
export function buyFreeze(writer: Writer, day: HarvestDay): Promise<boolean> {
  return writer.run(async (tx) => {
    const streak = await streakOf(tx, globalStreakScope);
    if (streak.freezesStored >= maxFreezesStored) return false;
    const balance = (await tx.rows('ledger').where('kind').equals('coin').toArray()).reduce(
      (sum, entry) => sum + entry.delta,
      0,
    );
    if (balance < freezeCost) return false;
    await tx.ledger({ kind: 'coin', delta: -freezeCost, reason: 'freeze:buy', harvestDay: day.key });
    await writeStreak(tx, globalStreakScope, { ...streak, freezesStored: streak.freezesStored + 1 });
    return true;
  });
}
