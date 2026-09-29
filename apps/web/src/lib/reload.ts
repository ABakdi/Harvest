import { background } from './actions';
import { flushPendingEdits } from './pending-edits';

const chunkReloadKey = 'harvest.chunkReloadAt';

/** Saves what is being typed, then reloads. Resolves false, without reloading, when something did not save. */
export async function reloadSaved({ force = false }: { force?: boolean } = {}): Promise<boolean> {
  const saved = await flushPendingEdits();
  if (!saved && !force) return false;
  window.location.reload();
  return true;
}

/** Whether an error is a code chunk that could not be fetched: this tab predates a deploy. */
export function isChunkLoadError(error: unknown): boolean {
  const message = error instanceof Error ? error.message : typeof error === 'string' ? error : '';
  return /Failed to fetch dynamically imported module|Importing a module script failed|error loading dynamically imported module|Unable to preload CSS/i.test(message);
}

/**
 * A chunk this tab asked for is gone, so a new version has been
 * deployed: reload once, after saving, to pick it up. A second failure
 * within a minute is not a deploy, and is shown instead of looping.
 */
export function reloadForNewVersion(): boolean {
  try {
    const last = Number(sessionStorage.getItem(chunkReloadKey) ?? 0);
    if (Date.now() - last < 60_000) return false;
    sessionStorage.setItem(chunkReloadKey, String(Date.now()));
  } catch {
    return false;
  }
  background(reloadSaved({ force: true }));
  return true;
}
