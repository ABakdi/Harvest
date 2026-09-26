import { buyListId, readListId, watchListId, wishListId, builtInListsStampedAt, tables } from '@harvest/contracts';
import Dexie from 'dexie';
import { describe, expect, it } from 'vitest';
import { HarvestDB, listsFeatureKey, tableSchemas } from '@/app/data/db';
import { hasDefaultName, itemsOfList, liveLists, openCounts } from '@/app/data/lists';
import { FakeServer } from './fake-server';
import { device } from './helpers';

/** Phase 6, M6.12: the data under Lists ([[Lists]] L1–L10), as the phone keeps it. */

describe('lists are rows (L1, L10)', () => {
  it('a fresh store has the four built-ins, queued for nothing', async () => {
    const h = await device(new FakeServer());
    const lists = await liveLists(h.db);
    expect(lists.map((list) => list.uuid)).toEqual([buyListId, wishListId, readListId, watchListId]);
    expect(lists.map((list) => list.kind)).toEqual(['shopping', 'shopping', 'media', 'media']);
    expect(lists.every(hasDefaultName)).toBe(true);
    expect(lists[0]!.updatedAt).toBe(builtInListsStampedAt);
    expect(await h.db.outbox.count()).toBe(0);
  });

  it('seeding again never undoes a rename', async () => {
    const h = await device(new FakeServer());
    await h.lists.renameList(readListId, 'Reading pile');
    await h.lists.ensureBuiltIns();
    const read = (await h.db.rows('lists').get(readListId))!;
    expect(read.name).toBe('Reading pile');
    expect(hasDefaultName(read)).toBe(false);
    expect(await h.db.rows('lists').count()).toBe(4);
  });

  it('a list I make joins the end; lists reorder', async () => {
    const h = await device(new FakeServer());
    const packing = await h.lists.createList({ name: ' Packing ', kind: 'plain', icon: 'luggage' });
    expect(packing).toMatchObject({ name: 'Packing', position: 4, builtIn: null });
    await h.lists.reorderLists([packing.uuid, buyListId, wishListId, readListId, watchListId]);
    expect((await liveLists(h.db))[0]!.uuid).toBe(packing.uuid);
    expect((await h.db.outbox.toArray()).filter((row) => row.table === 'lists')).toHaveLength(6);
  });
});

describe("a list's kind decides its items' fields (L2)", () => {
  it('keeps a media item’s link and drops a shopping estimate', async () => {
    const h = await device(new FakeServer());
    const dune = await h.lists.addItem(readListId, {
      title: ' Dune ',
      mediaType: 'book',
      link: 'https://example.com/dune',
      creator: 'Frank Herbert',
      priceMinor: 250_000,
      targetDay: '2026-10-01',
    });
    expect(dune).toMatchObject({
      title: 'Dune',
      list: 'wish',
      listUuid: readListId,
      mediaType: 'book',
      creator: 'Frank Herbert',
      priceMinor: null,
      targetDay: null,
    });
    const coat = await h.lists.addItem(buyListId, { title: 'Coat', priceMinor: 100, link: 'https://x' });
    expect(coat).toMatchObject({ list: 'buy', priceMinor: 100, link: null });
  });

  it('moves between lists of the same kind only, joining the bottom', async () => {
    const h = await device(new FakeServer());
    const dune = await h.lists.addItem(readListId, { title: 'Dune' });
    await h.lists.addItem(watchListId, { title: 'Arrival' });
    expect(await h.lists.moveItem(dune.uuid, buyListId)).toBe(false);
    expect(await h.lists.moveItem(dune.uuid, readListId)).toBe(false);
    expect(await h.lists.moveItem(dune.uuid, watchListId)).toBe(true);
    const watch = await itemsOfList(h.db, watchListId);
    expect(watch.map((row) => row.title)).toEqual(['Arrival', 'Dune']);
    expect(watch[1]!.position).toBe(1);
  });

  it('reads an item from before lists by its old column', async () => {
    const h = await device(new FakeServer());
    await h.wishlist.add({ list: 'wish', title: 'Lamp' });
    await h.db.table('wishlist_items').put({
      uuid: 'old',
      list: 'buy',
      title: 'Kettle',
      priceMinor: null,
      currency: 'DZD',
      note: null,
      targetDay: null,
      boughtAt: null,
      position: 0,
      createdAt: '2026-09-01T10:00:00.000Z',
      updatedAt: '2026-09-01T10:00:00.000Z',
      deletedAt: null,
    });
    expect((await itemsOfList(h.db, buyListId)).map((row) => row.uuid)).toEqual(['old']);
    expect((await h.lists.addItem(buyListId, { title: 'Bread' })).position).toBe(1);
    expect((await openCounts(h.db)).get(buyListId)).toBe(2);
  });
});

