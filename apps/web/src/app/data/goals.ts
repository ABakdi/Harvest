import { HarvestDay, Xp } from '@harvest/core';
import type { Row } from './db';
import type { Tx, Writer } from './writer';

export type GoalRow = Row<'goals'>;
export type GoalItemRow = Row<'goal_items'>;
export type GoalItemKind = GoalItemRow['kind'];

/**
 * Goals and what they take, mirroring GoalsRepository on the phone.
 * A goal is judged by nothing (GL1): nothing here reads a check-in, and
 * nothing here writes to a seed.
 */
export class GoalsRepository {
  constructor(private readonly writer: Writer) {}

  create(input: { title: string; why?: string; targetDay?: string | null }): Promise<GoalRow> {
    return this.writer.run(async (tx) => {
      const goals = await tx.rows('goals').toArray();
      const position = goals.reduce((max, goal) => Math.max(max, goal.position), -1) + 1;
      const now = tx.now();
      const row: GoalRow = {
        uuid: crypto.randomUUID(),
        title: input.title.trim(),
        why: input.why?.trim() ?? '',
        targetDay: input.targetDay ?? null,
        status: 'active',
        statusNote: null,
        achievedAt: null,
        position,
        createdAt: now,
        updatedAt: now,
        deletedAt: null,
      };
      await tx.put('goals', row);
      return row;
    });
  }

  update(uuid: string, input: { title: string; why: string; targetDay: string | null }): Promise<void> {
    return this.write(uuid, { title: input.title.trim(), why: input.why.trim(), targetDay: input.targetDay });
  }

  /** Board order, as arranged. */
  reorder(uuids: string[]): Promise<void> {
    return this.writer.run(async (tx) => {
      for (const [position, uuid] of uuids.entries()) {
        await tx.patch('goals', uuid, { position, updatedAt: tx.now() });
      }
    });
  }

  /** Marks a goal achieved and pays for it, once (GL4). Always my click. */
  achieve(uuid: string): Promise<void> {
    return this.writer.run(async (tx) => {
      const now = tx.clockNow();
      await tx.patch('goals', uuid, { status: 'achieved', achievedAt: now.toISOString(), updatedAt: now.toISOString() });
      if ((await xpNet(tx, uuid)) <= 0) {
        await tx.ledger({ kind: 'xp', delta: Xp.goalAchieved, reason: `goal:${uuid}`, harvestDay: HarvestDay.of(now).key });
      }
    });
  }

  /**
   * Back to active, from achieved or dropped. What achieving paid is
   * taken back with a mirror row, the way an undone check-in is.
   */
  reopen(uuid: string): Promise<void> {
    return this.writer.run(async (tx) => {
      const now = tx.clockNow();
      await tx.patch('goals', uuid, {
        status: 'active',
        achievedAt: null,
        statusNote: null,
        updatedAt: now.toISOString(),
      });
      if ((await xpNet(tx, uuid)) > 0) {
        await tx.ledger({
          kind: 'xp',
          delta: -Xp.goalAchieved,
          reason: `goal-undo:${uuid}`,
          harvestDay: HarvestDay.of(now).key,
        });
      }
    });
  }

  /** Dropping is not failing, and costs nothing. Its seeds keep going (GL5). */
  drop(uuid: string, note: string | null): Promise<void> {
    return this.write(uuid, { status: 'dropped', statusNote: note?.trim() || null });
  }

  /** Soft delete, with its items (GL7); [restore] undoes it. */
  delete(uuid: string): Promise<void> {
    return this.writer.run((tx) => setDeleted(tx, uuid, tx.now()));
  }

  restore(uuid: string): Promise<void> {
    return this.writer.run((tx) => setDeleted(tx, uuid, null));
  }

  // ------------------------------------------------------------- items

  addItem(goalUuid: string, body: string, kind: GoalItemKind = 'step'): Promise<GoalItemRow> {
    return this.writer.run(async (tx) => {
      const siblings = (await tx.rows('goal_items').where('goalUuid').equals(goalUuid).toArray()).filter(
        (item) => item.kind === kind,
      );
      const position = siblings.reduce((max, item) => Math.max(max, item.position), -1) + 1;
      const now = tx.now();
      const row: GoalItemRow = {
        uuid: crypto.randomUUID(),
        goalUuid,
        kind,
        body: body.trim(),
        note: null,
        doneAt: null,
        position,
        commitmentUuid: null,
        createdAt: now,
        updatedAt: now,
        deletedAt: null,
      };
      await tx.put('goal_items', row);
      return row;
    });
  }

  editItem(uuid: string, body: string, note: string | null): Promise<void> {
    return this.writeItem(uuid, { body: body.trim(), note: note?.trim() || null });
  }

  /** Ticks or un-ticks by hand. */
  setDone(uuid: string, done: boolean): Promise<void> {
    return this.writer.run(async (tx) => {
      const now = tx.now();
      await tx.patch('goal_items', uuid, { doneAt: done ? now : null, updatedAt: now });
    });
  }

  /** One section's order, as arranged. */
  reorderItems(uuids: string[]): Promise<void> {
    return this.writer.run(async (tx) => {
      for (const [position, uuid] of uuids.entries()) {
        await tx.patch('goal_items', uuid, { position, updatedAt: tx.now() });
      }
    });
  }

  deleteItem(uuid: string): Promise<void> {
    return this.writer.run(async (tx) => {
      const now = tx.now();
      await tx.patch('goal_items', uuid, { deletedAt: now, updatedAt: now });
    });
  }

  restoreItem(uuid: string): Promise<void> {
    return this.writeItem(uuid, { deletedAt: null });
  }

  private write(uuid: string, changes: Partial<GoalRow>): Promise<void> {
    return this.writer.run(async (tx) => {
      await tx.patch('goals', uuid, { ...changes, updatedAt: tx.now() });
    });
  }

  private writeItem(uuid: string, changes: Partial<GoalItemRow>): Promise<void> {
    return this.writer.run(async (tx) => {
      await tx.patch('goal_items', uuid, { ...changes, updatedAt: tx.now() });
    });
  }
}

/** What achieving this goal has paid, net of its mirror rows. */
async function xpNet(tx: Tx, uuid: string): Promise<number> {
  const rows = await tx.ledgerFor(`goal:${uuid}`, `goal-undo:${uuid}`);
  return rows.reduce((sum, row) => sum + row.delta, 0);
}

/**
 * Items go with the goal and come back with it: only the ones that went
 * with it, which share its deletion stamp. An item deleted on its own
 * before stays deleted.
 */
async function setDeleted(tx: Tx, uuid: string, at: string | null): Promise<void> {
  const goal = await tx.get('goals', uuid);
  if (!goal) return;
  const stamp = at ?? goal.deletedAt;
  const items = (await tx.rows('goal_items').where('goalUuid').equals(uuid).toArray()).filter((item) =>
    at !== null ? item.deletedAt === null : item.deletedAt === stamp,
  );
  const now = tx.now();
  await tx.put('goals', { ...goal, deletedAt: at, updatedAt: now });
  for (const item of items) await tx.put('goal_items', { ...item, deletedAt: at, updatedAt: now });
}
