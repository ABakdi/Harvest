import { isPortableSetting, tierOf } from '@harvest/contracts';
import { strToU8, zipSync, type Zippable } from 'fflate';
import { albumFolder, archiveFileName, ArchivePaths, attachmentPath, memoryPath, notePath } from './archive';
import { buildWorkbook, type CellValue } from './archive-xlsx';
import type { HarvestDB } from './db';
import { harvestSheets, type ExportData } from './export-sheets';
import { localFileHashes } from './files';

/**
 * "My data", out: the whole of this browser's copy as the same zip the
 * phone writes ([[ADR-007-Archive-Format]], Business Rules #11). The
 * workbook with its live formulas, the notes as a vault of markdown,
 * and every picture and recording this browser has or can fetch.
 *
 * A port of the phone's `export_repository.dart` and
 * `archive_service.dart`. It reads the tables directly rather than
 * through the repositories on purpose: those show what a screen should
 * show, and an export that quietly drops rows is not a backup (rule
 * X7). The trash goes out with everything else.
 */

/** How far the archive has got, for a screen to show. */
export interface ArchiveProgress {
  done: number;
  total: number;
  label: string | null;
}

/** Stopped part-way on purpose. Nothing was saved anywhere. */
export class ArchiveCancelled extends Error {
  override readonly name = 'ArchiveCancelled';
}

/** A file by the name of its bytes: the cache, or the existing download. */
export type FileSource = (sha256: string) => Promise<Blob | null>;

export interface ArchiveContents {
  data: ExportData;
  /** One `.md` per live note, at the path its row names. */
  notes: { path: string; body: string }[];
  /** A picture or clip, fetched by [hash]. */
  memories: { path: string; hash: string | null }[];
  /** A recording beside its note's `.md` ([[Notes]] N7). */
  attachments: { path: string; hash: string | null }[];
}

const locationTables = ['saved_places', 'location_points', 'geotags'] as const;

/**
 * Everything the archive is written from, in one pass: the rows and
 * the files have to be laid out together, because the sheet says where
 * each file went (ADR-007 rule 4).
 */