describe('done, started, rated (L4, L7, L8)', () => {
  it('a wish is not bought where it is; To buy is where things get bought', async () => {
    const h = await device(new FakeServer());
    const machine = await h.wishlist.add({ list: 'wish', title: 'Espresso machine', priceMinor: 540_000 });
    expect(await h.lists.setDone(machine.uuid, true)).toBe(false);
    await h.wishlist.move(machine.uuid, 'buy');
    expect(await h.lists.setDone(machine.uuid, true)).toBe(true);
    // A stamp, not a transaction: nothing in the ledger or the wallet.
    expect(await h.db.rows('ledger').count()).toBe(0);
    expect(await h.db.rows('money_txns').count()).toBe(0);
    expect(await h.db.rows('expenses').count()).toBe(0);
  });

  it('media: want, in progress, finished and rated', async () => {
    const h = await device(new FakeServer());
    const dune = await h.lists.addItem(readListId, { title: 'Dune' });
    expect(await h.lists.setStarted(dune.uuid, true)).toBe(true);
    await h.lists.setDone(dune.uuid, true);
    expect(await h.lists.setRating(dune.uuid, 4)).toBe(true);
    await expect(h.lists.setRating(dune.uuid, 6)).rejects.toThrow(RangeError);
    expect(await h.lists.setLink(dune.uuid, '  ')).toBe(true);
    expect(await h.lists.setCreator(dune.uuid, 'Frank Herbert')).toBe(true);
    expect(await h.lists.setMediaType(dune.uuid, 'book')).toBe(true);
    await h.lists.linkSeed(dune.uuid, 'seed-1');
    await h.lists.linkNote(dune.uuid, 'note-1');
    const row = (await h.db.rows('wishlist_items').get(dune.uuid))!;
    expect(row).toMatchObject({ rating: 4, link: null, creator: 'Frank Herbert', mediaType: 'book', seedUuid: 'seed-1', noteUuid: 'note-1' });
    expect(row.startedAt).not.toBeNull();
    expect(row.boughtAt).not.toBeNull();
    expect(await h.db.rows('ledger').count()).toBe(0);
  });

  it('only media items start, rate or carry a link', async () => {
    const h = await device(new FakeServer());
    const coat = await h.lists.addItem(buyListId, { title: 'Coat' });
    expect(await h.lists.setStarted(coat.uuid, true)).toBe(false);
    expect(await h.lists.setRating(coat.uuid, 3)).toBe(false);
    expect(await h.lists.setLink(coat.uuid, 'https://x')).toBe(false);
  });
});

describe('deletion (L6, L10)', () => {
  it('a built-in list is not deleted', async () => {
    const h = await device(new FakeServer());
    expect(await h.lists.deleteList(readListId)).toBe(false);
    expect(await liveLists(h.db)).toHaveLength(4);
  });

  it('a list takes its items to the trash and brings back exactly those', async () => {
    const h = await device(new FakeServer());
    const packing = await h.lists.createList({ name: 'Packing', kind: 'plain' });
    const socks = await h.lists.addItem(packing.uuid, { title: 'Socks' });
    const hat = await h.lists.addItem(packing.uuid, { title: 'Hat' });
    await h.lists.deleteItem(hat.uuid);
    h.clock.advance(1000);

    expect(await h.lists.deleteList(packing.uuid)).toBe(true);
    expect((await liveLists(h.db)).map((list) => list.uuid)).not.toContain(packing.uuid);
    expect(await itemsOfList(h.db, packing.uuid)).toEqual([]);
    await expect(h.lists.addItem(packing.uuid, { title: 'Scarf' })).rejects.toThrow();

    await h.lists.restoreList(packing.uuid);
    expect((await itemsOfList(h.db, packing.uuid)).map((row) => row.uuid)).toEqual([socks.uuid]);
  });

  it('purge hard-deletes old trash and never a built-in', async () => {
    const h = await device(new FakeServer());
    const packing = await h.lists.createList({ name: 'Packing', kind: 'plain' });
    await h.lists.addItem(packing.uuid, { title: 'Socks' });
    await h.lists.deleteList(packing.uuid);
    h.clock.advance(40 * 86_400_000);
    await h.lists.purgeDeleted(30 * 86_400_000);
    expect(await h.db.rows('wishlist_items').count()).toBe(0);
    expect(await h.db.rows('lists').count()).toBe(4);
  });
});

