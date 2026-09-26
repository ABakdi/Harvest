import { buyListId } from '@harvest/contracts';
import { HarvestDay } from '@harvest/core';
import { fireEvent, render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import type { ReactNode } from 'react';
import { MemoryRouter } from 'react-router';
import { describe, expect, it } from 'vitest';
import { ExpenseEditor } from '@/app/components/expense-editor';
import { ListItemEditor } from '@/app/components/list-item-editor';
import { HarvestContext } from '@/app/context';
import { DialogsProvider } from '@/app/dialogs';
import { readBudget, readVault } from '@/app/data/vault';
import { BudgetPanel } from '@/app/screens/budget';
import { GranaryScreen } from '@/app/screens/granary';
import { FakeServer } from './fake-server';
import { device, testUser } from './helpers';

// Radix's switch measures itself; jsdom has nothing to measure with.
globalThis.ResizeObserver ??= class {
  observe() {}
  unobserve() {}
  disconnect() {}
};

/**
 * The money guards: no pot below zero whichever way a row comes and
 * goes, one wallet movement per expense, and the amounts, days and
 * currencies the phone's sheets would take ([[Finances]]).
 */

type Device = Awaited<ReturnType<typeof device>>;

const today = HarvestDay.parse('2026-09-19');

function show(h: Device, ui: ReactNode) {
  return render(
    <HarvestContext.Provider value={h}>
      <MemoryRouter>
        <DialogsProvider>{ui}</DialogsProvider>
      </MemoryRouter>
    </HarvestContext.Provider>,
  );
}

async function unlocked() {
  const h = await device(new FakeServer());
  await h.keyring.unlock('a long passphrase', testUser.syncSalt, 1);
  return h;
}

async function walletBalance(h: Device, currency = 'DZD') {
  return (await h.db.rows('money_txns').toArray())
    .filter((row) => row.account === 'wallet' && row.deletedAt === null && row.currency === currency)
    .reduce((sum, row) => sum + row.deltaMinor, 0);
}

async function linkedRows(h: Device, expenseUuid: string) {
  return (await h.db.rows('money_txns').toArray()).filter((row) => row.linkUuid === expenseUuid);
}

describe('a pot never goes below zero', () => {
  it('refuses to take back a deposit that has been spent', async () => {
    const h = await device(new FakeServer());
    const deposit = await h.vault.moveWallet(100_00, 'DZD', null);
    await h.vault.moveWallet(-80_00, 'DZD', null);
    await expect(h.vault.removeMove(deposit)).rejects.toMatchObject({ rule: 'overdraw' });
    expect(await walletBalance(h)).toBe(20_00);
  });

  it('refuses to bring back a withdrawal the pot no longer holds', async () => {
    const h = await device(new FakeServer());
    await h.vault.moveWallet(100_00, 'DZD', null);
    const withdrawal = await h.vault.moveWallet(-80_00, 'DZD', null);
    expect(await h.vault.removeMove(withdrawal)).toBe(true);
    await h.vault.moveWallet(-50_00, 'DZD', null);
    await expect(h.vault.restoreMove(withdrawal)).rejects.toMatchObject({ rule: 'overdraw' });
    expect(await walletBalance(h)).toBe(50_00);
    // A deposit's undo is always welcome.
    const deposit = await h.vault.moveWallet(10_00, 'DZD', null);
    await h.vault.removeMove(deposit);
    await h.vault.restoreMove(deposit);
    expect(await walletBalance(h)).toBe(60_00);
  });
});

describe('the expense editor', () => {
  it('a category made from it does not log the expense', async () => {
    const h = await unlocked();
    let closed = false;
    show(h, <ExpenseEditor expense={null} onClose={() => (closed = true)} />);
    await userEvent.type(await screen.findByLabelText('Amount'), '5');
    await userEvent.click(screen.getByRole('button', { name: 'New category' }));
    const name = await screen.findByLabelText('Category name');
    await userEvent.type(name, 'Books');
    await userEvent.click(within(name.closest('[role="dialog"]') as HTMLElement).getByRole('button', { name: 'Save' }));

    await waitFor(async () => expect(await h.db.rows('expense_categories').count()).toBe(1));
    expect(await h.db.rows('expenses').count()).toBe(0);
    expect(closed).toBe(false);
    expect(await screen.findByRole('radio', { name: 'Books', checked: true })).toBeInTheDocument();
  });

  it('never pays from a wallet that cannot cover the amount', async () => {
    const h = await unlocked();
    await h.vault.moveWallet(100_00, 'DZD', null);
    show(h, <ExpenseEditor expense={null} onClose={() => {}} />);
    const amount = await screen.findByLabelText('Amount');
    await userEvent.type(amount, '50');
    const wallet = screen.getByRole('switch', { name: 'From the wallet' });
    await waitFor(() => expect(wallet).toBeChecked());
    // Chosen by hand, then the amount outgrows the wallet.
    await userEvent.click(wallet);
    await userEvent.click(wallet);
    expect(wallet).toBeChecked();
    await userEvent.type(amount, '0');
    expect(wallet).not.toBeChecked();
    expect(wallet).toBeDisabled();
    await userEvent.click(screen.getByRole('button', { name: 'Log it' }));

    await waitFor(async () => expect(await h.db.rows('expenses').count()).toBe(1));
    expect(await walletBalance(h)).toBe(100_00);
  });

  it('an edit counts what the expense already took as the wallet’s', async () => {
    const h = await unlocked();
    await h.vault.moveWallet(100_00, 'DZD', null);
    const uuid = await h.money.log({ amountMinor: 80_00, currency: 'DZD', category: 'food', note: null, day: today.key, fromWallet: true });
    const expense = (await h.db.rows('expenses').get(uuid))!;
    show(h, <ExpenseEditor expense={expense} onClose={() => {}} />);
    const amount = await screen.findByLabelText('Amount');
    await userEvent.clear(amount);
    await userEvent.type(amount, '90');
    await waitFor(() => expect(screen.getByRole('switch', { name: 'From the wallet' })).toBeChecked());
    await userEvent.click(screen.getByRole('button', { name: 'Save' }));

    await waitFor(async () => expect(await walletBalance(h)).toBe(10_00));
  });

  it('takes a day up to a year either side of today', async () => {
    const h = await unlocked();
    show(h, <ExpenseEditor expense={null} onClose={() => {}} />);
    const day = await screen.findByLabelText('Logged on');
    expect(day).toHaveAttribute('min', '2025-09-19');
    expect(day).toHaveAttribute('max', '2027-09-19');
  });
});

describe('an expense’s wallet movement', () => {
  it('turned off and on again is the same row, brought back', async () => {
    const h = await device(new FakeServer());
    await h.vault.moveWallet(100_00, 'DZD', null);
    const input = { amountMinor: 30_00, currency: 'DZD', category: 'food', note: null, day: today.key };
    const uuid = await h.money.log({ ...input, fromWallet: true });
    await h.money.update(uuid, { ...input, fromWallet: false });
    await h.money.update(uuid, { ...input, amountMinor: 40_00, fromWallet: true });

    const rows = await linkedRows(h, uuid);
    expect(rows).toHaveLength(1);
    expect(rows[0]).toMatchObject({ deltaMinor: -40_00, deletedAt: null });
    expect(await walletBalance(h)).toBe(60_00);
  });

  it('the undo of a removal brings back the movement that went with it, and only that', async () => {
    const h = await device(new FakeServer());
    await h.vault.moveWallet(100_00, 'DZD', null);
    const uuid = await h.money.log({ amountMinor: 25_00, currency: 'DZD', category: 'food', note: null, day: today.key, fromWallet: true });
    // A movement of the same expense dropped long ago, stored first.
    const live = (await linkedRows(h, uuid))[0]!;
    await h.db.rows('money_txns').delete(live.uuid);
    await h.db.rows('money_txns').put({ ...live, uuid: '00000000-old', deltaMinor: -90_00, deletedAt: '2026-09-01T10:00:00.000Z' });
    await h.db.rows('money_txns').put(live);

    await h.money.remove(uuid);
    expect(await walletBalance(h)).toBe(100_00);
    await h.money.restore(uuid);
    expect(await walletBalance(h)).toBe(75_00);
    expect((await h.db.rows('money_txns').get('00000000-old'))?.deletedAt).not.toBeNull();
  });
});

describe('the list item editor on a shopping list', () => {
  it('reads "12,50" as twelve and a half, in the default currency once it is known', async () => {
    const h = await device(new FakeServer());
    await h.db.rows('kv_settings').put({ key: 'finance.defaultCurrency', valueJson: '"EUR"', updatedAt: '' });
    show(h, <ListItemEditor item={null} listUuid={buyListId} onClose={() => {}} />);
    await userEvent.type(screen.getByLabelText('Title'), 'Kettle');
    await userEvent.type(await screen.findByLabelText('Estimated price'), '12,50');
    await userEvent.click(screen.getByRole('button', { name: 'Add' }));

    await waitFor(async () => expect(await h.db.rows('wishlist_items').count()).toBe(1));
    expect((await h.db.rows('wishlist_items').toArray())[0]).toMatchObject({ priceMinor: 12_50, currency: 'EUR' });
  });

  it('an edit that changes the list moves the item in the same write', async () => {
    const h = await device(new FakeServer());
    await h.wishlist.add({ list: 'wish', title: 'Espresso machine' });
    const kettle = await h.wishlist.add({ list: 'buy', title: 'Kettle' });
    await h.wishlist.edit(kettle.uuid, { title: 'Steel kettle' }, 'wish');
    expect(await h.db.rows('wishlist_items').get(kettle.uuid)).toMatchObject({ title: 'Steel kettle', list: 'wish', position: 1 });
  });
});

describe('the Granary’s reads', () => {
  it('the month counts up to today, as the phone does', async () => {
    const h = await device(new FakeServer());
    await h.db.rows('kv_settings').put({ key: 'finance.monthlyBudgetMinor', valueJson: '"30000"', updatedAt: '' });
    await h.money.log({ amountMinor: 20_00, currency: 'DZD', category: 'food', note: null, day: '2026-09-10', fromWallet: false });
    await h.money.log({ amountMinor: 50_00, currency: 'DZD', category: 'bills', note: null, day: '2026-09-25', fromWallet: false });
    const budget = await readBudget(h.db, today);
    expect(budget.spentThisMonth).toBe(20_00);
    expect(budget.byCategory).toEqual([['food', 20_00]]);
  });

  it('lists debts open first, then oldest first, as the phone does', async () => {
    const h = await device(new FakeServer());
    const base = { amountMinor: 10_00, currency: 'DZD', remindAt: null, note: null };
    await h.vault.createDebt({ ...base, person: 'Amine', payOffBy: '2026-12-01' });
    h.clock.advance(1000);
    await h.vault.createDebt({ ...base, person: 'Sara', payOffBy: '2026-10-01' });
    const vault = await readVault(h.db);
    expect(vault.debts.map((view) => view.debt.person)).toEqual(['Amine', 'Sara']);
  });

  it('a repeat logs once however quickly it is tapped', async () => {
    const h = await unlocked();
    for (const day of ['2026-09-16', '2026-09-17', '2026-09-18']) {
      await h.money.log({ amountMinor: 3_00, currency: 'DZD', category: 'food', note: 'coffee', day, fromWallet: false });
    }
    show(h, <GranaryScreen />);
    const card = await screen.findByRole('region', { name: 'Same as the last 3 days?' });
    const button = within(card).getByRole('button', { name: 'Log it' });
    fireEvent.click(button);
    fireEvent.click(button);
    await waitFor(async () => expect((await h.db.rows('expenses').toArray()).filter((row) => row.harvestDay === today.key)).toHaveLength(1));
    await new Promise((resolve) => setTimeout(resolve, 50));
    expect((await h.db.rows('expenses').toArray()).filter((row) => row.harvestDay === today.key)).toHaveLength(1);
  });

  it('the budget’s sentences follow the language, their amounts kept left to right', async () => {
    const h = await device(new FakeServer());
    await h.db.rows('kv_settings').put({ key: 'finance.monthlyBudgetMinor', valueJson: '"30000"', updatedAt: '' });
    await h.money.log({ amountMinor: 20_00, currency: 'DZD', category: 'food', note: null, day: today.key, fromWallet: false });
    show(h, <BudgetPanel />);
    const line = await screen.findByText(/this month/);
    expect(line).not.toHaveAttribute('dir');
    expect(line.textContent).toContain('⁦DA20⁩');
  });
});
