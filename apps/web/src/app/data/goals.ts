import { HarvestDay, parentDoneAt, Xp } from '@harvest/core';
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

  /** A new item at the end of its section. */
  addItem(goalUuid: string, body: string, kind: GoalItemKind = 'step'): Promise<GoalItemRow> {
    return this.writer.run(async (tx) => {
      const siblings = (await itemsOf(tx, goalUuid)).filter((item) => parentOf(item) === null && item.kind === kind);
      const row = newItem(tx, { goalUuid, body, kind, parentUuid: null, siblings });
      await tx.put('goal_items', row);
      return row;
    });
  }

  /**
   * A new subtask at the end of [parentUuid]'s. It takes its parent's
   * kind, and a subtask has no subtasks of its own (GL8): asked to give
   * one some, this adds nothing and returns null. An open subtask
   * reopens a ticked parent.
   */
  addSubtask(parentUuid: string, body: string): Promise<GoalItemRow | null> {
    return this.writer.run(async (tx) => {
      const parent = await tx.get('goal_items', parentUuid);
      if (!parent || parent.deletedAt !== null || parentOf(parent) !== null) return null;
      const siblings = (await itemsOf(tx, parent.goalUuid)).filter((item) => parentOf(item) === parentUuid);
      const row = newItem(tx, { goalUuid: parent.goalUuid, body, kind: parent.kind, parentUuid, siblings });
      await tx.put('goal_items', row);
      await settleParent(tx, parentUuid);
      return row;
    });
  }

  editItem(uuid: string, body: string, note: string | null): Promise<void> {
    return this.writeItem(uuid, { body: body.trim(), note: note?.trim() || null });
  }

  /**
   * Ticks or un-ticks by hand. A parent takes all its subtasks with it,
   * in one transaction, and a subtask settles its parent (GL8).
   */
  setDone(uuid: string, done: boolean): Promise<void> {
    return this.writer.run(async (tx) => {
      const item = await tx.get('goal_items', uuid);
      if (item) await tickGoalItem(tx, item, done);
    });
  }

  /** One section's order, or one task's subtasks, as arranged. */
  reorderItems(uuids: string[]): Promise<void> {
    return this.writer.run(async (tx) => {
      for (const [position, uuid] of uuids.entries()) {
        await tx.patch('goal_items', uuid, { position, updatedAt: tx.now() });
      }
    });
  }

  /**
   * A subtask lifted to an item of its own, at the end of its section.
   * It keeps its tick; the parent it left settles on the rest (GL8).
   */
  liftItem(uuid: string): Promise<void> {
    return this.writer.run(async (tx) => {
      const item = await tx.get('goal_items', uuid);
      const from = item ? parentOf(item) : null;
      if (!item || from === null) return;
      const items = await itemsOf(tx, item.goalUuid);
      const position =
        items
          .filter((other) => parentOf(other) === null && other.kind === item.kind)
          .reduce((max, other) => Math.max(max, other.position), -1) + 1;
      await tx.put('goal_items', { ...item, parentUuid: null, position, updatedAt: tx.now() });
      await settleParent(tx, from);
    });
  }

  /**
   * An item without subtasks moved under another top-level item of the
   * same goal, as its last subtask. It takes the parent's kind, and the
   * parent settles on its subtasks now (GL8). Anything else (a parent,
   * itself, a subtask, another goal's item) is refused with false.
   */
  nestItem(uuid: string, parentUuid: string): Promise<boolean> {
    return this.writer.run(async (tx) => {
      const item = await tx.get('goal_items', uuid);
      const parent = await tx.get('goal_items', parentUuid);
      if (!item || !parent || uuid === parentUuid) return false;
      if (item.deletedAt !== null || parent.deletedAt !== null || item.goalUuid !== parent.goalUuid) return false;
      if (parentOf(parent) !== null) return false;
      const items = await itemsOf(tx, item.goalUuid);
      if (items.some((other) => parentOf(other) === uuid && other.deletedAt === null)) return false;
      const position =
        items.filter((other) => parentOf(other) === parentUuid).reduce((max, other) => Math.max(max, other.position), -1) + 1;
      const from = parentOf(item);
      await tx.put('goal_items', { ...item, kind: parent.kind, parentUuid, position, updatedAt: tx.now() });
      await settleParent(tx, parentUuid);
      if (from !== null && from !== parentUuid) await settleParent(tx, from);
      return true;
    });
  }

  /**
   * Soft delete. A parent takes its live subtasks with it, under the
   * same stamp (GL7), and [restoreItem] brings exactly those back. A
   * subtask's parent settles on the ones left.
   */
  deleteItem(uuid: string): Promise<void> {
    return this.writer.run(async (tx) => {
      const item = await tx.get('goal_items', uuid);
      if (!item || item.deletedAt !== null) return;
      const now = tx.now();
      const subtasks = (await itemsOf(tx, item.goalUuid)).filter((other) => parentOf(other) === uuid && other.deletedAt === null);
      await tx.put('goal_items', { ...item, deletedAt: now, updatedAt: now });
      for (const subtask of subtasks) await tx.put('goal_items', { ...subtask, deletedAt: now, updatedAt: now });
      const parent = parentOf(item);
      if (parent !== null) await settleParent(tx, parent);
    });
  }

  restoreItem(uuid: string): Promise<void> {
    return this.writer.run(async (tx) => {
      const item = await tx.get('goal_items', uuid);
      if (!item || item.deletedAt === null) return;
      const stamp = item.deletedAt;
      const now = tx.now();
      const subtasks = (await itemsOf(tx, item.goalUuid)).filter((other) => parentOf(other) === uuid && other.deletedAt === stamp);
      await tx.put('goal_items', { ...item, deletedAt: null, updatedAt: now });
      for (const subtask of subtasks) await tx.put('goal_items', { ...subtask, deletedAt: null, updatedAt: now });
      await settleParent(tx, parentOf(item) ?? uuid);
    });
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

/** The task a subtask belongs to. A row stored before v24 has no key for it. */
export const parentOf = (item: GoalItemRow): string | null => item.parentUuid ?? null;

function newItem(
  tx: Tx,
  input: { goalUuid: string; body: string; kind: GoalItemKind; parentUuid: string | null; siblings: GoalItemRow[] },
): GoalItemRow {
  const now = tx.now();
  return {
    uuid: crypto.randomUUID(),
    goalUuid: input.goalUuid,
    kind: input.kind,
    body: input.body.trim(),
    note: null,
    doneAt: null,
    position: input.siblings.reduce((max, item) => Math.max(max, item.position), -1) + 1,
    commitmentUuid: null,
    parentUuid: input.parentUuid,
    createdAt: now,
    updatedAt: now,
    deletedAt: null,
  };
}

const itemsOf = (tx: Tx, goalUuid: string) => tx.rows('goal_items').where('goalUuid').equals(goalUuid).toArray();

/**
 * Keeps a parent's stored tick drawn from its live subtasks (GL8): the
 * latest of their ticks once all are ticked, null while any is open. A
 * parent with no live subtask keeps its own tick. The phone writes it
 * the same way, from the same rule in `@harvest/core`.
 */
async function settleParent(tx: Tx, uuid: string): Promise<void> {
  const parent = await tx.get('goal_items', uuid);
  if (!parent || parent.deletedAt !== null) return;
  const subtasks = (await itemsOf(tx, parent.goalUuid)).filter((item) => parentOf(item) === uuid);
  const doneAt = parentDoneAt(subtasks);
  if (doneAt === undefined || doneAt === parent.doneAt) return;
  await tx.put('goal_items', { ...parent, doneAt, updatedAt: tx.now() });
}

/**
 * Ticks or un-ticks one item, as a hand or a planted to-do's check-in
 * does (GL3): a parent does the same to every live subtask, and a
 * subtask settles its parent, which it may complete (GL8). An item
 * already in that state is left as it is, keeping its stamp.
 */
export async function tickGoalItem(tx: Tx, item: GoalItemRow, done: boolean): Promise<void> {
  if (item.deletedAt !== null) return;
  const now = tx.now();
  const subtasks = (await itemsOf(tx, item.goalUuid)).filter((other) => parentOf(other) === item.uuid && other.deletedAt === null);
  if (subtasks.length > 0) {
    for (const subtask of subtasks) {
      if ((subtask.doneAt !== null) !== done) await tx.put('goal_items', { ...subtask, doneAt: done ? now : null, updatedAt: now });
    }
    await settleParent(tx, item.uuid);
    return;
  }
  if ((item.doneAt !== null) !== done) await tx.put('goal_items', { ...item, doneAt: done ? now : null, updatedAt: now });
  const parent = parentOf(item);
  if (parent !== null) await settleParent(tx, parent);
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
