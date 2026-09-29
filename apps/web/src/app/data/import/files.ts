import { HarvestDay } from '@harvest/core';
import { ArchiveLimits, dayOf, instantOf, intOf, isSafeRelative, plainExtension, safeFileName, safeSegment } from '../archive';
import type { HarvestDB } from '../db';
import { SheetNames } from '../export-sheets';
import { sha256Of } from '../files';
import { text, at, type SheetRow, type Context } from './sheet-spec';
import { micros, localStamps, emptyCount, decide, type Planned } from './plan';
import type { ArchiveBundle } from '../import';

/*
 * The two sheets that bring files with them, memories and recordings,
 * and the note bodies the vault carries beside the notes sheet.
 */

/**
 * Where a memory's file is said to live. The row's own stored path is
 * honoured when it is a plain relative path, so an archive taken from a
 * phone and put back is a no-op; anything else is regenerated the way
 * a fresh capture's would be ([[Audit-v2-Beta]] S2-01).
 */
function destinationFor(row: SheetRow, today: string): string {
  const stored = row.StoredPath ?? '';
  if (isSafeRelative(stored)) return stored;
  const day = dayOf(row.HarvestDay) ?? today;
  const uuid = safeSegment(row.Uuid ?? 'memory').padEnd(8, '0').slice(0, 8);
  return `${safeSegment(row.AlbumUuid ?? 'album')}/${day}-${uuid}${plainExtension(row.File ?? stored)}`;
}

export async function planMemories(db: HarvestDB, bundle: ArchiveBundle, context: Context): Promise<Planned> {
  const planned: Planned = { count: emptyCount(), pending: [], files: new Map(), uploads: [], newFiles: 0 };
  const local = await localStamps(db, 'memories', 'updatedAt');
  // A picture with no day of its own is named for today's Harvest Day, not the UTC date.
  const today = HarvestDay.of(new Date(context.now)).key;
  for (const row of bundle.sheets.get(SheetNames.memories) ?? []) {
    const uuid = row.Uuid;
    if (!uuid) continue;
    const bytes = bundle.files.get(row.File ?? '');
    const stamp = local.get(uuid);
    const incoming = micros(instantOf(row.UpdatedAt));
    if (stamp !== undefined && (incoming === null || incoming <= stamp)) {
      planned.count.unchanged++;
      continue;
    }
    const hash = bytes ? await sha256Of(bytes.slice().buffer) : null;
    const built = {
      uuid,
      albumUuid: row.AlbumUuid ?? '',
      harvestDay: dayOf(row.HarvestDay) ?? '',
      path: destinationFor(row, today),
      kind: row.Kind ?? 'photo',
      note: text(row.Note),
      // The name the archive gave, or none until the server has the
      // bytes: a row is stamped only once its file can be fetched.
      fileHash: row.FileHash ?? null,
      capturedAt: at(row.CapturedAt) ?? context.now,
      updatedAt: at(row.UpdatedAt) ?? context.now,
      deletedAt: at(row.DeletedAt),
    };
    if (decide('memories', built, stamp, incoming, planned) && bytes && hash) {
      if (stamp === undefined) planned.newFiles++;
      planned.files.set(hash, bytes);
      planned.uploads.push({ table: 'memories', uuid, sha256: hash, check: built.fileHash !== null });
    }
  }
  return planned;
}

/**
 * The name a recording is kept under: the one its row gives when that
 * is a plain file name, and made into one when it is not. A name with
 * a slash or a `..` in it is a path, and an archive does not get to
 * name a path.
 */
function attachmentName(row: SheetRow): string {
  const given = row.FileName?.trim() ?? '';
  const name = given === '' ? '' : safeFileName(given);
  if (name !== '' && name !== 'untitled' && !name.startsWith('.')) return name;
  return `${safeSegment(row.Uuid ?? 'recording')}${plainExtension(row.File ?? '', '.m4a')}`;
}

export async function planAttachments(db: HarvestDB, bundle: ArchiveBundle, context: Context): Promise<Planned> {
  const planned: Planned = { count: emptyCount(), pending: [], files: new Map(), uploads: [], newFiles: 0 };
  const rows = await db.rows('note_attachments').toArray();
  const local = await localStamps(db, 'note_attachments', 'updatedAt');
  // The file name is unique, because it is how an embed finds its file:
  // one already answering for another recording stays with it.
  const owners = new Map(rows.map((row) => [row.fileName, row.uuid]));
  for (const row of bundle.sheets.get(SheetNames.noteAttachments) ?? []) {
    const uuid = row.Uuid;
    const note = row.NoteUuid;
    if (!uuid || !note) continue;
    const name = attachmentName(row);
    const owner = owners.get(name);
    if (owner !== undefined && owner !== uuid) {
      planned.count.unchanged++;
      continue;
    }
    let bytes = bundle.files.get(row.File ?? '');
    if (bytes && bytes.length > ArchiveLimits.entryBytes) bytes = undefined;
    const stamp = local.get(uuid);
    const incoming = micros(instantOf(row.UpdatedAt));
    if (stamp !== undefined && (incoming === null || incoming <= stamp)) {
      planned.count.unchanged++;
      continue;
    }
    const hash = bytes ? await sha256Of(bytes.slice().buffer) : null;
    const built = {
      uuid,
      noteUuid: note,
      kind: row.Kind ?? 'audio',
      fileName: name,
      // Every recording lives at `<noteUuid>/<fileName>`; the archive's
      // StoredPath is not read at all.
      storedPath: `${safeSegment(note)}/${name}`,
      durationMs: intOf(row.DurationMs),
      sizeBytes: bytes?.length ?? intOf(row.SizeBytes) ?? 0,
      fileHash: row.FileHash ?? null,
      createdAt: at(row.CreatedAt) ?? context.now,
      updatedAt: at(row.UpdatedAt) ?? context.now,
      deletedAt: at(row.DeletedAt),
    };
    if (decide('note_attachments', built, stamp, incoming, planned)) {
      owners.set(name, uuid);
      if (bytes && hash) {
        if (stamp === undefined) planned.newFiles++;
        planned.files.set(hash, bytes);
        planned.uploads.push({ table: 'note_attachments', uuid, sha256: hash, check: built.fileHash !== null });
      }
    }
  }
  return planned;
}

/** The `.md` files the notes sheet points at, decoded once. */
export function noteBodies(bundle: ArchiveBundle): Map<string, string> {
  const bodies = new Map<string, string>();
  const decoder = new TextDecoder('utf-8');
  for (const row of bundle.sheets.get(SheetNames.notes) ?? []) {
    const file = row.File;
    if (!file) continue;
    const bytes = bundle.files.get(file);
    if (bytes) bodies.set(file, decoder.decode(bytes));
  }
  return bodies;
}
