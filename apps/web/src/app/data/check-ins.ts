import { planCheckIn, type CheckInPlan, type HarvestDay } from '@harvest/core';
import type { SeedRow } from './seeds';
import { onCheckIn, onUndo } from './streaks';
import type { Tx, Writer } from './writer';

/** The day's live units for one seed. */
export async function loggedOn(tx: Tx, seedUuid: string, dayKey: string): Promise<number> {
  const rows = await tx.rows('check_ins').where('[commitmentUuid+harvestDay]').equals([seedUuid, dayKey]).toArray();
  return rows.reduce((sum, row) => (row.deletedAt === null ? sum + row.quantity : sum), 0);
}

/** Every live unit ever logged on one seed. */
async function loggedEver(tx: Tx, seedUuid: string): Promise<number> {
  const rows = await tx.rows('check_ins').where('commitmentUuid').equals(seedUuid).toArray();
  return rows.reduce((sum, row) => (row.deletedAt === null ? sum + row.quantity : sum), 0);
}

/** What is left of a project's target after [logged] units; never below zero. */
export function projectLeft(seed: Pick<SeedRow, 'totalTarget'>, logged: number): number {
  return Math.max((seed.totalTarget ?? 0) - logged, 0);
}

/**
 * A planted to-do ticks the goal item it came from, and an undone
 * check-in un-ticks it ([[Goals]] GL3): the only change an item gets
 * without my hand, in the check-in's own transaction.
 */
async function tickGoalItems(tx: Tx, seedUuid: string, done: boolean): Promise<void> {
  const items = await tx.rows('goal_items').where('commitmentUuid').equals(seedUuid).toArray();
  const now = tx.now();
  for (const item of items) {
    if (item.deletedAt !== null || (item.doneAt !== null) === done) continue;
    await tx.put('goal_items', { ...item, doneAt: done ? now : null, updatedAt: now });
  }
}

/**
 * Check-ins, mirroring the phone's CheckInService: the one door effort
 * comes in by. The cap is read and the rows written in one transaction,
 * so two fast clicks cannot both slip under it.
 */
export class CheckInsRepository {
  constructor(private readonly writer: Writer) {}

  checkIn(seed: SeedRow, day: HarvestDay, quantity = 1): Promise<CheckInPlan> {
    return this.writer.run(async (tx) => {
      // One rule for both caps (`roomToday`): twice the daily
      // commitment on a day, and no more than what is left of the
      // target — 50 of 50 is done, never 160 of 50.
      const ever = seed.type === 'project' ? await loggedEver(tx, seed.uuid) : 0;
      const plan = planCheckIn(seed, await loggedOn(tx, seed.uuid, day.key), quantity, ever);
      if (plan.quantityLogged <= 0) return plan;
      const now = tx.now();
      const uuid = crypto.randomUUID();
      await tx.put('check_ins', {
        uuid,
        commitmentUuid: seed.uuid,
        harvestDay: day.key,
        quantity: plan.quantityLogged,
        loggedAt: now,
        deletedAt: null,
        updatedAt: now,
      });
      await tx.ledger({ kind: 'xp', delta: plan.xpEarned, reason: `checkin:${uuid}`, harvestDay: day.key });
      if (seed.type === 'todo') await tickGoalItems(tx, seed.uuid, true);
      await onCheckIn(tx, seed, day);
      return plan;
    });
  }

  /**
   * Undoes the day's check-ins for [seed]: same-day corrections only.
   * Rows are soft-deleted and their XP reversed with a mirror row, so
   * history stays honest and sync can follow.
   */
  undo(seed: SeedRow, day: HarvestDay): Promise<void> {
    return this.writer.run(async (tx) => {
      const rows = (
        await tx.rows('check_ins').where('[commitmentUuid+harvestDay]').equals([seed.uuid, day.key]).toArray()
      ).filter((row) => row.deletedAt === null);
      const now = tx.now();
      for (const row of rows) {
        await tx.put('check_ins', { ...row, deletedAt: now, updatedAt: now });
        const earned = (await tx.ledgerFor(`checkin:${row.uuid}`)).reduce(
          (sum, entry) => sum + entry.delta,
          0,
        );
        if (earned !== 0) {
          await tx.ledger({ kind: 'xp', delta: -earned, reason: `undo:${row.uuid}`, harvestDay: day.key });
        }
      }
      if (rows.length > 0 && seed.type === 'todo') await tickGoalItems(tx, seed.uuid, false);
      await onUndo(tx, seed, day);
    });
  }
}
