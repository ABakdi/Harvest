import { goalProgress, nextGoalItem, type GoalProgress } from '@harvest/core';
import type { HarvestDB } from './db';
import { parentOf, type GoalItemRow, type GoalRow } from './goals';
import type { SeedRow } from './seeds';

export interface GoalView {
  goal: GoalRow;
  /** Top-level requirements, in order. */
  needs: GoalItemRow[];
  /** Top-level tasks, in order. */
  steps: GoalItemRow[];
  /** Each parent's live subtasks, in order (GL8). */
  subtasks: Map<string, GoalItemRow[]>;
  /** Subtasks counted in their parent's place (GL2). */
  progress: GoalProgress | null;
  /** The card's "what now?": the first open task, or its first open subtask. */
  next: GoalItemRow | null;
  /** [next]'s parent, when it is a subtask. */
  nextParent: GoalItemRow | null;
  /** Seeds that serve it, archived ones included (GL5). */
  seeds: SeedRow[];
  streaks: Map<string, number>;
}

const byPosition = (a: GoalItemRow, b: GoalItemRow) => a.position - b.position || a.createdAt.localeCompare(b.createdAt);

/**
 * Whether an item reads as ticked: a parent is done exactly when all
 * its subtasks are (GL8), whatever its stored tick says mid-sync.
 */
export function isItemDone(view: GoalView, item: GoalItemRow): boolean {
  const subtasks = view.subtasks.get(item.uuid);
  return subtasks ? subtasks.every((subtask) => subtask.doneAt !== null) : item.doneAt !== null;
}

export async function loadGoals(db: HarvestDB): Promise<GoalView[]> {
  const [goals, items, seeds, streaks] = await Promise.all([
    db.rows('goals').toArray(),
    db.rows('goal_items').toArray(),
    db.rows('commitments').toArray(),
    db.rows('streaks').toArray(),
  ]);
  const streakBy = new Map(streaks.map((row) => [row.scope, row.current]));
  return goals
    .filter((goal) => goal.deletedAt === null)
    .sort((a, b) => a.position - b.position || a.createdAt.localeCompare(b.createdAt))
    .map((goal) => {
      const live = items.filter((item) => item.goalUuid === goal.uuid && item.deletedAt === null);
      const liveIds = new Set(live.map((item) => item.uuid));
      // A subtask whose parent is gone (two devices disagreeing) reads as
      // top-level, as the shared rule does, so nothing drops from view.
      const topLevel = live.filter((item) => {
        const parent = parentOf(item);
        return parent === null || !liveIds.has(parent);
      });
      const subtasks = new Map<string, GoalItemRow[]>();
      for (const item of live) {
        const parent = parentOf(item);
        if (parent === null || !liveIds.has(parent)) continue;
        subtasks.set(parent, [...(subtasks.get(parent) ?? []), item]);
      }
      for (const list of subtasks.values()) list.sort(byPosition);
      const planted = new Set(live.map((item) => item.commitmentUuid).filter((uuid) => uuid !== null));
      const next = nextGoalItem(live);
      const nextParentId = next ? parentOf(next) : null;
      return {
        goal,
        needs: topLevel.filter((item) => item.kind === 'need').sort(byPosition),
        steps: topLevel.filter((item) => item.kind === 'step').sort(byPosition),
        subtasks,
        progress: goalProgress(live),
        next,
        nextParent: live.find((item) => item.uuid === nextParentId) ?? null,
        seeds: seeds
          .filter((seed) => seed.deletedAt === null && (seed.goalUuid === goal.uuid || planted.has(seed.uuid)))
          .sort((a, b) => a.createdAt.localeCompare(b.createdAt)),
        streaks: streakBy,
      };
    });
}
