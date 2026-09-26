import {
  builtInListOf,
  legacyListOf,
  listUuidOfItem,
  sameInstant,
  wishListId,
  type BuiltInList,
  type ListKind,
  type MediaType,
} from '@harvest/contracts';
import { seedBuiltInLists, type HarvestDB, type Row } from './db';
import type { Tx, Writer } from './writer';

export { listsFeatureKey, seedBuiltInLists } from './db';

export type ListRow = Row<'lists'>;
export type ListItemRow = Row<'wishlist_items'>;

/** What I type about an item; the fields of other kinds are dropped (L2). */
export interface ListItemInput {
  title: string;
  note?: string | null;
  /** Shopping: an estimate, a plan and never a ledger line (L3). */
  priceMinor?: number | null;
  currency?: string;
  /** Shopping: the planned day, a plan (L5). */
  targetDay?: string | null;
  /** Media. */
  mediaType?: MediaType | null;
  link?: string | null;
  creator?: string | null;
}

/** The list an item belongs to, reading a row from before lists by its old column. */
export function listOfItem(row: ListItemRow): string {
  return listUuidOfItem(row);
}

/** Which of the four [list] is, if it is one. */
export function builtInOf(list: ListRow): BuiltInList | undefined {
  return list.builtIn === null ? undefined : builtInListOf(list.uuid);
}

/** Whether a built-in list still has the name it was made with, so the app shows a localised one. */
export function hasDefaultName(list: ListRow): boolean {
  const builtIn = builtInOf(list);
  return builtIn !== undefined && list.name === builtIn.name;
}

/** The live lists, in my order. */
export async function liveLists(db: HarvestDB): Promise<ListRow[]> {
  return (await db.rows('lists').toArray())
    .filter((row) => row.deletedAt === null)
    .sort((a, b) => a.position - b.position || a.createdAt.localeCompare(b.createdAt));
}

/** One list's live items, open and done, in my order. */
export async function itemsOfList(db: HarvestDB, listUuid: string): Promise<ListItemRow[]> {
  return inHandOrder((await db.rows('wishlist_items').toArray()).filter((row) => row.deletedAt === null && listOfItem(row) === listUuid));
}

/** How many open items each live list has — the count on its chip. */
export async function openCounts(db: HarvestDB): Promise<Map<string, number>> {
  const counts = new Map((await liveLists(db)).map((list) => [list.uuid, 0]));
  for (const row of await db.rows('wishlist_items').toArray()) {
    const list = listOfItem(row);
    if (row.deletedAt !== null || row.boughtAt !== null || !counts.has(list)) continue;
    counts.set(list, counts.get(list)! + 1);
  }
  return counts;
}

function inHandOrder(rows: ListItemRow[]): ListItemRow[] {
  return rows.sort((a, b) => a.position - b.position || a.createdAt.localeCompare(b.createdAt));
}

function blankToNull(text: string | null | undefined): string | null {
  const trimmed = text?.trim();
  return trimmed ? trimmed : null;
}

/** Only the fields [kind] carries; the rest are written empty (L2). */
function fieldsOf(kind: ListKind, input: Omit<ListItemInput, 'title'>) {
  const shopping = kind === 'shopping';
  const media = kind === 'media';
  return {
    note: blankToNull(input.note),
    priceMinor: shopping ? (input.priceMinor ?? null) : null,
    currency: input.currency ?? 'DZD',
    targetDay: shopping ? (input.targetDay ?? null) : null,
    mediaType: media ? (input.mediaType ?? null) : null,
    link: media ? blankToNull(input.link) : null,
    creator: media ? blankToNull(input.creator) : null,
  };
}

/** One past the last live item of [listUuid]; deleted rows hold no place. */
async function nextPosition(tx: Tx, listUuid: string): Promise<number> {
  const live = (await tx.rows('wishlist_items').toArray()).filter((row) => row.deletedAt === null && listOfItem(row) === listUuid);
  return live.reduce((max, row) => Math.max(max, row.position), -1) + 1;
}

async function nextListPosition(tx: Tx): Promise<number> {
  const live = (await tx.rows('lists').toArray()).filter((row) => row.deletedAt === null);
  return live.reduce((max, row) => Math.max(max, row.position), -1) + 1;
}

/**
 * Every list and every item ([[Lists]]), mirroring the phone's
 * ListsRepository: the `lists` table, and the items in `wishlist_items`,
 * which kept its name for the devices and archives from before.
 *
 * Nothing here pays or costs anything (L8), and nothing touches money
 * (L3, L4): marking a shopping item bought is a stamp. Every write goes
 * through the writer with a fresh `updatedAt`, so it is queued for sync.
 *
 * The `*In(tx, …)` forms do the same inside a transaction already open,
 * so a caller can put two changes in one write.
 */
export class ListsRepository {
  constructor(private readonly writer: Writer) {}

  /** The four built-in lists, made again if they are missing (L10). */
  ensureBuiltIns(): Promise<void> {
    return seedBuiltInLists(this.writer.db);
  }

  // ---------------------------------------------------------------- lists

