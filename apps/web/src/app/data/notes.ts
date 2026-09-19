import type { Row } from './db';
import { settingKeys, settingText, writeSetting } from './settings';
import type { Tx, Writer } from './writer';

export type NoteRow = Row<'notes'>;

/** Long enough for a note, short enough that a runaway paste cannot fill the store. */
export const maxNoteBody = 100_000;
export const maxNoteTitle = 200;

const capTitle = (title: string) => title.trim().slice(0, maxNoteTitle);
const capBody = (body: string) => body.slice(0, maxNoteBody);

export interface WikiLink {
  title: string;
  start: number;
  end: number;
}

/**
 * Every `[[wiki link]]` in a body, in order (`linksIn`). The title is
 * trimmed, and a bracket pair spanning a newline is not a link.
 */
export function linksIn(body: string): WikiLink[] {
  const found: WikiLink[] = [];
  for (const match of body.matchAll(/\[\[([^[\]\n]+)\]\]/g)) {
    const title = match[1]!.trim();
    if (title) found.push({ title, start: match.index, end: match.index + match[0].length });
  }
  return found;
}

/** `/Health//Sleep/` → `Health/Sleep`. */
export function normalizeFolder(path: string): string {
  return path
    .split('/')
    .map((part) => part.trim())
    .filter((part) => part.length > 0)
    .join('/');
}

export function decodeFolders(text: string | null): string[] {
  if (!text) return [];
  try {
    const decoded: unknown = JSON.parse(text);
    return Array.isArray(decoded)
      ? decoded.filter((entry): entry is string => typeof entry === 'string' && entry.length > 0).sort()
      : [];
  } catch {
    return [];
  }
}

/** Every folder and every parent of one, sorted: the sidebar's tree. */
export function folderTree(noteFolders: string[], declared: string[]): string[] {
  const all = new Set<string>();
  for (const folder of [...noteFolders, ...declared]) {
    if (!folder) continue;
    const parts = folder.split('/');
    for (let i = 1; i <= parts.length; i++) all.add(parts.slice(0, i).join('/'));
  }
  return [...all].sort();
}

/** The first line of prose, for the list (`Note.preview`). */
export function notePreview(body: string): string {
  for (const raw of body.split('\n')) {
    const line = raw
      .replace(/^\s{0,3}#{1,6}\s+/, '')
      .replace(/^\s{0,3}[-*+]\s+(\[[ xX]\]\s+)?/, '')
      .replace(/^\s{0,3}>\s?/, '')
      .trim();
    if (line) return line;
  }
  return '';
}

/**
 * The notes vault, mirroring NotesRepository on the phone. The body is
 * the truth (rule N2): links are read from it whenever they are needed,
 * which is why this side never writes `note_links`. That index is the
 * phone's own cache of the bodies; the phone does not queue it for sync
 * either, and a vault this size is read in a blink.
 */
export class NotesRepository {
  constructor(private readonly writer: Writer) {}

  create(input: { title?: string; folder?: string; body?: string } = {}): Promise<NoteRow> {
    return this.writer.run(async (tx) => {
      const now = tx.now();
      const row: NoteRow = {
        uuid: crypto.randomUUID(),
        title: capTitle(input.title ?? ''),
        folder: normalizeFolder(input.folder ?? ''),
        body: capBody(input.body ?? ''),
        createdAt: now,
        updatedAt: now,
        deletedAt: null,
      };
      await tx.put('notes', row);
      return row;
    });
  }

  update(uuid: string, changes: { title?: string; folder?: string; body?: string }): Promise<void> {
    return this.writer.run(async (tx) => {
      const row = await tx.get('notes', uuid);
      if (!row) return;
      const next: NoteRow = {
        ...row,
        ...(changes.title !== undefined ? { title: capTitle(changes.title) } : {}),
        ...(changes.folder !== undefined ? { folder: normalizeFolder(changes.folder) } : {}),
        ...(changes.body !== undefined ? { body: capBody(changes.body) } : {}),
        updatedAt: tx.now(),
      };
      if (next.title === row.title && next.folder === row.folder && next.body === row.body) return;
      await tx.put('notes', next);
    });
  }

  /** Soft delete: into the trash, undoable. */
  remove(uuid: string): Promise<void> {
    return this.writer.run(async (tx) => {
      const now = tx.now();
      await tx.patch('notes', uuid, { deletedAt: now, updatedAt: now });
    });
  }

  restore(uuid: string): Promise<void> {
    return this.writer.run(async (tx) => {
      await tx.patch('notes', uuid, { deletedAt: null, updatedAt: tx.now() });
    });
  }

  /** One note, gone for good, from the trash. */
  purge(uuid: string): Promise<void> {
    return this.writer.run((tx) => tx.purge('notes', uuid));
  }

  /** Empties the trash: the one step that is not undoable. */
  emptyTrash(): Promise<number> {
    return this.writer.run(async (tx) => {
      const trashed = (await tx.rows('notes').toArray()).filter((note) => note.deletedAt !== null);
      for (const note of trashed) await tx.purge('notes', note.uuid);
      return trashed.length;
    });
  }

  /**
   * Moves every note under [from] to [to], prefix and all: renaming
   * `Health` to `Body` moves `Health/Sleep` with it.
   */
  renameFolder(from: string, to: string): Promise<void> {
    const target = normalizeFolder(to);
    return this.writer.run(async (tx) => {
      const now = tx.now();
      for (const note of await tx.rows('notes').toArray()) {
        if (note.folder !== from && !note.folder.startsWith(`${from}/`)) continue;
        const rest = note.folder.slice(from.length).replace(/^\//, '');
        const moved = target ? (rest ? `${target}/${rest}` : target) : rest;
        await tx.put('notes', { ...note, folder: moved, updatedAt: now });
      }
      const declared = await declaredFolders(tx);
      await writeFolders(
        tx,
        declared.map((folder) =>
          folder === from ? target : folder.startsWith(`${from}/`) ? target + folder.slice(from.length) : folder,
        ),
      );
    });
  }

  /** Remembers a folder that has no note in it yet. */
  addFolder(path: string): Promise<string> {
    const cleaned = normalizeFolder(path);
    return this.writer.run(async (tx) => {
      if (!cleaned) return cleaned;
      const declared = await declaredFolders(tx);
      if (!declared.includes(cleaned)) await writeFolders(tx, [...declared, cleaned]);
      return cleaned;
    });
  }
}

async function declaredFolders(tx: Tx): Promise<string[]> {
  return decodeFolders(settingText((await tx.get('kv_settings', settingKeys.noteFolders))?.valueJson));
}

async function writeFolders(tx: Tx, folders: string[]): Promise<void> {
  const unique = [...new Set(folders.filter((folder) => folder.length > 0))].sort();
  await writeSetting(tx, settingKeys.noteFolders, JSON.stringify(unique));
}
