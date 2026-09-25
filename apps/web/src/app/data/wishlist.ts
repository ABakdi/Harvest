import type { Row } from './db';
import type { Tx, Writer } from './writer';

export type WishlistRow = Row<'wishlist_items'>;
/** Which list an item sits in (W1): the buy list is day to day and the wishlist is future planning. Same rows, two moods. */
export type WishlistList = WishlistRow['list'];

export interface WishlistInput {
  title: string;
  priceMinor?: number | null;
  currency?: string;
  note?: string | null;
  targetDay?: string | null;
}

/** One past the last live item of [list]; deleted rows hold no place. */
async function nextPosition(tx: Tx, list: WishlistList): Promise<number> {
  const live = (await tx.rows('wishlist_items').toArray()).filter(
    (row) => row.list === list && row.deletedAt === null,
  );
  return live.reduce((max, row) => Math.max(max, row.position), -1) + 1;
}

/**
 * The two lists of the Granary's Wishlist tab, mirroring the phone's
 * WishlistRepository ([[Wishlist]]). Nothing here touches money: an
 * estimated price is a plan (W2), so no wallet movement, no ledger row
 * and no XP are ever written. Only the list, the order and the bought
 * stamp change.
 */
export class WishlistRepository {
  constructor(private readonly writer: Writer) {}

  add(input: { list: WishlistList } & WishlistInput): Promise<WishlistRow> {
    return this.writer.run(async (tx) => {
      const position = await nextPosition(tx, input.list);
      const now = tx.now();
      const row: WishlistRow = {
        uuid: crypto.randomUUID(),
        list: input.list,
        title: input.title.trim(),
        priceMinor: input.priceMinor ?? null,
        currency: input.currency ?? 'DZD',
        note: input.note?.trim() || null,
        targetDay: input.targetDay ?? null,
        boughtAt: null,
        position,
        createdAt: now,
        updatedAt: now,
        deletedAt: null,
      };
      await tx.put('wishlist_items', row);
      return row;
    });
  }

  /**
   * Edits an item and, given [to], moves it to that list in the same
   * write (as [move] does), so the edit never lands without the move.
   */
  edit(uuid: string, input: WishlistInput, to?: WishlistList): Promise<void> {
    return this.writer.run(async (tx) => {
      const row = await tx.rows('wishlist_items').get(uuid);
      const moving = to !== undefined && row !== undefined && row.list !== to;
      await tx.patch('wishlist_items', uuid, {
        title: input.title.trim(),
        priceMinor: input.priceMinor ?? null,
        currency: input.currency ?? 'DZD',
        note: input.note?.trim() || null,
        targetDay: input.targetDay ?? null,
        ...(moving ? { list: to, position: await nextPosition(tx, to) } : {}),
        updatedAt: tx.now(),
      });
    });
  }

  /**
   * A mood, not a copy (W4): the row keeps its price, note, target day
   * and history, and joins the bottom of the other list so it never
   * collides with an order already there — as the phone does.
   */
  move(uuid: string, to: WishlistList): Promise<void> {
    return this.writer.run(async (tx) => {
      const row = await tx.rows('wishlist_items').get(uuid);
      if (!row || row.list === to) return;
      const position = await nextPosition(tx, to);
      await tx.patch('wishlist_items', uuid, { list: to, position, updatedAt: tx.now() });
    });
  }

  /** One list's order, as arranged. */
  reorder(list: WishlistList, uuids: string[]): Promise<void> {
    return this.writer.run(async (tx) => {
      for (const [position, uuid] of uuids.entries()) {
        await tx.patch('wishlist_items', uuid, { list, position, updatedAt: tx.now() });
      }
    });
  }

  /**
   * Marks it bought; un-buying brings it back if the purchase fell
   * through (W3). The stamp is not a transaction.
   */
  setBought(uuid: string, bought: boolean): Promise<void> {
    return this.write(uuid, { boughtAt: bought ? this.writer.clock().toISOString() : null });
  }

  /** Soft delete, like the rest of the table (W6); [restore] undoes it. */
  delete(uuid: string): Promise<void> {
    return this.write(uuid, { deletedAt: this.writer.clock().toISOString() });
  }

  restore(uuid: string): Promise<void> {
    return this.write(uuid, { deletedAt: null });
  }

  /** Hard-deletes rows soft-deleted longer than [olderThanMs] ago — "delete" must eventually mean gone. */
  purgeDeleted(olderThanMs: number): Promise<void> {
    return this.writer.run(async (tx) => {
      const cutoff = new Date(tx.clockNow().getTime() - olderThanMs).toISOString();
      const stale = (await tx.rows('wishlist_items').toArray()).filter(
        (row) => row.deletedAt !== null && row.deletedAt < cutoff,
      );
      for (const row of stale) await tx.purge('wishlist_items', row.uuid);
    });
  }

  private write(uuid: string, changes: Partial<WishlistRow>): Promise<void> {
    return this.writer.run(async (tx) => {
      await tx.patch('wishlist_items', uuid, { ...changes, updatedAt: tx.now() });
    });
  }
}