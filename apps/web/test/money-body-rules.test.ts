import { HarvestDay } from '@harvest/core';
import { describe, expect, it } from 'vitest';
import { exerciseHistory, readProgram, readSession } from '@/app/data/gym';
import { atMinutes, readNights, stepsHistory, type StepRow } from '@/app/data/health';
import { settingKeys, readSetting } from '@/app/data/settings';
import { monthRange, readInsights, readVault } from '@/app/data/vault';
import { FakeServer } from './fake-server';
import { device } from './helpers';

/**
 * The money and body rules the phone already holds, now held here too
 * ([[Audit-v3]] Q5-17, Q5-20, Q5-39, Q5-47, Q5-48, Q5-67, G5-02, G5-03,
 * G5-04).
 */

type Device = Awaited<ReturnType<typeof device>>;

async function walletBalance(h: Device, currency = 'DZD') {
  return (await h.db.rows('money_txns').toArray())
    .filter((row) => row.account === 'wallet' && row.deletedAt === null && row.currency === currency)
    .reduce((sum, row) => sum + row.deltaMinor, 0);
}

async function xp(h: Device) {
  return (await h.db.rows('ledger').toArray()).reduce((sum, row) => sum + row.delta, 0);
}

const debtInput = {
  person: 'Sami',
  currency: 'DZD',
  payOffBy: null,
  remindAt: null,
  note: null,
};

describe('the Undo of a removed payment (Q5-17)', () => {
  it('is refused when the debt was paid again meanwhile', async () => {
    const h = await device(new FakeServer());
    const debt = await h.vault.createDebt({
      ...debtInput,
      amountMinor: 1000_00,
    });
    const first = await h.vault.payDebt(debt, 1000_00, false, null);
    await h.vault.removePayment(first);
    await h.vault.payDebt(debt, 1000_00, false, null);
    await expect(h.vault.restorePayment(first)).rejects.toMatchObject({
      rule: 'overpay',
    });
    const view = (await readVault(h.db)).debts[0]!;
    expect(view.paidMinor).toBe(1000_00);
  });

  it('is refused when the wallet no longer holds it', async () => {
    const h = await device(new FakeServer());
    await h.vault.moveWallet(1000_00, 'DZD', null);
    const debt = await h.vault.createDebt({
      ...debtInput,
      amountMinor: 5000_00,
    });
    const payment = await h.vault.payDebt(debt, 1000_00, true, null);
    await h.vault.removePayment(payment);
    expect(await walletBalance(h)).toBe(1000_00);
    await h.vault.moveWallet(-1000_00, 'DZD', null);
    await expect(h.vault.restorePayment(payment)).rejects.toMatchObject({
      rule: 'overdraw',
    });
    expect(await walletBalance(h)).toBe(0);
  });

  it('still brings back the payment and its movement when nothing moved', async () => {
    const h = await device(new FakeServer());
    await h.vault.moveWallet(1000_00, 'DZD', null);
    const debt = await h.vault.createDebt({
      ...debtInput,
      amountMinor: 5000_00,
    });
    const payment = await h.vault.payDebt(debt, 400_00, true, null);
    await h.vault.removePayment(payment);
    await h.vault.restorePayment(payment);
    expect(await walletBalance(h)).toBe(600_00);
    expect((await readVault(h.db)).debts[0]!.paidMinor).toBe(400_00);
  });
});

