import type { AdminOverview, Announcement } from '@harvest/contracts';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { runInNewContext } from 'node:vm';
import { MemoryRouter } from 'react-router';
import { Toaster } from 'sonner';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { AccountCircle } from '@/app/components/account-circle';
import { LeaveContext } from '@/app/app-root';
import { HarvestContext } from '@/app/context';
import { NewsPopup } from '@/app/components/news-popup';
import { NewsSection } from '@/app/components/news-settings';
import {
  appVersion,
  disablePush,
  enablePush,
  keyBytes,
  localDay,
  popupsToShow,
  pushStatus,
  sendHeartbeat,
  type PushApi,
} from '@/app/data/news';
import { AdminScreen, checkDraft, newsState, type AdminApi } from '@/app/screens/admin';
import { PrivacyPage } from '@/pages/site/privacy';
import i18n from '@/i18n';
import { api } from '@/lib/api';
import { getNewsPrefs, heartbeatDay, markNewsSeen, pushEndpoint, reloadNewsPrefs, seenNews, setNewsPrefs, setPushEndpoint } from '@/lib/news-prefs';
import { FakeServer } from './fake-server';
import { device, testUser } from './helpers';

/** The admin panel, the heartbeat, the news and Web Push ([[Admin]], Checkpoint 12). */

// Radix's switch measures itself; jsdom has no ResizeObserver.
globalThis.ResizeObserver ??= class {
  observe() {}
  unobserve() {}
  disconnect() {}
} as unknown as typeof ResizeObserver;

beforeEach(() => {
  localStorage.clear();
  reloadNewsPrefs();
});

afterEach(async () => {
  vi.restoreAllMocks();
  vi.unstubAllGlobals();
  localStorage.clear();
  reloadNewsPrefs();
  await i18n.changeLanguage('en');
});

const client = () => new QueryClient({ defaultOptions: { queries: { retry: false } } });

function news(id: string, fields: Partial<Announcement> = {}): Announcement {
  return {
    id,
    title: `News ${id}`,
    body: 'Update when you can.',
    link: null,
    push: false,
    popup: true,
    audience: 'everyone',
    startsAt: '2026-09-29T08:00:00.000Z',
    endsAt: null,
    createdAt: '2026-09-29T08:00:00.000Z',
    ...fields,
  };
}

const overview: AdminOverview = {
  accounts: { total: 42, verified: 40, newToday: 2, newWeek: 5, newMonth: 11 },
  active: { today: 17, week: 30, month: 38 },
  streaks: {
    sharing: 25,
    median: 6,
    mean: 9.4,
    longest: 120,
    bands: [
      { band: '0', accounts: 3 },
      { band: '7–13', accounts: 8 },
    ],
  },
  platforms: [
    { platform: 'android', accounts: 30 },
    { platform: 'web', accounts: 12 },
  ],
  versions: [{ version: '3.3.0', accounts: 28 }],
  downloads: { total: 512, releases: [{ tag: 'v3.3.0', name: 'Harvest 3.3.0', publishedAt: '2026-09-29T10:00:00.000Z', downloads: 120 }] },
  generatedAt: '2026-09-29T12:00:00.000Z',
};