export async function readArchiveContents(
  db: HarvestDB,
  { generatedAt, includePlaces = true }: { generatedAt: Date; includePlaces?: boolean },
): Promise<ArchiveContents> {
  const all = <T extends Parameters<HarvestDB['rows']>[0]>(table: T) => db.rows(table).toArray();
  const [
    seeds,
    checkIns,
    seedNotes,
    goals,
    goalItems,
    lists,
    wishlist,
    expenses,
    categories,
    money,
    debts,
    payments,
    focus,
    ledger,
    streaks,
    settings,
    notes,
    attachments,
    albums,
    memories,
    steps,
    weights,
    sleep,
    exercises,
    programs,
    days,
    slots,
    targets,
    maxes,
    sessions,
    sessionExercises,
    sets,
  ] = await Promise.all([
    all('commitments'),
    all('check_ins'),
    all('seed_notes'),
    all('goals'),
    all('goal_items'),
    all('lists'),
    all('wishlist_items'),
    all('expenses'),
    all('expense_categories'),
    all('money_txns'),
    all('debts'),
    all('debt_payments'),
    all('pomodoro_sessions'),
    all('ledger'),
    all('streaks'),
    all('kv_settings'),
    all('notes'),
    all('note_attachments'),
    all('albums'),
    all('memories'),
    all('step_days'),
    all('body_weights'),
    all('sleep_sessions'),
    all('exercises'),
    all('programs'),
    all('program_days'),
    all('program_slots'),
    all('target_sets'),
    all('training_maxes'),
    all('workout_sessions'),
    all('session_exercises'),
    all('workout_sets'),
  ]);
  // Location is exported only with my say-so, per export (PL6).
  const [places, points, geotags] = includePlaces
    ? await Promise.all([all('saved_places'), all('location_points'), all('geotags')])
    : [[], [], []];

  // A file made here waits with no hash on its row until the server has
  // it; the archive still carries it, from this browser's own copy.
  const local = await localFileHashes(db);
  const hashOf = (row: { uuid: string; fileHash: string | null }) => row.fileHash ?? local.get(row.uuid) ?? null;

  const taken = new Set<string>();
  const noteFiles: ArchiveContents['notes'] = [];
  const livePaths = new Map<string, string>();
  const noteRows: CellValue[][] = notes.map((row) => {
    const path = notePath({ title: row.title, folder: row.folder, taken });
    // A deleted note keeps its row so a merge can see it, but gets no
    // file: the vault is what I still have.
    const live = row.deletedAt === null;
    if (live) {
      noteFiles.push({ path, body: row.body });
      livePaths.set(row.uuid, path);
    }
    return [row.uuid, row.title, row.folder, live ? path : null, row.body, row.createdAt, row.updatedAt, row.deletedAt];
  });

  // A recording goes beside its note's `.md`; one in the trash, or on a
  // note in the trash, keeps its row and leaves no file.
  const attachmentFiles: ArchiveContents['attachments'] = [];
  const attachmentRows: CellValue[][] = attachments.map((row) => {
    const note = livePaths.get(row.noteUuid);
    let path: string | null = null;
    if (row.deletedAt === null && note !== undefined) {
      path = attachmentPath({ notePath: note, fileName: row.fileName, taken });
      attachmentFiles.push({ path, hash: hashOf(row) });
    }
    return [
      row.uuid,
      row.noteUuid,
      row.kind,
      row.fileName,
      path,
      row.storedPath,
      row.durationMs,
      row.sizeBytes,
      row.fileHash,
      row.createdAt,
      row.updatedAt,
      row.deletedAt,
    ];
  });

  // A memory in the trash keeps its row and its file: the archive
  // carries the trash as it stands, so an import does not resurrect it.
  const albumNames = new Map(albums.map((row) => [row.uuid, row.name]));
  const memoryFiles: ArchiveContents['memories'] = [];
  const memoryRows: CellValue[][] = memories.map((row) => {
    const path = memoryPath({ albumName: albumNames.get(row.albumUuid) ?? 'Album', day: row.harvestDay, storedPath: row.path, taken });
    memoryFiles.push({ path, hash: hashOf(row) });
    return [
      row.uuid,
      row.albumUuid,
      row.harvestDay,
      path,
      row.path,
      row.kind,
      row.note,
      row.fileHash,
      row.capturedAt,
      row.updatedAt,
      row.deletedAt,
    ];
  });

  const data: ExportData = {
    generatedAt: generatedAt.toISOString(),
    seeds: seeds.map((row) => [
      row.uuid,
      row.type,
      row.title,
      row.scheduleJson,
      row.totalTarget,
      row.dailyCommitment,
      row.dueDay,
      row.note,
      row.remindAt,
      row.deadline,
      row.goalUuid,
      row.pausedAt,
      row.archivedAt,
      row.archiveNote,
      row.deletedAt,
      row.createdAt,
      row.updatedAt,
    ]),
    checkIns: checkIns.map((row) => [
      row.uuid,
      row.commitmentUuid,
      row.harvestDay,
      row.quantity,
      row.loggedAt,
      row.updatedAt,
      row.deletedAt,
    ]),
    seedNotes: seedNotes.map((row) => [
      row.uuid,
      row.commitmentUuid,
      row.harvestDay,
      row.body,
      row.loggedAt,
      row.updatedAt,
      row.deletedAt,
    ]),
    goals: goals.map((row) => [
      row.uuid,
      row.title,
      row.why,
      row.targetDay,
      row.status,
      row.statusNote,
      row.achievedAt,
      row.position,
      row.createdAt,
      row.updatedAt,
      row.deletedAt,
    ]),
    goalItems: goalItems.map((row) => [
      row.uuid,
      row.goalUuid,
      row.kind,
      row.body,
      row.note,
      row.doneAt,
      row.position,
      row.commitmentUuid,
      row.parentUuid ?? null,
      row.createdAt,
      row.updatedAt,
      row.deletedAt,
    ]),
    lists: lists.map((row) => [
      row.uuid,
      row.name,
      row.kind,
      row.icon,
      row.position,
      row.builtIn,
      row.createdAt,
      row.updatedAt,
      row.deletedAt,
    ]),
    wishlist: wishlist.map((row) => [
      row.uuid,
      row.list,
      // A row kept from before lists may have no key for these at all.
      row.listUuid ?? null,
      row.title,
      row.priceMinor,
      row.currency,
      row.note,
      row.targetDay,
      row.mediaType ?? null,
      row.link ?? null,
      row.creator ?? null,
      row.startedAt ?? null,
      row.rating ?? null,
      row.seedUuid ?? null,
      row.noteUuid ?? null,
      row.boughtAt,
      row.position,
      row.createdAt,
      row.updatedAt,
      row.deletedAt,
    ]),
    expenses: expenses.map((row) => [
      row.uuid,
      row.harvestDay,
      row.category,
      row.currency,
      row.amountMinor,
      row.note,
      row.loggedAt,
      row.updatedAt,
      row.deletedAt,
    ]),
    categories: categories.map((row) => [row.uuid, row.name, row.icon, row.createdAt, row.updatedAt, row.deletedAt]),
    money: money.map((row) => [
      row.uuid,
      row.harvestDay,
      row.account,
      row.kind,
      row.reference,
      row.currency,
      row.deltaMinor,
      row.note,
      row.linkUuid,
      row.loggedAt,
      row.updatedAt,
      row.deletedAt,
    ]),
    debts: debts.map((row) => [
      row.uuid,
      row.person,
      row.currency,
      row.amountMinor,
      row.payOffBy,
      row.remindAt,
      row.note,
      row.settledAt,
      row.createdAt,
      row.deletedAt,
      row.updatedAt,
    ]),
    debtPayments: payments.map((row) => [row.uuid, row.debtUuid, row.harvestDay, row.amountMinor, row.loggedAt, row.deletedAt]),
    focus: focus.map((row) => [row.uuid, row.commitmentUuid, row.harvestDay, row.focusBlocks, row.startedAt, row.endedAt]),
    ledger: ledger.map((row) => [row.uuid, row.kind, row.delta, row.reason, row.harvestDay, row.loggedAt]),
    streaks: streaks.map((row) => [row.scope, row.current, row.best, row.lastEarnedDay, row.freezesStored, row.updatedAt]),
    // Only my preferences: a device's own bookkeeping means nothing
    // anywhere else, and the importer refuses it anyway (S3-05).
    settings: settings.filter((row) => isPortableSetting(row.key)).map((row) => [row.key, row.valueJson, row.updatedAt]),
    notes: noteRows,
    noteAttachments: attachmentRows,
    albums: albums.map((row) => [
      row.uuid,
      row.name,
      albumFolder(row.name),
      row.scheduleJson,
      row.remindAt,
      row.note,
      row.createdAt,
      row.updatedAt,
      row.deletedAt,
    ]),
    memories: memoryRows,
    steps: steps.map((row) => [row.harvestDay, row.steps, row.lastCounter, row.updatedAt]),
    weights: weights.map((row) => [row.uuid, row.harvestDay, row.grams, row.note, row.measuredAt, row.updatedAt, row.deletedAt]),
    sleep: sleep.map((row) => [
      row.uuid,
      row.harvestDay,
      row.fellAsleepAt,
      row.wokeAt,
      row.targetMinutes,
      row.restedStars,
      row.note,
      row.createdAt,
      row.updatedAt,
      row.deletedAt,
    ]),
    exercises: exercises.map((row) => [
      row.uuid,
      row.name,
      row.bodyPart,
      row.equipment,
      row.target,
      row.note,
      row.createdAt,
      row.updatedAt,
      row.deletedAt,
    ]),
    programs: programs.map((row) => [
      row.uuid,
      row.name,
      row.note,
      row.weeks,
      row.commitmentUuid,
      row.albumUuid,
      row.photoPrompt,
      row.createdAt,
      row.updatedAt,
      row.deletedAt,
    ]),
    programDays: days.map((row) => [row.uuid, row.programUuid, row.name, row.position, row.week, row.accessories]),
    programSlots: slots.map((row) => [row.uuid, row.dayUuid, row.exerciseId, row.position, row.restSeconds, row.barGrams, row.note]),
    targetSets: targets.map((row) => [
      row.uuid,
      row.slotUuid,
      row.position,
      row.reps,
      row.weightGrams,
      row.percentTenths,
      row.openEnded,
    ]),
    trainingMaxes: maxes.map((row) => [row.programUuid, row.exerciseId, row.grams, row.updatedAt]),
    sessions: sessions.map((row) => [
      row.uuid,
      row.programUuid,
      row.dayUuid,
      row.title,
      row.harvestDay,
      row.note,
      row.startedAt,
      row.endedAt,
      row.pausedAt,
      row.pausedSeconds,
      row.updatedAt,
      row.deletedAt,
    ]),
    sessionExercises: sessionExercises.map((row) => [
      row.uuid,
      row.sessionUuid,
      row.position,
      row.exerciseId,
      row.plannedExerciseId,
      row.slotUuid,
      row.skipped,
      row.skipReason,
      row.note,
      row.restSeconds,
      row.barGrams,
    ]),
    sets: sets.map((row) => [
      row.uuid,
      row.sessionExerciseUuid,
      row.position,
      row.weightGrams,
      row.reps,
      row.done,
      row.targetLabel,
      row.openEnded,
      row.loggedAt,
    ]),
    savedPlaces: places.map((row) => [
      row.uuid,
      row.name,
      row.latitude,
      row.longitude,
      row.radiusM,
      row.notes,
      row.createdAt,
      row.updatedAt,
      row.deletedAt,
    ]),
    locationPoints: points.map((row) => [
      row.uuid,
      row.harvestDay,
      row.recordedAt,
      row.latitude,
      row.longitude,
      row.accuracyM,
      row.speedMps,
      row.altitudeM,
      row.updatedAt,
      row.deletedAt,
    ]),
    geotags: geotags.map((row) => [
      row.uuid,
      row.targetTable,
      row.targetUuid,
      row.harvestDay,
      row.at,
      row.latitude,
      row.longitude,
      row.accuracyM,
      row.state,
      row.updatedAt,
      row.deletedAt,
    ]),
  };

  return { data, notes: noteFiles, memories: memoryFiles, attachments: attachmentFiles };
}

