/**
 * Where everything sits inside a Harvest archive, and what an archive
 * may weigh before it is refused ([[ADR-007-Archive-Format]]).
 *
 * A port of the phone's `archive_layout.dart` and the limits in
 * `archive_reader.dart`: the paths have to agree exactly with what the
 * phone writes and reads, because a zip made here goes back into a
 * phone and the other way round.
 */

export const ArchivePaths = {
  workbook: 'harvest.xlsx',
  notes: 'notes',
  gallery: 'gallery',
} as const;

/**
 * Whether an export carries my location history ([[Places]] PL6). A
 * choice about this browser's exports, so it never leaves it: the key
 * is not a portable setting and is never queued for sync.
 */
export const exportIncludesPlacesKey = 'export.includePlaces';

/**
 * What an archive may weigh. Generous for a real one, a hard stop for
 * one made to be large ([[Audit-v2-Beta]] S2-02). The same numbers as
 * the phone's `ArchiveLimits`.
 */
export const ArchiveLimits = {
  /** The picked file itself. */
  archiveBytes: 768 * 1024 * 1024,
  /** Any one entry, uncompressed. */
  entryBytes: 64 * 1024 * 1024,
  /** Every entry, uncompressed, added up. */
  expandedBytes: 1024 * 1024 * 1024,
  /** The workbook on its own: a spreadsheet of rows, never pictures. */
  workbookBytes: 64 * 1024 * 1024,
  entries: 100_000,
} as const;

/** Why an archive could not be opened. */
export type ArchiveProblem = 'unreadable' | 'notHarvest' | 'badWorkbook' | 'tooLarge';

export class ArchiveInvalid extends Error {
  override readonly name = 'ArchiveInvalid';

  constructor(readonly problem: ArchiveProblem) {
    super(`ArchiveInvalid(${problem})`);
  }
}

/** `harvest-2026-09-05-1430.zip`, in local time, as the phone names it. */
export function archiveFileName(at: Date): string {
  const two = (value: number) => String(value).padStart(2, '0');
  return `harvest-${at.getFullYear()}-${two(at.getMonth() + 1)}-${two(at.getDate())}-${two(at.getHours())}${two(at.getMinutes())}.zip`;
}

/**
 * A filename that survives every platform, with the real title kept in
 * the workbook beside it (ADR-007 rule 4). The phone's `safeFileName`.
 */
