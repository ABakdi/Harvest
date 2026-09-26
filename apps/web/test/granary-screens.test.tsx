import { fireEvent, render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import type { ReactNode } from 'react';
import { MemoryRouter } from 'react-router';
import { describe, expect, it } from 'vitest';
import { ExpenseEditor } from '@/app/components/expense-editor';
import { HarvestDay } from '@harvest/core';
import { HarvestContext } from '@/app/context';
import { BudgetPanel } from '@/app/screens/budget';
import { InsightsPanel } from '@/app/screens/insights';
import { VaultPanel } from '@/app/screens/vault';
import { FakeServer } from './fake-server';
import { device, testUser } from './helpers';
import { formatMoney } from '@/lib/format';

// Radix's switch measures itself; jsdom has nothing to measure with.
globalThis.ResizeObserver ??= class {
  observe() {}
  unobserve() {}
  disconnect() {}
};

/**
 * The Granary's money screens on the web, doing what the phone's do
 * ([[Finances]]): moving money, paying debts, setting the budget and
 * reading a span — with sums typed straight into the amount box.
 */

type Device = Awaited<ReturnType<typeof device>>;

function show(h: Device, ui: ReactNode) {
  return render(
    <HarvestContext.Provider value={h}>
      <MemoryRouter>{ui}</MemoryRouter>
    </HarvestContext.Provider>,
  );
}

async function wallet(h: Device) {
  return (await h.db.rows('money_txns').toArray()).filter((row) => row.account === 'wallet' && row.deletedAt === null);
}

describe('the vault, moved from the browser', () => {
  it('adds a sum to the wallet, showing what it comes to first', async () => {
    const h = await device(new FakeServer());
    show(h, <VaultPanel />);
    await userEvent.click(await screen.findByRole('button', { name: 'Add' }));
    const dialog = await screen.findByRole('dialog');
    await userEvent.type(within(dialog).getByLabelText('Amount'), '120+30');
    expect(within(dialog).getByText('= DA150')).toBeInTheDocument();
    await userEvent.type(within(dialog).getByLabelText('Note (optional)'), 'found money');
    await userEvent.click(within(dialog).getByRole('button', { name: 'Save' }));

    await waitFor(async () => expect(await wallet(h)).toHaveLength(1));
    expect((await wallet(h))[0]).toMatchObject({ deltaMinor: 150_00, kind: 'manual', note: 'found money' });
    expect(await screen.findByText('found money')).toBeInTheDocument();
    // The ledger is written here now; nothing says otherwise.
    expect(screen.queryByText(/moved on the phone/)).not.toBeInTheDocument();
  });

  it('will not take more than the wallet holds', async () => {
    const h = await device(new FakeServer());
    await h.vault.moveWallet(150_00, 'DZD', null);
    show(h, <VaultPanel />);
    await userEvent.click(await screen.findByRole('button', { name: 'Take' }));
    const dialog = await screen.findByRole('dialog');
    expect(within(dialog).getByText('At most DA150')).toBeInTheDocument();
    await userEvent.type(within(dialog).getByLabelText('Amount'), '200');
    expect(within(dialog).getByText('That is more than DA150.')).toBeInTheDocument();
    expect(within(dialog).getByRole('button', { name: 'Save' })).toBeDisabled();
  });

  it('logs a debt and pays it, prefilled with what is left', async () => {
    const h = await device(new FakeServer());
    show(h, <VaultPanel />);
    fireEvent.click(await screen.findByRole('button', { name: /Owed/ }));
    await userEvent.click(await screen.findByRole('button', { name: 'Log a debt' }));
    let dialog = await screen.findByRole('dialog');
    await userEvent.type(within(dialog).getByLabelText('Owed to'), 'Nadia');
    await userEvent.type(within(dialog).getByLabelText('Amount'), '2*100');
    await userEvent.click(within(dialog).getByRole('button', { name: 'Save' }));

    await userEvent.click(await screen.findByRole('button', { name: 'Pay' }));
    dialog = await screen.findByRole('dialog', { name: 'Pay Nadia' });
    expect(within(dialog).getByLabelText('Amount')).toHaveValue('200');
    await userEvent.clear(within(dialog).getByLabelText('Amount'));
    await userEvent.type(within(dialog).getByLabelText('Amount'), '50');
    // An empty wallet cannot pay, so it is not offered.
    expect(within(dialog).getByRole('switch', { name: 'From the wallet' })).toBeDisabled();
    await userEvent.click(within(dialog).getByRole('button', { name: 'Save' }));

    expect(await screen.findByText('DA50 of DA200 paid')).toBeInTheDocument();
    const [payment] = await h.db.rows('debt_payments').toArray();
    expect(payment?.amountMinor).toBe(50_00);
  });
});

describe('the budget, set from the browser', () => {
  it('sets the month in minor units under the phone key, and clears it', async () => {
    const h = await device(new FakeServer());
    show(h, <BudgetPanel />);
    await userEvent.click(await screen.findByRole('button', { name: 'Set a monthly budget' }));
    let dialog = await screen.findByRole('dialog');
    await userEvent.type(within(dialog).getByLabelText('Budget for the month'), '300+200');
    await userEvent.click(within(dialog).getByRole('button', { name: 'Save' }));
    await waitFor(async () =>
      expect((await h.db.rows('kv_settings').get('finance.monthlyBudgetMinor'))?.valueJson).toBe('"50000"'),
    );
    expect(await screen.findByText('Left today')).toBeInTheDocument();

    await userEvent.click(screen.getByRole('button', { name: 'Edit budget' }));
    dialog = await screen.findByRole('dialog');
    await userEvent.click(within(dialog).getByRole('button', { name: 'Clear budget' }));
    expect(await screen.findByText('No monthly budget set')).toBeInTheDocument();
    expect((await h.db.rows('kv_settings').get('finance.monthlyBudgetMinor'))?.valueJson).toBe('""');
  });

  it('adds a custom category, and removes it with an undo', async () => {
    const h = await device(new FakeServer());
    show(h, <BudgetPanel />);
    await userEvent.click(await screen.findByRole('button', { name: 'New category' }));
    const dialog = await screen.findByRole('dialog');
    await userEvent.type(within(dialog).getByLabelText('Category name'), 'Books');
    await userEvent.click(within(dialog).getByRole('radio', { name: 'School' }));
    await userEvent.click(within(dialog).getByRole('button', { name: 'Save' }));
    await userEvent.click(await screen.findByRole('button', { name: 'Remove Books' }));
    await waitFor(async () => expect((await h.db.rows('expense_categories').toArray())[0]?.deletedAt).not.toBeNull());
    expect((await h.db.rows('expense_categories').toArray())[0]?.icon).toBe('school');
  });
});

describe('the expense editor', () => {
  it('logs what a sum comes to, a comma inside it being a decimal point', async () => {
    const h = await device(new FakeServer());
    await h.keyring.unlock('a long passphrase', testUser.syncSalt, 1);
    show(h, <ExpenseEditor expense={null} onClose={() => {}} />);
    const amount = await screen.findByLabelText('Amount');
    await userEvent.type(amount, '12,5+3');
    expect(screen.getByText('= DA15.50')).toBeInTheDocument();
    await userEvent.type(amount, '+');
    expect(screen.getByText('Finish the sum to log it')).toBeInTheDocument();
    await userEvent.type(amount, '0,02');
    await userEvent.click(screen.getByRole('button', { name: 'Log it' }));
    await waitFor(async () => expect(await h.db.rows('expenses').count()).toBe(1));
    expect((await h.db.rows('expenses').toArray())[0]?.amountMinor).toBe(15_52);
  });
});

describe('insights', () => {
  it('totals the week, averages it over the days gone, and lists its moves', async () => {
    const h = await device(new FakeServer());
    const today = HarvestDay.parse('2026-09-19');
    const week = today.weekStart;
    await h.money.log({ amountMinor: 70_00, currency: 'DZD', category: 'food', note: null, day: week.key, fromWallet: false });
    await h.vault.moveWallet(100_00, 'DZD', null);
    await h.money.log({ amountMinor: 30_00, currency: 'DZD', category: 'transport', note: 'bus', day: '2026-09-19', fromWallet: true });
    show(h, <InsightsPanel />);

    // The average divides by the days of the week that have happened.
    const elapsed = week.daysUntil(today) + 1;
    expect(await screen.findByText('DA100', { selector: 'span' })).toBeInTheDocument();
    expect(screen.getByText(formatMoney(Math.trunc(100_00 / elapsed), 'DZD'))).toBeInTheDocument();
    expect(screen.getByText('70% (DA70)')).toBeInTheDocument();
    expect(screen.getByText('2 movements')).toBeInTheDocument();

    // Narrowed to one form, the ledger says how much it is showing.
    await userEvent.click(screen.getByRole('button', { name: 'Filter' }));
    await userEvent.click(screen.getByRole('button', { name: 'Expense' }));
    expect(screen.getByText('1 movement')).toBeInTheDocument();
    expect(screen.getByText('Showing 1 of 2')).toBeInTheDocument();
  });

  it('asks for a custom range that runs forwards', async () => {
    const h = await device(new FakeServer());
    show(h, <InsightsPanel />);
    await userEvent.click(await screen.findByRole('radio', { name: 'Custom' }));
    fireEvent.change(screen.getByLabelText('From'), { target: { value: '2026-09-20' } });
    fireEvent.change(screen.getByLabelText('To'), { target: { value: '2026-09-10' } });
    expect(await screen.findByRole('alert')).toHaveTextContent('The first day has to come before the last.');
  });
});
