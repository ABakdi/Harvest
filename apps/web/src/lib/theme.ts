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
  const dark = isDark();
  root.classList.toggle('dark', dark);
  root.dataset.preset = getPrefs().themePreset;
  paintThemeColor(dark);
}

/**
 * The browser's own bar (Android Chrome, an installed app) in the page's
 * ground colour for the chosen preset and mode, not a fixed green over a
 * cream or navy page (W6-25).
 */
function paintThemeColor(dark: boolean): void {
  const colour = getComputedStyle(document.documentElement)
    .getPropertyValue(dark ? '--p-surface-dark' : '--p-surface-light')
    .trim();
  if (!colour) return;
  const metas = [...document.querySelectorAll<HTMLMetaElement>('meta[name="theme-color"]')];
  const [first, ...rest] = metas;
  const meta = first ?? document.head.appendChild(Object.assign(document.createElement('meta'), { name: 'theme-color' }));
  meta.removeAttribute('media');
  meta.content = colour;
  for (const extra of rest) extra.remove();
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
