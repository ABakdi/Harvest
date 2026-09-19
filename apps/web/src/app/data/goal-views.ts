import { goalProgress, type GoalProgress } from '@harvest/core';
import type { HarvestDB } from './db';
import type { GoalItemRow, GoalRow } from './goals';
import type { SeedRow } from './seeds';

export interface GoalView {
  goal: GoalRow;
  needs: GoalItemRow[];
  steps: GoalItemRow[];
  progress: GoalProgress | null;
  /** The first unticked step, or need if every step is done: "what now?". */
  next: GoalItemRow | null;
  /** Seeds that serve it, archived ones included (GL5). */
  seeds: SeedRow[];
  streaks: Map<string, number>;
}

const byPosition = (a: GoalItemRow, b: GoalItemRow) => a.position - b.position || a.createdAt.localeCompare(b.createdAt);

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
      const needs = live.filter((item) => item.kind === 'need').sort(byPosition);
      const steps = live.filter((item) => item.kind === 'step').sort(byPosition);
      const planted = new Set(live.map((item) => item.commitmentUuid).filter((uuid) => uuid !== null));
      return {
        goal,
        needs,
        steps,
        progress: goalProgress(live),
        next: steps.find((item) => item.doneAt === null) ?? needs.find((item) => item.doneAt === null) ?? null,
        seeds: seeds
          .filter((seed) => seed.deletedAt === null && (seed.goalUuid === goal.uuid || planted.has(seed.uuid)))
          .sort((a, b) => a.createdAt.localeCompare(b.createdAt)),
        streaks: streakBy,
      };
    });
}