describe('a debt can be corrected and removed (G5-02)', () => {
  it('an edit changes it, and settles or reopens it', async () => {
    const h = await device(new FakeServer());
    const debt = await h.vault.createDebt({
      ...debtInput,
      person: 'Samy',
      amountMinor: 5000_00,
    });
    await h.vault.payDebt(debt, 3000_00, false, null);
    await h.vault.updateDebt(debt, {
      ...debtInput,
      person: ' Sami ',
      amountMinor: 3000_00,
      remindAt: '20:30',
      note: 'lunch',
    });
    let row = (await h.db.rows('debts').get(debt))!;
    expect(row).toMatchObject({
      person: 'Sami',
      amountMinor: 3000_00,
      remindAt: '20:30',
      note: 'lunch',
    });
    expect(row.settledAt).not.toBeNull();
    await h.vault.updateDebt(debt, { ...debtInput, amountMinor: 4000_00 });
    row = (await h.db.rows('debts').get(debt))!;
    expect(row.settledAt).toBeNull();
  });

  it('refuses less than was paid, and a new currency under payments', async () => {
    const h = await device(new FakeServer());
    const debt = await h.vault.createDebt({
      ...debtInput,
      amountMinor: 5000_00,
    });
    await h.vault.payDebt(debt, 3000_00, false, null);
    await expect(h.vault.updateDebt(debt, { ...debtInput, amountMinor: 2999_99 })).rejects.toMatchObject({ rule: 'belowPaid' });
    await expect(
      h.vault.updateDebt(debt, {
        ...debtInput,
        amountMinor: 5000_00,
        currency: 'EUR',
      }),
    ).rejects.toMatchObject({
      rule: 'currency',
    });
  });

  it('removing takes its payments along, and Undo brings back just those', async () => {
    const h = await device(new FakeServer());
    await h.vault.moveWallet(5000_00, 'DZD', null);
    const debt = await h.vault.createDebt({
      ...debtInput,
      amountMinor: 5000_00,
    });
    await h.vault.payDebt(debt, 1000_00, true, null);
    h.clock.advance(1000);
    const alone = await h.vault.payDebt(debt, 500_00, false, null);
    h.clock.advance(1000);
    // One removed on its own earlier stays removed.
    await h.vault.removePayment(alone);
    h.clock.advance(1000);
    await h.vault.deleteDebt(debt);
    expect((await readVault(h.db)).debts).toHaveLength(0);
    // The money that left the wallet stays gone.
    expect(await walletBalance(h)).toBe(4000_00);
    await h.vault.restoreDebt(debt);
    const view = (await readVault(h.db)).debts[0]!;
    expect(view.paidMinor).toBe(1000_00);
    expect(await walletBalance(h)).toBe(4000_00);
  });
});

describe('Insights count up to today (G5-03)', () => {
  it('leaves out an expense logged ahead', async () => {
    const h = await device(new FakeServer());
    const today = HarvestDay.parse('2026-09-19');
    await h.money.log({
      amountMinor: 15_00,
      currency: 'DZD',
      category: 'food',
      note: null,
      day: today.key,
      fromWallet: false,
    });
    await h.money.log({
      amountMinor: 900_00,
      currency: 'DZD',
      category: 'bills',
      note: null,
      day: today.addDays(3).key,
      fromWallet: false,
    });
    const view = await readInsights(h.db, monthRange(today), today);
    expect(view.total).toBe(15_00);
    expect(view.byCategory).toEqual([['food', 15_00]]);
    expect([...view.dayTotals.keys()]).toEqual([today.key]);
  });
});

describe('logging ahead (Q5-67)', () => {
  it('pays no XP for a day still to come, and pays once it is moved to today', async () => {
    const h = await device(new FakeServer());
    const input = {
      amountMinor: 5_00,
      currency: 'DZD',
      category: 'bills',
      note: null,
      fromWallet: false,
    };
    const uuid = await h.money.log({ ...input, day: '2026-09-29' });
    expect(await xp(h)).toBe(0);
    await h.money.update(uuid, { ...input, day: '2026-09-19' });
    expect(await xp(h)).toBe(10);
  });
});

describe('the default currency carries the budget (G5-04)', () => {
  it('converts at the stored rate, and keeps the number without one', async () => {
    const h = await device(new FakeServer());
    await h.settings.setMany({
      'rate.dzdPerEur': '250',
      [settingKeys.monthlyBudget]: '5000000',
    });
    await h.settings.setDefaultCurrency('EUR');
    expect(await readSetting(h.db, settingKeys.defaultCurrency)).toBe('EUR');
    expect(await readSetting(h.db, settingKeys.monthlyBudget)).toBe('20000');
    // No EUR→USD rate: the number stays.
    await h.settings.setDefaultCurrency('USD');
    expect(await readSetting(h.db, settingKeys.monthlyBudget)).toBe('20000');
  });
});

