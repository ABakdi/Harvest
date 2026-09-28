import type { Me } from '@harvest/contracts';
import { LoaderIcon, WifiOffIcon } from 'lucide-react';
import { createContext, useContext, useEffect, useMemo, useRef, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { Link, Navigate, useLocation } from 'react-router';
import { HarvestMark } from '@/components/brand';
import { Button } from '@/components/ui/button';
import {
  api,
  finishSignOut,
  isServerTrouble,
  markSignOut,
  onSessionChange,
  refreshSession,
  resumeSession,
  signOutPending,
} from '@/lib/api';
import { AppShell } from './app-shell';
import { createHarvest, HarvestContext, type Harvest } from './context';
import { getMeta, HarvestDB, metaKeys, setMeta } from './data/db';
import { startSyncTriggers } from './sync/triggers';
import { wipeDrafts } from '@/lib/note-drafts';
import { background } from '@/lib/actions';

/** The one local store of this browser, opened only when /app is. */
let database: HarvestDB | null = null;
export function localDb(): HarvestDB {
  database ??= new HarvestDB();
  return database;
}

/**
 * Empties this browser (W5). The store is deleted outright rather than
 * emptied table by table, so nothing survives, not even the outbox.
 */
export async function wipeLocal(): Promise<void> {
  const db = localDb();
  db.close();
  await db.delete();
  database = null;
  // Unsaved note drafts live in localStorage: they go too (S6-11).
  wipeDrafts();
}

export { finishSignOut, signOutPendingKey } from '@/lib/api';

export type Boot =
  | { kind: 'loading' }
  | { kind: 'leaving' }
  /** The session ended elsewhere: the store is being forgotten. */
  | { kind: 'ending' }
  | { kind: 'left' }
  | { kind: 'ready'; harvest: Harvest; offline: boolean }
  | { kind: 'signedOut' }
  | { kind: 'offlineEmpty' }
  | { kind: 'failed' };

/**
 * Opens the session and the store. An access token this tab still holds
 * from before a reload says who is signed in; failing that, the refresh
 * cookie does. Offline — or with the server turning the refresh away
 * for now (429, 5xx) — the account this browser last saw is trusted, so
 * the app opens from IndexedDB all the same (W1); the next sync settles
 * whether the session still stands. Only a 401 means signed out, and
 * then this browser forgets the account's data (S5-15).
 */
export async function boot(): Promise<Boot> {
  // A sign-out still owed to the server: never pick that session up again.
  if (signOutPending()) {
    await finishSignOut();
    return { kind: 'signedOut' };
  }
  let db = localDb();
  await db.open();
  const known = (await getMeta<Me>(db, metaKeys.user)) ?? null;
  let user: Me;
  let offline = false;
  try {
    const result = resumeSession() ?? (await refreshSession());
    if (!result) {
      // The server said the session is gone (401), not that it could not
      // be reached: what this browser holds of the account goes too, as
      // on signing out (W5, S5-15), before the sign-in page.
      if (known) await wipeLocal();
      return { kind: 'signedOut' };
    }
    user = result.user;
  } catch (error) {
    if (!isServerTrouble(error)) return { kind: 'failed' };
    if (!known) return { kind: 'offlineEmpty' };
    user = known;
    offline = true;
  }
  if (known && known.id !== user.id) {
    // Another account's rows must never show under this one.
    await wipeLocal();
    db = localDb();
    await db.open();
  }
  await setMeta(db, metaKeys.user, user);
  return { kind: 'ready', harvest: createHarvest(db, user), offline };
}

/**
 * Signing out, or deleting the account, from inside the app. The shell
 * is taken down first, so no screen is still reading the store while it
 * is deleted (W5).
 */
export interface Leave {
  signOut(): void;
  /** Resolves when the server has deleted the account; rejects on a wrong password. */
  deleteAccount(password: string): Promise<void>;
}

export const LeaveContext = createContext<Leave | null>(null);

export function useLeave(): Leave {
  const leave = useContext(LeaveContext);
  if (!leave) throw new Error('useLeave outside the app');
  return leave;
}

export function AppRoot() {
  const { t } = useTranslation();
  const location = useLocation();
  const [state, setState] = useState<Boot>({ kind: 'loading' });
  // Set while this tab is the one leaving, so its own sign-out is not
  // mistaken for a session that ended elsewhere.
  const leaving = useRef(false);

  useEffect(() => {
    let live = true;
    background(boot().then((next) => {
      if (live) setState(next);
    }));
    return () => {
      live = false;
    };
  }, []);

  const harvest = state.kind === 'ready' ? state.harvest : null;
  // Bumped when the session brings a fresher account (verified in
  // another tab, say), so what shows it — the verify banner, the account
  // circle — draws again (Q6-18). The object itself stays the one the
  // sync engine and the file store read the salt from.
  const [freshUser, setFreshUser] = useState<Me | null>(null);
  const provided = useMemo(() => (harvest && freshUser ? { ...harvest, user: freshUser } : harvest), [harvest, freshUser]);

  useEffect(() => {
    if (state.kind !== 'leaving') return;
    background((async () => {
      // Remembered until the server has heard it: offline, the cookie and
      // the session would otherwise outlive the sign-out (S6-02).
      markSignOut(true);
      await finishSignOut();
      await wipeLocal();
      setState({ kind: 'left' });
    })());
  }, [state]);

  const leave: Leave = {
    signOut: () => {
      leaving.current = true;
      setState({ kind: 'leaving' });
    },
    deleteAccount: async (password: string) => {
      leaving.current = true;
      try {
        await api.deleteMe(password);
      } catch (error) {
        leaving.current = false;
        throw error;
      }
      setState({ kind: 'leaving' });
    },
  };

  useEffect(() => {
    if (!harvest) return;
    background(harvest.engine.refreshCounts());
    const stop = startSyncTriggers(harvest.engine, harvest.writer);
    // Each change here counts as waiting at once, not only after the next sync runs (W6-02).
    const offWrite = harvest.writer.onWrite(() => background(harvest.engine.refreshCounts()));
    // Signed out in another tab, or the session ended: this one follows.
    const off = onSessionChange((user) => {
      if (user) {
        harvest.user = user;
        setFreshUser(user);
        background(setMeta(harvest.db, metaKeys.user, user));
      } else if (!leaving.current) {
        // Ended elsewhere, or refused on refresh: the shell comes down,
        // and then the store, as on signing out (S5-15).
        leaving.current = true;
        setState({ kind: 'ending' });
        background(wipeLocal().then(() => setState({ kind: 'signedOut' })));
      }
    });
    // Ask the browser not to evict the store under storage pressure.
    background(navigator.storage?.persist?.());
    return () => {
      stop();
      offWrite();
      off();
    };
  }, [harvest]);

  if (state.kind === 'left') return <Navigate to="/" replace />;
  if (state.kind === 'loading' || state.kind === 'leaving' || state.kind === 'ending') {
    return (
      <div className="flex min-h-dvh flex-col items-center justify-center gap-3" role="status">
        <HarvestMark className="size-14" />
        <LoaderIcon className="size-5 animate-spin text-muted-foreground" aria-hidden />
        <span className="sr-only">{state.kind === 'leaving' ? t('app.leaving') : t('app.opening')}</span>
      </div>
    );
  }
  if (state.kind === 'signedOut') {
    return <Navigate to={`/login?next=${encodeURIComponent(location.pathname)}`} replace />;
  }
  if (state.kind === 'offlineEmpty' || state.kind === 'failed') {
    return (
      <div className="mx-auto flex min-h-dvh max-w-md flex-col items-center justify-center gap-4 px-4 text-center">
        <WifiOffIcon className="size-10 text-muted-foreground" aria-hidden />
        <h1 className="text-xl font-extrabold">
          {state.kind === 'offlineEmpty' ? t('app.offlineEmptyTitle') : t('app.bootFailedTitle')}
        </h1>
        <p className="text-muted-foreground">
          {state.kind === 'offlineEmpty' ? t('app.offlineEmptyBody') : t('app.bootFailedBody')}
        </p>
        <div className="flex gap-2">
          <Button onClick={() => window.location.reload()}>{t('common.tryAgain')}</Button>
          <Button asChild variant="outline">
            <Link to="/">{t('site.homeLink')}</Link>
          </Button>
        </div>
      </div>
    );
  }
  return (
    <LeaveContext.Provider value={leave}>
      <HarvestContext.Provider value={provided ?? state.harvest}>
        <AppShell startedOffline={state.offline} />
      </HarvestContext.Provider>
    </LeaveContext.Provider>
  );
}

export default AppRoot;
