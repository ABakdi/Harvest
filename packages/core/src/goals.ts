/**
 * A goal's progress ([[Goals]] GL2): ticked items over all items, needs
 * and steps alike. Deleted items are gone from both sides of the
 * fraction. A goal with no items has no progress at all, which is not
 * the same as zero: the board shows "add what it takes" instead of an
 * empty ring.
 */
export interface GoalItemLike {
  readonly doneAt: string | Date | null;
  readonly deletedAt?: string | Date | null;
}

export interface GoalProgress {
  readonly done: number;
  readonly total: number;
  /** 0..1. */
  readonly ratio: number;
  /** Every item ticked: the card may offer *Mark achieved*, never do it (GL4). */
  readonly complete: boolean;
}

export function goalProgress(items: readonly GoalItemLike[]): GoalProgress | null {
  const live = items.filter((item) => item.deletedAt === null || item.deletedAt === undefined);
  if (live.length === 0) return null;
  const done = live.filter((item) => item.doneAt !== null).length;
  return { done, total: live.length, ratio: done / live.length, complete: done === live.length };
}
