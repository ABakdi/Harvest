import { useLiveQuery } from 'dexie-react-hooks';
import { useEffect, useState, type RefObject } from 'react';
import { useHarvest } from './context';
import type { FileMiss } from './data/files';
import { readSetting, settingKeys } from './data/settings';
import { background } from '@/lib/actions';

/** Whether this browser holds the private tier's key; undefined while it looks. */
export function usePrivateKey(): boolean | undefined {
  const { keyring, user } = useHarvest();
  const [unlocked, setUnlocked] = useState<boolean | undefined>(undefined);
  useEffect(() => {
    let live = true;
    const check = () =>
      background(keyring.key(user.syncSalt).then((key) => {
        if (live) setUnlocked(key !== null);
      }));
    check();
    const off = keyring.onUnlock(check);
    return () => {
      live = false;
      off();
    };
  }, [keyring, user.syncSalt]);
  return unlocked;
}

/** A `kv_settings` value as text, live. */
export function useSetting(key: string): string | null | undefined {
  const { db } = useHarvest();
  return useLiveQuery(() => readSetting(db, key), [db, key]);
}

export function useDefaultCurrency(): string {
  return useSetting(settingKeys.defaultCurrency) ?? 'DZD';
}

/**
 * A count that goes up each time a file that could not be had might now
 * be had: the sync PIN was entered, or a sync finished. Listens only
 * while [waiting], so a file already shown is never fetched again.
 */
export function useFileRetry(waiting: boolean): number {
  const { keyring, engine } = useHarvest();
  const [tick, setTick] = useState(0);
  useEffect(() => {
    if (!waiting) return;
    const bump = () => setTick((n) => n + 1);
    let phase = engine.status.phase;
    const offSync = engine.subscribe(() => {
      const next = engine.status.phase;
      if (phase === 'syncing' && next !== 'syncing') bump();
      phase = next;
    });
    const offUnlock = keyring.onUnlock(bump);
    return () => {
      offSync();
      offUnlock();
    };
  }, [waiting, keyring, engine]);
  return tick;
}

/**
 * A picture or a recording, as this browser can show it ([[Gallery]]
 * G9): loading, ready with a URL, or missing and why — still on the
 * phone, waiting for the sync PIN, or failed with *Try again*. A fetch
 * is bounded, so loading always ends.
 */
export type FileView =
  | { state: 'loading' }
  | { state: 'ready'; url: string }
  | { state: FileMiss; retry: () => void };

/**
 * At most [size] of these at once; the rest wait their turn. A gallery
 * of a thousand tiles asks for its files five at a time, not a thousand
 * at once ([[Audit-v3]] Q5-32).
 */
export function fetchPool(size: number): <T>(work: () => Promise<T>) => Promise<T> {
  let running = 0;
  const waiting: (() => void)[] = [];
  return async <T>(work: () => Promise<T>): Promise<T> => {
    if (running >= size) await new Promise<void>((resolve) => waiting.push(resolve));
    running++;
    try {
      return await work();
    } finally {
      running--;
      waiting.shift()?.();
    }
  };
}

const filePool = fetchPool(5);

/**
 * A file by its hash, as a [FileView]; no hash is still on the phone.
 * With [enabled] false (a tile not on screen yet) nothing is fetched and
 * it reads as loading.
 */
export function useFileView(sha256: string | null, enabled = true): FileView {
  const { files } = useHarvest();
  // Keyed by the hash, so a tile scrolled into a new row starts again
  // rather than showing the last file it held.
  const [found, setFound] = useState<{ hash: string; url: string } | { hash: string; miss: FileMiss }>();
  const [asked, setAsked] = useState(0);
  // Locked or offline the first time: asked again when that may have changed.
  const missing = sha256 !== null && found?.hash === sha256 && 'miss' in found;
  const retry = useFileRetry(missing);

  useEffect(() => {
    if (sha256 === null || !enabled) return;
    let live = true;
    let made: string | null = null;
    // Not started at all if the tile is gone before its turn.
    background(filePool(async () => (live ? files.find(sha256) : null)).then((got) => {
      if (got === null) return;
      if (!live) return;
      if (typeof got === 'string') {
        setFound({ hash: sha256, miss: got });
        return;
      }
      made = URL.createObjectURL(got);
      setFound({ hash: sha256, url: made });
    }));
    return () => {
      live = false;
      if (made !== null) URL.revokeObjectURL(made);
    };
  }, [files, sha256, retry, asked, enabled]);

  if (sha256 === null) return { state: 'onPhone', retry: () => setAsked((n) => n + 1) };
  if (found?.hash !== sha256) return { state: 'loading' };
  if ('url' in found) return { state: 'ready', url: found.url };
  return {
    state: found.miss,
    retry: () => {
      setFound(undefined);
      setAsked((n) => n + 1);
    },
  };
}

/**
 * Whether [ref]'s element has come near the screen; once it has, it
 * stays true. Without IntersectionObserver it is simply true.
 */
export function useSeen(ref: RefObject<Element | null>, margin = '300px'): boolean {
  const [seen, setSeen] = useState(() => typeof IntersectionObserver === 'undefined');
  useEffect(() => {
    const element = ref.current;
    if (seen || !element) return;
    const observer = new IntersectionObserver(
      (entries) => {
        if (entries.some((entry) => entry.isIntersecting)) {
          setSeen(true);
          observer.disconnect();
        }
      },
      { rootMargin: margin },
    );
    observer.observe(element);
    return () => observer.disconnect();
  }, [ref, seen, margin]);
  return seen;
}

/**
 * A picture or a recording as a URL, once this browser has it.
 *
 * Undefined while it is being fetched and null when it cannot be had,
 * for callers that only need the URL; [useFileView] says why.
 */
export function useFile(sha256: string | null): string | null | undefined {
  const view = useFileView(sha256);
  if (view.state === 'loading') return undefined;
  return view.state === 'ready' ? view.url : null;
}
