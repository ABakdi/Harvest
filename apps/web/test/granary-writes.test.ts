import { HarvestDay } from '@harvest/core';
import { describe, expect, it } from 'vitest';
import { categoryNameProblem, readCategories } from '@/app/data/categories';
import { readRepeatSuggestion } from '@/app/data/money';
import {
  MoneyRuleError,
  elapsedDays,
  matchesFilter,
  monthRange,
  readInsights,
  readVault,
  weekRange,
  type TxnRow,
} from '@/app/data/vault';
import { FakeServer } from './fake-server';
import { device } from './helpers';

/**
 * The Granary's writes from the browser, row for row what the phone's
 * VaultRepository and FinanceActions write ([[Finances]] The Vault):
 * every movement a `money_txns` row with its kind, reference and link,
 * and the guards that keep a pot from going below zero or a debt from
 * being overpaid.
 */

type Device = Awaited<ReturnType<typeof device>>;

async function live(h: Device, account?: string) {
  return (await h.db.rows('money_txns').toArray()).filter((row) => row.deletedAt === null && (!account || row.account === account));
}

async function balance(h: Device, account: string, currency = 'DZD') {
  return (await live(h, account)).filter((row) => row.currency === currency).reduce((sum, row) => sum + row.deltaMinor, 0);
}

describe('the wallet and savings', () => {
  it('adds and takes, and refuses to take more than the wallet holds', async () => {
    const h = await device(new FakeServer());
    await h.vault.moveWallet(500_00, 'DZD', 'salary');
    await h.vault.moveWallet(-120_00, 'DZD', null);
    expect(await balance(h, 'wallet')).toBe(380_00);
    const rows = await live(h, 'wallet');
    expect(rows.every((row) => row.kind === 'manual' && row.harvestDay === '2026-09-19')).toBe(true);

    await expect(h.vault.moveWallet(-381_00, 'DZD', null)).rejects.toBeInstanceOf(MoneyRuleError);
    // Money in one currency cannot pay for another.
    await expect(h.vault.moveWallet(-1_00, 'USD', null)).rejects.toMatchObject({ rule: 'overdraw' });
    expect(await balance(h, 'wallet')).toBe(380_00);
    expect((await h.db.outbox.toArray()).filter((entry) => entry.table === 'money_txns')).toHaveLength(2);
  });

  it('saves from the wallet as a transfer, and new money as a single row', async () => {
    const h = await device(new FakeServer());
    await h.vault.moveWallet(300_00, 'DZD', null);
    await h.vault.depositSavings(100_00, 'DZD', true, 'rainy day');
    await h.vault.depositSavings(50_00, 'DZD', false, null);

    expect(await balance(h, 'wallet')).toBe(200_00);
    expect(await balance(h, 'savings')).toBe(150_00);
    const transfers = (await live(h)).filter((row) => row.kind === 'transfer');
    expect(transfers.map((row) => [row.account, row.deltaMinor, row.reference, row.note]).sort()).toEqual([
      ['savings', 100_00, 'wallet', 'rainy day'],
      ['wallet', -100_00, 'savings', 'rainy day'],
    ]);
    await expect(h.vault.depositSavings(201_00, 'DZD', true, null)).rejects.toMatchObject({ rule: 'overdraw' });
  });

  it('withdraws savings into the wallet, never past what the pot holds', async () => {
    const h = await device(new FakeServer());
    await h.vault.depositSavings(80_00, 'EUR', false, null);
    await h.vault.withdrawSavings(30_00, 'EUR', null);
    expect(await balance(h, 'savings', 'EUR')).toBe(50_00);
    expect(await balance(h, 'wallet', 'EUR')).toBe(30_00);
    await expect(h.vault.withdrawSavings(50_01, 'EUR', null)).rejects.toMatchObject({ rule: 'overdraw' });
    await expect(h.vault.withdrawSavings(0, 'EUR', null)).rejects.toMatchObject({ rule: 'amount' });
  });

  it('removes a hand-made movement with undo, and leaves the others to their owners', async () => {
    const h = await device(new FakeServer());
    const uuid = await h.vault.moveWallet(40_00, 'DZD', null);
    await h.money.log({ amountMinor: 10_00, currency: 'DZD', category: 'food', note: null, day: '2026-09-19', fromWallet: true });
    const spare = await h.vault.moveWallet(5_00, 'DZD', null);
    expect(await h.vault.removeMove(spare)).toBe(true);
    expect(await balance(h, 'wallet')).toBe(30_00);
    await h.vault.restoreMove(spare);
    expect(await balance(h, 'wallet')).toBe(35_00);
    // The 40 has been spent in part: taking it back would leave the
    // wallet below zero.
    await expect(h.vault.removeMove(uuid)).rejects.toMatchObject({ rule: 'overdraw' });

    const expenseMove = (await live(h, 'wallet')).find((row) => row.kind === 'expense')!;
    expect(await h.vault.removeMove(expenseMove.uuid)).toBe(false);
  });
});

