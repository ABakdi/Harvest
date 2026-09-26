import { buyListId, wishListId } from '@harvest/contracts';
import { ListsRepository, listOfItem, type ListItemRow } from './lists';
import type { Writer } from './writer';

export type WishlistRow = ListItemRow;
/** Which list an item sits in (W1): the buy list is day to day and the wishlist is future planning. Same rows, two moods. */
export type WishlistList = 'buy' | 'wish';

export interface WishlistInput {
  title: string;
  priceMinor?: number | null;
  currency?: string;
  note?: string | null;
  targetDay?: string | null;
}

/** The built-in list each of the two is now ([[Lists]]). */
export const wishlistListIds: Record<WishlistList, string> = { buy: buyListId, wish: wishListId };

/** Which of the two lists [row] is in, or null for any other list's item. */
export function wishlistListOf(row: WishlistRow): WishlistList | null {
  const list = listOfItem(row);
  if (list === buyListId) return 'buy';
  if (list === wishListId) return 'wish';
  return null;
}

/**
 * The two lists of the Granary's Wishlist tab, which are now the
 * built-in *To buy* and *Wishlist* shopping lists ([[Lists]]). A thin
 * door onto [ListsRepository], as the phone's WishlistRepository is,
 * until Records → Lists replaces the tab. Nothing here touches money:
 * an estimated price is a plan (W2).
 */
export class WishlistRepository {
  private readonly lists: ListsRepository;

  constructor(private readonly writer: Writer) {
    this.lists = new ListsRepository(writer);
  }

  async add(input: { list: WishlistList } & WishlistInput): Promise<WishlistRow> {
    await this.lists.ensureBuiltIns();
    const { list, ...fields } = input;
    return this.lists.addItem(wishlistListIds[list], fields);
  }

  /**
   * Edits an item and, given [to], moves it to that list in the same
   * write (as [move] does), so the edit never lands without the move.
   */
  edit(uuid: string, input: WishlistInput, to?: WishlistList): Promise<void> {
    return this.writer.run(async (tx) => {
      await this.lists.editItemIn(tx, uuid, input);
      if (to !== undefined) await this.lists.moveItemIn(tx, uuid, wishlistListIds[to]);
    });
  }

  /**
   * A mood, not a copy (W4): the row keeps its price, note, target day
   * and history, and joins the bottom of the other list.
   */
  async move(uuid: string, to: WishlistList): Promise<void> {
    await this.lists.moveItem(uuid, wishlistListIds[to]);
  }

  /** One list's order, as arranged. */
  reorder(list: WishlistList, uuids: string[]): Promise<void> {
    return this.lists.reorderItems(wishlistListIds[list], uuids);
  }

  /**
   * Marks it bought; un-buying brings it back if the purchase fell
   * through (W3). A wish is moved to the buy list before it is bought
   * (W7). The stamp is not a transaction.
   */
  async setBought(uuid: string, bought: boolean): Promise<void> {
    await this.lists.setDone(uuid, bought);
  }

  /** Soft delete, like the rest of the table (W6); [restore] undoes it. */
  delete(uuid: string): Promise<void> {
    return this.lists.deleteItem(uuid);
  }

  restore(uuid: string): Promise<void> {
    return this.lists.restoreItem(uuid);
  }

  /** Hard-deletes rows soft-deleted longer than [olderThanMs] ago — every list's, since the items share one table. */
  purgeDeleted(olderThanMs: number): Promise<void> {
    return this.lists.purgeDeleted(olderThanMs);
  }
}
