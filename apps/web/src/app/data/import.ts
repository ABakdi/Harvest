import { isPortableSetting } from '@harvest/contracts';
import { unzipSync } from 'fflate';
import { boundedUnzip, ZipTooLargeError } from './bounded-zip';
import { ArchiveInvalid, ArchiveLimits, ArchivePaths } from './archive';
import { readWorkbook, type SheetRows } from './archive-xlsx';
import { SheetNames } from './export-sheets';
import type { FileStore } from './files';
import type { Writer } from './writer';
import type { StoredTable } from './db';
import { settleGoalParents } from './goals';
import { spec, at, updated, type Context, type Spec } from './import/sheet-spec';
import { fieldSheets } from './import/field';
import { moneySheets } from './import/money';
import { farmerSheets } from './import/farmer';
import { recordSheets } from './import/records';
import { bodySheets } from './import/body';
import { placeSheets } from './import/places';
import { planRows, type Planned } from './import/plan';
import { planMemories, planAttachments, noteBodies } from './import/files';

/**
 * "My data", back in: a Harvest archive merged into this browser
 * ([[ADR-007-Archive-Format]], Business Rules #11). A port of the
 * phone's `archive_reader.dart` and `import_service.dart`, under the
 * same rules and none of them negotiable:
 *
 * - **Merge by uuid.** A row already here is replaced only when the
 *   archive's copy is newer by its own clock (`UpdatedAt` wherever the
 *   table has one, so a deletion wins like any other edit — B-05).
 * - **Nothing here is deleted for being missing.** An archive is a
 *   second copy, not an authority.
 * - **Previewed first.** [previewImport] and [applyImport] read the
 *   archive the same way, so what was shown is what happens.
 * - **An archive is data, never instructions.** It does not choose
 *   where a file goes, which bookkeeping this device believes, or how
 *   much memory it may take.
 *
 * Every row goes through the writer, so it is checked against the
 * contract and queued for sync like any other change ([[Audit-v2]]
 * Q3-01). A row the contract refuses is left out and counted, where
 * the phone would have stored it as it came.
 */

/** A Harvest archive, opened. */
export interface ArchiveBundle {
  /** Sheet name to its rows, keyed by header. */
  sheets: Map<string, SheetRows>;
  /** Everything else in the zip, by its path inside it. */
  files: Map<string, Uint8Array>;
  /**
   * Entries left out for being over `ArchiveLimits.entryBytes`: one long
   * video costs its own file, never the whole archive (Q5-06).
   */
  skipped?: number;
}

/**
 * Opens a Harvest zip. Nothing is written by this: reading is kept
 * apart from applying so the preview can be shown and refused
 * (ADR-007 rule 6).
 */
export function openArchive(bytes: Uint8Array): ArchiveBundle {
  if (bytes.length > ArchiveLimits.archiveBytes) throw new ArchiveInvalid('tooLarge');

  // The sizes come from the zip's own directory, so they are checked
  // before a single entry is inflated: a bomb is refused by its label.
  const listed: { name: string; size: number }[] = [];
  try {
    unzipSync(bytes, {
      filter: (file) => {
        listed.push({ name: file.name, size: file.originalSize });
        return false;
      },
    });
  } catch {
    throw new ArchiveInvalid('unreadable');
  }
  if (listed.length > ArchiveLimits.entries) throw new ArchiveInvalid('tooLarge');
  const limitOf = (name: string) => (name === ArchivePaths.workbook ? ArchiveLimits.workbookBytes : ArchiveLimits.entryBytes);
  let expanded = 0;
  const oversized = new Set<string>();
  for (const entry of listed) {
    if (entry.name.endsWith('/')) continue;
    const workbookEntry = entry.name === ArchivePaths.workbook;
    if (entry.size < 0 || (workbookEntry && entry.size > limitOf(entry.name))) throw new ArchiveInvalid('tooLarge');
    if (entry.size > limitOf(entry.name)) {
      // Left out, never inflated, and counted for the preview.
      oversized.add(entry.name);
      continue;
    }
    expanded += entry.size;
    if (expanded > ArchiveLimits.expandedBytes) throw new ArchiveInvalid('tooLarge');
  }

  // Weighed as it inflates, whatever the directory claimed (S6-09).
  let entries: Record<string, Uint8Array>;
  try {
    entries = boundedUnzip(bytes, {
      limitOf,
      total: ArchiveLimits.expandedBytes,
      maxEntries: ArchiveLimits.entries,
      keep: (name) => !oversized.has(name),
    });
  } catch (error) {
    throw new ArchiveInvalid(error instanceof ZipTooLargeError ? 'tooLarge' : 'unreadable');
  }

  // The label is the archive's own word, so what came out is weighed
  // again ([[Audit-v2]] S3-01).
  const files = new Map<string, Uint8Array>();
  let workbook: Uint8Array | null = null;
  let inflated = 0;
  for (const [name, data] of Object.entries(entries)) {
    inflated += data.length;
    if (data.length > limitOf(name) || inflated > ArchiveLimits.expandedBytes) throw new ArchiveInvalid('tooLarge');
    if (name === ArchivePaths.workbook) workbook = data;
    else files.set(name, data);
  }
  if (workbook === null) throw new ArchiveInvalid('notHarvest');

  let sheets: Map<string, SheetRows>;
  try {
    sheets = readWorkbook(workbook);
  } catch (error) {
    throw new ArchiveInvalid(error instanceof ZipTooLargeError ? 'tooLarge' : 'badWorkbook');
  }
  return { sheets, files, skipped: oversized.size };
}

