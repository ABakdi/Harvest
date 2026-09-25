import { fireEvent, render, screen } from '@testing-library/react';
import { MemoryRouter } from 'react-router';
import { describe, expect, it } from 'vitest';
import { HarvestContext } from '@/app/context';
import { readBudget, readVault } from '@/app/data/vault';
import { BudgetPanel } from '@/app/screens/budget';
import { VaultPanel } from '@/app/screens/vault';
import { HarvestDay } from '@harvest/core';
import { FakeServer } from './fake-server';
import { device } from './helpers';

const today = HarvestDay.parse('2026-09-19');

async function withMoney() {
  const h = await device(new FakeServer());
  const txn = (uuid: string, account: string, deltaMinor: number, currency = 'DZD', kind = 'manual') => ({
    uuid,
    account,
    deltaMinor,
    currency,
    note: null,
    kind,
    reference: null,
    linkUuid: null,
    harvestDay: '2026-09-18',
    loggedAt: `2026-09-18T1${uuid.length}:00:00.000Z`,
    deletedAt: null,
    updatedAt: '',
  });
  await h.db.rows('money_txns').bulkPut([
    txn('t1', 'wallet', 500_00),
    txn('t2', 'wallet', -120_00, 'DZD', 'expense'),
    txn('t3', 'savings', 1_000_00),
    txn('t4', 'wallet', 50_00, 'USD'),
    // A deleted movement is not money.
    { ...txn('t5', 'wallet', 9_999_00), deletedAt: '2026-09-18T12:00:00.000Z' },
  ]);
  await h.db.rows('debts').put({
    uuid: 'd1',
    person: 'Amine',
    amountMinor: 200_00,
    currency: 'DZD',
    payOffBy: '2026-10-01',
    remindAt: null,
    note: null,
    settledAt: null,
    createdAt: '',
    deletedAt: null,
    updatedAt: '',
  });
  await h.db.rows('debt_payments').put({
    uuid: 'p1',
    debtUuid: 'd1',
    amountMinor: 50_00,
    harvestDay: '2026-09-18',
    loggedAt: '2026-09-18T12:00:00.000Z',
    deletedAt: null,
  });
  return h;
}

describe('the vault', () => {
  it('sums each pot per currency, and never across them', async () => {
    const h = await withMoney();
    const vault = await readVault(h.db);
    const wallet = vault.pots.find((pot) => pot.account === 'wallet')!;
    expect(wallet.balances).toEqual([
      ['DZD', 380_00],
      ['USD', 50_00],
    ]);
    expect(vault.pots.find((pot) => pot.account === 'savings')?.balances).toEqual([['DZD', 1_000_00]]);
  });

  it('counts what a debt has left, and says so on screen', async () => {
    const h = await withMoney();
    const vault = await readVault(h.db);
    expect(vault.debts[0]?.leftMinor).toBe(150_00);

    render(
      <HarvestContext.Provider value={h}>
        <MemoryRouter>
          <VaultPanel />
        </MemoryRouter>
      </HarvestContext.Provider>,
    );
    // Debts are their own section, chosen from the Owed tile.
    fireEvent.click(await screen.findByRole('button', { name: /Owed/ }));
    expect(await screen.findByText('Amine')).toBeInTheDocument();
    // Three times over: what this debt has left, the section's balance
    // per currency, and the Owed tile, which is every unsettled debt
    // converted into the default currency.
    expect(screen.getAllByText('DA150')).toHaveLength(3);
    expect(screen.getByText('DA50 of DA200 paid')).toBeInTheDocument();
  });
});

describe('the budget', () => {
  it('floats the daily limit over the days that are left', async () => {
    const h = await withMoney();
    await h.db.rows('kv_settings').put({ key: 'finance.monthlyBudgetMinor', valueJson: '"30000"', updatedAt: '' });
    await h.db.rows('expenses').bulkPut([
      { uuid: 'e1', amountMinor: 100_00, currency: 'DZD', category: 'food', note: null, harvestDay: '2026-09-10', loggedAt: '', deletedAt: null, updatedAt: '' },
      { uuid: 'e2', amountMinor: 20_00, currency: 'DZD', category: 'transport', note: null, harvestDay: '2026-09-19', loggedAt: '', deletedAt: null, updatedAt: '' },
    ]);

    const budget = await readBudget(h.db, today);
    expect(budget.spentThisMonth).toBe(120_00);
    // 300 budgeted, 100 gone before today, 200 left over the 12 days
    // from the 19th to the 30th.
    expect(budget.snapshot?.floatingDailyLimit).toBe(Math.trunc(200_00 / 12));
    expect(budget.byCategory[0]).toEqual(['food', 100_00]);
  });

  it('says what to do when no budget is set', async () => {
    const h = await withMoney();
    render(
      <HarvestContext.Provider value={h}>
        <BudgetPanel />
      </HarvestContext.Provider>,
    );
    expect(await screen.findByText('No monthly budget set')).toBeInTheDocument();
  });
});
