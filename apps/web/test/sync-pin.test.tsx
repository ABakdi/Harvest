import { deriveSyncKey, sealRow, syncSecretProblem } from '@harvest/contracts';
import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, describe, expect, it, vi } from 'vitest';
import expense from '../../../packages/contracts/fixtures/private-data/expenses.json';
import secrets from '../../../packages/contracts/fixtures/sync-secret.json';
import { PassphrasePrompt, pinDigits } from '@/app/components/passphrase-prompt';
import { HarvestContext } from '@/app/context';
import { FakeServer } from './fake-server';
import { device, testUser } from './helpers';

type Device = Awaited<ReturnType<typeof device>>;

afterEach(() => {
  vi.restoreAllMocks();
});

const fixture = secrets as { cases: { input: string; expected: string | null }[] };

function prompt(h: Device, onUnlocked = vi.fn()) {
  vi.spyOn(h.engine, 'sync').mockResolvedValue();
  render(
    <HarvestContext.Provider value={h}>
      <PassphrasePrompt onUnlocked={onUnlocked} />
    </HarvestContext.Provider>,
  );
  return onUnlocked;
}

/** A row another device sealed with [secret], waiting here to be opened. */
async function sealedWith(h: Device, secret: string) {
  const key = await deriveSyncKey(secret, testUser.syncSalt);
  const enc = await sealRow(key, 'expenses', expense.uuid, expense);
  await h.db.sealed.put({ table: 'expenses', uuid: expense.uuid, updatedAt: expense.updatedAt, deletedAt: null, enc });
}

describe('the sync secret rule on the web ([[Accounts]] AC7)', () => {
  it.each(fixture.cases)('reads $input as the phone does', ({ input, expected }) => {
    expect(syncSecretProblem(input)).toBe(expected);
  });

  it('keeps a PIN to ASCII digits, whatever keypad typed them', () => {
    expect(pinDigits('١٢٣٤')).toBe('1234');
    expect(pinDigits('۱۲۳۴۵۶')).toBe('123456');
    expect(pinDigits('12a3 4')).toBe('1234');
    expect(pinDigits('12345678')).toBe('123456');
  });
});

describe('the sync PIN prompt', () => {
  it('asks for a PIN by default: the number pad, obscured, never saved', async () => {
    const h = await device(new FakeServer());
    prompt(h);
    const field = await screen.findByLabelText('Sync PIN (4 to 6 digits)');
    expect(field).toHaveAttribute('type', 'password');
    expect(field).toHaveAttribute('inputmode', 'numeric');
    expect(field).toHaveAttribute('autocomplete', 'off');
    expect(field).toHaveAttribute('maxlength', '6');
    expect(screen.getByText(/A PIN is quick; a longer passphrase keeps your data safer/)).toBeInTheDocument();
  });

  it('on the first device, has it chosen and typed twice', async () => {
    const h = await device(new FakeServer());
    const unlocked = prompt(h);
    expect(await screen.findByRole('heading', { name: 'Choose a sync PIN' })).toBeInTheDocument();
    const user = userEvent.setup();
    await user.type(screen.getByLabelText('Sync PIN (4 to 6 digits)'), '123');
    await user.type(screen.getByLabelText('The same PIN again'), '123');
    await user.click(screen.getByRole('button', { name: 'Use it' }));
    expect(await screen.findByRole('alert')).toHaveTextContent('A PIN is at least 4 digits.');

    await user.type(screen.getByLabelText('Sync PIN (4 to 6 digits)'), '4');
    await user.type(screen.getByLabelText('The same PIN again'), '5');
    await user.click(screen.getByRole('button', { name: 'Use it' }));
    expect(await screen.findByRole('alert')).toHaveTextContent('The two do not match.');
    expect(await h.keyring.key(testUser.syncSalt)).toBeNull();

    fireEvent.change(screen.getByLabelText('The same PIN again'), { target: { value: '1234' } });
    await user.click(screen.getByRole('button', { name: 'Use it' }));
    await waitFor(() => expect(unlocked).toHaveBeenCalled(), { timeout: 15_000 });
    h.keyring.forget();
    expect(await h.keyring.key(testUser.syncSalt)).not.toBeNull();
  }, 20_000);

  it('switches to a passphrase of 8 characters or more, and back', async () => {
    const h = await device(new FakeServer());
    prompt(h);
    const user = userEvent.setup();
    await user.click(await screen.findByRole('button', { name: 'Use a passphrase instead' }));
    const field = screen.getByLabelText('Passphrase (8 characters or more)');
    expect(field).not.toHaveAttribute('inputmode');
    await user.type(field, 'short');
    await user.type(screen.getByLabelText('The same passphrase again'), 'short');
    await user.click(screen.getByRole('button', { name: 'Use it' }));
    expect(await screen.findByRole('alert')).toHaveTextContent('A passphrase is at least 8 characters.');

    await user.click(screen.getByRole('button', { name: 'Use a PIN instead' }));
    expect(screen.getByLabelText('Sync PIN (4 to 6 digits)')).toHaveValue('');
  });

  it('once something sealed is here, enters it once and checks it against that row', async () => {
    const h = await device(new FakeServer());
    await sealedWith(h, '2468');
    const unlocked = prompt(h);
    expect(await screen.findByRole('heading', { name: 'Enter your sync PIN' })).toBeInTheDocument();
    expect(screen.queryByLabelText('The same PIN again')).toBeNull();
    const user = userEvent.setup();

    await user.type(screen.getByLabelText('Sync PIN (4 to 6 digits)'), '1357');
    await user.click(screen.getByRole('button', { name: 'Unlock' }));
    expect(await screen.findByRole('alert', {}, { timeout: 15_000 })).toHaveTextContent(
      "This doesn't open what your other devices sent.",
    );
    expect(await h.keyring.key(testUser.syncSalt)).toBeNull();

    await user.clear(screen.getByLabelText('Sync PIN (4 to 6 digits)'));
    await user.type(screen.getByLabelText('Sync PIN (4 to 6 digits)'), '2468');
    await user.click(screen.getByRole('button', { name: 'Unlock' }));
    await waitFor(() => expect(unlocked).toHaveBeenCalled(), { timeout: 15_000 });
    expect(await h.db.rows('expenses').get(expense.uuid)).toMatchObject({ amountMinor: expense.amountMinor });
  }, 30_000);
});
