import { wishListId } from '@harvest/contracts';
import type { HarvestDB } from './db';
import { liveLists, listOfItem, type ListItemRow, type ListRow } from './lists';
import type { SeedRow } from './seeds';

/** How far the seed an item was planted as has come ([[Lists]]: Plant as a seed). */
export interface SeedProgress {
  seed: SeedRow;
  /** What has been logged on it, all time. */
  done: number;
  /** A project's target; null for a to-do. */
  total: number | null;
  /** A project that reached its target, or a to-do that was done: the moment to offer finishing the item. */
  complete: boolean;
}

export interface ListsView {
  lists: ListRow[];
  /** Open items per live list, for the chips. */
  counts: Map<string, number>;
  /** Every live item of a live list, in each list's order. */
  items: ListItemRow[];
  /** The linked seeds that are still there, by seed uuid. */
  seeds: Map<string, SeedProgress>;
}

/** Everything the Lists view shows, in one read. */
export async function loadListsView(db: HarvestDB): Promise<ListsView> {
  const [lists, rows, seeds, checkIns] = await Promise.all([
    liveLists(db),
    db.rows('wishlist_items').toArray(),
    db.rows('commitments').toArray(),
    db.rows('check_ins').toArray(),
  ]);
  const live = new Set(lists.map((list) => list.uuid));
  const items = rows
    .filter((row) => row.deletedAt === null && live.has(listOfItem(row)))
    .sort((a, b) => a.position - b.position || a.createdAt.localeCompare(b.createdAt));
  const counts = new Map(lists.map((list) => [list.uuid, 0]));
  for (const row of items) {
    if (row.boughtAt === null) counts.set(listOfItem(row), counts.get(listOfItem(row))! + 1);
  }

  const linked = new Set(items.map((row) => row.seedUuid).filter((uuid) => uuid !== null));
  const logged = new Map<string, number>();
  for (const row of checkIns) {
    if (row.deletedAt !== null || !linked.has(row.commitmentUuid)) continue;
    logged.set(row.commitmentUuid, (logged.get(row.commitmentUuid) ?? 0) + row.quantity);
  }
  const progress = new Map<string, SeedProgress>();
  for (const seed of seeds) {
    if (!linked.has(seed.uuid) || seed.deletedAt !== null) continue;
    const done = logged.get(seed.uuid) ?? 0;
    const total = seed.type === 'project' ? seed.totalTarget : null;
    const complete = seed.type === 'project' ? total !== null && done >= total : seed.type === 'todo' && done > 0;
    progress.set(seed.uuid, { seed, done, total, complete });
  }
  return { lists, counts, items, seeds: progress };
}

/**
 * What the open shopping items are expected to cost, per currency and
 * never added across ([[Lists]] L3): a plan, not a ledger line. The
 * Wishlist is someday, not planned, so its items are left out.
 */
export async function readPlannedPurchases(db: HarvestDB): Promise<[string, number][]> {
  const shopping = new Set((await liveLists(db)).filter((list) => list.kind === 'shopping' && list.uuid !== wishListId).map((list) => list.uuid));
  const sums = new Map<string, number>();
  for (const row of await db.rows('wishlist_items').toArray()) {
    if (row.deletedAt !== null || row.boughtAt !== null || row.priceMinor === null || !shopping.has(listOfItem(row))) continue;
    sums.set(row.currency, (sums.get(row.currency) ?? 0) + row.priceMinor);
  }
  return [...sums.entries()];
}
