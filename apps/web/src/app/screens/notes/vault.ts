import type { HarvestDB } from '../../data/db';
import { decodeFolders, folderTree, type NoteRow } from '../../data/notes';
import { settingKeys, settingText } from '../../data/settings';

/** The notes, the trash and the folders, read together for the sidebar and the note. */
export interface Vault {
  notes: NoteRow[];
  trash: NoteRow[];
  folders: string[];
}

export async function loadVault(db: HarvestDB): Promise<Vault> {
  const [rows, declared] = await Promise.all([db.rows('notes').toArray(), db.rows('kv_settings').get(settingKeys.noteFolders)]);
  const notes = rows.filter((note) => note.deletedAt === null);
  return {
    notes,
    trash: rows.filter((note) => note.deletedAt !== null).sort((a, b) => (b.deletedAt ?? '').localeCompare(a.deletedAt ?? '')),
    folders: folderTree(
      notes.map((note) => note.folder),
      decodeFolders(settingText(declared?.valueJson)),
    ),
  };
}

export type Sort = 'edited' | 'created' | 'title';

/** The notes in the order the sidebar is sorted by. */
export function sortNotes(notes: NoteRow[], sort: Sort): NoteRow[] {
  const compare: Record<Sort, (a: NoteRow, b: NoteRow) => number> = {
    edited: (a, b) => b.updatedAt.localeCompare(a.updatedAt),
    created: (a, b) => b.createdAt.localeCompare(a.createdAt),
    title: (a, b) => a.title.localeCompare(b.title),
  };
  return [...notes].sort(compare[sort]);
}

/** The notes whose title or text holds [query], in the sidebar's order. */
export function searchNotes(notes: NoteRow[], query: string, sort: Sort): NoteRow[] {
  const needle = query.trim().toLowerCase();
  return sortNotes(
    notes.filter((note) => note.title.toLowerCase().includes(needle) || note.body.toLowerCase().includes(needle)),
    sort,
  );
}

/** The folders directly inside [parent], `''` for the top of the vault. */
export function childFolders(folders: string[], parent: string): string[] {
  return folders.filter((path) => (parent ? path.startsWith(`${parent}/`) && !path.slice(parent.length + 1).includes('/') : !path.includes('/')));
}

/** [folder] and every folder it sits in, outermost first: what has to be open to see a note in it. */
export function foldersAbove(folder: string): string[] {
  if (!folder) return [];
  const parts = folder.split('/');
  return parts.map((_, i) => parts.slice(0, i + 1).join('/'));
}

/*
 * The note I was last in, remembered on this device as the phone
 * remembers it (`SettingKeys.recordsNote`): opening Notes on a phone
 * lands on it again. An empty value means I closed a note on purpose,
 * and Notes then opens on the list rather than on a note.
 */
const lastNoteKey = 'harvest.notes.last';

export function rememberedNote(): string | null {
  try {
    return localStorage.getItem(lastNoteKey);
  } catch {
    return null;
  }
}

export function rememberNote(uuid: string | null): void {
  try {
    if (uuid === null) localStorage.removeItem(lastNoteKey);
    else localStorage.setItem(lastNoteKey, uuid);
  } catch {
    // A browser that keeps nothing opens on the latest note instead.
  }
}

/**
 * Which note Notes opens on, on a phone: the one I was last in while it
 * is still there, else the latest; none when I closed one on purpose or
 * there are none.
 */
export function noteToReopen(notes: NoteRow[], remembered: string | null): NoteRow | null {
  if (remembered === '' || notes.length === 0) return null;
  const last = notes.find((note) => note.uuid === remembered);
  return last ?? sortNotes(notes, 'edited')[0] ?? null;
}
