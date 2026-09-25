import { HarvestDay } from '@harvest/core';
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import type { ReactNode } from 'react';
import { MemoryRouter } from 'react-router';
import { describe, expect, it } from 'vitest';
import { ExpenseEditor } from '@/app/components/expense-editor';
import { MovesLedger } from '@/app/components/money-ledger';
import { HarvestContext } from '@/app/context';
import { DialogsProvider } from '@/app/dialogs';
import { readVault } from '@/app/data/vault';
import { FakeServer } from './fake-server';
import { device, testUser } from './helpers';

// Radix's switch measures itself; jsdom has nothing to measure with.
globalThis.ResizeObserver ??= class {
  observe() {}
  unobserve() {}
  disconnect() {}
};

/**
 * An expense logged ahead counts on its day, not before ([[Finances]]):
 * dated the 22nd from the wallet, it leaves the wallet whole on the 19th.
 */

type Device = Awaited<ReturnType<typeof device>>;

const ahead = '2026-09-22';

function show(h: Device, ui: ReactNode) {
  return render(
    <HarvestContext.Provider value={h}>
      <MemoryRouter>
        <DialogsProvider>{ui}</DialogsProvider>
      </MemoryRouter>
    </HarvestContext.Provider>,
  );
}

/** A wallet of DA100, and DA80 of food from it logged for the 22nd. */
async function withUpcoming() {
  const h = await device(new FakeServer());
  await h.keyring.unlock('a long passphrase', testUser.syncSalt, 1);
  await h.vault.moveWallet(100_00, 'DZD', null);
  const uuid = await h.money.log({ amountMinor: 80_00, currency: 'DZD', category: 'food', note: null, day: ahead, fromWallet: true });
  return { h, uuid };
}

async function wallet(h: Device) {
  const vault = await readVault(h.db, HarvestDay.of(h.clock()));
  return new Map(vault.pots.find((pot) => pot.account === 'wallet')!.balances).get('DZD') ?? 0;
}

describe('a movement logged ahead', () => {
  it('leaves the wallet whole until its day, then takes from it', async () => {
    const { h } = await withUpcoming();
    expect(await wallet(h)).toBe(100_00);
    h.clock.set('2026-09-21T12:00:00.000Z');
    expect(await wallet(h)).toBe(100_00);
    h.clock.set('2026-09-22T12:00:00.000Z');
    expect(await wallet(h)).toBe(20_00);
    h.clock.set('2026-09-23T12:00:00.000Z');
    expect(await wallet(h)).toBe(20_00);
  });

  it('is not in what the wallet can give today', async () => {
    const { h } = await withUpcoming();
    await h.vault.moveWallet(-100_00, 'DZD', null);
    expect(await wallet(h)).toBe(0);
  });

  it('leaves a new expense the whole wallet to pay from', async () => {
    const { h } = await withUpcoming();
    show(h, <ExpenseEditor expense={null} onClose={() => {}} />);
    await userEvent.type(await screen.findByLabelText('Amount'), '90');
    await waitFor(() => expect(screen.getByRole('switch', { name: 'From the wallet' })).toBeChecked());
  });

  it('gives nothing back to the wallet when it is edited, since the wallet never took it', async () => {
    const { h, uuid } = await withUpcoming();
    const expense = (await h.db.rows('expenses').get(uuid))!;
    show(h, <ExpenseEditor expense={expense} onClose={() => {}} />);
    const amount = await screen.findByLabelText('Amount');
    await userEvent.clear(amount);
    await userEvent.type(amount, '100');
    const from = screen.getByRole('switch', { name: 'From the wallet' });
    await waitFor(() => expect(from).toBeChecked());
    // DA150 would fit only if the DA80 were counted as given back.
    await userEvent.clear(amount);
    await userEvent.type(amount, '150');
    await waitFor(() => expect(from).toBeDisabled());
  });

  it('sits on top of the ledger, under its own day, marked upcoming', async () => {
    const { h } = await withUpcoming();
    const vault = await readVault(h.db, HarvestDay.of(h.clock()));
    const pot = vault.pots.find((row) => row.account === 'wallet')!;
    expect(pot.movements.map((row) => row.deltaMinor)).toEqual([-80_00, 100_00]);
    show(h, <MovesLedger rows={pot.movements} total={pot.movements.length} rates={vault.rates} empty="" />);
    const headings = await screen.findAllByRole('heading', { level: 3 });
    expect(headings).toHaveLength(2);
    expect(headings[0]).toHaveTextContent(/22 · upcoming$/);
    expect(headings[1]).not.toHaveTextContent('upcoming');
  });
});
