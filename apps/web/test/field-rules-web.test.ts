import { HarvestDay } from '@harvest/core';
import { builtInLists } from '@harvest/contracts';
import { describe, expect, it } from 'vitest';
import { notePath, safeFileName } from '@/app/data/archive';
import { fairShare } from '@/app/components/search-dialog';
import { loadField } from '@/app/data/field';
import { notesFor, notesOn } from '@/app/data/seed-notes';
import { settleGoalParents } from '@/app/data/goals';
import { boundsOf, readDay } from '@/app/data/places';
import { fetchPool } from '@/app/hooks';
import { shortcutKey } from '@/app/shortcuts';
import { loadGoals } from '@/app/data/goal-views';
import { loadListsView, readPlannedPurchases } from '@/app/data/list-views';
import { FakeServer } from './fake-server';
import { device } from './helpers';

const today = HarvestDay.parse('2026-09-19');
const buy = builtInLists.find((list) => list.key === 'buy')!.uuid;
const wish = builtInLists.find((list) => list.key === 'wish')!.uuid;

/** The shared Field, Goals and Lists rules as the web writes them ([[Audit-v3]]). */
describe('streaks judged across a gap (Q5-02)', () => {
  it('a check-in after missed days starts the run again', async () => {
    const h = await device(new FakeServer());
    await h.db.rows('streaks').put({
      scope: 'global',
      current: 5,
      best: 5,
      lastEarnedDay: today.addDays(-3).key,
      freezesStored: 0,
      updatedAt: new Date().toISOString(),
    });
    for (const title of ['a', 'b', 'c']) {
      const seed = await h.seeds.plant({ type: 'habit', title, schedule: { type: 'daily' } });
      await h.checkIns.checkIn(seed, today);
    }
    expect(await h.db.rows('streaks').get('global')).toMatchObject({ current: 1, best: 5, lastEarnedDay: today.key });
  });

  it("a habit's own streak starts again after a missed due day", async () => {
    const h = await device(new FakeServer());
    const seed = await h.seeds.plant({ type: 'habit', title: 'Walk', schedule: { type: 'daily' } });
    await h.db.rows('streaks').put({
      scope: seed.uuid,
      current: 4,
      best: 4,
      lastEarnedDay: today.addDays(-3).key,
      freezesStored: 0,
      updatedAt: new Date().toISOString(),
    });
    await h.checkIns.checkIn(seed, today);
    expect(await h.db.rows('streaks').get(seed.uuid)).toMatchObject({ current: 1, best: 4 });
  });
});

describe('streak milestones (Q5-29)', () => {
  it('an undo and a new check-in do not pay the seventh day again', async () => {
    const h = await device(new FakeServer());
    await h.db.rows('streaks').put({
      scope: 'global',
      current: 6,
      best: 6,
      lastEarnedDay: today.previous.key,
      freezesStored: 0,
      updatedAt: new Date().toISOString(),
    });
    const seeds = [];
    for (const title of ['a', 'b', 'c']) {
      seeds.push(await h.seeds.plant({ type: 'habit', title, schedule: { type: 'daily' } }));
    }
    for (const seed of seeds) await h.checkIns.checkIn(seed, today);
    await h.checkIns.undo(seeds[0]!, today);
    await h.checkIns.checkIn((await h.db.rows('commitments').get(seeds[0]!.uuid))!, today);
    const coins = (await h.db.rows('ledger').toArray()).filter((row) => row.kind === 'coin');
    expect(coins.map((row) => row.reason)).toEqual(['streak:7']);
  });
});

describe('a planted task undone (Q5-43)', () => {
  it('takes back only the ticks the check-in gave', async () => {
    const h = await device(new FakeServer());
    const goal = await h.goals.create({ title: 'Race' });
    const task = await h.goals.addItem(goal.uuid, 'Run a 10 km race');
    const find = (await h.goals.addSubtask(task.uuid, 'Find a race'))!;
    const register = (await h.goals.addSubtask(task.uuid, 'Register'))!;
    await h.goals.setDone(find.uuid, true);
    h.clock.advance(60_000);
    const seed = await h.seeds.plant({ type: 'todo', title: 'Run', goalUuid: goal.uuid }, task.uuid);
    await h.checkIns.checkIn(seed, today);
    expect((await h.db.rows('goal_items').get(register.uuid))?.doneAt).not.toBeNull();

    await h.checkIns.undo(seed, today);
    expect((await h.db.rows('goal_items').get(find.uuid))?.doneAt).not.toBeNull();
    expect((await h.db.rows('goal_items').get(register.uuid))?.doneAt).toBeNull();
    expect((await h.db.rows('goal_items').get(task.uuid))?.doneAt).toBeNull();
  });
});