describe('debts', () => {
  async function withDebt() {
    const h = await device(new FakeServer());
    await h.vault.moveWallet(1_000_00, 'DZD', null);
    const uuid = await h.vault.createDebt({
      person: ' Sami ',
      amountMinor: 300_00,
      currency: 'DZD',
      payOffBy: '2026-10-01',
      remindAt: '9:05',
      note: null,
    });
    return { h, uuid };
  }

  it('pays in parts, from the wallet when asked, and settles when fully paid', async () => {
    const { h, uuid } = await withDebt();
    expect((await h.db.rows('debts').get(uuid))?.person).toBe('Sami');

    const first = await h.vault.payDebt(uuid, 100_00, true, 'first half');
    await h.vault.payDebt(uuid, 50_00, false, null);
    const debt = (await readVault(h.db)).debts[0]!;
    expect([debt.paidMinor, debt.leftMinor, debt.debt.settledAt]).toEqual([150_00, 150_00, null]);
    // Only the wallet-funded payment left the wallet, linked to it.
    const moved = (await live(h, 'wallet')).filter((row) => row.kind === 'debt');
    expect(moved).toHaveLength(1);
    expect(moved[0]).toMatchObject({ deltaMinor: -100_00, reference: 'Sami', linkUuid: first, note: 'first half' });

    await expect(h.vault.payDebt(uuid, 150_01, false, null)).rejects.toMatchObject({ rule: 'overpay' });
    await h.vault.payDebt(uuid, 150_00, false, null);
    expect((await h.db.rows('debts').get(uuid))?.settledAt).not.toBeNull();
    await expect(h.vault.payDebt(uuid, 1_00, false, null)).rejects.toMatchObject({ rule: 'settled' });
  });

  it('removing a payment refunds the wallet and reopens the debt; undo puts both back', async () => {
    const { h, uuid } = await withDebt();
    const payment = await h.vault.payDebt(uuid, 300_00, true, null);
    expect((await h.db.rows('debts').get(uuid))?.settledAt).not.toBeNull();
    expect(await balance(h, 'wallet')).toBe(700_00);

    await h.vault.removePayment(payment);
    expect((await h.db.rows('debts').get(uuid))?.settledAt).toBeNull();
    expect(await balance(h, 'wallet')).toBe(1_000_00);

    await h.vault.restorePayment(payment);
    expect((await h.db.rows('debts').get(uuid))?.settledAt).not.toBeNull();
    expect(await balance(h, 'wallet')).toBe(700_00);
  });

  it('will not pay from a wallet that cannot cover it', async () => {
    const { h, uuid } = await withDebt();
    await h.vault.moveWallet(-950_00, 'DZD', null);
    await expect(h.vault.payDebt(uuid, 100_00, true, null)).rejects.toMatchObject({ rule: 'overdraw' });
    expect(await h.db.rows('debt_payments').count()).toBe(0);
  });
});

