import { HarvestDay } from '@harvest/core';
import { describe, expect, it } from 'vitest';
import { FakeServer } from './fake-server';
import { device } from './helpers';

const today = HarvestDay.parse('2026-09-19');

async function ledger(h: Awaited<ReturnType<typeof device>>) {
  return (await h.db.rows('ledger').toArray()).sort((a, b) => a.loggedAt.localeCompare(b.loggedAt));
}

describe('check-ins', () => {
  it('caps a project at twice its daily commitment, and pays per unit', async () => {
    const h = await device(new FakeServer());
    const seed = await h.seeds.plant({ type: 'project', title: 'Read', totalTarget: 300, dailyCommitment: 5 });

    expect(await h.checkIns.checkIn(seed, today, 7)).toEqual({ quantityLogged: 7, xpEarned: 14, capped: false });
    h.clock.advance(1000);
    expect(await h.checkIns.checkIn(seed, today, 5)).toEqual({ quantityLogged: 3, xpEarned: 6, capped: true });
    expect(await h.checkIns.checkIn(seed, today, 1)).toEqual({ quantityLogged: 0, xpEarned: 0, capped: true });

    const checkIns = await h.db.rows('check_ins').toArray();
    expect(checkIns.map((row) => row.quantity).sort()).toEqual([3, 7]);
    const entries = await ledger(h);
    expect(entries.map((entry) => entry.delta)).toEqual([14, 6]);
    expect(entries.every((entry) => entry.reason.startsWith('checkin:'))).toBe(true);
  });

  it('takes a habit once a day, and an undo mirrors its XP', async () => {
    const h = await device(new FakeServer());
    const seed = await h.seeds.plant({ type: 'habit', title: 'Walk', schedule: { type: 'daily' } });

    expect((await h.checkIns.checkIn(seed, today)).quantityLogged).toBe(1);
    expect((await h.checkIns.checkIn(seed, today)).quantityLogged).toBe(0);
    expect((await h.db.rows('streaks').get(seed.uuid))?.current).toBe(1);

    h.clock.advance(1000);
    await h.checkIns.undo(seed, today);
    const [row] = await h.db.rows('check_ins').toArray();
    expect(row?.deletedAt).not.toBeNull();
    const entries = await ledger(h);
    expect(entries.map((entry) => entry.reason)).toEqual([`checkin:${row!.uuid}`, `undo:${row!.uuid}`]);
    expect(entries.reduce((sum, entry) => sum + entry.delta, 0)).toBe(0);
    expect((await h.db.rows('streaks').get(seed.uuid))?.current).toBe(0);
  });

  it('earns the global streak at the daily goal, and gives it back on undo', async () => {
    const h = await device(new FakeServer());
    const seeds = await Promise.all(
      ['One', 'Two', 'Three'].map((title) => h.seeds.plant({ type: 'habit', title, schedule: { type: 'daily' } })),
    );
    for (const seed of seeds.slice(0, 2)) await h.checkIns.checkIn(seed, today);
    expect(await h.db.rows('streaks').get('global')).toBeUndefined();

    await h.checkIns.checkIn(seeds[2]!, today);
    expect(await h.db.rows('streaks').get('global')).toMatchObject({ current: 1, best: 1, lastEarnedDay: today.key });

    await h.checkIns.undo(seeds[0]!, today);
    expect(await h.db.rows('streaks').get('global')).toMatchObject({ current: 0, best: 1, lastEarnedDay: null });
  });

  it('ticks and un-ticks the goal item a to-do was planted from', async () => {
    const h = await device(new FakeServer());
    const goal = await h.goals.create({ title: 'Half marathon' });
    const item = await h.goals.addItem(goal.uuid, 'Buy shoes');
    const seed = await h.seeds.plant({ type: 'todo', title: 'Buy shoes', goalUuid: goal.uuid }, item.uuid);
    expect((await h.db.rows('goal_items').get(item.uuid))?.commitmentUuid).toBe(seed.uuid);

    await h.checkIns.checkIn(seed, today);
    expect((await h.db.rows('goal_items').get(item.uuid))?.doneAt).not.toBeNull();
    await h.checkIns.undo(seed, today);
    expect((await h.db.rows('goal_items').get(item.uuid))?.doneAt).toBeNull();
  });
});

