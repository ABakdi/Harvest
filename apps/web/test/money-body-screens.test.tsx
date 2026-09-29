import { fireEvent, render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import type { ReactNode } from 'react';
import { MemoryRouter } from 'react-router';
import { describe, expect, it } from 'vitest';
import { ExpenseEditor } from '@/app/components/expense-editor';
import { TargetWeightDialog } from '@/app/components/target-weight';
import { HarvestContext } from '@/app/context';
import { healthKeys } from '@/app/data/health';
import { readSetting } from '@/app/data/settings';
import { InsightsPanel } from '@/app/screens/insights';
import { VaultPanel } from '@/app/screens/vault';
import { readProgram, readSession } from '@/app/data/gym';
import { GymPanel } from '@/app/screens/gym';
import { SetBadge } from '@/app/screens/gym/program-editor';
import { DialogsProvider } from '@/app/dialogs';
import { FakeServer } from './fake-server';
import { device, testUser } from './helpers';

// Radix's switch measures itself; jsdom has nothing to measure with.
globalThis.ResizeObserver ??= class {
  observe() {}
  unobserve() {}
  disconnect() {}
};

/**
 * The web halves of the money and body fixes ([[Audit-v3]] G5-02, G5-05,
 * Q5-17, Q5-46, Q5-49, Q5-50), on screen.
 */

type Device = Awaited<ReturnType<typeof device>>;

function show(h: Device, ui: ReactNode) {
  return render(
    <HarvestContext.Provider value={h}>
      <MemoryRouter>{ui}</MemoryRouter>
    </HarvestContext.Provider>,
  );
}

const debtInput = {
  person: 'Samy',
  amountMinor: 1500_00,
  currency: 'DZD',
  payOffBy: null,
  remindAt: null,
  note: null,
};

describe('a debt, corrected and removed (G5-02)', () => {
  async function openEditor(h: Device) {
    show(h, <VaultPanel />);
    fireEvent.click(await screen.findByRole('button', { name: /Owed/ }));
    await userEvent.click(await screen.findByRole('button', { name: 'Edit the debt to Samy' }));
    return screen.findByRole('dialog');
  }

  it('opens on what it is and saves the correction', async () => {
    const h = await device(new FakeServer());
    const uuid = await h.vault.createDebt(debtInput);
    const dialog = await openEditor(h);
    const person = within(dialog).getByLabelText('Owed to');
    expect(person).toHaveValue('Samy');
    await userEvent.clear(person);
    await userEvent.type(person, 'Sami');
    const amount = within(dialog).getByLabelText('Amount');
    await userEvent.clear(amount);
    await userEvent.type(amount, '2000');
    await userEvent.click(within(dialog).getByRole('button', { name: 'Save' }));
    await waitFor(async () => expect((await h.db.rows('debts').get(uuid))?.person).toBe('Sami'));
    expect((await h.db.rows('debts').get(uuid))?.amountMinor).toBe(2000_00);
  });

  it('will not owe less than was paid', async () => {
    const h = await device(new FakeServer());
    const uuid = await h.vault.createDebt(debtInput);
    await h.vault.payDebt(uuid, 1000_00, false, null);
    const dialog = await openEditor(h);
    const amount = within(dialog).getByLabelText('Amount');
    await userEvent.clear(amount);
    await userEvent.type(amount, '900');
    expect(within(dialog).getByRole('alert')).toHaveTextContent('Already paid DA1,000');
    expect(within(dialog).getByRole('button', { name: 'Save' })).toBeDisabled();
  });

  it('removes it after asking, and Undo is offered', async () => {
    const h = await device(new FakeServer());
    const uuid = await h.vault.createDebt(debtInput);
    const dialog = await openEditor(h);
    await userEvent.click(within(dialog).getByRole('button', { name: 'Delete' }));
    const confirm = await screen.findByRole('alertdialog');
    expect(within(confirm).getByText('Remove this debt?')).toBeInTheDocument();
    await userEvent.click(within(confirm).getByRole('button', { name: 'Delete' }));
    await waitFor(async () => expect((await h.db.rows('debts').get(uuid))?.deletedAt).not.toBeNull());
    await h.vault.restoreDebt(uuid);
    expect((await h.db.rows('debts').get(uuid))?.deletedAt).toBeNull();
  });
});

describe('an expense (Q5-49)', () => {
  it('asks before it is removed', async () => {
    const h = await device(new FakeServer());
    await h.keyring.unlock('a long passphrase', testUser.syncSalt, 1);
    const uuid = await h.money.log({
      amountMinor: 45_00,
      currency: 'DZD',
      category: 'food',
      note: null,
      day: '2026-09-19',
      fromWallet: false,
    });
    const expense = (await h.db.rows('expenses').get(uuid))!;
    show(h, <ExpenseEditor expense={expense} onClose={() => {}} />);
    await userEvent.click(await screen.findByRole('button', { name: 'Remove' }));
    expect((await h.db.rows('expenses').get(uuid))?.deletedAt).toBeNull();
    const confirm = await screen.findByRole('alertdialog');
    await userEvent.click(within(confirm).getByRole('button', { name: 'Remove' }));
    await waitFor(async () => expect((await h.db.rows('expenses').get(uuid))?.deletedAt).not.toBeNull());
  });

  it('logs on the day it is saved, not the day the form opened', async () => {
    const h = await device(new FakeServer());
    await h.keyring.unlock('a long passphrase', testUser.syncSalt, 1);
    // 02:58 on the 20th is still the 19th's Harvest Day.
    h.clock.set(new Date('2026-09-20T02:58:00').toISOString());
    show(h, <ExpenseEditor expense={null} onClose={() => {}} />);
    const amount = await screen.findByLabelText('Amount');
    await userEvent.type(amount, '12');
    // Past 3 AM by the time Log is pressed.
    h.clock.set(new Date('2026-09-20T03:02:00').toISOString());
    await userEvent.click(screen.getByRole('button', { name: 'Log it' }));
    await waitFor(async () => expect(await h.db.rows('expenses').count()).toBe(1));
    expect((await h.db.rows('expenses').toArray())[0]!.harvestDay).toBe('2026-09-20');
  });
});

describe('Insights (Q5-50)', () => {
  it('refuses a custom span out of the phone’s bounds', async () => {
    const h = await device(new FakeServer());
    show(h, <InsightsPanel />);
    await userEvent.click(await screen.findByRole('radio', { name: 'Custom' }));
    fireEvent.change(screen.getByLabelText('From'), {
      target: { value: '1900-01-01' },
    });
    expect(await screen.findByRole('alert')).toHaveTextContent(/Pick days between/);
  });
});

describe('the target weight (G5-05)', () => {
  it('is set, and cleared', async () => {
    const h = await device(new FakeServer());
    const { unmount } = show(h, <TargetWeightDialog target={null} unit="kg" onClose={() => {}} />);
    await userEvent.type(await screen.findByLabelText('Target'), '75.5');
    await userEvent.click(screen.getByRole('button', { name: 'Save' }));
    await waitFor(async () => expect(await readSetting(h.db, healthKeys.targetGrams)).toBe('75500'));
    unmount();
    show(h, <TargetWeightDialog target={75_500} unit="kg" onClose={() => {}} />);
    expect(await screen.findByLabelText('Target')).toHaveValue('75.5');
    await userEvent.click(screen.getByRole('button', { name: 'Clear target' }));
    await waitFor(async () => expect(await readSetting(h.db, healthKeys.targetGrams)).toBe(''));
  });
});

describe('a set badge (Q5-46)', () => {
  it('shows the number it is given, not a position', () => {
    render(<SetBadge number={2} openEnded={false} />);
    expect(screen.getByText('2')).toBeInTheDocument();
  });
});

describe('gym history (G5-10)', () => {
  it('keeps what the day was meant to be: instead of, and the note', async () => {
    const h = await device(new FakeServer());
    const program = await h.programs.createProgram('nSuns');
    const day = await h.programs.addDay(program.uuid, 'Day 1');
    const slot = await h.programs.addSlot(day.uuid, '0025');
    await h.programs.addTargetSet(slot.uuid, {
      reps: 5,
      weightGrams: 60_000,
      percentTenths: null,
      openEnded: false,
    });
    const tree = (await readProgram(h.db, program.uuid))!;
    const { session } = await h.sessions.start({
      day: tree.days[0]!,
      programUuid: program.uuid,
      trainingMaxes: new Map(),
    });
    const exercise = (await readSession(h.db, session.session.uuid))!.exercises[0]!;
    await h.sessions.replaceExercise(exercise.row.uuid, '0047');
    await h.sessions.setExerciseNote(exercise.row.uuid, 'rack was taken');
    await h.sessions.logSet(exercise.sets[0]!.uuid, {
      weightGrams: 60_000,
      reps: 5,
      done: true,
    });
    await h.sessions.finish(session.session.uuid);
    render(
      <HarvestContext.Provider value={h}>
        <MemoryRouter>
          <DialogsProvider>
            <GymPanel />
          </DialogsProvider>
        </MemoryRouter>
      </HarvestContext.Provider>,
    );
    expect(await screen.findByText(/^instead of /)).toBeInTheDocument();
    expect(screen.getByText('rack was taken')).toBeInTheDocument();
  });
});
