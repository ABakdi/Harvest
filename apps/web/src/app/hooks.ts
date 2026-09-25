import { useLiveQuery } from 'dexie-react-hooks';
import { useEffect, useState } from 'react';
import { useHarvest } from './context';
import { readSetting, settingKeys } from './data/settings';

/** Whether this browser holds the private tier's key; undefined while it looks. */
export function usePrivateKey(): boolean | undefined {
  const { keyring, user } = useHarvest();
  const [unlocked, setUnlocked] = useState<boolean | undefined>(undefined);
  useEffect(() => {
    let live = true;
    const check = () =>
      void keyring.key(user.syncSalt).then((key) => {
        if (live) setUnlocked(key !== null);
      });
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
 * be had: the passphrase was entered, or a sync finished. Listens only
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
 * A picture or a recording as a URL, once this browser has it.
 *
 * Undefined while it is being fetched and null when it cannot be had —
 * no hash yet, no passphrase, or the file has not reached the server —
 * so a caller can say *on another device* rather than show a broken
 * frame ([[Gallery]]).
 */
export function useFile(sha256: string | null): string | null | undefined {
  const { files } = useHarvest();
  // Keyed by the hash, so a tile scrolled into a new row starts again
  // rather than showing the last file it held.
  const [found, setFound] = useState<{ hash: string; url: string | null }>();
  // Locked or offline the first time: asked again when that may have changed.
  const retry = useFileRetry(sha256 !== null && found?.hash === sha256 && found.url === null);

  useEffect(() => {
    if (sha256 === null) return;
    let live = true;
    let made: string | null = null;
    void files.get(sha256).then((blob) => {
      if (!live) return;
      made = blob === null ? null : URL.createObjectURL(blob);
      setFound({ hash: sha256, url: made });
    });
    return () => {
      live = false;
      if (made !== null) URL.revokeObjectURL(made);
    };
  }, [files, sha256, retry]);

  if (sha256 === null) return null;
  return found?.hash === sha256 ? found.url : undefined;
}