/** What an import would do to one sheet. */
export interface ImportCount {
  added: number;
  updated: number;
  unchanged: number;
  /** Rows the contract refused, left out rather than stored broken. */
  skipped: number;
}

export interface ImportPreview {
  /** Per sheet, by the phone's sheet name. */
  tables: Record<string, ImportCount>;
  /** Files in the archive, and how many are not in this browser yet. */
  files: number;
  newFiles: number;
  /** Files too large to bring in, left out rather than refusing the archive. */
  skippedFiles?: number;
}

export function totalOf(preview: ImportPreview): ImportCount {
  const total: ImportCount = { added: 0, updated: 0, unchanged: 0, skipped: 0 };
  for (const count of Object.values(preview.tables)) {
    total.added += count.added;
    total.updated += count.updated;
    total.unchanged += count.unchanged;
    total.skipped += count.skipped;
  }
  return total;
}

/**
 * Sheet by sheet, parents first, the phone's `_tables` in the phone's
 * order. Recordings are merged right after the notes, and memories
 * right after the albums (see [merge]).
 */
/**
 * Sheet by sheet, parents first, the phone's `_tables` in the phone's
 * order. Recordings are merged right after the notes, and memories
 * right after the albums (see [merge]).
 */
const specs: Spec<StoredTable>[] = [
  ...fieldSheets,
  ...moneySheets,
  ...farmerSheets,
  ...recordSheets,
  ...bodySheets,
  // My preferences, and none of the device's bookkeeping: an archive
  // must not arm a lock or tell the streak engine the past is judged
  // ([[Audit-v2-Beta]] S2-04).
  spec({
    sheet: 'settings',
    table: 'kv_settings',
    keyOf: (row) => row.Key,
    stamp: updated,
    accept: (row) => isPortableSetting(row.Key ?? ''),
    build: (row, { now }) => ({
      key: row.Key,
      valueJson: row.Value ?? '',
      updatedAt: at(row.UpdatedAt) ?? now,
    }),
  }),
  ...placeSheets,
];

export interface ImportProgress {
  done: number;
  total: number;
}

/** How many steps a merge takes: every table, and the two with files. */
const stepCount = specs.length + 2;

async function merge(
  writer: Writer,
  bundle: ArchiveBundle,
  {
    write,
    onProgress,
    files,
  }: { write: boolean; onProgress?: ((progress: ImportProgress) => void) | undefined; files?: FileStore | undefined },
): Promise<ImportPreview> {
  const db = writer.db;
  const context: Context = { now: writer.clock().toISOString(), bodies: noteBodies(bundle) };
  const result: ImportPreview = { tables: {}, files: bundle.files.size, newFiles: 0, skippedFiles: bundle.skipped ?? 0 };
  let done = 0;

  const carry = async (sheet: string, planned: Planned) => {
    result.tables[sheet] = planned.count;
    result.newFiles += planned.newFiles;
    if (write) {
      // Files first, then the rows that point at them: a failure between
      // leaves a file nothing names, never a row naming nothing.
      if (planned.files.size > 0) {
        const fetchedAt = new Date().toISOString();
        await db.files.bulkPut([...planned.files].map(([sha256, bytes]) => ({ sha256, blob: new Blob([bytes.slice()]), fetchedAt })));
      }
      if (planned.pending.length > 0) {
        // One transaction per table, so a failure leaves whole tables. Not a
        // local action: the archive's own geotags come with it, and today's
        // position must not be stamped on (or shadow) them.
        await writer.run(
          async (tx) => {
            for (const { table, row } of planned.pending) await tx.put(table, row as never);
          },
          { local: false },
        );
      }
      // Queued once the rows are there, so a pass never finds an entry
      // whose row it cannot see and drops it.
      if (files) await files.queueAll(planned.uploads);
    }
    done++;
    onProgress?.({ done, total: stepCount });
  };

  for (const item of specs) {
    const name = SheetNames[item.sheet];
    await carry(name, await planRows(db, item, bundle.sheets.get(name) ?? [], context));
    if (item.sheet === 'notes') await carry(SheetNames.noteAttachments, await planAttachments(db, bundle, context));
    if (item.sheet === 'albums') await carry(SheetNames.memories, await planMemories(db, bundle, context));
  }
  return result;
}

/** What [bundle] would change, without changing anything. */
export function previewImport(writer: Writer, bundle: ArchiveBundle): Promise<ImportPreview> {
  return merge(writer, bundle, { write: false });
}

/**
 * Carries the merge out, through the writer, so sync hears every row.
 * With [files], the pictures and recordings it brought join the upload
 * queue and a pass starts, so the other devices get them too.
 */
export async function applyImport(
  writer: Writer,
  bundle: ArchiveBundle,
  { onProgress, files }: { onProgress?: (progress: ImportProgress) => void; files?: FileStore } = {},
): Promise<ImportPreview> {
  const result = await merge(writer, bundle, { write: true, onProgress, files });
  // A parent's tick is drawn from its subtasks (GL3), whichever copy of
  // each the merge kept (Q5-44).
  await settleGoalParents(writer);
  // No passphrase yet, or no connection: the queue keeps them for later.
  if (files) void files.upload().catch(() => undefined);
  return result;
}
