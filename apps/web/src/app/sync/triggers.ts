import type { Writer } from '../data/writer';
import type { SyncEngine } from './engine';

export interface TriggerOptions {
  debounceMs?: number;
  /** How often a visible page pulls. */
  visibleMs?: number;
  /** How often a hidden page still does. */
  intervalMs?: number;
}

/** The tabs of this browser tell each other about their writes and syncs. */
export const syncChannelName = 'harvest-sync';

/**
 * When the web syncs ([[Sync-API]]): on focus (the web's "resume"), when
 * the page shows again, two seconds after the last local write, every
 * minute while the page is visible (so two windows on two computers
 * catch up with each other without a click), every fifteen minutes while
 * it is hidden, when the connection comes back, and from "Sync now". The
 * engine is single-flight, so triggers that overlap cost one run, not two.
 *
 * Tabs of the same browser share the store, so what one writes shows in
 * the others by itself; what they also need is the count of what waits
 * to be sent. A write or a finished sync says so over a BroadcastChannel,
 * and the other tabs recount, without asking the server for anything.
 */
export function startSyncTriggers(engine: SyncEngine, writer: Writer, options: TriggerOptions = {}): () => void {
  const { debounceMs = 2_000, visibleMs = 60_000, intervalMs = 15 * 60_000 } = options;
  let debounce: ReturnType<typeof setTimeout> | undefined;
  const channel = typeof BroadcastChannel === 'undefined' ? null : new BroadcastChannel(syncChannelName);
  let stopped = false;
  const tell = () => {
    if (!stopped) channel?.postMessage('changed');
  };
  const kick = () => void engine.sync().then(tell, () => undefined);
  const visible = () => document.visibilityState !== 'hidden';

  const offWrite = writer.onWrite(() => {
    tell();
    clearTimeout(debounce);
    debounce = setTimeout(kick, debounceMs);
  });
  const onVisibility = () => {
    if (visible()) kick();
  };
  const onMessage = () => void engine.refreshCounts();
  channel?.addEventListener('message', onMessage);
  window.addEventListener('focus', kick);
  window.addEventListener('online', kick);
  document.addEventListener('visibilitychange', onVisibility);
  const whileVisible = setInterval(() => {
    if (visible()) kick();
  }, visibleMs);
  const whileHidden = setInterval(() => {
    if (!visible()) kick();
  }, intervalMs);
  kick();

  return () => {
    stopped = true;
    offWrite();
    clearTimeout(debounce);
    clearInterval(whileVisible);
    clearInterval(whileHidden);
    window.removeEventListener('focus', kick);
    window.removeEventListener('online', kick);
    document.removeEventListener('visibilitychange', onVisibility);
    channel?.removeEventListener('message', onMessage);
    channel?.close();
  };
}
