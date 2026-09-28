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
