/**
 * Typing in a note that has not reached IndexedDB yet, kept in
 * `localStorage` on every keystroke ([[Notes]], W4). `localStorage` is
 * written synchronously, so a reload a moment after typing — faster than
 * the autosave, faster than the write a `pagehide` starts — still finds
 * it, and the next load puts it back into the note.
 */
export interface NoteDraft {
  title: string;
  folder: string;
  body: string;
  /** When it was typed, on the app's clock: older than the note, it lost. */
  at: string;
}

const prefix = 'harvest.noteDraft.';

export function keepDraft(uuid: string, draft: NoteDraft): void {
  try {
    localStorage.setItem(prefix + uuid, JSON.stringify(draft));
  } catch {
    // Storage full or blocked: the autosave still runs.
  }
}

/** Drops the draft once saved — only the one saved, not newer typing that came in during the write. */
export function dropDraft(uuid: string, at?: string): void {
  try {
    const key = prefix + uuid;
    if (at !== undefined) {
      const stored = localStorage.getItem(key);
      if (stored === null || (JSON.parse(stored) as NoteDraft).at !== at) return;
    }
    localStorage.removeItem(key);
  } catch {
    // Nothing to drop.
  }
}

/** Every draft left behind, by note. */
export function leftDrafts(): [string, NoteDraft][] {
  const found: [string, NoteDraft][] = [];
  try {
    for (let i = 0; i < localStorage.length; i++) {
      const key = localStorage.key(i);
      if (!key?.startsWith(prefix)) continue;
      const draft = JSON.parse(localStorage.getItem(key) ?? 'null') as NoteDraft | null;
      if (draft && typeof draft.body === 'string' && typeof draft.at === 'string') found.push([key.slice(prefix.length), draft]);
    }
  } catch {
    // Unreadable storage keeps nothing.
  }
  return found;
}