export function safeFileName(title: string): string {
  const cleaned = title
    .replace(/[\\/:*?"<>|]/g, '-')
    .replace(/\s+/g, ' ')
    .trim();
  const trimmed = cleaned.replace(/^\.+/, '').trim();
  if (trimmed === '') return 'untitled';
  return trimmed.length > 120 ? trimmed.slice(0, 120).trim() : trimmed;
}

/** `path.posix.join` for the few segments a layout needs; empties dropped. */
export function joinPath(...parts: string[]): string {
  return parts.filter((part) => part !== '').join('/');
}

/** The directory part of a posix path, `.` when there is none. */
function dirname(path: string): string {
  const slash = path.lastIndexOf('/');
  return slash < 0 ? '.' : path.slice(0, slash);
}

/** The last segment's extension, dot included, as `path.extension` reads it. */
export function extensionOf(path: string): string {
  const base = path.slice(path.lastIndexOf('/') + 1);
  const dot = base.lastIndexOf('.');
  return dot <= 0 ? '' : base.slice(dot);
}

/** Every segment of a note's folder path, made safe, empties dropped. */
function safeFolder(folder: string): string {
  return folder
    .split('/')
    .map((segment) => segment.trim())
    .filter((segment) => segment !== '')
    .map(safeFileName)
    .join('/');
}

/**
 * `notes/Health/Sleep log.md`: the folder the app shows, the title as
 * the filename, a suffix when two land on the same name.
 */
export function notePath({ title, folder, taken }: { title: string; folder: string; taken: Set<string> }): string {
  const base = safeFileName(title.trim() === '' ? 'Untitled' : title);
  const directory = safeFolder(folder);
  let candidate = joinPath(ArchivePaths.notes, directory, `${base}.md`);
  let suffix = 2;
  while (taken.has(candidate)) {
    candidate = joinPath(ArchivePaths.notes, directory, `${base} (${suffix}).md`);
    suffix++;
  }
  taken.add(candidate);
  return candidate;
}

/**
 * A recording beside its note's `.md`, under the name the body embeds,
 * so `![[fileName]]` resolves when the vault is opened ([[Notes]] N7).
 */
export function attachmentPath({
  notePath: note,
  fileName,
  taken,
}: {
  notePath: string;
  fileName: string;
  taken: Set<string>;
}): string {
  const directory = dirname(note);
  const name = safeFileName(fileName);
  const extension = extensionOf(name);
  const stem = extension === '' ? name : name.slice(0, -extension.length);
  let candidate = joinPath(directory, name);
  let suffix = 2;
  while (taken.has(candidate)) {
    candidate = joinPath(directory, `${stem} (${suffix})${extension}`);
    suffix++;
  }
  taken.add(candidate);
  return candidate;
}

/** `gallery/Gym/2026-09-01.jpg`, numbered when a day holds more than one. */
export function memoryPath({
  albumName,
  day,
  storedPath,
  taken,
}: {
  albumName: string;
  day: string;
  storedPath: string;
  taken: Set<string>;
}): string {
  const album = safeFileName(albumName.trim() === '' ? 'Album' : albumName.trim());
  const extension = extensionOf(storedPath).toLowerCase();
  let candidate = joinPath(ArchivePaths.gallery, album, `${day}${extension}`);
  let suffix = 2;
  while (taken.has(candidate)) {
    candidate = joinPath(ArchivePaths.gallery, album, `${day}-${suffix}${extension}`);
    suffix++;
  }
  taken.add(candidate);
  return candidate;
}

/** The album's own folder inside the archive, for the sheet to name. */
export function albumFolder(albumName: string): string {
  return joinPath(ArchivePaths.gallery, safeFileName(albumName.trim() === '' ? 'Album' : albumName.trim()));
}

/**
 * Whether a stored path is a plain relative path that stays where it
 * is put: no `..`, not absolute, no drive, nothing to normalise away.
 * The phone's `GalleryStorage.isSafeRelative`.
 */
export function isSafeRelative(relative: string): boolean {
  if (relative === '' || relative.length > 512) return false;
  if (relative.includes('\\') || relative.includes(':')) return false;
  if (relative.startsWith('/')) return false;
  const segments = relative.split('/');
  // Anything `normalize` would change is refused: `a//b`, `a/./b`,
  // `a/../b`, a trailing slash.
  return segments.every((segment) => segment !== '' && segment !== '.' && segment !== '..');
}

/** One path segment, with nothing in it that could make it two. */
export function safeSegment(value: string): string {
  const cleaned = value.replace(/[^A-Za-z0-9_-]/g, '');
  return cleaned === '' ? 'x' : cleaned;
}

/** A short plain extension from [path], or [fallback]. */
export function plainExtension(path: string, fallback = '.jpg'): string {
  const extension = extensionOf(path).toLowerCase();
  return /^\.[a-z0-9]{1,4}$/.test(extension) ? extension : fallback;
}

// ------------------------------------------------------------- values

const timePattern =
  /^(\d{4})-(\d{2})-(\d{2})(?:[T ](\d{2}):(\d{2})(?::(\d{2})(?:[.,](\d+))?)?)?\s*(Z|[+-]\d{2}(?::?\d{2})?)?$/i;

/**
 * A cell's timestamp as the instant every row stores (ISO-8601 UTC).
 *
 * The phone writes its own clock without an offset, which Dart reads
 * back as local time, so a bare timestamp here is local time too; one
 * with a `Z` or an offset is exactly that. Microseconds survive, as
 * the phone writes them when it has them. Null for anything else.
 */
export function instantOf(text: string | undefined | null): string | null {
  if (!text) return null;
  const match = timePattern.exec(text.trim());
  if (!match) return null;
  const [, y, mo, d, h = '0', mi = '0', s = '0', fraction = '', zone] = match;
  const micros = Number((fraction + '000000').slice(0, 6));
  const fields = [Number(y), Number(mo) - 1, Number(d), Number(h), Number(mi), Number(s), Math.floor(micros / 1000)] as const;
  let millis: number;
  if (zone) {
    let offset = 0;
    if (zone.toUpperCase() !== 'Z') {
      const digits = zone.slice(1).replace(':', '');
      offset = (Number(digits.slice(0, 2)) * 60 + Number(digits.slice(2) || '0')) * (zone.startsWith('-') ? -1 : 1);
    }
    millis = Date.UTC(...fields) - offset * 60_000;
  } else {
    const local = new Date(...fields);
    if (fields[0] < 100) local.setFullYear(fields[0]);
    millis = local.getTime();
  }
  if (!Number.isFinite(millis)) return null;
  const iso = new Date(millis).toISOString();
  const sub = micros % 1000;
  return sub === 0 ? iso : `${iso.slice(0, -1)}${String(sub).padStart(3, '0')}Z`;
}

/** A Harvest Day key from a cell, even one a spreadsheet made a date. */
export function dayOf(text: string | undefined | null): string | null {
  const match = /^(\d{4}-\d{2}-\d{2})/.exec(text?.trim() ?? '');
  return match ? match[1]! : null;
}

/** An integer, rounding a decimal the way Dart's `round` does. */
export function intOf(text: string | undefined | null): number | null {
  if (text === undefined || text === null || text === '') return null;
  if (/^[+-]?\d+$/.test(text)) {
    const value = Number(text);
    return Number.isSafeInteger(value) ? value : null;
  }
  const value = Number(text);
  if (!Number.isFinite(value)) return null;
  const rounded = Math.sign(value) * Math.round(Math.abs(value));
  return Object.is(rounded, -0) ? 0 : rounded;
}

export function realOf(text: string | undefined | null): number | null {
  if (text === undefined || text === null || text === '') return null;
  const value = Number(text);
  return Number.isFinite(value) ? value : null;
}

/**
 * A spreadsheet writes booleans half a dozen ways, and a person editing
 * one writes them a seventh. Anything that is not plainly true is false.
 */
export function boolOf(text: string | undefined | null): boolean {
  const value = text?.trim().toLowerCase();
  return value === 'true' || value === '1' || value === 'yes';
}
