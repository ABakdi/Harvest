import { gramsOfPounds } from '@harvest/core';
import { fireEvent, render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import type { ReactNode } from 'react';
import { MemoryRouter, Route, Routes } from 'react-router';
import { Toaster } from 'sonner';
import { describe, expect, it } from 'vitest';
import { ExpenseEditor } from '@/app/components/expense-editor';
import { RatesCard } from '@/app/components/settings-rates';
import { HarvestContext, type Harvest } from '@/app/context';
import { readProgram, readSession } from '@/app/data/gym';
import { DialogsProvider } from '@/app/dialogs';
import { GymPanel } from '@/app/screens/gym';
import { ExercisePicker } from '@/app/screens/gym/exercise-picker';
import { ProgramEditorScreen } from '@/app/screens/gym/program-editor';
import { SessionScreen } from '@/app/screens/gym/session';
import { GranaryScreen } from '@/app/screens/granary';
import { VaultPanel } from '@/app/screens/vault';
import { WishlistPanel } from '@/app/screens/wishlist';
import { FakeServer } from './fake-server';
import { device, testUser } from './helpers';

// Radix's switch measures itself; jsdom has nothing to measure with.
globalThis.ResizeObserver ??= class {
  observe() {}
  unobserve() {}
  disconnect() {}
};

/**
 * What a hands-on pass through the browser could not reach or could
 * not trust: an expense logged ahead, a settled debt's payments, a
 * rejected rate, and loads in pounds that must read as a pound gym
 * loads them ([[Finances]], [[Gym]] Y8).
 */

type Device = Awaited<ReturnType<typeof device>>;

function show(h: Device, ui: ReactNode, at = '/') {
  return render(
    <HarvestContext.Provider value={h}>
      <MemoryRouter initialEntries={[at]}>
        <DialogsProvider>{ui}</DialogsProvider>
      </MemoryRouter>
      <Toaster />
    </HarvestContext.Provider>,
  );
}

async function unlocked() {
  const h = await device(new FakeServer());
  await h.keyring.unlock('a long passphrase', testUser.syncSalt, 1);
  return h;
}

describe('an expense logged ahead', () => {
  it('waits under Upcoming, out of the month, and can still be opened and removed', async () => {
    const h = await unlocked();
    await h.money.log({ amountMinor: 45_00, currency: 'DZD', category: 'food', note: 'today', day: '2026-09-19', fromWallet: false });
    await h.money.log({ amountMinor: 900_00, currency: 'DZD', category: 'bills', note: 'rent ahead', day: '2026-10-10', fromWallet: false });
    // Later this month still waits for its day.
    await h.money.log({ amountMinor: 70_00, currency: 'DZD', category: 'shopping', note: 'next week', day: '2026-09-25', fromWallet: false });
    show(h, <GranaryScreen />);

    const upcoming = await screen.findByRole('region', { name: 'Upcoming' });
    expect(within(upcoming).getByText('rent ahead')).toBeInTheDocument();
    expect(within(upcoming).getByText('next week')).toBeInTheDocument();
    expect(within(upcoming).getByText('2 expenses logged ahead. Each counts on its day, not before.')).toBeInTheDocument();
    // Soonest first.
    const notes = within(upcoming).getAllByText(/rent ahead|next week/).map((node) => node.textContent);
    expect(notes).toEqual(['next week', 'rent ahead']);

    // The month counts today's 45, not the 70 still to come.
    const month = screen.getByText('September 2026').closest('div')!.parentElement!;
    expect(month.textContent).toContain('DA45');
    expect(month.textContent).not.toContain('DA115');
    expect(month.textContent).toContain('1 expense');

    await userEvent.click(within(upcoming).getByText('rent ahead'));
    const dialog = await screen.findByRole('dialog');
    expect(within(dialog).getByLabelText('Logged on')).toHaveValue('2026-10-10');
    await userEvent.click(within(dialog).getByRole('button', { name: 'Remove' }));
    await waitFor(() => expect(screen.queryByText('rent ahead')).not.toBeInTheDocument());
    const rows = await h.db.rows('expenses').toArray();
    expect(rows.find((row) => row.note === 'rent ahead')?.deletedAt).not.toBeNull();
  });

  it('shows no Upcoming section when nothing is ahead', async () => {
    const h = await unlocked();
    await h.money.log({ amountMinor: 45_00, currency: 'DZD', category: 'food', note: null, day: '2026-09-19', fromWallet: false });
    show(h, <GranaryScreen />);
    await screen.findByText('September 2026');
    expect(screen.queryByRole('region', { name: 'Upcoming' })).not.toBeInTheDocument();
  });
});

describe('a settled debt', () => {
  it('celebrates the last payment, keeps its payments, and reopens when one is removed — with Undo', async () => {
    const h = await unlocked();
    await h.vault.createDebt({ person: 'Sam', amountMinor: 100_00, currency: 'DZD', payOffBy: null, remindAt: null, note: null });
    show(h, <VaultPanel />);
    fireEvent.click(await screen.findByRole('button', { name: /Owed/ }));
    await userEvent.click(await screen.findByRole('button', { name: 'Pay' }));
    const dialog = await screen.findByRole('dialog', { name: 'Pay Sam' });
    // A lead that says something, not the title again.
    expect(within(dialog).getByText('Still owed: DA100. Paying all of it settles the debt.')).toBeInTheDocument();
    await userEvent.click(within(dialog).getByRole('button', { name: 'Save' }));

    expect(await screen.findByText('Settled with Sam. Nothing left to pay!')).toBeInTheDocument();
    const settled = await screen.findByRole('region', { name: 'Settled' });
    await userEvent.click(within(settled).getByRole('button', { name: 'Payments · 1' }));
    await userEvent.click(within(settled).getByRole('button', { name: 'Remove the payment of DA100' }));
    await userEvent.click(within(await screen.findByRole('alertdialog')).getByRole('button', { name: 'Remove' }));

    await waitFor(async () => expect((await h.db.rows('debts').toArray())[0]!.settledAt).toBeNull());
    expect(await screen.findByRole('region', { name: 'Open' })).toBeInTheDocument();
    // Sonner captures the pointer, which jsdom cannot; a plain click is the keyboard's click anyway.
    const removed = (await screen.findByText('Payment removed')).closest('[data-sonner-toast]') as HTMLElement;
    fireEvent.click(within(removed).getByRole('button', { name: 'Undo' }));
    await waitFor(async () => expect((await h.db.rows('debts').toArray())[0]!.settledAt).not.toBeNull());
  });
});

describe('the vault says what it did', () => {
  it('confirms an Add, and Undo takes it back', async () => {
    const h = await unlocked();
    show(h, <VaultPanel />);
    await userEvent.click(await screen.findByRole('button', { name: 'Add' }));
    const dialog = await screen.findByRole('dialog', { name: 'Add to the wallet' });
    expect(within(dialog).getByText('Money coming in from outside: pay, a gift, cash found in a coat.')).toBeInTheDocument();
    await userEvent.type(within(dialog).getByLabelText('Amount'), '150');
    await userEvent.click(within(dialog).getByRole('button', { name: 'Save' }));

    const toast = (await screen.findByText('Added DA150 to the wallet')).closest('[data-sonner-toast]') as HTMLElement;
    fireEvent.click(within(toast).getByRole('button', { name: 'Undo' }));
    await waitFor(async () => expect((await h.db.rows('money_txns').toArray()).every((row) => row.deletedAt !== null)).toBe(true));
  });

  it('confirms a Take', async () => {
    const h = await unlocked();
    await h.vault.moveWallet(200_00, 'DZD', null);
    show(h, <VaultPanel />);
    await userEvent.click(await screen.findByRole('button', { name: 'Take' }));
    const dialog = await screen.findByRole('dialog', { name: 'Take from the wallet' });
    await userEvent.type(within(dialog).getByLabelText('Amount'), '50');
    await userEvent.click(within(dialog).getByRole('button', { name: 'Save' }));
    expect(await screen.findByText('Took DA50 from the wallet')).toBeInTheDocument();
  });

  it('a debt opens on a lead, not a copy of the title', async () => {
    const h = await unlocked();
    show(h, <VaultPanel />);
    fireEvent.click(await screen.findByRole('button', { name: /Owed/ }));
    await userEvent.click(await screen.findByRole('button', { name: 'Log a debt' }));
    const dialog = await screen.findByRole('dialog', { name: 'Log a debt' });
    expect(dialog).toHaveAccessibleDescription('Who I owe, how much, and when I mean to have it paid back.');
  });
});

describe('money inputs', () => {
  it('drops the amount complaint as soon as the sum is a real one', async () => {
    const h = await unlocked();
    show(h, <ExpenseEditor expense={null} onClose={() => {}} />);
    const dialog = await screen.findByRole('dialog');
    await userEvent.click(await within(dialog).findByRole('button', { name: 'Log it' }));
    expect(within(dialog).getByRole('alert')).toHaveTextContent('Type an amount above zero');
    await userEvent.type(within(dialog).getByLabelText('Amount'), '12+3');
    expect(within(dialog).queryByRole('alert')).not.toBeInTheDocument();
  });

  it('puts the stored rate back when what was typed is not one', async () => {
    const h = await device(new FakeServer());
    await h.settings.setString('rate.dzdPerUsd', '134.5');
    show(h, <RatesCard />);
    const field = await screen.findByLabelText('DZD per 1 USD');
    await waitFor(() => expect(field).toHaveValue('134.5'));
    await userEvent.clear(field);
    await userEvent.type(field, 'abc');
    fireEvent.blur(field);
    await waitFor(() => expect(field).toHaveValue('134.5'));
    expect(await screen.findByText(/not a usable rate/i)).toBeInTheDocument();
  });
});

describe('the wishlist', () => {
  it('shows an estimate in plain ink, not the colour of money owed', async () => {
    const h = await device(new FakeServer());
    await h.wishlist.add({ list: 'buy', title: 'Kettle', priceMinor: 30_00, currency: 'DZD' });
    show(h, <WishlistPanel />);
    await screen.findByText('Kettle');
    for (const price of screen.getAllByText('DA30')) expect(price.className).not.toMatch(/text-(primary|destructive|sun)\b/);
  });
});

// ----------------------------------------------------------------- gym

/** 60 kg and 61.25 kg, set in kilos, then read by someone lifting in pounds. */
async function kilosReadInPounds(h: Harvest) {
  const program = await h.programs.createProgram('Kilos');
  const day = await h.programs.addDay(program.uuid, 'Day 1');
  const slot = await h.programs.addSlot(day.uuid, '0025');
  await h.programs.addTargetSet(slot.uuid, { reps: 5, weightGrams: 60_000, percentTenths: null, openEnded: false });
  await h.programs.addTargetSet(slot.uuid, { reps: 5, weightGrams: 61_250, percentTenths: null, openEnded: false });
  await h.settings.setMany({ 'health.weightUnit': 'lb' });
  return (await readProgram(h.db, program.uuid))!;
}

function renderGym(h: Device, at: string) {
  show(
    h,
    <Routes>
      <Route path="/app/body/gym/programs/:uuid" element={<ProgramEditorScreen />} />
      <Route path="/app/body/gym/sessions/:uuid" element={<SessionScreen />} />
    </Routes>,
    at,
  );
}

describe('kilos read in pounds (Y8)', () => {
  it('the program reads a quarter-pound load, never 132.28', async () => {
    const h = await device(new FakeServer());
    const tree = await kilosReadInPounds(h);
    renderGym(h, `/app/body/gym/programs/${tree.program.uuid}`);
    await userEvent.click(await screen.findByText('Barbell Bench Press', {}, { timeout: 5000 }));
    const dialog = await screen.findByRole('dialog');
    expect(await within(dialog).findByText('132.25 lb × 5')).toBeInTheDocument();
    expect(within(dialog).getByText('135 lb × 5')).toBeInTheDocument();
    expect(within(dialog).queryByText(/132\.28|135\.03/)).not.toBeInTheDocument();
  });

  it('the session fills and ticks the rounded pounds', async () => {
    const h = await device(new FakeServer());
    const tree = await kilosReadInPounds(h);
    const { session } = await h.sessions.start({ day: tree.days[0]!, programUuid: tree.program.uuid, trainingMaxes: new Map(), unit: 'lb' });
    renderGym(h, `/app/body/gym/sessions/${session.session.uuid}`);

    expect(await screen.findByLabelText('Weight in lb, set 1', {}, { timeout: 5000 })).toHaveValue('132.25');
    expect(screen.getByLabelText('Weight in lb, set 2')).toHaveValue('135');
    await userEvent.click(screen.getByRole('button', { name: 'Log set 2' }));
    await waitFor(async () => {
      const sets = (await readSession(h.db, session.session.uuid))!.exercises[0]!.sets;
      expect(sets[1]!.weightGrams).toBe(gramsOfPounds(135));
    });
  });

  it('last time and the best read in quarter pounds too', async () => {
    const h = await device(new FakeServer());
    const tree = await kilosReadInPounds(h);
    const first = await h.sessions.start({ day: tree.days[0]!, programUuid: tree.program.uuid, trainingMaxes: new Map(), unit: 'kg' });
    const sets = (await readSession(h.db, first.session.session.uuid))!.exercises[0]!.sets;
    await h.sessions.logSet(sets[0]!.uuid, { weightGrams: 65_000, reps: 5, done: true });
    await h.sessions.finish(first.session.session.uuid);
    h.clock.advance(60 * 60 * 1000);
    const second = await h.sessions.start({ day: tree.days[0]!, programUuid: tree.program.uuid, trainingMaxes: new Map(), unit: 'lb' });
    renderGym(h, `/app/body/gym/sessions/${second.session.session.uuid}`);

    // Each set is its own left-to-right island inside the sentence.
    const line = (pattern: RegExp) => (_: string, element: Element | null) => element?.tagName === 'SPAN' && pattern.test(element.textContent ?? '');
    expect(await screen.findByText(line(/^Last time: 143\.25 lb×5$/), {}, { timeout: 5000 })).toBeInTheDocument();
    expect(screen.getByText(line(/^Best: 143\.25 lb×5/))).toBeInTheDocument();
    expect(screen.queryByText(/143\.3\b/)).not.toBeInTheDocument();
  });

  it('says what a typed load will be kept as before it is saved', async () => {
    const h = await device(new FakeServer());
    const tree = await kilosReadInPounds(h);
    await h.settings.setMany({ 'health.weightUnit': 'kg' });
    renderGym(h, `/app/body/gym/programs/${tree.program.uuid}`);
    await userEvent.click(await screen.findByText('Barbell Bench Press', {}, { timeout: 5000 }));
    await userEvent.click(await screen.findByRole('button', { name: 'Edit 60 kg × 5' }));
    const dialog = await screen.findByRole('dialog', { name: 'Edit the set' });
    const field = within(dialog).getByLabelText('Weight');
    await userEvent.clear(field);
    await userEvent.type(field, '61.3');
    expect(within(dialog).getByText('Kept as 61.25 kg, the nearest weight a bar can hold.')).toBeInTheDocument();
    fireEvent.blur(field);
    expect(field).toHaveValue('61.25');
  });
});

describe('the gym panel', () => {
  it('switches kilos and pounds from the gym, the same setting as body weight', async () => {
    const h = await device(new FakeServer());
    await h.settings.setMany({ 'health.weightUnit': 'kg' });
    show(h, <GymPanel />);
    const unit = await screen.findByRole('radiogroup', { name: 'Weights in' });
    await userEvent.click(within(unit).getByRole('radio', { name: 'lb' }));
    await waitFor(async () => expect((await h.db.rows('kv_settings').get('health.weightUnit'))?.valueJson).toBe('"lb"'));
  });

  it('counts the catalogue in the language’s numbers', async () => {
    const h = await device(new FakeServer());
    show(h, <GymPanel />);
    expect(await screen.findByText(/^1,\d{3} exercises$/)).toBeInTheDocument();
  });

  it('keeps the filter chips whole in the picker', async () => {
    const h = await device(new FakeServer());
    show(h, <ExercisePicker onClose={() => {}} />);
    const dialog = await screen.findByRole('dialog');
    const row = await within(dialog).findByRole('group', { name: 'Body part' }, { timeout: 5000 });
    expect(row.className).toMatch(/\bshrink-0\b/);
  });
});
