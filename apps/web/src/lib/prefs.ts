/**
 * Preferences that belong to this browser: the theme, the preset and
 * the language. They live in localStorage rather than the local store,
 * because the public pages read them too, and the public pages never
 * open IndexedDB (W3).
 */
import { useSyncExternalStore } from 'react';

export type ThemeMode = 'system' | 'light' | 'dark';
export const themeModes: readonly ThemeMode[] = ['system', 'light', 'dark'];

export const themePresets = ['harvest', 'sunrise', 'ocean', 'orchard', 'dusk'] as const;
export type ThemePreset = (typeof themePresets)[number];

export type Locale = 'en' | 'ar';
export const locales: readonly Locale[] = ['en', 'ar'];

export interface Prefs {
  themeMode: ThemeMode;
  themePreset: ThemePreset;
  /** Null follows the browser's language. */
  locale: Locale | null;
}

const keys = {
  themeMode: 'harvest.themeMode',
  themePreset: 'harvest.themePreset',
  locale: 'harvest.locale',
} as const;

function read(key: string): string | null {
  try {
    return localStorage.getItem(key);
  } catch {
    return null;
  }
}

function write(key: string, value: string | null): void {
  try {
    if (value === null) localStorage.removeItem(key);
    else localStorage.setItem(key, value);
  } catch {
    // Private windows may refuse storage; the choice lasts this visit.
  }
}

function load(): Prefs {
  const mode = read(keys.themeMode);
  const preset = read(keys.themePreset);
  const locale = read(keys.locale);
  return {
    themeMode: themeModes.includes(mode as ThemeMode) ? (mode as ThemeMode) : 'system',
    themePreset: themePresets.includes(preset as ThemePreset) ? (preset as ThemePreset) : 'harvest',
    locale: locales.includes(locale as Locale) ? (locale as Locale) : null,
  };
}

let current: Prefs = load();
const listeners = new Set<() => void>();

function emit(): void {
  for (const listener of listeners) listener();
}

export function getPrefs(): Prefs {
  return current;
}

export function setPrefs(patch: Partial<Prefs>): void {
  current = { ...current, ...patch };
  if (patch.themeMode !== undefined) write(keys.themeMode, patch.themeMode);
  if (patch.themePreset !== undefined) write(keys.themePreset, patch.themePreset);
  if (patch.locale !== undefined) write(keys.locale, patch.locale);
  emit();
}

export function subscribePrefs(listener: () => void): () => void {
  listeners.add(listener);
  return () => listeners.delete(listener);
}

export function usePrefs(): Prefs {
  return useSyncExternalStore(subscribePrefs, getPrefs, getPrefs);
}