function fakeAdmin(overrides: Partial<AdminApi> = {}): AdminApi {
  return {
    adminOverview: vi.fn(() => Promise.resolve(overview)),
    adminHistory: vi.fn((days: number) =>
      Promise.resolve({
        days: Array.from({ length: Math.min(days, 3) }, (_, i) => ({
          day: `2026-09-2${7 + i}`,
          accounts: 40 + i,
          verified: 38 + i,
          signups: i,
          active: 10 + i,
          active7: 20 + i,
          active30: 30 + i,
          sharing: 20,
          streakMedian: 5 + i,
          streakMean: 7,
        })),
      }),
    ),
    adminUsers: vi.fn((query: { q?: string; cursor?: string } = {}) =>
      Promise.resolve(
        query.cursor
          ? { users: [{ id: 'b'.repeat(24), email: 'second@example.com', displayName: null, createdAt: '2026-09-02T10:00:00.000Z', verifiedAt: null, lastActiveAt: null, platform: null, appVersion: null, streak: null }], next: null }
          : {
              users: [
                {
                  id: 'a'.repeat(24),
                  email: query.q ? `${query.q}@example.com` : 'first@example.com',
                  displayName: 'Warda',
                  createdAt: '2026-09-01T10:00:00.000Z',
                  verifiedAt: '2026-09-01T10:05:00.000Z',
                  lastActiveAt: '2026-09-29T09:00:00.000Z',
                  platform: 'android',
                  appVersion: '3.3.0',
                  streak: { current: 12, best: 40 },
                },
              ],
              next: query.q ? null : 'a'.repeat(24),
            },
      ),
    ),
    adminAnnouncements: vi.fn(() => Promise.resolve({ announcements: [{ ...news('n1', { push: true }), pushed: 7 }] })),
    createAnnouncement: vi.fn((body) => Promise.resolve({ ...news('n2'), ...body } as Announcement)),
    endAnnouncement: vi.fn(() => Promise.resolve(news('n1'))),
    deleteAnnouncement: vi.fn(() => Promise.resolve()),
    adminReports: vi.fn(() => Promise.resolve({ reports: [], next: null, unread: 0 })),
    setReportStatus: vi.fn(() => Promise.reject(new Error('no reports here'))),
    deleteReport: vi.fn(() => Promise.resolve()),
    reportAttachment: vi.fn(() => Promise.resolve(new Blob())),
    ...overrides,
  };
}

function renderAdmin(source: AdminApi) {
  render(
    <QueryClientProvider client={client()}>
      <MemoryRouter>
        <AdminScreen source={source} />
        <Toaster />
      </MemoryRouter>
    </QueryClientProvider>,
  );
}