  /** A list of my own, at the end of the row (L1: a list is a row). */
  createList(input: { name: string; kind: ListKind; icon?: string | null }): Promise<ListRow> {
    return this.writer.run(async (tx) => {
      const now = tx.now();
      const row: ListRow = {
        uuid: crypto.randomUUID(),
        name: input.name.trim(),
        kind: input.kind,
        icon: input.icon ?? null,
        position: await nextListPosition(tx),
        builtIn: null,
        createdAt: now,
        updatedAt: now,
        deletedAt: null,
      };
      await tx.put('lists', row);
      return row;
    });
  }

  /** Built-in lists can be renamed too; the app then shows my name instead of the localised one. */
  renameList(uuid: string, name: string): Promise<void> {
    return this.writeList(uuid, { name: name.trim() });
  }

  setListIcon(uuid: string, icon: string | null): Promise<void> {
    return this.writeList(uuid, { icon });
  }

  /** The lists' order, as arranged; every row carries a fresh stamp. */
  reorderLists(uuids: string[]): Promise<void> {
    return this.writer.run(async (tx) => {
      for (const [position, uuid] of uuids.entries()) {
        await tx.patch('lists', uuid, { position, updatedAt: tx.now() });
      }
    });
  }

  /**
   * Soft-deletes a list I made, and its live items with it, under one
   * stamp so [restoreList] brings back exactly those (L6). A built-in
   * list is not deleted (L10): false.
   */
  deleteList(uuid: string): Promise<boolean> {
    return this.writer.run(async (tx) => {
      const list = await tx.get('lists', uuid);
      if (!list || list.builtIn !== null || list.deletedAt !== null) return false;
      const stamp = tx.now();
      await tx.patch('lists', uuid, { deletedAt: stamp, updatedAt: stamp });
      for (const row of await tx.rows('wishlist_items').toArray()) {
        if (row.deletedAt !== null || listOfItem(row) !== uuid) continue;
        await tx.patch('wishlist_items', row.uuid, { deletedAt: stamp, updatedAt: stamp });
      }
      return true;
    });
  }

  /** Undoes [deleteList]: the list, and the items that went with it. An item deleted on its own before stays in the trash. */
  restoreList(uuid: string): Promise<void> {
    return this.writer.run(async (tx) => {
      const list = await tx.get('lists', uuid);
      const stamp = list?.deletedAt;
      if (!list || !stamp) return;
      await tx.patch('lists', uuid, { deletedAt: null, updatedAt: tx.now() });
      for (const row of await tx.rows('wishlist_items').toArray()) {
        if (row.deletedAt === null || !sameInstant(row.deletedAt, stamp) || listOfItem(row) !== uuid) continue;
        await tx.patch('wishlist_items', row.uuid, { deletedAt: null, updatedAt: tx.now() });
      }
    });
  }

  // ---------------------------------------------------------------- items

  /**
   * Adds an item at the bottom of [listUuid]. Only the fields of the
   * list's kind are kept (L2). Adding pays nothing (L8).
   */
  addItem(listUuid: string, input: ListItemInput): Promise<ListItemRow> {
    return this.writer.run((tx) => this.addItemIn(tx, listUuid, input));
  }

  async addItemIn(tx: Tx, listUuid: string, input: ListItemInput): Promise<ListItemRow> {
    const list = await tx.get('lists', listUuid);
    if (!list || list.deletedAt !== null) throw new Error(`No such list: ${listUuid}`);
    const now = tx.now();
    const row: ListItemRow = {
      uuid: crypto.randomUUID(),
      list: legacyListOf(listUuid),
      listUuid,
      title: input.title.trim(),
      ...fieldsOf(list.kind, input),
      startedAt: null,
      rating: null,
      seedUuid: null,
      noteUuid: null,
      boughtAt: null,
      position: await nextPosition(tx, listUuid),
      createdAt: now,
      updatedAt: now,
      deletedAt: null,
    };
    await tx.put('wishlist_items', row);
    return row;
  }

  /** Edits what I typed about an item; the fields of other kinds stay empty (L2). */
  editItem(uuid: string, input: ListItemInput): Promise<void> {
    return this.writer.run((tx) => this.editItemIn(tx, uuid, input));
  }

  async editItemIn(tx: Tx, uuid: string, input: ListItemInput): Promise<void> {
    const row = await tx.get('wishlist_items', uuid);
    if (!row) return;
    const kind = (await tx.get('lists', listOfItem(row)))?.kind ?? 'shopping';
    await tx.patch('wishlist_items', uuid, { title: input.title.trim(), ...fieldsOf(kind, input), updatedAt: tx.now() });
  }

  /**
   * Moves an item to another list of the same kind, as the same row
   * (L2): it keeps every field and its history, and joins the bottom.
   * Another kind, a deleted list, or the list it is on: false.
   */
  moveItem(uuid: string, toListUuid: string): Promise<boolean> {
    return this.writer.run((tx) => this.moveItemIn(tx, uuid, toListUuid));
  }