describe('sync', () => {
  it('two devices share the built-ins, and a rename wins over a late seed', async () => {
    const server = new FakeServer();
    const a = await device(server);
    await a.lists.renameList(readListId, 'Reading pile');
    const dune = await a.lists.addItem(readListId, { title: 'Dune', mediaType: 'book' });
    await a.engine.sync();

    const b = await device(server);
    await b.engine.sync();
    expect(await b.db.rows('lists').count()).toBe(4);
    expect((await b.db.rows('lists').get(readListId))!.name).toBe('Reading pile');
    expect((await itemsOfList(b.db, readListId)).map((row) => row.uuid)).toEqual([dune.uuid]);
    // Every row the server holds is one the contract takes.
    for (const record of server.stored.values()) {
      if (record.table === 'lists') expect(tables.lists.data.safeParse(record.data).success).toBe(true);
    }
  });
});

describe('the browser store', () => {
  it('upgrades a v3 wishlist into the built-in lists and turns Lists on', async () => {
    const name = `lists-upgrade-${Date.now()}`;
    const old = new Dexie(name);
    const { wishlist_items: wishlistItems, lists: _lists, ...firstTables } = tableSchemas;
    old.version(1).stores({ ...firstTables, outbox: '++seq, [table+key], table', meta: 'key', sealed: '[table+uuid], table' });
    old.version(2).stores({ files: 'sha256' });
    old.version(3).stores({ wishlist_items: wishlistItems });
    await old.open();
    const row = {
      list: 'buy',
      title: 'Winter coat',
      priceMinor: null,
      currency: 'DZD',
      note: null,
      targetDay: null,
      boughtAt: null,
      position: 0,
      createdAt: '2026-09-19T12:00:00.000Z',
      updatedAt: '2026-09-19T12:00:00.000Z',
      deletedAt: null,
    };
    await old.table('wishlist_items').bulkPut([
      { ...row, uuid: 'coat' },
      { ...row, uuid: 'lamp', list: 'wish', title: 'Lamp' },
    ]);
    old.close();

    const db = new HarvestDB(name);
    await db.open();
    expect(db.verno).toBe(4);
    expect(await db.rows('lists').count()).toBe(4);
    const coat = (await db.rows('wishlist_items').get('coat'))!;
    expect(coat).toMatchObject({ listUuid: buyListId, mediaType: null, rating: null });
    // A local rewrite, not an edit.
    expect(coat.updatedAt).toBe(row.updatedAt);
    expect(tables.wishlist_items.data.safeParse(coat).success).toBe(true);
    expect((await db.rows('wishlist_items').get('lamp'))!.listUuid).toBe(wishListId);
    expect((await db.rows('kv_settings').get(listsFeatureKey))?.valueJson).toBe('"true"');
    expect((await db.outbox.toArray()).map((entry) => [entry.table, entry.key])).toEqual([['kv_settings', listsFeatureKey]]);
    db.close();
  });

  it('leaves Lists off for someone who kept no Wishlist', async () => {
    const name = `lists-empty-${Date.now()}`;
    const old = new Dexie(name);
    const { wishlist_items: wishlistItems, lists: _lists, ...firstTables } = tableSchemas;
    old.version(1).stores({ ...firstTables, outbox: '++seq, [table+key], table', meta: 'key', sealed: '[table+uuid], table' });
    old.version(2).stores({ files: 'sha256' });
    old.version(3).stores({ wishlist_items: wishlistItems });
    await old.open();
    old.close();

    const db = new HarvestDB(name);
    await db.open();
    expect(await db.rows('kv_settings').get(listsFeatureKey)).toBeUndefined();
    expect(await db.rows('lists').count()).toBe(4);
    db.close();
  });
});