describe('a parent left behind by a pull (Q5-44)', () => {
  it('is settled again', async () => {
    const h = await device(new FakeServer());
    const goal = await h.goals.create({ title: 'Race' });
    const task = await h.goals.addItem(goal.uuid, 'Run');
    const sub = (await h.goals.addSubtask(task.uuid, 'Register'))!;
    await h.goals.setDone(sub.uuid, true);
    expect((await h.db.rows('goal_items').get(task.uuid))?.doneAt).not.toBeNull();
    // A pulled row reopened the subtask, written on its own.
    await h.db.rows('goal_items').update(sub.uuid, { doneAt: null });
    await settleGoalParents(h.writer);
    expect((await h.db.rows('goal_items').get(task.uuid))?.doneAt).toBeNull();
  });
});

describe('a subtask restored under a parent that became a subtask (G5-08)', () => {
  it('comes back as an item of its own', async () => {
    const h = await device(new FakeServer());
    const goal = await h.goals.create({ title: 'Race' });
    const p = await h.goals.addItem(goal.uuid, 'P');
    const q = await h.goals.addItem(goal.uuid, 'Q');
    const s = (await h.goals.addSubtask(p.uuid, 'S'))!;
    await h.goals.deleteItem(s.uuid);
    expect(await h.goals.nestItem(p.uuid, q.uuid)).toBe(true);
    await h.goals.restoreItem(s.uuid);
    expect((await h.db.rows('goal_items').get(s.uuid))?.parentUuid).toBeNull();
    const view = (await loadGoals(h.db)).find((entry) => entry.goal.uuid === goal.uuid)!;
    expect(view.steps.map((item) => item.body)).toContain('S');
  });
});

describe('lists', () => {
  it('a bought item moved to the Wishlist is a wish again (Q5-45)', async () => {
    const h = await device(new FakeServer());
    await h.lists.ensureBuiltIns();
    const coat = await h.lists.addItem(buy, { title: 'Coat' });
    await h.lists.setDone(coat.uuid, true);
    expect(await h.lists.moveItem(coat.uuid, wish)).toBe(true);
    expect((await h.db.rows('wishlist_items').get(coat.uuid))?.boughtAt).toBeNull();
  });

  it('planned purchases leave the Wishlist out, by the shared rule (G5-01)', async () => {
    const h = await device(new FakeServer());
    await h.lists.ensureBuiltIns();
    await h.lists.addItem(buy, { title: 'Kettle', priceMinor: 85000, currency: 'DZD' });
    await h.lists.addItem(wish, { title: 'Espresso machine', priceMinor: 1800000, currency: 'DZD' });
    expect(await readPlannedPurchases(h.db)).toEqual([['DZD', 85000]]);
  });

  it('an item whose seed is archived offers to finish it too (G5-07)', async () => {
    const h = await device(new FakeServer());
    await h.lists.ensureBuiltIns();
    const item = await h.lists.addItem(buy, { title: 'Kettle' });
    const seed = await h.seeds.plant({ type: 'todo', title: 'Kettle' });
    await h.lists.linkSeed(item.uuid, seed.uuid);
    await h.db.rows('commitments').update(seed.uuid, { archivedAt: new Date().toISOString() });
    expect((await loadListsView(h.db)).seeds.get(seed.uuid)?.complete).toBe(true);
  });
});

describe('archive names and cells (Q5-59)', () => {
  it('Ideas and ideas do not land on one file', () => {
    const taken = new Set<string>();
    expect(notePath({ title: 'Ideas', folder: '', taken })).toBe('notes/Ideas.md');
    expect(notePath({ title: 'ideas', folder: '', taken })).toBe('notes/ideas (2).md');
  });

  it('a name loses its control characters, trailing dots and reserved words', () => {
    expect(safeFileName('a\u0001b')).toBe('ab');
    expect(safeFileName('Notes...')).toBe('Notes');
    expect(safeFileName('con')).toBe('con_');
  });
});

describe('the map frames a month of trail (Q5-32)', () => {
  it('without spreading every point into one call', () => {
    const spots = Array.from({ length: 200_000 }, (_, i) => [3 + i / 1e6, 36 + i / 1e6] as const);
    expect(boundsOf(spots)).toEqual([
      [3, 36],
      [3 + 199_999 / 1e6, 36 + 199_999 / 1e6],
    ]);
    expect(boundsOf([])).toBeNull();
  });
});

describe('a night at home across 3 AM (Q5-58)', () => {
  it('is a stay on both days, each its own part', async () => {
    const h = await device(new FakeServer());
    const point = (day: string, at: Date, latitude: number) => ({
      uuid: crypto.randomUUID(),
      harvestDay: day,
      recordedAt: at.toISOString(),
      latitude,
      longitude: 3.06,
      accuracyM: 10,
      speedMps: null,
      altitudeM: null,
      updatedAt: at.toISOString(),
      deletedAt: null,
    });
    const evening = today.previous;
    await h.db.rows('location_points').bulkPut([
      point(evening.key, new Date(evening.year, evening.month - 1, evening.day, 12), 36.7),
      point(evening.key, new Date(evening.year, evening.month - 1, evening.day, 19), 36.75),
      point(today.key, new Date(today.year, today.month - 1, today.day, 8), 36.7501),
      point(today.key, new Date(today.year, today.month - 1, today.day, 9), 36.8),
    ]);
    const night = await readDay(h.db, evening);
    const morning = await readDay(h.db, today);
    expect(night.stays.map((stay) => stay.lengthMs / 60_000)).toEqual([8 * 60]);
    expect(morning.stays.map((stay) => stay.lengthMs / 60_000)).toEqual([5 * 60]);
  });
});

