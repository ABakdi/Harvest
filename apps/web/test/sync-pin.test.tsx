import { syncSecretProblem } from '@harvest/contracts';
import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, describe, expect, it, vi } from 'vitest';
import secrets from '../../../packages/contracts/fixtures/sync-secret.json';
import { howLongItStands, PassphrasePrompt, pinDigits } from '@/app/components/passphrase-prompt';
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
  it('asks for a passphrase by default (M7.5): hidden until shown, never saved, and how long it would stand', async () => {
    const h = await device(new FakeServer());
    prompt(h);
    const field = await screen.findByLabelText('Passphrase (a few words, 8 characters or more)');
    expect(field).toHaveAttribute('type', 'password');
    expect(field).not.toHaveAttribute('inputmode');
    expect(field).toHaveAttribute('autocomplete', 'off');
    const user = userEvent.setup();
    await user.click(screen.getByRole('button', { name: 'Show' }));
    expect(field).toHaveAttribute('type', 'text');
    await user.click(screen.getByRole('button', { name: 'Hide' }));
    expect(field).toHaveAttribute('type', 'password');

    // The trade-off sits beside the way to a PIN.
    expect(screen.getByText(/could try every PIN in minutes/)).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Use a PIN instead' })).toBeInTheDocument();

    fireEvent.change(field, { target: { value: 'olives' } });
    expect(await screen.findByText('Weak:')).toBeInTheDocument();
    fireEvent.change(field, { target: { value: 'olive tamarind harbour lantern' } });
    expect(await screen.findByText('Strong:')).toBeInTheDocument();
    expect(screen.getByText(/it would stand millions of years/)).toBeInTheDocument();
  });

  it('keeps a PIN one tap away: the number pad, obscured, and what it would stand said plainly', async () => {
    const h = await device(new FakeServer());
    prompt(h);
    const user = userEvent.setup();
    await user.click(await screen.findByRole('button', { name: 'Use a PIN instead' }));
    const field = screen.getByLabelText('Sync PIN (4 to 6 digits)');
    expect(field).toHaveAttribute('type', 'password');
    expect(field).toHaveAttribute('inputmode', 'numeric');
    expect(field).toHaveAttribute('maxlength', '6');
    expect(screen.getByText(/A PIN falls in minutes/)).toBeInTheDocument();
    fireEvent.change(field, { target: { value: '482917' } });
    expect(await screen.findByText('A PIN:')).toBeInTheDocument();
    expect(screen.getByText(/it would stand about 26 seconds/)).toBeInTheDocument();
  });

  it('tells how long a secret stands in words, to the largest unit, and past a thousand years only its order', () => {
    expect(howLongItStands(0.4)).toEqual({ key: 'instantly' });
    expect(howLongItStands(26)).toEqual({ key: 'seconds', count: 26 });
    expect(howLongItStands(52 * 60)).toEqual({ key: 'minutes', count: 52 });
    expect(howLongItStands(5 * 3600)).toEqual({ key: 'hours', count: 5 });
    expect(howLongItStands(40 * 86_400)).toEqual({ key: 'days', count: 40 });
    expect(howLongItStands(12 * 365 * 86_400)).toEqual({ key: 'years', count: 12 });
    expect(howLongItStands(3570 * 365 * 86_400)).toEqual({ key: 'thousandsOfYears' });
    expect(howLongItStands(1e15)).toEqual({ key: 'millionsOfYears' });
  });

  it('on the first device, has it chosen and typed twice', async () => {
    const h = await device(new FakeServer());
    const unlocked = prompt(h);
    expect(await screen.findByRole('heading', { name: 'Choose a sync PIN' })).toBeInTheDocument();
    const user = userEvent.setup();
    await user.click(screen.getByRole('button', { name: 'Use a PIN instead' }));
    await user.type(screen.getByLabelText('Sync PIN (4 to 6 digits)'), '123');
    await user.type(screen.getByLabelText('The same PIN again'), '123');
    await user.click(screen.getByRole('button', { name: 'Use it' }));
    expect(await screen.findByRole('alert')).toHaveTextContent('A PIN is at least 4 digits.');

    // One anyone would try first is refused when it is chosen.
    await user.type(screen.getByLabelText('Sync PIN (4 to 6 digits)'), '4');
    await user.type(screen.getByLabelText('The same PIN again'), '4');
    await user.click(screen.getByRole('button', { name: 'Use it' }));
    expect(await screen.findByRole('alert')).toHaveTextContent('Too easy to guess.');

    fireEvent.change(screen.getByLabelText('Sync PIN (4 to 6 digits)'), { target: { value: '1239' } });
    fireEvent.change(screen.getByLabelText('The same PIN again'), { target: { value: '1235' } });
    await user.click(screen.getByRole('button', { name: 'Use it' }));
    expect(await screen.findByRole('alert')).toHaveTextContent('The two do not match.');
    expect(await h.keyring.key(testUser.syncSalt)).toBeNull();

    fireEvent.change(screen.getByLabelText('The same PIN again'), { target: { value: '1239' } });
    await user.click(screen.getByRole('button', { name: 'Use it' }));
    await waitFor(() => expect(unlocked).toHaveBeenCalled(), { timeout: 15_000 });
    h.keyring.forget();
    expect(await h.keyring.key(testUser.syncSalt)).not.toBeNull();
  }, 20_000);

  it('refuses a passphrase under 8 characters, and switches to a PIN and back', async () => {
    const h = await device(new FakeServer());
    prompt(h);
    const user = userEvent.setup();
    expect(await screen.findByRole('heading', { name: 'Choose a sync PIN' })).toBeInTheDocument();
    const field = screen.getByLabelText('Passphrase (a few words, 8 characters or more)');
    expect(field).not.toHaveAttribute('inputmode');
    await user.type(field, 'short');
    await user.type(screen.getByLabelText('The same passphrase again'), 'short');
    await user.click(screen.getByRole('button', { name: 'Use it' }));
    expect(await screen.findByRole('alert')).toHaveTextContent('A passphrase is at least 8 characters.');

    await user.click(screen.getByRole('button', { name: 'Use a PIN instead' }));
    expect(screen.getByLabelText('Sync PIN (4 to 6 digits)')).toHaveValue('');
    await user.click(screen.getByRole('button', { name: 'Use a passphrase instead' }));
    expect(screen.getByLabelText('Passphrase (a few words, 8 characters or more)')).toHaveValue('');
  });

  it('once the account has a PIN, enters it once, and a wrong one is refused on the spot', async () => {
    const server = new FakeServer();
    const first = await device(server);
    await first.keyring.unlock('2468', testUser.syncSalt);
    const uuid = await first.money.log({
      amountMinor: 45_000,
      currency: 'DZD',
      category: 'food',
      note: 'Couscous',
      fromWallet: false,
      day: '2026-09-19',
    });
    await first.engine.sync();

    const h = await device(server);
    await h.engine.sync();
    const unlocked = prompt(h);
    expect(await screen.findByRole('heading', { name: 'Enter your sync PIN' })).toBeInTheDocument();
    expect(screen.queryByLabelText('The same PIN again')).toBeNull();
    const user = userEvent.setup();

    // Entering, one field takes either: a PIN typed there is the PIN.
    const field = screen.getByLabelText('Sync passphrase or PIN');
    await user.type(field, '1357');
    await user.click(screen.getByRole('button', { name: 'Unlock' }));
    expect(await screen.findByRole('alert', {}, { timeout: 15_000 })).toHaveTextContent(
      "That isn't the PIN your other devices use.",
    );
    expect(await h.keyring.key(testUser.syncSalt)).toBeNull();

    // In the digits of an Arabic keypad, all the same.
    await user.clear(field);
    await user.type(field, '٢٤٦٨');
    await user.click(screen.getByRole('button', { name: 'Unlock' }));
    await waitFor(() => expect(unlocked).toHaveBeenCalled(), { timeout: 15_000 });
    expect(await h.db.rows('expenses').get(uuid)).toMatchObject({ amountMinor: 45_000 });
  }, 30_000);

  it('a fresh browser with nothing pulled yet still enters, never chooses a second PIN (Q5-01)', async () => {
    const server = new FakeServer();
    const first = await device(server);
    await first.keyring.unlock('2468', testUser.syncSalt, 1);
    const h = await device(server);
    prompt(h);
    expect(await screen.findByRole('heading', { name: 'Enter your sync PIN' })).toBeInTheDocument();
    expect(await screen.findByRole('button', { name: 'Forgot the PIN? Start over' })).toBeInTheDocument();
  });

  it('starts over with the password, after saying what goes', async () => {
    const server = new FakeServer();
    const first = await device(server);
    await first.keyring.unlock('2468', testUser.syncSalt, 1);
    const h = await device(server);
    prompt(h);
    const user = userEvent.setup();
    await user.click(await screen.findByRole('button', { name: 'Forgot the PIN? Start over' }));
    expect(await screen.findByText(/This deletes everything kept on the server for this account/)).toBeInTheDocument();
    await user.type(screen.getByLabelText('Your account password'), 'not it');
    await user.click(screen.getByRole('button', { name: 'Start over' }));
    expect(await screen.findByText("That isn't this account's password.")).toBeInTheDocument();
    expect(server.check).not.toBeNull();

    await user.clear(screen.getByLabelText('Your account password'));
    await user.type(screen.getByLabelText('Your account password'), 'the password');
    await user.click(screen.getByRole('button', { name: 'Start over' }));
    expect(await screen.findByRole('heading', { name: 'Choose a sync PIN' })).toBeInTheDocument();
    expect(server.check).toBeNull();
  });
});