describe('the admin panel', () => {
  it('shows the counts, the charts over time and the downloads', async () => {
    const source = fakeAdmin();
    renderAdmin(source);
    expect(await screen.findByText('42')).toBeInTheDocument();
    expect(screen.getByText('17')).toBeInTheDocument();
    expect(screen.getByText('512')).toBeInTheDocument();
    expect(screen.getByText(/40 verified/)).toBeInTheDocument();
    expect(await screen.findByRole('img', { name: /^Accounts from/ })).toBeInTheDocument();
    expect(screen.getByText('Harvest 3.3.0')).toBeInTheDocument();
    expect(screen.getByText('Android')).toBeInTheDocument();

    const user = userEvent.setup();
    await user.click(screen.getByRole('radio', { name: '90 days' }));
    await waitFor(() => expect(source.adminHistory).toHaveBeenCalledWith(90));
  });

  it('says so when GitHub could not be asked', async () => {
    renderAdmin(fakeAdmin({ adminOverview: vi.fn(() => Promise.resolve({ ...overview, downloads: null })) }));
    expect(await screen.findAllByText('GitHub could not be asked just now.')).toHaveLength(2);
  });

  it('lists accounts, searches them and pages on', async () => {
    const source = fakeAdmin();
    renderAdmin(source);
    const user = userEvent.setup();
    await user.click(screen.getByRole('tab', { name: 'Users' }));
    expect(await screen.findByText('first@example.com')).toBeInTheDocument();
    expect(screen.getByText('12 (best 40)')).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Show more' }));
    expect(await screen.findByText('second@example.com')).toBeInTheDocument();
    expect(screen.getByText('Not shared')).toBeInTheDocument();
    await user.type(screen.getByRole('searchbox', { name: 'Search by email' }), 'warda');
    await user.click(screen.getByRole('button', { name: 'Search' }));
    expect(await screen.findByText('warda@example.com')).toBeInTheDocument();
    expect(source.adminUsers).toHaveBeenCalledWith(expect.objectContaining({ q: 'warda' }));
  });

  it('writes news, refusing what the server would, and ends and deletes it', async () => {
    const source = fakeAdmin();
    renderAdmin(source);
    const user = userEvent.setup();
    await user.click(screen.getByRole('tab', { name: 'News' }));
    expect(await screen.findByText('Push · 7 sent')).toBeInTheDocument();

    await user.click(screen.getByRole('button', { name: 'Publish' }));
    expect(await screen.findByText('A title of up to 80 characters.')).toBeInTheDocument();
    expect(source.createAnnouncement).not.toHaveBeenCalled();

    await user.type(screen.getByLabelText('Title'), 'Harvest 3.3');
    await user.type(screen.getByLabelText('Message'), 'Update when you can.');
    await user.type(screen.getByLabelText('Link (optional)'), 'http://example.com');
    await user.click(screen.getByRole('button', { name: 'Publish' }));
    expect(await screen.findByText('An address starting with https://, or nothing.')).toBeInTheDocument();

    await user.clear(screen.getByLabelText('Link (optional)'));
    await user.click(screen.getByRole('switch', { name: 'Show as a pop-up when the app opens' }));
    await user.click(screen.getByRole('button', { name: 'Publish' }));
    await waitFor(() =>
      expect(source.createAnnouncement).toHaveBeenCalledWith({
        title: 'Harvest 3.3',
        body: 'Update when you can.',
        link: null,
        push: true,
        popup: true,
        audience: 'everyone',
        startsAt: null,
        endsAt: null,
      }),
    );

    await user.click(screen.getByRole('button', { name: 'End now' }));
    await waitFor(() => expect(source.endAnnouncement).toHaveBeenCalledWith('n1', expect.any(String)));
    await user.click(screen.getByRole('button', { name: 'Delete' }));
    const confirm = await screen.findByRole('alertdialog');
    await user.click(within(confirm).getByRole('button', { name: 'Delete' }));
    await waitFor(() => expect(source.deleteAnnouncement).toHaveBeenCalledWith('n1'));
  });

  it('checks a draft as the contract does', () => {
    const draft = { title: 'Hi', body: 'There', link: '', push: false, popup: false, audience: 'everyone' as const, startsAt: '', endsAt: '' };
    expect(checkDraft(draft)).toEqual({ problems: { push: true } });
    expect(checkDraft({ ...draft, push: true, startsAt: '2026-10-02T10:00', endsAt: '2026-10-01T10:00' })).toEqual({ problems: { endsAt: true } });
    const ok = checkDraft({ ...draft, popup: true, startsAt: '2026-10-01T10:00' });
    expect('body' in ok && ok.body.startsAt).toBe(new Date('2026-10-01T10:00').toISOString());
  });

  it('knows live, scheduled and ended', () => {
    const now = new Date('2026-09-29T12:00:00Z');
    expect(newsState({ startsAt: '2026-09-29T08:00:00Z', endsAt: null }, now)).toBe('live');
    expect(newsState({ startsAt: '2026-09-30T08:00:00Z', endsAt: null }, now)).toBe('scheduled');
    expect(newsState({ startsAt: '2026-09-28T08:00:00Z', endsAt: '2026-09-29T11:00:00Z' }, now)).toBe('ended');
  });
});

