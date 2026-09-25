import {
  commitmentFromRow,
  cycleMinutes,
  decodeCycle,
  fallbackCycle,
  sleepDebt,
  globalStreakScope,
  isDueOn,
  isOverdueOn,
  maxUnitsPerDay,
  productiveActions,
  dailyGoalFromJson,
  type DueCommitment,
  type HarvestDay,
} from '@harvest/core';
import type { HarvestDB } from './db';
import { readNights } from './health';
import type { SeedRow } from './seeds';
import { readSetting, settingKeys } from './settings';
import { readBudget } from './vault';

export interface FieldSeed {
  row: SeedRow;
  commitment: DueCommitment;
  due: boolean;
  overdue: boolean;
  /** Units logged on the day. */
  today: number;
  /** Units ever logged. */
  total: number;
  /** Distinct days done in the day's week (times-per-week habits). */
  doneDaysThisWeek: number;
  /** The day's check-in is in (a project: its daily commitment is met). */
  done: boolean;
  /** Room left under the over-log cap on the day. */
  room: number;
  streak: number | null;
}

export interface FieldView {
  today: FieldSeed[];
  resting: FieldSeed[];
  dayXp: number;
  totalXp: number;
  coins: number;
  actions: number;
  goal: number;
  streak: { current: number; best: number; freezes: number };
}

/**
 * The field for one Harvest Day, computed from the rows with
 * `packages/core` (W2): what is due by `isDueOn` and its start-day rule,
 * what is done, and the day's numbers. Nothing here is stored.
 */
export async function loadField(db: HarvestDB, day: HarvestDay): Promise<FieldView> {
  const [rows, checkIns, streaks, ledger, goalSetting, albums, memories] = await Promise.all([
    db.rows('commitments').toArray(),
    db.rows('check_ins').toArray(),
    db.rows('streaks').toArray(),
    db.rows('ledger').toArray(),
    db.rows('kv_settings').get(settingKeys.dailyHarvestGoal),
    db.rows('albums').toArray(),
    db.rows('memories').where('harvestDay').equals(day.key).toArray(),
  ]);

  const week = new Set(day.weekDays.map((d) => d.key));
  const totals = new Map<string, number>();
  const todays = new Map<string, number>();
  const weekDays = new Map<string, Set<string>>();
  for (const row of checkIns) {
    if (row.deletedAt !== null) continue;
    totals.set(row.commitmentUuid, (totals.get(row.commitmentUuid) ?? 0) + row.quantity);
    if (row.harvestDay === day.key) todays.set(row.commitmentUuid, (todays.get(row.commitmentUuid) ?? 0) + row.quantity);
    if (week.has(row.harvestDay)) {
      const days = weekDays.get(row.commitmentUuid) ?? new Set<string>();
      days.add(row.harvestDay);
      weekDays.set(row.commitmentUuid, days);
    }
  }
  const streakBy = new Map(streaks.map((row) => [row.scope, row]));

  const live: FieldSeed[] = [];
  for (const row of rows) {
    if (row.deletedAt !== null || row.archivedAt !== null) continue;
    let commitment: DueCommitment;
    try {
      commitment = commitmentFromRow(row);
    } catch {
      continue; // an unreadable seed is skipped, not a broken field
    }
    const today = todays.get(row.uuid) ?? 0;
    const total = totals.get(row.uuid) ?? 0;
    const doneDaysThisWeek = weekDays.get(row.uuid)?.size ?? 0;
    const done = row.type === 'project' ? today >= (row.dailyCommitment ?? 0) && today > 0 : today > 0;
    live.push({
      row,
      commitment,
      due: isDueOn(commitment, day, { doneDaysThisWeek, totalLogged: total }),
      overdue: isOverdueOn(commitment, day, total),
      today,
      total,
      doneDaysThisWeek,
      done,
      room: Math.max(maxUnitsPerDay(commitment) - today, 0),
      streak: row.type === 'habit' ? (streakBy.get(row.uuid)?.current ?? 0) : null,
    });
  }
  live.sort((a, b) => a.row.createdAt.localeCompare(b.row.createdAt));

  const scheduledAlbums = new Set(albums.filter((a) => a.deletedAt === null && a.scheduleJson !== null).map((a) => a.uuid));
  const albumActions = new Set(memories.filter((m) => m.deletedAt === null && scheduledAlbums.has(m.albumUuid)).map((m) => m.albumUuid)).size;

  let dayXp = 0;
  let totalXp = 0;
  let coins = 0;
  for (const entry of ledger) {
    if (entry.kind === 'coin') {
      coins += entry.delta;
      continue;
    }
    totalXp += entry.delta;
    if (entry.harvestDay === day.key) dayXp += entry.delta;
  }
  const global = streakBy.get(globalStreakScope);

  return {
    today: live.filter((seed) => (seed.due && seed.row.pausedAt === null) || seed.today > 0),
    resting: live.filter((seed) => !((seed.due && seed.row.pausedAt === null) || seed.today > 0)),
    dayXp,
    totalXp,
    coins,
    actions: productiveActions(todays, rows, albumActions),
    goal: dailyGoalFromJson(goalSetting?.valueJson),
    streak: { current: global?.current ?? 0, best: global?.best ?? 0, freezes: global?.freezesStored ?? 0 },
  };
}