describe('shortcuts on an Arabic keyboard (Q5-37)', () => {
  it('read the key by its place when it is not a Latin one', () => {
    expect(shortcutKey({ key: 'ى', code: 'KeyN', shiftKey: false })).toBe('n');
    expect(shortcutKey({ key: 'ث', code: 'KeyE', shiftKey: false })).toBe('e');
    expect(shortcutKey({ key: 'ظ', code: 'Slash', shiftKey: false })).toBe('/');
    expect(shortcutKey({ key: '؟', code: 'Slash', shiftKey: true })).toBe('?');
    expect(shortcutKey({ key: 'N', code: 'KeyN', shiftKey: true })).toBe('n');
    expect(shortcutKey({ key: 'Escape', code: 'Escape', shiftKey: false })).toBe('Escape');
  });
});

describe('search results (Q5-52)', () => {
  it('give every kind its share before one kind takes the rest', () => {
    const seeds = Array.from({ length: 40 }, (_, i) => `seed${i}`);
    const hits = fairShare([seeds, ['goal'], ['note1', 'note2']], 30);
    expect(hits).toHaveLength(30);
    expect(hits).toContain('note2');
    expect(hits).toContain('goal');
    expect(hits.slice(0, 27)).toEqual(seeds.slice(0, 27));
  });
});

describe('the field reads what it needs (Q5-31)', () => {
  it('keeps its lifetime numbers right as the ledger grows and check-ins come and go', async () => {
    const h = await device(new FakeServer());
    const book = await h.seeds.plant({ type: 'project', title: 'Read', totalTarget: 300, dailyCommitment: 10 });
    await h.checkIns.checkIn(book, today.addDays(-20), 10);
    let view = await loadField(h.db, today);
    expect(view.today.find((seed) => seed.row.uuid === book.uuid)?.total).toBe(10);
    expect(view.totalXp).toBe(20);
    expect(view.dayXp).toBe(0);

    await h.checkIns.checkIn(book, today, 5);
    view = await loadField(h.db, today);
    expect(view.today.find((seed) => seed.row.uuid === book.uuid)).toMatchObject({ total: 15, today: 5 });
    expect(view.totalXp).toBe(30);
    expect(view.dayXp).toBe(10);
  });
});

describe('the gallery asks for files a few at a time (Q5-32)', () => {
  it('never runs more than the pool at once, and runs them all', async () => {
    const pool = fetchPool(5);
    let running = 0;
    let most = 0;
    const done = await Promise.all(
      Array.from({ length: 40 }, (_, i) =>
        pool(async () => {
          running++;
          most = Math.max(most, running);
          await new Promise((resolve) => setTimeout(resolve, 1));
          running--;
          return i;
        }),
      ),
    );
    expect(most).toBe(5);
    expect(done).toEqual(Array.from({ length: 40 }, (_, i) => i));
  });
});

describe('one note per seed-day (Q6-07)', () => {
  it('reads the newest of two, and folds them on the next write', async () => {
    const h = await device(new FakeServer());
    const seed = await h.seeds.plant({ type: 'habit', title: 'Read', schedule: { type: 'daily' } });
    const row = (uuid: string, body: string, at: string) => ({
      uuid,
      commitmentUuid: seed.uuid,
      harvestDay: today.key,
      body,
      loggedAt: at,
      deletedAt: null,
      updatedAt: at,
    });
    await h.db.rows('seed_notes').bulkPut([
      row('a', 'from the phone', '2026-09-19T10:00:00.000Z'),
      row('b', 'from the web', '2026-09-19T11:00:00.000Z'),
    ]);
    expect((await notesOn(h.db, today)).get(seed.uuid)).toBe('from the web');
    expect(await notesFor(h.db, seed.uuid)).toHaveLength(1);

    await h.seedNotes.write(seed.uuid, today, 'both');
    const rows = (await h.db.rows('seed_notes').toArray()).filter((r) => r.deletedAt === null);
    expect(rows.map((r) => [r.uuid, r.body])).toEqual([['b', 'both']]);
  });
});

describe('achieving then deleting a goal (U6-04)', () => {
  it('takes the XP back, and an undo pays it again', async () => {
    const h = await device(new FakeServer());
    const goal = await h.goals.create({ title: 'Farm' });
    const net = async () =>
      (await h.db.rows('ledger').toArray())
        .filter((row) => row.kind === 'xp' && row.reason.endsWith(goal.uuid))
        .reduce((sum, row) => sum + row.delta, 0);
    await h.goals.achieve(goal.uuid);
    expect(await net()).toBe(50);
    await h.goals.delete(goal.uuid);
    expect(await net()).toBe(0);
    await h.goals.restore(goal.uuid);
    expect(await net()).toBe(50);
    await h.goals.delete(goal.uuid);
    await h.goals.delete(goal.uuid);
    expect(await net()).toBe(0);
  });
});