  async moveItemIn(tx: Tx, uuid: string, toListUuid: string): Promise<boolean> {
    const row = await tx.get('wishlist_items', uuid);
    if (!row || listOfItem(row) === toListUuid) return false;
    const from = await tx.get('lists', listOfItem(row));
    const to = await tx.get('lists', toListUuid);
    if (!to || to.deletedAt !== null) return false;
    if (from && from.kind !== to.kind) return false;
    await tx.patch('wishlist_items', uuid, {
      list: legacyListOf(toListUuid),
      listUuid: toListUuid,
      position: await nextPosition(tx, toListUuid),
      updatedAt: tx.now(),
    });
    return true;
  }

  /** One list's order, as arranged. */
  reorderItems(listUuid: string, uuids: string[]): Promise<void> {
    return this.writer.run(async (tx) => {
      for (const [position, uuid] of uuids.entries()) {
        await tx.patch('wishlist_items', uuid, { list: legacyListOf(listUuid), listUuid, position, updatedAt: tx.now() });
      }
    });
  }

  /**
   * Bought, finished or ticked — a stamp, not a transaction (L4) — and
   * undone if it was not. The Wishlist's items are not bought: a wish
   * moves to *To buy* first (L7), so marking one is refused (false).
   */
  setDone(uuid: string, done: boolean): Promise<boolean> {
    return this.writer.run(async (tx) => {
      const row = await tx.get('wishlist_items', uuid);
      if (!row) return false;
      if (done && listOfItem(row) === wishListId) return false;
      await tx.patch('wishlist_items', uuid, { boughtAt: done ? tx.now() : null, updatedAt: tx.now() });
      return true;
    });
  }

  /** A media item in progress, or back to wanted. Other kinds have no start: false. */
  setStarted(uuid: string, started: boolean): Promise<boolean> {
    return this.media(uuid, (tx) => ({ startedAt: started ? tx.now() : null }));
  }

  /** A media item's rating, 1–5, or none. */
  setRating(uuid: string, rating: number | null): Promise<boolean> {
    if (rating !== null && (!Number.isInteger(rating) || rating < 1 || rating > 5)) {
      return Promise.reject(new RangeError(`A rating is 1 to 5, not ${rating}`));
    }
    return this.media(uuid, () => ({ rating }));
  }

  /** A media item's link. Saved as typed; nothing is fetched (L9). */
  setLink(uuid: string, link: string | null): Promise<boolean> {
    return this.media(uuid, () => ({ link: blankToNull(link) }));
  }

  setCreator(uuid: string, creator: string | null): Promise<boolean> {
    return this.media(uuid, () => ({ creator: blankToNull(creator) }));
  }

  setMediaType(uuid: string, mediaType: MediaType | null): Promise<boolean> {
    return this.media(uuid, () => ({ mediaType }));
  }

  /** The seed this item was planted as, or none. The seed pays as any seed does (L8); the link is all this keeps. */
  linkSeed(uuid: string, seedUuid: string | null): Promise<void> {
    return this.writeItem(uuid, { seedUuid });
  }

  /** The note written about this item, or none. */
  linkNote(uuid: string, noteUuid: string | null): Promise<void> {
    return this.writeItem(uuid, { noteUuid });
  }

  /** Soft delete (L6); [restoreItem] undoes it. */
  deleteItem(uuid: string): Promise<void> {
    return this.writeItem(uuid, { deletedAt: this.writer.clock().toISOString() });
  }

  restoreItem(uuid: string): Promise<void> {
    return this.writeItem(uuid, { deletedAt: null });
  }

  /** Hard-deletes items and lists soft-deleted longer than [olderThanMs] ago. A built-in list is never purged. */
  purgeDeleted(olderThanMs: number): Promise<void> {
    return this.writer.run(async (tx) => {
      const cutoff = new Date(tx.clockNow().getTime() - olderThanMs).toISOString();
      for (const row of await tx.rows('wishlist_items').toArray()) {
        if (row.deletedAt !== null && row.deletedAt < cutoff) await tx.purge('wishlist_items', row.uuid);
      }
      for (const row of await tx.rows('lists').toArray()) {
        if (row.builtIn === null && row.deletedAt !== null && row.deletedAt < cutoff) await tx.purge('lists', row.uuid);
      }
    });
  }

  // ------------------------------------------------------------- helpers

  private media(uuid: string, changes: (tx: Tx) => Partial<ListItemRow>): Promise<boolean> {
    return this.writer.run(async (tx) => {
      const row = await tx.get('wishlist_items', uuid);
      if (!row) return false;
      if ((await tx.get('lists', listOfItem(row)))?.kind !== 'media') return false;
      await tx.patch('wishlist_items', uuid, { ...changes(tx), updatedAt: tx.now() });
      return true;
    });
  }

  private writeList(uuid: string, changes: Partial<ListRow>): Promise<void> {
    return this.writer.run(async (tx) => {
      await tx.patch('lists', uuid, { ...changes, updatedAt: tx.now() });
    });
  }

  private writeItem(uuid: string, changes: Partial<ListItemRow>): Promise<void> {
    return this.writer.run(async (tx) => {
      await tx.patch('wishlist_items', uuid, { ...changes, updatedAt: tx.now() });
    });
  }
}