/** What tomorrow asks for: habits due, and the to-dos planned for it. */
export interface TomorrowPlan {
  day: HarvestDay;
  habits: SeedRow[];
  todos: SeedRow[];
}

/**
 * Tomorrow at a glance, as the phone's `tomorrowPlan` works it out:
 * habits by `isDueOn` (a times-per-week habit whose week is already
 * done is not due), and to-dos planned for tomorrow and not yet done.
 * Projects are implicitly daily, so they stay off it.
 */
export async function readTomorrow(db: HarvestDB, today: HarvestDay): Promise<TomorrowPlan> {
  const tomorrow = today.next;
  const [rows, checkIns] = await Promise.all([db.rows('commitments').toArray(), db.rows('check_ins').toArray()]);
  const week = new Set(tomorrow.weekDays.map((d) => d.key));
  const totals = new Map<string, number>();
  const weekDays = new Map<string, Set<string>>();
  for (const row of checkIns) {
    if (row.deletedAt !== null) continue;
    totals.set(row.commitmentUuid, (totals.get(row.commitmentUuid) ?? 0) + row.quantity);
    if (week.has(row.harvestDay)) {
      const days = weekDays.get(row.commitmentUuid) ?? new Set<string>();
      days.add(row.harvestDay);
      weekDays.set(row.commitmentUuid, days);
    }
  }
  const habits: SeedRow[] = [];
  const todos: SeedRow[] = [];
  const live = rows
    .filter((row) => row.deletedAt === null && row.archivedAt === null)
    .sort((a, b) => a.createdAt.localeCompare(b.createdAt));
  for (const row of live) {
    if (row.type === 'habit') {
      let commitment: DueCommitment;
      try {
        commitment = commitmentFromRow(row);
      } catch {
        continue;
      }
      if (isDueOn(commitment, tomorrow, { doneDaysThisWeek: weekDays.get(row.uuid)?.size ?? 0 })) habits.push(row);
    } else if (row.type === 'todo') {
      if ((totals.get(row.uuid) ?? 0) === 0 && row.dueDay === tomorrow.key) todos.push(row);
    }
  }
  return { day: tomorrow, habits, todos };
}

/** The two gauges under the field's header: money left today, and sleep owed. */
export interface FieldGauges {
  /** Left (positive) or over (negative) today, in the default currency; null without a budget. */
  budgetLeft: number | null;
  /** Minutes of sleep owed; only when Health is switched on and something is owed. */
  sleepOwed: number | null;
}

/**
 * The same headline the Granary shows, and the sleep debt the Body
 * shows — the field header's two lines on the phone. Nothing owed is
 * not news, so the sleep line is only there when there is a debt.
 */
export async function readFieldGauges(db: HarvestDB, today: HarvestDay): Promise<FieldGauges> {
  const [budget, health, nights, bed, wake] = await Promise.all([
    readBudget(db, today),
    readSetting(db, 'features.health'),
    readNights(db),
    readSetting(db, 'cycle.bedTime'),
    readSetting(db, 'cycle.wakeTime'),
  ]);
  const snapshot = budget.monthlyBudget > 0 ? budget.snapshot : null;
  let sleepOwed: number | null = null;
  if (health === 'true') {
    const cycle = decodeCycle(bed && wake ? `${bed}-${wake}` : null) ?? fallbackCycle;
    const debt = sleepDebt(nights, { targetMinutes: cycleMinutes(cycle), upTo: today });
    if (debt.minutes > 0) sleepOwed = debt.minutes;
  }
  return {
    budgetLeft: snapshot === null ? null : snapshot.floatingDailyLimit - snapshot.spentToday,
    sleepOwed,
  };
}
