/**
 * A goal's progress ([[Goals]] GL2): ticked items over all items, needs
 * and steps alike, with a parent's subtasks counted in its place (GL8):
 * a task with three subtasks weighs three, not one. Deleted items are
 * gone from both sides of the fraction. A goal with no items has no
 * progress at all, which is not the same as zero: the board shows "add
 * what it takes" instead of an empty ring.
 */
export interface GoalItemLike {
  readonly uuid?: string;
  /** The task a subtask belongs to; absent or null on a top-level item. */
  readonly parentUuid?: string | null;
  readonly kind?: 'need' | 'step';
  readonly position?: number;
  readonly createdAt?: string | Date;
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

const isLive = (item: GoalItemLike) => item.deletedAt === null || item.deletedAt === undefined;
const epoch = (at: string | Date) => (at instanceof Date ? at.getTime() : Date.parse(at));

/** The uuids of live items that have at least one live subtask. */
function parentsOf(live: readonly GoalItemLike[]): Set<string> {
  const uuids = new Set(live.map((item) => item.uuid).filter((uuid) => uuid !== undefined));
  const parents = new Set<string>();
  for (const item of live) {
    if (item.parentUuid && uuids.has(item.parentUuid)) parents.add(item.parentUuid);
  }
  return parents;
}

export function goalProgress(items: readonly GoalItemLike[]): GoalProgress | null {
  const live = items.filter(isLive);
  const parents = parentsOf(live);
  const counted = live.filter((item) => item.uuid === undefined || !parents.has(item.uuid));
  if (counted.length === 0) return null;
  const done = counted.filter((item) => item.doneAt !== null).length;
  return { done, total: counted.length, ratio: done / counted.length, complete: done === counted.length };
}

/**
 * What a parent's stored `doneAt` must be, drawn from its subtasks (GL8):
 * with every live subtask ticked, the latest of their ticks; with any
 * open, null. `undefined` when it has no live subtask, and then the
 * parent's own tick stands. Both devices write it the same way, so a
 * parent synced from either one reads the same.
 */
export function parentDoneAt<T extends string | Date>(
  subtasks: readonly (GoalItemLike & { readonly doneAt: T | null })[],
): T | null | undefined {
  const live = subtasks.filter(isLive);
  if (live.length === 0) return undefined;
  let latest: T | null = null;
  for (const item of live) {
    if (item.doneAt === null) return null;
    if (latest === null || epoch(item.doneAt) > epoch(latest)) latest = item.doneAt;
  }
  return latest;
}

/** Position, then the order they were made in. */
function inOrder<T extends GoalItemLike>(items: readonly T[]): T[] {
  return [...items].sort(
    (a, b) =>
      (a.position ?? 0) - (b.position ?? 0) ||
      (a.createdAt === undefined || b.createdAt === undefined ? 0 : epoch(a.createdAt) - epoch(b.createdAt)),
  );
}

/**
 * The card's answer to *what now?* ([[Goals]], the board): the first open
 * task, or its first open subtask when it has subtasks. With every task
 * done, the same for requirements. A parent is open while any of its
 * live subtasks is, whatever its own stored tick says. A subtask whose
 * parent is gone reads as top-level, so nothing is lost from view.
 */
export function nextGoalItem<T extends GoalItemLike>(items: readonly T[]): T | null {
  const live = items.filter(isLive);
  const uuids = new Set(live.map((item) => item.uuid).filter((uuid) => uuid !== undefined));
  const topLevel = (item: T) => !item.parentUuid || !uuids.has(item.parentUuid);
  const subtasksOf = (item: T) =>
    item.uuid === undefined ? [] : inOrder(live.filter((child) => child.parentUuid === item.uuid));
  for (const kind of ['step', 'need'] as const) {
    for (const item of inOrder(live.filter((it) => topLevel(it) && (it.kind ?? 'step') === kind))) {
      const subtasks = subtasksOf(item);
      if (subtasks.length > 0) {
        const open = subtasks.find((child) => child.doneAt === null);
        if (open) return open;
      } else if (item.doneAt === null) {
        return item;
      }
    }
  }
  return null;
}
