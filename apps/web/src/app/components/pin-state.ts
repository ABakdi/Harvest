import { useEffect, useState } from 'react';
import { useHarvest } from '../context';

/**
 * Whether the account has a sync PIN yet, as the server's key share
 * says: true once one was chosen on some device, false while none has
 * been (or after a start over), undefined until the answer comes or
 * when the server cannot be reached. What the account sheet offers —
 * choose one or enter it — follows this (W6-08).
 */
export function usePinChosen(): boolean | undefined {
  const { keyring } = useHarvest();
  const [chosen, setChosen] = useState<boolean | undefined>(undefined);
  useEffect(() => {
    let live = true;
    keyring.state().then(
      (answer) => {
        if (live) setChosen(answer.state === 'set');
      },
      () => undefined,
    );
    return () => {
      live = false;
    };
  }, [keyring]);
  return chosen;
}

/** Whether the browser says it has a network, followed live (W6-02). */
export function useOnline(): boolean {
  const [online, setOnline] = useState(() => typeof navigator === 'undefined' || navigator.onLine !== false);
  useEffect(() => {
    const update = () => setOnline(navigator.onLine !== false);
    window.addEventListener('online', update);
    window.addEventListener('offline', update);
    return () => {
      window.removeEventListener('online', update);
      window.removeEventListener('offline', update);
    };
  }, []);
  return online;
}