describe('expenses and categories', () => {
  it('moves the wallet movement with the expense when its day changes', async () => {
    const h = await device(new FakeServer());
    const uuid = await h.money.log({ amountMinor: 12_00, currency: 'DZD', category: 'food', note: null, day: '2026-09-19', fromWallet: true });
    await h.money.update(uuid, { amountMinor: 15_00, currency: 'DZD', category: 'food', note: 'lunch', day: '2026-09-17', fromWallet: true });
    const move = (await live(h, 'wallet'))[0]!;
    expect(move).toMatchObject({ deltaMinor: -15_00, harvestDay: '2026-09-17', note: 'lunch', linkUuid: uuid });
  });

  it('suggests day four of the same thing three days running, until it is logged', async () => {
    const h = await device(new FakeServer());
    const today = HarvestDay.parse('2026-09-19');
    for (const day of ['2026-09-16', '2026-09-17', '2026-09-18']) {
      await h.money.log({ amountMinor: 150_00, currency: 'DZD', category: 'food', note: 'coffee', day, fromWallet: false });
    }
    expect(await readRepeatSuggestion(h.db, today)).toEqual({ amountMinor: 150_00, currency: 'DZD', category: 'food', note: 'coffee' });
    await h.money.log({ amountMinor: 150_00, currency: 'DZD', category: 'food', note: null, day: today.key, fromWallet: false });
    expect(await readRepeatSuggestion(h.db, today)).toBeNull();
    // Two days is not a habit.
    expect(await readRepeatSuggestion(h.db, HarvestDay.parse('2026-09-18'))).toBeNull();
  });

  it('creates and removes custom categories, with undo, and refuses a name twice', async () => {
    const h = await device(new FakeServer());
    const uuid = await h.categories.create(' Coffee ', 'coffee');
    let rows = await readCategories(h.db);
    expect(rows.map((row) => [row.name, row.icon])).toEqual([['Coffee', 'coffee']]);
    expect(categoryNameProblem('coffee', rows)).toBe('taken');
    expect(categoryNameProblem('Food', rows)).toBe('taken');
    expect(categoryNameProblem('  ', rows)).toBe('empty');
    expect(categoryNameProblem('Books', rows)).toBeNull();

    await h.categories.remove(uuid);
    expect(await readCategories(h.db)).toEqual([]);
    await h.categories.restore(uuid);
    rows = await readCategories(h.db);
    expect(rows).toHaveLength(1);
    expect((await h.db.outbox.toArray()).filter((entry) => entry.table === 'expense_categories')).toHaveLength(3);
  });
});

describe('insights', () => {
  const today = HarvestDay.parse('2026-09-19');

  it('spans the week and the month, and averages over the days that have happened', () => {
    const week = weekRange(today);
    expect(elapsedDays(week, today)).toBe(today.weekStart.daysUntil(today) + 1);
    const month = monthRange(today);
    expect([month.from.key, month.to.key]).toEqual(['2026-09-01', '2026-09-30']);
    expect(elapsedDays(month, today)).toBe(19);
    expect(elapsedDays({ kind: 'custom', from: today.next, to: today.addDays(3) }, today)).toBe(0);
  });

  it('adds the span up per day and per category, and lists its moves', async () => {
    const h = await device(new FakeServer());
    await h.money.log({ amountMinor: 100_00, currency: 'DZD', category: 'food', note: null, day: '2026-09-02', fromWallet: false });
    await h.money.log({ amountMinor: 40_00, currency: 'DZD', category: 'transport', note: null, day: '2026-09-19', fromWallet: false });
    await h.money.log({ amountMinor: 999_00, currency: 'DZD', category: 'food', note: null, day: '2026-08-31', fromWallet: false });
    await h.vault.moveWallet(10_00, 'DZD', 'found it');

    const view = await readInsights(h.db, monthRange(today));
    expect(view.total).toBe(140_00);
    expect(view.byCategory).toEqual([
      ['food', 100_00],
      ['transport', 40_00],
    ]);
    expect(view.dayTotals.get('2026-09-19')).toBe(40_00);
    expect(view.moves).toHaveLength(1);
  });

  it('filters moves by form, category and a word in the note or reference', () => {
    const row = (kind: string, reference: string | null, note: string | null) => ({ kind, reference, note }) as TxnRow;
    const food = row('expense', 'food', 'bread');
    const sami = row('debt', 'Sami', null);
    const added = row('manual', null, 'salary');
    const none = { kinds: [], categories: [], query: '' };
    expect([food, sami, added].every((one) => matchesFilter(none, one))).toBe(true);
    expect(matchesFilter({ ...none, kinds: ['debt'] }, sami)).toBe(true);
    expect(matchesFilter({ ...none, kinds: ['debt'] }, food)).toBe(false);
    // A category narrows to expenses by construction.
    expect(matchesFilter({ ...none, categories: ['food'] }, food)).toBe(true);
    expect(matchesFilter({ ...none, categories: ['food'] }, added)).toBe(false);
    expect(matchesFilter({ ...none, query: 'sam' }, sami)).toBe(true);
    expect(matchesFilter({ ...none, query: ' SALARY ' }, added)).toBe(true);
    expect(matchesFilter({ ...none, query: 'rent' }, added)).toBe(false);
  });
});
