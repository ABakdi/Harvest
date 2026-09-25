import Dexie from 'dexie';
import { describe, expect, it } from 'vitest';
import { HarvestDB, tableSchemas } from '@/app/data/db';
import { SavedPlaceRepository } from '@/app/data/places';
import { FakeServer } from './fake-server';
import { device } from './helpers';

describe('the wishlist order', () => {
  it('a moved item joins the bottom of the other list, as on the phone (W4)', async () => {
    const h = await device(new FakeServer());
    const kettle = await h.wishlist.add({ list: 'buy', title: 'Kettle' });
    const bread = await h.wishlist.add({ list: 'buy', title: 'Bread' });
    const coat = await h.wishlist.add({ list: 'wish', title: 'Winter coat' });
    expect(coat.position).toBe(0);

    await h.wishlist.move(coat.uuid, 'buy');
    const buy = (await h.db.rows('wishlist_items').toArray())
      .filter((row) => row.list === 'buy')
      .sort((a, b) => a.position - b.position);
    expect(buy.map((row) => row.uuid)).toEqual([kettle.uuid, bread.uuid, coat.uuid]);
    expect(buy.at(-1)?.position).toBe(2);
  });

  it('moving to the list it is already on changes nothing', async () => {
    const h = await device(new FakeServer());
    const kettle = await h.wishlist.add({ list: 'buy', title: 'Kettle' });
    const before = await h.db.rows('wishlist_items').get(kettle.uuid);
    await h.wishlist.move(kettle.uuid, 'buy');
    expect(await h.db.rows('wishlist_items').get(kettle.uuid)).toEqual(before);
  });
});

describe('the browser store', () => {
  it('adds the wishlist to a store opened before it existed, keeping what was there', async () => {
    const name = `upgrade-${Date.now()}`;
    // The store as the first release left it: versions 1 and 2, no wishlist.
    const old = new Dexie(name);
    const { wishlist_items: _wishlist, ...firstTables } = tableSchemas;
    old.version(1).stores({
      ...firstTables,
      outbox: '++seq, [table+key], table',
      meta: 'key',
      sealed: '[table+uuid], table',
    });
    old.version(2).stores({ files: 'sha256' });
    await old.open();
    await old.table('meta').put({ key: 'kept', value: 42 });
    old.close();

    const db = new HarvestDB(name);
    await db.open();
    expect(db.verno).toBe(3);
    expect(await db.meta.get('kept')).toEqual({ key: 'kept', value: 42 });
    await db.rows('wishlist_items').put({
      uuid: 'coat',
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
    });
    expect(await db.rows('wishlist_items').count()).toBe(1);
    db.close();
  });
});

describe('a saved place kept from before notes existed', () => {
  it('still edits, and reads as having no notes', async () => {
    const h = await device(new FakeServer());
    // As a v3.0.0-beta.1 pull left it in the store: no notes key at all.
    await h.db.table('saved_places').put({
      uuid: 'home',
      name: 'Home',
      latitude: 36.7538,
      longitude: 3.0588,
      radiusM: 100,
      createdAt: '2026-09-10T20:00:00.000Z',
      updatedAt: '2026-09-10T20:00:00.000Z',
      deletedAt: null,
    });

    await new SavedPlaceRepository(h.writer).update('home', { name: 'Home, sweet' });
    expect(await h.db.rows('saved_places').get('home')).toMatchObject({ name: 'Home, sweet', notes: null });
  });
});
