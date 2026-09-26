import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';
import {
  builtInListOf,
  builtInLists,
  builtInListsStampedAt,
  buyListId,
  legacyListOf,
  listsNamespace,
  listUuidOfItem,
  readListId,
  tables,
  watchListId,
  wishListId,
} from '../src/index.js';

/** RFC 4122 uuid v5, spelled out so the test does not trust a library. */
function v5(name: string, namespace: string): string {
  const bytes = createHash('sha1')
    .update(Buffer.concat([Buffer.from(namespace.replace(/-/g, ''), 'hex'), Buffer.from(name, 'utf8')]))
    .digest()
    .subarray(0, 16);
  bytes[6] = (bytes[6]! & 0x0f) | 0x50;
  bytes[8] = (bytes[8]! & 0x3f) | 0x80;
  const hex = bytes.toString('hex');
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
}

const urlNamespace = '6ba7b811-9dad-11d1-80b4-00c04fd430c8';

describe('the built-in lists (L10)', () => {
  it('have ids derived from their keys, the same on every device', () => {
    expect(listsNamespace).toBe(v5('harvest:lists', urlNamespace));
    expect(buyListId).toBe(v5('lists/buy', listsNamespace));
    expect(wishListId).toBe(v5('lists/wish', listsNamespace));
    expect(readListId).toBe(v5('lists/read', listsNamespace));
    expect(watchListId).toBe(v5('lists/watch', listsNamespace));
  });

  it('match the fixture the phone reads', () => {
    const fixture = JSON.parse(
      readFileSync(new URL('../fixtures/built-in-lists.json', import.meta.url), 'utf8'),
    ) as { namespace: string; lists: unknown[]; stampedAt: string };
    expect(fixture.namespace).toBe(listsNamespace);
    expect(fixture.lists).toEqual(builtInLists.map((list) => ({ ...list })));
    expect(fixture.stampedAt).toBe(builtInListsStampedAt);
  });

  it('are two shopping lists and two media lists, and valid rows', () => {
    expect(builtInLists.map((list) => [list.key, list.kind])).toEqual([
      ['buy', 'shopping'],
      ['wish', 'shopping'],
      ['read', 'media'],
      ['watch', 'media'],
    ]);
    for (const list of builtInLists) {
      const row = {
        uuid: list.uuid,
        name: list.name,
        kind: list.kind,
        icon: null,
        position: list.position,
        builtIn: list.key,
        createdAt: builtInListsStampedAt,
        updatedAt: builtInListsStampedAt,
        deletedAt: null,
      };
      expect(tables.lists.data.safeParse(row).success).toBe(true);
    }
    expect(builtInListOf(readListId)?.key).toBe('read');
    expect(builtInListOf('someone-else')).toBeUndefined();
  });
});

describe('an item from before lists', () => {
  const item = {
    uuid: '6c3a1f4e-9b2d-4e8a-9f1c-3d7b5a2e8c64',
    list: 'buy',
    title: 'Winter coat',
    priceMinor: 1800000,
    currency: 'DZD',
    note: null,
    targetDay: null,
    boughtAt: null,
    position: 0,
    createdAt: '2026-09-20T10:10:00.000Z',
    updatedAt: '2026-09-20T10:15:00.000Z',
    deletedAt: null,
  };

  it('parses with every new column null', () => {
    const parsed = tables.wishlist_items.data.parse(item);
    expect(parsed).toMatchObject({
      listUuid: null,
      mediaType: null,
      link: null,
      creator: null,
      startedAt: null,
      rating: null,
      seedUuid: null,
      noteUuid: null,
    });
  });

  it('belongs to the shopping list its old column names', () => {
    expect(listUuidOfItem(item)).toBe(buyListId);
    expect(listUuidOfItem({ ...item, list: 'wish' })).toBe(wishListId);
    expect(listUuidOfItem({ ...item, listUuid: readListId })).toBe(readListId);
    expect(legacyListOf(buyListId)).toBe('buy');
    expect(legacyListOf(readListId)).toBe('wish');
  });

  it('still refuses a rating out of range and an unknown media type', () => {
    expect(tables.wishlist_items.data.safeParse({ ...item, rating: 6 }).success).toBe(false);
    expect(tables.wishlist_items.data.safeParse({ ...item, rating: 0 }).success).toBe(false);
    expect(tables.wishlist_items.data.safeParse({ ...item, mediaType: 'comic' }).success).toBe(false);
  });
});
