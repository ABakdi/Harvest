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
  if (document.visibilityState === 'hidden') void flushPendingEdits();
}

function onPageHide() {
  void flushPendingEdits();
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

export async function flushPendingEdits(): Promise<void> {
  await Promise.all(
    [...flushers].map(async (flush) => {
      await flush();
    }),
  );
}
