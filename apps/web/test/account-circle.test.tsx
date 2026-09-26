import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { act, render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter } from 'react-router';
import { Toaster } from 'sonner';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { AccountCircle, accountMark } from '@/app/components/account-circle';
import { LeaveContext } from '@/app/app-root';
import { HarvestContext } from '@/app/context';
import type { SyncStatus } from '@/app/sync/engine';
import i18n from '@/i18n';
import { api } from '@/lib/api';
import { FakeServer } from './fake-server';
import { device, testUser } from './helpers';

type Device = Awaited<ReturnType<typeof device>>;

afterEach(async () => {
  vi.restoreAllMocks();
  await i18n.changeLanguage('en');
});

const idle: SyncStatus = {
  phase: 'idle',
  lastSyncedAt: '2026-09-19T11:55:00.000Z',
  pending: 0,
  invalid: 0,
  sealed: 0,
  locked: 0,
  firstSync: false,
  error: null,
};

function mount(h: Device, leave = { signOut: vi.fn(), deleteAccount: vi.fn() }) {
  vi.spyOn(api, 'sessions').mockResolvedValue({
    sessions: [
      {
        id: 's1',
        client: 'web',
        deviceName: 'This laptop',
        createdAt: '2026-09-01T10:00:00.000Z',
        lastSeenAt: '2026-09-19T11:00:00.000Z',
        current: true,
      },
      {
        id: 's2',
        client: 'android',
        deviceName: 'Pixel',
        createdAt: '2026-09-01T10:00:00.000Z',
        lastSeenAt: '2026-09-19T09:00:00.000Z',
        current: false,
      },
    ],
  } as Awaited<ReturnType<typeof api.sessions>>);
  render(
    <QueryClientProvider client={new QueryClient({ defaultOptions: { queries: { retry: false } } })}>
      <MemoryRouter>
        <LeaveContext.Provider value={leave}>
          <HarvestContext.Provider value={h}>
            <AccountCircle />
            <Toaster />
          </HarvestContext.Provider>
        </LeaveContext.Provider>
      </MemoryRouter>
    </QueryClientProvider>,
  );
  return leave;
}

describe('the account circle’s mark', () => {
  it('is green synced, amber waiting, grey offline and red when sync cannot go on', () => {
    expect(accountMark(idle)).toBe('synced');
    expect(accountMark({ ...idle, pending: 2 })).toBe('pending');
    expect(accountMark({ ...idle, locked: 1 })).toBe('pending');
    expect(accountMark({ ...idle, phase: 'syncing' })).toBe('pending');
    expect(accountMark({ ...idle, phase: 'offline', pending: 3 })).toBe('offline');
    expect(accountMark({ ...idle, phase: 'error' })).toBe('error');
    expect(accountMark({ ...idle, phase: 'signedOut' })).toBe('error');
    expect(accountMark({ ...idle, phase: 'unverified' })).toBe('error');
  });
});

describe('the account circle ([[Accounts]], on the web)', () => {
  it('carries the initial, the status and a dot while there is no sync PIN here', async () => {
    const h = await device(new FakeServer());
    mount(h);
    const circle = screen.getByRole('button', { name: 'Account and sync' });
    expect(circle).toHaveTextContent('F');
    await waitFor(() => expect(circle).toHaveAccessibleDescription(/No sync PIN in this browser/));
    expect(circle.querySelector('[data-no-pin]')).not.toBeNull();

    await act(() => h.keyring.unlock('2468', testUser.syncSalt, 1));
    await waitFor(() => expect(circle.querySelector('[data-no-pin]')).toBeNull());
    expect(circle).not.toHaveAccessibleDescription(/No sync PIN/);
  });

  it('opens the sheet from the keyboard: email, sync, the PIN, devices', async () => {
    const h = await device(new FakeServer());
    const sync = vi.spyOn(h.engine, 'sync').mockResolvedValue();
    mount(h);
    const user = userEvent.setup();
    screen.getByRole('button', { name: 'Account and sync' }).focus();
    await user.keyboard('{Enter}');

    const sheet = await screen.findByRole('dialog', { name: 'Account and sync' });
    expect(within(sheet).getByText(testUser.email)).toBeInTheDocument();
    expect(within(sheet).getByText('Verified')).toBeInTheDocument();
    expect(within(sheet).getByText('Online')).toBeInTheDocument();
    expect(within(sheet).getByText(/Money, places and pictures from your other devices stay locked/)).toBeInTheDocument();
    expect(await within(sheet).findByText('Pixel')).toBeInTheDocument();

    await user.click(within(sheet).getByRole('button', { name: 'Sync now' }));
    expect(sync).toHaveBeenCalled();

    await user.click(within(sheet).getByRole('button', { name: 'Enter your sync PIN' }));
    expect(await screen.findByLabelText('Sync PIN (4 to 6 digits)')).toBeInTheDocument();
  });

  it('forgets the PIN on this browser, after asking', async () => {
    const h = await device(new FakeServer());
    await h.keyring.unlock('2468', testUser.syncSalt, 1);
    mount(h);
    const user = userEvent.setup();
    await user.click(screen.getByRole('button', { name: 'Account and sync' }));
    const sheet = await screen.findByRole('dialog', { name: 'Account and sync' });
    await user.click(await within(sheet).findByRole('button', { name: 'Forget it on this browser' }));
    const confirm = await screen.findByRole('alertdialog');
    await user.click(within(confirm).getByRole('button', { name: 'Forget it on this browser' }));

    await waitFor(async () => expect(await h.keyring.key(testUser.syncSalt)).toBeNull());
    expect(await screen.findByText('Forgotten on this browser')).toBeInTheDocument();
    expect(await within(sheet).findByRole('button', { name: 'Enter your sync PIN' })).toBeInTheDocument();
  });

  it('warns before signing out with changes not sent', async () => {
    const h = await device(new FakeServer());
    vi.spyOn(h.engine, 'sync').mockResolvedValue();
    await h.notes.create({ title: 'Not sent yet' });
    const leave = mount(h);
    const user = userEvent.setup();
    await user.click(screen.getByRole('button', { name: 'Account and sync' }));
    const sheet = await screen.findByRole('dialog', { name: 'Account and sync' });
    await user.click(within(sheet).getByRole('button', { name: 'Sign out of this browser' }));

    const warning = await screen.findByRole('alertdialog');
    expect(within(warning).getByText('Some changes have not synced')).toBeInTheDocument();
    expect(leave.signOut).not.toHaveBeenCalled();
    await user.click(within(warning).getByRole('button', { name: 'Sign out anyway' }));
    expect(leave.signOut).toHaveBeenCalled();
  });

  it('reads right to left in Arabic', async () => {
    await i18n.changeLanguage('ar');
    const h = await device(new FakeServer());
    mount(h);
    expect(screen.getByRole('button', { name: 'الحساب والمزامنة' })).toBeInTheDocument();
  });
});