describe('the body', () => {
  it('draws the last 14 days, a gap as a zero (Q5-47)', () => {
    const today = HarvestDay.parse('2026-09-19');
    const row = (harvestDay: string, steps: number) => ({ harvestDay, steps }) as StepRow;
    const history = stepsHistory([row(today.addDays(-20).key, 900), row(today.addDays(-3).key, 4000), row(today.addDays(-1).key, 1200)], today)!;
    expect(history.bars).toHaveLength(14);
    expect(history.bars[0]!.harvestDay).toBe(today.addDays(-13).key);
    expect(history.bars[13]!.harvestDay).toBe(today.key);
    expect(history.bars.map((bar) => bar.steps).filter((steps) => steps > 0)).toEqual([4000, 1200]);
  });

  it('reads one night per morning, the newer, and a new log pays it once (Q5-20)', async () => {
    const h = await device(new FakeServer());
    const morning = HarvestDay.parse('2026-09-19');
    const night = {
      day: morning,
      fellAsleepAt: atMinutes(morning, -60),
      wokeAt: atMinutes(morning, 7 * 60),
      targetMinutes: 480,
      restedStars: null,
    };
    await h.health.logNight(night);
    const first = (await readNights(h.db))[0]!;
    // Another device's night for the same morning, arrived by sync, with its own XP.
    await h.db.rows('sleep_sessions').put({ ...first, uuid: 'web', updatedAt: '2026-09-19T13:00:00.000Z' });
    await h.db.rows('ledger').put({
      ...(await h.db.rows('ledger').toArray())[0]!,
      uuid: 'xp-web',
      reason: 'sleep:web',
    });
    expect((await readNights(h.db)).map((row) => row.uuid)).toEqual(['web']);
    const paid = await xp(h);
    h.clock.advance(3_600_000);
    await h.health.logNight({ ...night, restedStars: 4 });
    const live = (await h.db.rows('sleep_sessions').toArray()).filter((row) => row.deletedAt === null);
    expect(live).toHaveLength(1);
    expect(live[0]!.restedStars).toBe(4);
    expect(await xp(h)).toBe(paid / 2);
  });
});

describe('the gym', () => {
  async function aProgram(h: Device) {
    const program = await h.programs.createProgram('nSuns');
    const day = await h.programs.addDay(program.uuid, 'Day 1');
    const slot = await h.programs.addSlot(day.uuid, '0047');
    await h.programs.addTargetSet(slot.uuid, {
      reps: 5,
      weightGrams: 60_000,
      percentTenths: null,
      openEnded: false,
    });
    return (await readProgram(h.db, program.uuid))!;
  }

  it('a second Finish changes nothing (Q5-39)', async () => {
    const h = await device(new FakeServer());
    const tree = await aProgram(h);
    const { session } = await h.sessions.start({
      day: tree.days[0]!,
      programUuid: tree.program.uuid,
      trainingMaxes: new Map(),
    });
    await h.sessions.finish(session.session.uuid);
    const ended = (await readSession(h.db, session.session.uuid))!.session.endedAt;
    h.clock.advance(60_000);
    const again = await h.sessions.finish(session.session.uuid);
    expect(again.xpEarned).toBe(0);
    expect((await readSession(h.db, session.session.uuid))!.session.endedAt).toBe(ended);
  });

  it('a history of 1 is one outing that logged a set, not an empty one (Q5-48)', async () => {
    const h = await device(new FakeServer());
    const tree = await aProgram(h);
    const run = async (done: boolean) => {
      const { session } = await h.sessions.start({
        day: tree.days[0]!,
        programUuid: tree.program.uuid,
        trainingMaxes: new Map(),
      });
      const set = (await readSession(h.db, session.session.uuid))!.exercises[0]!.sets[0]!;
      if (done)
        await h.sessions.logSet(set.uuid, {
          weightGrams: 60_000,
          reps: 5,
          done: true,
        });
      await h.sessions.finish(session.session.uuid);
      h.clock.advance(86_400_000);
    };
    await run(true);
    await run(false);
    const history = await exerciseHistory(h.db, '0047', 1);
    expect(history.map((outing) => outing.day)).toEqual(['2026-09-19']);
  });
});