describe('who reaches the admin panel', () => {
  async function sheetFor(admin: boolean) {
    const h = await device(new FakeServer(), undefined, { ...testUser, admin });
    vi.spyOn(api, 'sessions').mockResolvedValue({ sessions: [] });
    render(
      <QueryClientProvider client={client()}>
        <MemoryRouter>
          <LeaveContext.Provider value={{ signOut: vi.fn(), deleteAccount: vi.fn() }}>
            <HarvestContext.Provider value={h}>
              <AccountCircle />
            </HarvestContext.Provider>
          </LeaveContext.Provider>
        </MemoryRouter>
      </QueryClientProvider>,
    );
    await userEvent.setup().click(screen.getByRole('button', { name: 'Account and sync' }));
    return screen.findByRole('dialog');
  }

  it('an admin finds it in the account sheet', async () => {
    const sheet = await sheetFor(true);
    expect(within(sheet).getByRole('link', { name: 'Admin' })).toHaveAttribute('href', '/app/admin');
  });

  it('anyone else does not', async () => {
    const sheet = await sheetFor(false);
    expect(within(sheet).queryByRole('link', { name: 'Admin' })).toBeNull();
  });

  it('the shell sends anyone else from /app/admin to the field', () => {
    const shell = readFileSync(resolve(__dirname, '../src/app/app-shell.tsx'), 'utf8');
    expect(shell).toMatch(/path="admin" element=\{user\.admin === true \? <AdminScreen \/> : <Navigate to="\/app\/field" replace \/>\}/);
  });
});

describe('the heartbeat', () => {
  it('goes once a day, with the version and the streak while it is shared', async () => {
    const h = await device(new FakeServer());
    await h.db.rows('streaks').put({ scope: 'global', current: 6, best: 14, lastEarnedDay: '2026-09-28', freezesStored: 0, updatedAt: '2026-09-28T10:00:00.000Z' });
    const beat = { heartbeat: vi.fn(() => Promise.resolve()) };
    const morning = new Date('2026-09-29T08:00:00');

    expect(await sendHeartbeat(h.db, beat, morning)).toBe(true);
    expect(beat.heartbeat).toHaveBeenCalledWith({ platform: 'web', appVersion, streak: { current: 6, best: 14 } });
    expect(heartbeatDay()).toBe(localDay(morning));
    // Again the same day: nothing.
    expect(await sendHeartbeat(h.db, beat, new Date('2026-09-29T20:00:00'))).toBe(false);
    expect(beat.heartbeat).toHaveBeenCalledTimes(1);

    // Not shared any more: the next day it goes without the streak.
    setNewsPrefs({ shareStreak: false });
    expect(await sendHeartbeat(h.db, beat, new Date('2026-09-30T08:00:00'))).toBe(true);
    expect(beat.heartbeat).toHaveBeenLastCalledWith({ platform: 'web', appVersion, streak: null });
  });

  it('keeps quiet on a failure, and tries again next time', async () => {
    const h = await device(new FakeServer());
    const beat = { heartbeat: vi.fn(() => Promise.reject(new Error('offline'))) };
    expect(await sendHeartbeat(h.db, beat, new Date('2026-09-29T08:00:00'))).toBe(false);
    expect(heartbeatDay()).toBeNull();
  });

  it('carries the phone’s version number for the release', () => {
    expect(appVersion).toMatch(/^\d+\.\d+\.\d+/);
  });

  it('turning Share my streak off says it again today, without the streak', async () => {
    render(<NewsSection push={{ pushKey: vi.fn(), subscribePush: vi.fn(), unsubscribePush: vi.fn() }} />);
    localStorage.setItem('harvest.heartbeatDay', '2026-09-29');
    await userEvent.setup().click(screen.getByRole('switch', { name: 'Share my streak' }));
    expect(getNewsPrefs().shareStreak).toBe(false);
    expect(heartbeatDay()).toBeNull();
  });
});

