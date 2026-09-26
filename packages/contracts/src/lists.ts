/**
 * The four lists every device has from the start ([[Lists]] L10), and
 * the ids they have on every device.
 *
 * Each id is a uuid v5 of `lists/<key>` under [listsNamespace], itself
 * the v5 of `harvest:lists` under the URL namespace (the way a geotag's
 * id is made). The ids are written out rather than computed so neither
 * client needs a v5 implementation to know them; the contract tests
 * derive them again, and the phone's tests read the same numbers from
 * `fixtures/built-in-lists.json`. Two devices that upgrade on their own
 * therefore make the same four rows, never two *To read*s.
 */
export const listsNamespace = '41156d84-936a-5a92-bd30-68dd604b6acb';

export const builtInListKeys = ['buy', 'wish', 'read', 'watch'] as const;
export type BuiltInListKey = (typeof builtInListKeys)[number];

export const listKinds = ['plain', 'shopping', 'media'] as const;
export type ListKind = (typeof listKinds)[number];

/** What a media item is ([[Lists]]: Kinds). */
export const mediaTypes = ['book', 'article', 'show', 'film', 'video', 'podcast', 'other'] as const;
export type MediaType = (typeof mediaTypes)[number];

export const buyListId = 'c4de613f-e027-5f99-bf47-f64aca9d6dfd';
export const wishListId = 'c89712ef-e04a-50a7-841f-0f698b7ec26c';
export const readListId = 'f09ec3ec-5479-525d-9c50-5dd509700907';
export const watchListId = '6711774e-0b76-5b66-81cd-09ce52a56399';

export interface BuiltInList {
  readonly key: BuiltInListKey;
  readonly uuid: string;
  readonly kind: ListKind;
  /** The stored name; the apps show a localised one while it is unchanged. */
  readonly name: string;
  readonly position: number;
}

/** The four, in the order they are first shown. */
export const builtInLists: readonly BuiltInList[] = [
  { key: 'buy', uuid: buyListId, kind: 'shopping', name: 'To buy', position: 0 },
  { key: 'wish', uuid: wishListId, kind: 'shopping', name: 'Wishlist', position: 1 },
  { key: 'read', uuid: readListId, kind: 'media', name: 'To read', position: 2 },
  { key: 'watch', uuid: watchListId, kind: 'media', name: 'To watch', position: 3 },
];

/**
 * The stamp a seeded built-in carries, older than anything I could
 * write: a device that upgrades late never outranks a rename made on
 * the other one.
 */
export const builtInListsStampedAt = '2020-01-01T00:00:00.000Z';

export function builtInListOf(uuid: string | null | undefined): BuiltInList | undefined {
  return builtInLists.find((list) => list.uuid === uuid);
}

/**
 * The list a `wishlist_items` row belongs to. `listUuid` is the truth;
 * a row written by a client from before lists (or an archive from then)
 * has only the old `list` column, which named one of the two shopping
 * lists.
 */
export function listUuidOfItem(row: { list: string; listUuid?: string | null }): string {
  return row.listUuid ?? (row.list === 'buy' ? buyListId : wishListId);
}

/** The old `list` column for an item in [listUuid]: `buy` only for *To buy*. */
export function legacyListOf(listUuid: string): 'buy' | 'wish' {
  return listUuid === buyListId ? 'buy' : 'wish';
}
