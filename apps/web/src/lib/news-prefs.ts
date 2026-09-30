/**
 * What belongs to this browser about the news and the heartbeat
 * ([[Admin]]): whether it asks for news at all, whether it shares the
 * streak, which pop-ups it has shown, and the day it last said hello.
 * In localStorage, like the theme: they are this browser's, and nothing
 * here ever syncs.
 */
import { useSyncExternalStore } from 'react';

export interface NewsPrefs {
  /** *News from Harvest*: asks for news and shows it. On unless turned off. */
  news: boolean;
  /** *Share my streak*: the heartbeat carries the streak. On unless turned off. */
  shareStreak: boolean;
}

export const newsKeys = {
  news: 'harvest.news',
  shareStreak: 'harvest.shareStreak',
  seen: 'harvest.newsSeen',
  heartbeatDay: 'harvest.heartbeatDay',
  pushEndpoint: 'harvest.pushEndpoint',
} as const;

/** How many shown pop-ups are remembered: far more than will ever be live at once. */
const seenCap = 200;

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
    // A private window may refuse storage; the choice lasts this visit.
  }
}

function load(): NewsPrefs {
  return { news: read(newsKeys.news) !== 'off', shareStreak: read(newsKeys.shareStreak) !== 'off' };
}

let current: NewsPrefs = load();
const listeners = new Set<() => void>();

export function getNewsPrefs(): NewsPrefs {
  return current;
}

export function setNewsPrefs(patch: Partial<NewsPrefs>): void {
  current = { ...current, ...patch };
  if (patch.news !== undefined) write(newsKeys.news, patch.news ? null : 'off');
  if (patch.shareStreak !== undefined) write(newsKeys.shareStreak, patch.shareStreak ? null : 'off');
  for (const listener of listeners) listener();
}

function subscribe(listener: () => void): () => void {
  listeners.add(listener);
  return () => listeners.delete(listener);
}

export function useNewsPrefs(): NewsPrefs {
  return useSyncExternalStore(subscribe, getNewsPrefs, getNewsPrefs);
}

/** The pop-ups this browser has already shown. */
export function seenNews(): Set<string> {
  try {
    const parsed = JSON.parse(read(newsKeys.seen) ?? '[]') as unknown;
    return new Set(Array.isArray(parsed) ? parsed.filter((id): id is string => typeof id === 'string') : []);
  } catch {
    return new Set();
  }
}

export function markNewsSeen(id: string): void {
  const seen = [...seenNews().add(id)];
  write(newsKeys.seen, JSON.stringify(seen.slice(-seenCap)));
}

export function heartbeatDay(): string | null {
  return read(newsKeys.heartbeatDay);
}

export function setHeartbeatDay(day: string | null): void {
  write(newsKeys.heartbeatDay, day);
}

/** The push subscription this browser made, to take back on sign-out. */
export function pushEndpoint(): string | null {
  return read(newsKeys.pushEndpoint);
}

export function setPushEndpoint(endpoint: string | null): void {
  write(newsKeys.pushEndpoint, endpoint);
}

/** For tests: read localStorage again. */
export function reloadNewsPrefs(): void {
  current = load();
  for (const listener of listeners) listener();
}
