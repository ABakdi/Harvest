import { useSyncExternalStore } from 'react';
import { getPrefs, subscribePrefs } from '@/lib/prefs';

const darkQuery = (): MediaQueryList | null =>
  typeof window !== 'undefined' && typeof window.matchMedia === 'function'
    ? window.matchMedia('(prefers-color-scheme: dark)')
    : null;

export function isDark(): boolean {
  const { themeMode } = getPrefs();
  if (themeMode === 'system') return darkQuery()?.matches ?? false;
  return themeMode === 'dark';
}

/** Puts the chosen look on <html>: the `dark` class and the preset. */
export function applyTheme(): void {
  const root = document.documentElement;
  root.classList.toggle('dark', isDark());
  root.dataset.preset = getPrefs().themePreset;
}

function subscribe(listener: () => void): () => void {
  const query = darkQuery();
  query?.addEventListener('change', listener);
  const unsubscribe = subscribePrefs(listener);
  return () => {
    query?.removeEventListener('change', listener);
    unsubscribe();
  };
}

/** Keeps <html> in step with the preferences and the system theme. */
export function startTheme(): () => void {
  applyTheme();
  return subscribe(applyTheme);
}

export function useIsDark(): boolean {
  return useSyncExternalStore(subscribe, isDark, () => false);
}
