import { HarvestDay } from '@harvest/core';
import { describe, expect, it } from 'vitest';
import { FakeServer } from './fake-server';
import { device } from './helpers';

/**
 * Both caps are one rule from `@harvest/core` (`roomToday`): twice the
 * daily commitment on a day, and never past the total target.
 */
describe('a project log', () => {
  it('stops at what is left of the target, and says it was cut', async () => {
    const h = await device(new FakeServer());
    const today = HarvestDay.parse('2026-09-19');
    const seed = await h.seeds.plant({ type: 'project', title: 'Book', totalTarget: 100, dailyCommitment: 10 });
    for (let back = 9; back >= 1; back--) await h.checkIns.checkIn(seed, today.addDays(-back), 10);
    const plan = await h.checkIns.checkIn(seed, today, 20);
    expect(plan).toEqual({ quantityLogged: 10, xpEarned: 20, capped: true });
    const after = await h.checkIns.checkIn(seed, today, 1);
    expect(after.quantityLogged).toBe(0);
  });

  it('stops at twice the commitment on one day', async () => {
    const h = await device(new FakeServer());
    const seed = await h.seeds.plant({ type: 'project', title: 'Book', totalTarget: 1000, dailyCommitment: 10 });
    const plan = await h.checkIns.checkIn(seed, HarvestDay.parse('2026-09-19'), 30);
    expect(plan).toEqual({ quantityLogged: 20, xpEarned: 40, capped: true });
  });
});