describe('the news pop-up', () => {
  it('shows each live pop-up once, newest first, and remembers it', async () => {
    const source = {
      announcements: vi.fn(() =>
        Promise.resolve({
          announcements: [
            news('old', { startsAt: '2026-09-20T08:00:00.000Z' }),
            news('new', { startsAt: '2026-09-28T08:00:00.000Z', link: 'https://harvest.abakdi.com/download' }),
            news('push-only', { popup: false }),
          ],
        }),
      ),
    };
    const user = userEvent.setup();
    const { unmount } = render(<NewsPopup source={source} />);
    expect(await screen.findByRole('dialog', { name: 'News new' })).toBeInTheDocument();
    expect(screen.getByRole('link', { name: 'Open' })).toHaveAttribute('href', 'https://harvest.abakdi.com/download');
    await user.click(screen.getByRole('button', { name: 'Got it' }));
    expect(await screen.findByRole('dialog', { name: 'News old' })).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Got it' }));
    await waitFor(() => expect(screen.queryByRole('dialog')).toBeNull());
    expect([...seenNews()].sort()).toEqual(['new', 'old']);
    unmount();

    // The next opening: nothing new to show.
    render(<NewsPopup source={source} />);
    await waitFor(() => expect(source.announcements).toHaveBeenCalledTimes(2));
    expect(screen.queryByRole('dialog')).toBeNull();
  });

  it('never asks while News from Harvest is off', async () => {
    setNewsPrefs({ news: false });
    const source = { announcements: vi.fn(() => Promise.resolve({ announcements: [news('a')] })) };
    render(<NewsPopup source={source} />);
    await new Promise((resolve) => setTimeout(resolve, 20));
    expect(source.announcements).not.toHaveBeenCalled();
  });

  it('leaves out what is not live yet, or not any more', () => {
    const now = new Date('2026-09-29T12:00:00Z');
    markNewsSeen('seen');
    const shown = popupsToShow(
      [news('seen'), news('later', { startsAt: '2026-09-30T00:00:00Z' }), news('over', { endsAt: '2026-09-29T11:00:00Z' }), news('now')],
      seenNews(),
      now,
    );
    expect(shown.map((item) => item.id)).toEqual(['now']);
  });
});

describe('web push', () => {
  function pushApi(key: string | null = 'BAAA') {
    const pushKey = vi.fn(() => Promise.resolve(key));
    const subscribePush = vi.fn(() => Promise.resolve());
    const unsubscribePush = vi.fn(() => Promise.resolve());
    const client: PushApi = { pushKey, subscribePush, unsubscribePush };
    return { client, pushKey, subscribePush, unsubscribePush };
  }

  function stubBrowser(permission: NotificationPermission = 'default', granted: NotificationPermission = 'granted') {
    let subscription: PushSubscription | null = null;
    const unsubscribe = vi.fn(() => {
      subscription = null;
      return Promise.resolve(true);
    });
    const pushManager = {
      getSubscription: vi.fn(() => Promise.resolve(subscription)),
      subscribe: vi.fn(() => {
        subscription = {
          endpoint: 'https://push.example/abc',
          toJSON: () => ({ endpoint: 'https://push.example/abc', keys: { p256dh: 'p', auth: 'a' } }),
          unsubscribe,
        } as unknown as PushSubscription;
        return Promise.resolve(subscription);
      }),
    };
    const requestPermission = vi.fn(() => Promise.resolve(granted));
    vi.stubGlobal('PushManager', function PushManager() {});
    vi.stubGlobal('Notification', Object.assign(function Notification() {}, { permission, requestPermission }));
    Object.defineProperty(navigator, 'serviceWorker', {
      configurable: true,
      value: { getRegistration: vi.fn(() => Promise.resolve({ pushManager })) },
    });
    return { pushManager, requestPermission, unsubscribe };
  }

  afterEach(() => {
    Reflect.deleteProperty(navigator, 'serviceWorker');
  });

  it('subscribes only on a tap, with the server’s key, and tells the server', async () => {
    const browser = stubBrowser();
    const server = pushApi();
    expect(await pushStatus()).toBe('off');
    expect(await enablePush(server.client)).toBe('on');
    expect(browser.requestPermission).toHaveBeenCalledTimes(1);
    expect(browser.pushManager.subscribe).toHaveBeenCalledWith({ userVisibleOnly: true, applicationServerKey: keyBytes('BAAA') });
    expect(server.subscribePush).toHaveBeenCalledWith({ endpoint: 'https://push.example/abc', keys: { p256dh: 'p', auth: 'a' } });
    expect(pushEndpoint()).toBe('https://push.example/abc');
    expect(await pushStatus()).toBe('on');

    await disablePush(server.client);
    expect(browser.unsubscribe).toHaveBeenCalled();
    expect(server.unsubscribePush).toHaveBeenCalledWith('https://push.example/abc');
    expect(pushEndpoint()).toBeNull();
    expect(await pushStatus()).toBe('off');
  });

  it('stops at a refusal, and at a server that sends no push', async () => {
    stubBrowser('default', 'denied');
    expect(await enablePush(pushApi().client)).toBe('denied');
    stubBrowser();
    const noKey = pushApi(null);
    expect(await enablePush(noKey.client)).toBe('unsupported');
    expect(noKey.subscribePush).not.toHaveBeenCalled();
  });

  it('is not offered where there is no service worker', async () => {
    expect(await pushStatus()).toBe('unsupported');
  });

  it('takes back a subscription the browser lost, by the endpoint it remembers', async () => {
    stubBrowser();
    setPushEndpoint('https://push.example/old');
    const server = pushApi();
    await disablePush(server.client);
    expect(server.unsubscribePush).toHaveBeenCalledWith('https://push.example/old');
  });

  it('reads a base64url key into bytes', () => {
    expect([...keyBytes('AQID')]).toEqual([1, 2, 3]);
    expect([...keyBytes('-_8')]).toEqual([251, 255]);
  });
});

