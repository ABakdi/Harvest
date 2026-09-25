import { isSafeRelative, safeFileName } from './archive';
import type { Row } from './db';
import type { FileStore } from './files';
import type { Writer } from './writer';

export type AttachmentRow = Row<'note_attachments'>;

/** The extensions an embed may name and still be a recording ([[Notes]] N7). */
export const audioExtensions: ReadonlySet<string> = new Set(['m4a', 'aac', 'mp3', 'wav', 'ogg', 'opus']);

const embedPattern = /!\[\[([^[\]\n]+?)\]\]/g;

function isAudio(name: string): boolean {
  const dot = name.lastIndexOf('.');
  return dot > 0 && audioExtensions.has(name.slice(dot + 1).toLowerCase());
}

/**
 * Every recording a body embeds, by file name, in order
 * (`audioEmbedsIn`). An embed is Obsidian's own `![[name.m4a]]`, so the
 * pair of `.md` and recording opens there as it is; only names with an
 * audio extension count.
 */
export function audioEmbedsIn(body: string): string[] {
  const found: string[] = [];
  for (const match of body.matchAll(embedPattern)) {
    const name = match[1]!.trim();
    if (isAudio(name)) found.push(name);
  }
  return found;
}

/**
 * The extension an audio file from this computer is filed under: its
 * own when the phone knows it, else one from its type; null when it is
 * not a recording the phone would keep (N7).
 */
export function audioExtensionOf(file: { name: string; type: string }): string | null {
  const dot = file.name.lastIndexOf('.');
  const own = dot > 0 ? file.name.slice(dot + 1).toLowerCase() : '';
  if (audioExtensions.has(own)) return own;
  const byType: Record<string, string> = {
    'audio/mp4': 'm4a',
    'audio/x-m4a': 'm4a',
    'audio/aac': 'aac',
    'audio/mpeg': 'mp3',
    'audio/wav': 'wav',
    'audio/x-wav': 'wav',
    'audio/ogg': 'ogg',
    'audio/opus': 'opus',
  };
  return byType[file.type.split(';')[0]!.toLowerCase()] ?? null;
}

/** The embed line for [fileName]. */
export function audioEmbed(fileName: string): string {
  return `![[${fileName}]]`;
}

/**
 * A recording's file name from [stem]: made safe the way an archive's
 * names are (`safeFileName`), with nothing that would break its embed
 * line, and a counter when [taken] already holds it. The phone refuses
 * to store a path its `GalleryStorage.isSafeRelative` rejects, so a name
 * with a `:` or `\` would never reach it (N7).
 */
export function attachmentFileName(stem: string, extension: string, taken: ReadonlySet<string> = new Set()): string {
  const safe = safeFileName(stem.replace(/[[\]\n#^]/g, ' '));
  const ext = extension.toLowerCase().replace(/[^a-z0-9]/g, '') || 'm4a';
  let name = `${safe}.${ext}`;
  for (let i = 2; taken.has(name); i++) name = `${safe} (${i}).${ext}`;
  return name;
}

/**
 * A recording's name: the moment it started, which is what I remember
 * it by (`voiceFileName`). A second one in the same minute gets a
 * counter. The extension is the one the browser recorded in.
 */
export function voiceFileName(at: Date, taken: ReadonlySet<string> = new Set(), extension = 'm4a'): string {
  const two = (n: number) => String(n).padStart(2, '0');
  const stem = `Voice ${at.getFullYear()}-${two(at.getMonth() + 1)}-${two(at.getDate())} ${two(at.getHours())}-${two(at.getMinutes())}`;
  return attachmentFileName(stem, extension, taken);
}

/** A voice note's title, from the moment it was started. */
export function voiceNoteTitle(at: Date): string {
  return voiceFileName(at).replace(/\.m4a$/, '');
}

/**
 * The recordings in notes, mirroring the phone's
 * NoteAttachmentsRepository. A recording is a file beside the note and
 * an embed line in its body (N7); the bytes are kept in this browser
 * and sent sealed, like a picture ([[Sync-API]], files).
 */
export class AttachmentsRepository {
  constructor(
    private readonly writer: Writer,
    private readonly files: FileStore,
  ) {}

  /** Every recording's name, so a new one never collides. */
  async takenNames(): Promise<Set<string>> {
    return new Set((await this.writer.db.rows('note_attachments').toArray()).map((row) => row.fileName));
  }

  /** Files a finished recording under [noteUuid]. */
  async add(input: { noteUuid: string; blob: Blob; fileName: string; durationMs: number | null }): Promise<AttachmentRow> {
    // One folder per note, one plain name inside it: anything else the
    // phone would refuse to store, and so never download.
    const storedPath = `${input.noteUuid}/${input.fileName}`;
    if (input.fileName.includes('/') || !isSafeRelative(storedPath)) throw new Error(`Unsafe recording name: ${input.fileName}`);
    const { sha256, size } = await this.files.keep(input.blob);
    const uuid = crypto.randomUUID();
    await this.files.queue('note_attachments', uuid, sha256);
    const row = await this.writer.run(async (tx) => {
      const now = tx.now();
      const attachment: AttachmentRow = {
        uuid,
        noteUuid: input.noteUuid,
        kind: 'audio',
        fileName: input.fileName,
        // Where the phone keeps it: one folder per note.
        storedPath,
        durationMs: input.durationMs === null ? null : Math.round(input.durationMs),
        sizeBytes: size,
        fileHash: null,
        createdAt: now,
        updatedAt: now,
        deletedAt: null,
      };
      await tx.put('note_attachments', attachment);
      return attachment;
    });
    void this.files.upload().catch(() => undefined);
    return row;
  }

  /**
   * Recordings the body no longer embeds go to the trash with its next
   * save, and one embedded again comes back (`reconcile`). The embed
   * line is the truth, as the body always is (N2).
   */
  reconcile(noteUuid: string, body: string): Promise<void> {
    const embedded = new Set(audioEmbedsIn(body).map((name) => name.toLowerCase()));
    return this.writer.run(async (tx) => {
      const rows = await tx.rows('note_attachments').where('noteUuid').equals(noteUuid).toArray();
      const now = tx.now();
      for (const row of rows) {
        const wanted = embedded.has(row.fileName.toLowerCase());
        const trashed = row.deletedAt !== null;
        if (wanted === !trashed) continue;
        await tx.put('note_attachments', { ...row, deletedAt: wanted ? null : now, updatedAt: now });
      }
    });
  }
}
