import { describe, expect, it } from 'vitest';
import { readCategories } from '@/app/data/categories';
import { FakeServer } from './fake-server';
import { device } from './helpers';

/**
 * Custom categories are listed by when each was made, as the phone
 * lists them. A restore bumps `updatedAt` so the undo syncs, and must
 * not move the category to the end of the list for it.
 */
describe('the order of custom categories', () => {
  it('keeps a deleted and restored category where it was', async () => {
    const h = await device(new FakeServer());
    const books = await h.categories.create('Books', 'school');
    h.clock.advance(1000);
    await h.categories.create('Coffee', 'coffee');
    h.clock.advance(1000);
    await h.categories.create('Gifts', 'gift');
    h.clock.advance(1000);

    await h.categories.remove(books);
    h.clock.advance(1000);
    await h.categories.restore(books);

    const rows = await readCategories(h.db);
    expect(rows.map((row) => row.name)).toEqual(['Books', 'Coffee', 'Gifts']);
    // The restore is still an edit the other devices hear about.
    const restored = rows[0]!;
    expect(restored.createdAt).toBe('2026-09-19T12:00:00.000Z');
    expect(restored.updatedAt).toBe('2026-09-19T12:00:04.000Z');
  });

  it('orders a category from before createdAt by its last edit', async () => {
    const h = await device(new FakeServer());
    h.clock.advance(60_000);
    await h.categories.create('Coffee', 'coffee');
    await h.db.rows('expense_categories').put({
      uuid: 'old',
      name: 'Books',
      icon: 'school',
      createdAt: null,
      deletedAt: null,
      updatedAt: '2026-09-19T12:00:30.000Z',
    });

    expect((await readCategories(h.db)).map((row) => row.name)).toEqual(['Books', 'Coffee']);
  });
});