describe('the service worker’s push script', () => {
  it('shows what comes and opens the app or the link', async () => {
    const source = readFileSync(resolve(__dirname, '../public/push-sw.js'), 'utf8');
    const handlers: Record<string, (event: unknown) => void> = {};
    const showNotification = vi.fn(() => Promise.resolve());
    const openWindow = vi.fn(() => Promise.resolve());
    const worker = {
      addEventListener: (type: string, handler: (event: unknown) => void) => {
        handlers[type] = handler;
      },
      registration: { showNotification },
      location: { origin: 'https://harvest.abakdi.com' },
    };
    const clients = { matchAll: vi.fn(() => Promise.resolve([])), openWindow };
    runInNewContext(source, { self: worker, clients, URL });

    let waited: Promise<unknown> = Promise.resolve();
    handlers.push!({
      data: { json: () => ({ id: 'n1', title: 'Harvest 3.3', body: 'Update', link: 'https://harvest.abakdi.com/download' }) },
      waitUntil: (promise: Promise<unknown>) => {
        waited = promise;
      },
    });
    await waited;
    expect(showNotification).toHaveBeenCalledWith('Harvest 3.3', expect.objectContaining({ body: 'Update', tag: 'news-n1', data: { link: 'https://harvest.abakdi.com/download' } }));

    const close = vi.fn();
    handlers.notificationclick!({
      notification: { close, data: { link: 'https://harvest.abakdi.com/download' } },
      waitUntil: (promise: Promise<unknown>) => {
        waited = promise;
      },
    });
    await waited;
    expect(close).toHaveBeenCalled();
    expect(openWindow).toHaveBeenCalledWith('https://harvest.abakdi.com/download');

    handlers.notificationclick!({ notification: { close, data: { link: null } }, waitUntil: (promise: Promise<unknown>) => (waited = promise) });
    await waited;
    expect(openWindow).toHaveBeenLastCalledWith('https://harvest.abakdi.com/app');
  });
});

describe('the privacy page says it', () => {
  it('names the news, push, the heartbeat and what the admin sees', () => {
    render(
      <MemoryRouter>
        <PrivacyPage />
      </MemoryRouter>,
    );
    expect(screen.getByText('News from Harvest, while it is on')).toBeInTheDocument();
    expect(screen.getByText('Notifications, if you allow them')).toBeInTheDocument();
    expect(screen.getByText('That you use it, and your streak if you share it')).toBeInTheDocument();
    expect(screen.getByText('What whoever runs the server can see')).toBeInTheDocument();
  });
});