describe('goals', () => {
  it('pays +50 once for achieving, and takes it back with a mirror row on reopen', async () => {
    const h = await device(new FakeServer());
    const goal = await h.goals.create({ title: 'Learn calligraphy' });

    const achieve = (uuid: string) => h.goals.achieve(uuid);
    const reopen = (uuid: string) => h.goals.reopen(uuid);
    for (const step of [achieve, achieve, reopen, achieve]) {
      await step(goal.uuid);
      h.clock.advance(1000);
    }

    const entries = await ledger(h);
    expect(entries.map((entry) => [entry.reason, entry.delta])).toEqual([
      [`goal:${goal.uuid}`, 50],
      [`goal-undo:${goal.uuid}`, -50],
      [`goal:${goal.uuid}`, 50],
    ]);
    expect(await h.db.rows('goals').get(goal.uuid)).toMatchObject({ status: 'achieved' });
  });

  it('deletes a goal with its items, and restores only those', async () => {
    const h = await device(new FakeServer());
    const goal = await h.goals.create({ title: 'Car' });
    const kept = await h.goals.addItem(goal.uuid, 'Save');
    const gone = await h.goals.addItem(goal.uuid, 'Old idea');
    await h.goals.deleteItem(gone.uuid);
    h.clock.advance(1000);

    await h.goals.delete(goal.uuid);
    expect((await h.db.rows('goal_items').get(kept.uuid))?.deletedAt).not.toBeNull();
    await h.goals.restore(goal.uuid);
    expect((await h.db.rows('goal_items').get(kept.uuid))?.deletedAt).toBeNull();
    expect((await h.db.rows('goal_items').get(gone.uuid))?.deletedAt).not.toBeNull();
  });
});

describe('expenses', () => {
  const input = { amountMinor: 45_000, currency: 'DZD', category: 'food', note: null, fromWallet: false };

  it('pays the day once, moves the pay with the expense, and mirrors it when the last one goes', async () => {
    const h = await device(new FakeServer());
    const first = await h.money.log({ ...input, day: '2026-09-18' });
    h.clock.advance(1000);
    const second = await h.money.log({ ...input, day: '2026-09-18' });
    h.clock.advance(1000);
    expect((await ledger(h)).map((e) => [e.reason, e.delta])).toEqual([['expenses:2026-09-18', 10]]);

    await h.money.update(second, { ...input, day: '2026-09-19' });
    expect((await ledger(h)).map((e) => [e.reason, e.delta])).toEqual([
      ['expenses:2026-09-18', 10],
      ['expenses:2026-09-19', 10],
    ]);

    h.clock.advance(1000);
    await h.money.remove(first);
    h.clock.advance(1000);
    expect((await ledger(h)).map((e) => [e.reason, e.delta]).at(-1)).toEqual(['expenses-undo:2026-09-18', -10]);

    h.clock.advance(1000);
    await h.money.restore(first);
    expect((await ledger(h)).map((e) => [e.reason, e.delta]).at(-1)).toEqual(['expenses:2026-09-18', 10]);
  });

  it('keeps a wallet-paid expense and its movement in step', async () => {
    const h = await device(new FakeServer());
    const uuid = await h.money.log({ ...input, fromWallet: true, day: '2026-09-19' });
    const [move] = await h.db.rows('money_txns').toArray();
    expect(move).toMatchObject({ account: 'wallet', deltaMinor: -45_000, kind: 'expense', linkUuid: uuid });

    await h.money.update(uuid, { ...input, amountMinor: 50_000, fromWallet: true, day: '2026-09-19' });
    expect((await h.db.rows('money_txns').get(move!.uuid))?.deltaMinor).toBe(-50_000);

    await h.money.remove(uuid);
    expect((await h.db.rows('money_txns').get(move!.uuid))?.deletedAt).not.toBeNull();
  });
});

describe('the outbox', () => {
  it('queues every write with its row, and keeps device settings home', async () => {
    const h = await device(new FakeServer());
    await h.seeds.plant({ type: 'todo', title: 'Call the dentist' });
    await h.settings.setString('dailyHarvestGoal', '4');
    await h.settings.setString('streak.lastJudgedDay', '2026-09-18');

    const tables = (await h.db.outbox.toArray()).map((entry) => entry.table);
    expect(tables).toEqual(['commitments', 'kv_settings']);
  });
});