export interface BuiltArchive {
  bytes: Uint8Array;
  fileName: string;
  /**
   * Private-tier rows this browser holds only sealed, because the
   * passphrase has not been entered here: they cannot be in the
   * archive, and the screen says so rather than hand over less than it
   * looks like.
   */
  sealed: number;
  /** Files a row names that this browser could not get. */
  missingFiles: number;
}

/** Already-compressed media gain nothing from deflate. */
function levelFor(path: string): 0 | 6 {
  return /\.(jpe?g|png|webp|heic|gif|mp4|mov|m4a|aac|mp3|ogg|opus|webm)$/i.test(path) ? 0 : 6;
}

/**
 * Builds the zip in memory and hands it over in one piece: a
 * half-written archive that looks finished is worse than none
 * (ADR-007). [cancelled] is asked between entries.
 */
export async function buildArchive(
  db: HarvestDB,
  file: FileSource,
  {
    now = new Date(),
    includePlaces = true,
    onProgress,
    cancelled,
  }: {
    now?: Date;
    includePlaces?: boolean;
    onProgress?: (progress: ArchiveProgress) => void;
    cancelled?: () => boolean;
  } = {},
): Promise<BuiltArchive> {
  const contents = await readArchiveContents(db, { generatedAt: now, includePlaces });
  const entries: Zippable = {};
  const total = 1 + contents.notes.length + contents.attachments.length + contents.memories.length;
  let done = 0;
  let missingFiles = 0;
  const step = (label: string | null) => {
    done++;
    onProgress?.({ done, total, label });
  };
  const check = () => {
    if (cancelled?.()) throw new ArchiveCancelled();
  };

  entries[ArchivePaths.workbook] = [buildWorkbook(harvestSheets(contents.data), now), { level: 6 }];
  step(ArchivePaths.workbook);

  for (const note of contents.notes) {
    check();
    entries[note.path] = [strToU8(note.body), { level: 6 }];
    step(note.path);
  }

  // A row whose file cannot be had is not a reason to lose the archive:
  // the row still goes out, and the sheet is honest about it.
  for (const item of [...contents.attachments, ...contents.memories]) {
    check();
    const blob = item.hash === null ? null : await file(item.hash);
    if (blob === null) missingFiles++;
    else entries[item.path] = [new Uint8Array(await blob.arrayBuffer()), { level: levelFor(item.path) }];
    step(item.path);
  }

  check();
  const sealed = (await db.sealed.toArray()).filter(
    (row) => tierOf(row.table) === 'private' && (includePlaces || !(locationTables as readonly string[]).includes(row.table)),
  ).length;
  return { bytes: zipSync(entries, { mtime: now }), fileName: archiveFileName(now), sealed, missingFiles };
}
