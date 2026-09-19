import type { Writer } from '../data/writer';
import type { SyncEngine } from './engine';

export interface TriggerOptions {
  debounceMs?: number;
  intervalMs?: number;
}

/**
 * When the web syncs ([[Sync-API]]): on focus (the web's "resume"),
 * two seconds after the last local write, every fifteen minutes while
 * open, when the connection comes back, and from "Sync now". The engine
 * is single-flight, so triggers that overlap cost one run, not two.
 */
export function startSyncTriggers(engine: SyncEngine, writer: Writer, options: TriggerOptions = {}): () => void {
  const { debounceMs = 2_000, intervalMs = 15 * 60_000 } = options;
  let debounce: ReturnType<typeof setTimeout> | undefined;
  const kick = () => void engine.sync();

  const offWrite = writer.onWrite(() => {
    clearTimeout(debounce);
    debounce = setTimeout(kick, debounceMs);
  });
  window.addEventListener('focus', kick);
  window.addEventListener('online', kick);
  const interval = setInterval(kick, intervalMs);
  kick();

  return () => {
    offWrite();
    clearTimeout(debounce);
    clearInterval(interval);
    window.removeEventListener('focus', kick);
    window.removeEventListener('online', kick);
  };
}
