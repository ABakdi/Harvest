import { useCallback, useRef, useState } from 'react';

/**
 * One write at a time from a dialog: a double click or a held Enter
 * runs the work once, not twice (two check-ins, two XP rows). The ref
 * answers at once, before React has drawn the disabled button; the
 * state is what the button reads.
 */
export function useBusy() {
  const running = useRef(false);
  const [busy, setBusy] = useState(false);
  const run = useCallback(async <T>(work: () => Promise<T>): Promise<T | undefined> => {
    if (running.current) return undefined;
    running.current = true;
    setBusy(true);
    try {
      return await work();
    } finally {
      running.current = false;
      setBusy(false);
    }
  }, []);
  return [busy, run] as const;
}
