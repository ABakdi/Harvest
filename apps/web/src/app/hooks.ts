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
