import { background } from './actions';
/**
 * Editors with unsaved typing register a flush here, so a reload the
 * update toast asks for saves first (W4: an update never costs an edit).
 * Leaving the page flushes too: the tab going hidden is the last moment
 * a browser reliably lets an IndexedDB write finish, so a close or a
 * reload right after typing keeps the typing.
 */
const flushers = new Set<() => Promise<void> | void>();

let listening = false;

function onHidden() {
  if (document.visibilityState === 'hidden') background(flushPendingEdits());
}

function onPageHide() {
  background(flushPendingEdits());
}

function listen() {
  if (listening || typeof window === 'undefined') return;
  listening = true;
  document.addEventListener('visibilitychange', onHidden);
  window.addEventListener('pagehide', onPageHide);
}

export function registerPendingEdit(flush: () => Promise<void> | void): () => void {
  listen();
  flushers.add(flush);
  return () => flushers.delete(flush);
}

/**
 * Saves every registered edit. One editor failing does not stop the
 * others; the answer is whether all of them saved, so a caller about to
 * reload can say so first.
 */
export async function flushPendingEdits(): Promise<boolean> {
  const outcomes = await Promise.allSettled(
    [...flushers].map(async (flush) => {
      await flush();
    }),
  );
  return outcomes.every((outcome) => outcome.status === 'fulfilled');
}
