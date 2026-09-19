/**
 * What things pay, from the XP table in [[Gamification]]. Every value
 * here is also a constant in the Dart app; the fixture
 * `fixtures/xp.json` holds the two to the same numbers.
 */
export const Xp = {
  /** A habit or a to-do checked off (`Xp.habitOrTodo`). */
  habitOrTodo: 10,
  /** Each unit logged on a project (`Xp.perProjectUnit`). */
  perProjectUnit: 2,
  /** A picture in a scheduled album; paid as a check-in (`Xp.habitOrTodo`). */
  memory: 10,
  /** A finished gym session; it goes through the check-in door (`Xp.habitOrTodo`). */
  gymSession: 10,
  /** Writing a night down, not sleeping well (`sleepXp`). */
  sleep: 15,
  /** A body weight, once a day (`weightXp`). */
  bodyWeight: 5,
  /** Meeting the step goal, once a day, when a goal is set (`stepGoalXp`). */
  stepGoal: 5,
  /** Logging the day's expenses (`expenseLogXp`). */
  expenseLog: 10,
  /**
   * Each completed focus block (`pomodoroBlockXp`). The XP table on the
   * Gamification page says "per session"; the phone pays per block, and
   * the phone is the rule.
   */
  pomodoroBlock: 5,
  /** Achieving a goal, once ([[Goals]] GL4). */
  goalAchieved: 50,
} as const;

/** Coins for global streak milestones (`streakMilestoneCoins`). */
export const streakMilestoneCoins: Readonly<Record<number, number>> = Object.freeze({
  7: 50,
  30: 200,
  100: 1000,
});

/** A streak freeze's price in coins, and how many can be stored (business rule #4). */
export const freezeCost = 100;
export const maxFreezesStored = 2;

/** The Daily Harvest Goal when none has been set. */
export const defaultDailyHarvestGoal = 3;

/** Farmer ranks, one step per 1,000 lifetime XP (`FarmerRank`). */
export const farmerRanks = ['sprout', 'seedling', 'gardener', 'harvester', 'masterFarmer'] as const;
export type FarmerRank = (typeof farmerRanks)[number];
export const xpPerRank = 1000;

/** `FarmerRank.forXp`: lifetime XP to rank, capped at the last one. */
export function farmerRankForXp(xp: number): FarmerRank {
  const index = Math.min(Math.max(Math.trunc(xp / xpPerRank), 0), farmerRanks.length - 1);
  return farmerRanks[index] as FarmerRank;
}
