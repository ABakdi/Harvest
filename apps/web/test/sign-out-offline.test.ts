import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { boot, finishSignOut, localDb, signOutPendingKey, wipeLocal } from '@/app/app-root';
import { metaKeys, setMeta } from '@/app/data/db';
import { api, resetApiForTests } from '@/lib/api';
import { keepDraft, leftDrafts } from '@/lib/note-drafts';
import { testUser } from './helpers';

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), { status, headers: { 'content-type': 'application/json' } });
const ok = () => json(200, { accessToken: 'fresh', expiresIn: 900, user: testUser });

describe('a sign-out the server has not heard (S6-02)', () => {
  beforeEach(async () => {
    await wipeLocal();
    localStorage.clear();
    resetApiForTests();
    const db = localDb();
    await db.open();
    await setMeta(db, metaKeys.user, testUser);
  });

  afterEach(() => {
    vi.restoreAllMocks();
    localStorage.clear();
  });

  it('never resumes that session, and is said to the server once it can be', async () => {
    localStorage.setItem(signOutPendingKey, '1');
    const fetch = vi.spyOn(globalThis, 'fetch').mockRejectedValue(new TypeError('offline'));
    // The refresh cookie would sign straight back in: it is never asked.
    expect(await boot()).toMatchObject({ kind: 'signedOut' });
    expect(fetch.mock.calls.every(([url]) => !(url as string).includes('/v1/auth/refresh'))).toBe(true);
    expect(localStorage.getItem(signOutPendingKey)).not.toBeNull();

    fetch.mockReset();
    fetch.mockResolvedValue(new Response(null, { status: 204 }));
    expect(await finishSignOut()).toBe(true);
    expect(fetch.mock.calls[0]![0] as string).toContain('/v1/auth/logout');
    expect(localStorage.getItem(signOutPendingKey)).toBeNull();

    fetch.mockResolvedValue(ok());
    expect(await boot()).toMatchObject({ kind: 'ready' });
  });
});

describe('a sign-in after a sign-out the server has not heard (S6-02)', () => {
  afterEach(() => {
    vi.restoreAllMocks();
    localStorage.clear();
  });

  it('ends the old session first, so the next start does not end the new one', async () => {
    localStorage.setItem(signOutPendingKey, '1');
    const fetch = vi
      .spyOn(globalThis, 'fetch')
      .mockImplementation((input) =>
        Promise.resolve((input as string).includes('/logout') ? new Response(null, { status: 204 }) : ok()),
      );
    await api.login({ email: 'a@b.test', password: 'Tomato-Basket-42' });
    const urls = fetch.mock.calls.map(([url]) => url as string);
    expect(urls[0]).toContain('/v1/auth/logout');
    expect(urls[1]).toContain('/v1/auth/login');
    expect(localStorage.getItem(signOutPendingKey)).toBeNull();
  });
});

describe('what signing out wipes (S6-11)', () => {
  it('takes the note drafts in localStorage with the store', async () => {
    keepDraft('n1', { title: 'Secret', folder: '', body: 'not saved yet', at: new Date().toISOString() });
    expect(leftDrafts()).toHaveLength(1);
    localStorage.setItem('harvest.themeMode', 'dark');
    await wipeLocal();
    expect(leftDrafts()).toHaveLength(0);
    // A device preference is not the account's data.
    expect(localStorage.getItem('harvest.themeMode')).toBe('dark');
  });
});
