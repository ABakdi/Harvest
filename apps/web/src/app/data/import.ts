import { instantMicros, isPortableSetting, listUuidOfItem, tables, tierOf, type SyncedTable } from '@harvest/contracts';
import { unzipSync } from 'fflate';
import {
  ArchiveInvalid,
  ArchiveLimits,
  ArchivePaths,
  boolOf,
  dayOf,
  instantOf,
  intOf,
  isSafeRelative,
  plainExtension,
  realOf,
  safeFileName,
  safeSegment,
} from './archive';
import { readWorkbook, type SheetRows } from './archive-xlsx';
import { primaryKeyOf, recordKeyOf, type HarvestDB, type Row } from './db';
import { SheetNames, type SheetKey } from './export-sheets';
import { sha256Of, type FileStore, type PendingUpload } from './files';
import type { Writer } from './writer';

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

/** A rating the contract takes, 1–5; anything else reads as none, as on the phone. */
function ratingOf(stars: number | null): number | null {
  return stars !== null && stars >= 1 && stars <= 5 ? stars : null;
}

/** A Harvest archive, opened. */
export interface ArchiveBundle {
  /** Sheet name to its rows, keyed by header. */
  sheets: Map<string, SheetRows>;
  /** Everything else in the zip, by its path inside it. */
  files: Map<string, Uint8Array>;
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
  for (const entry of listed) {
    if (entry.name.endsWith('/')) continue;
    if (entry.size < 0 || entry.size > limitOf(entry.name)) throw new ArchiveInvalid('tooLarge');
    expanded += entry.size;
    if (expanded > ArchiveLimits.expandedBytes) throw new ArchiveInvalid('tooLarge');
  }

  let entries: Record<string, Uint8Array>;
  try {
    entries = unzipSync(bytes, { filter: (file) => !file.name.endsWith('/') });
  } catch {
    throw new ArchiveInvalid('unreadable');
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
  } catch {
    throw new ArchiveInvalid('badWorkbook');
  }
  return { sheets, files };
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

type SheetRow = Record<string, string>;

interface Context {
  now: string;
  /** Note bodies from the vault, by archive path. */
  bodies: Map<string, string>;
}

/** How one sheet merges into one table. */
interface Spec<T extends SyncedTable> {
  sheet: SheetKey;
  table: T;
  keyOf: (row: SheetRow) => string | null | undefined;
  /**
   * The column that says how new the row is, and the local column it is
   * compared with. Null for a child row that has no clock of its own —
   * it is added when missing and otherwise left alone.
   */
  stamp: { sheet: string; local: keyof Row<T> & string } | null;
  build: (row: SheetRow, context: Context, existing: Row<T> | undefined) => Record<string, unknown>;
  accept?: (row: SheetRow) => boolean;
}

function spec<T extends SyncedTable>(value: Spec<T>): Spec<SyncedTable> {
  return value;
}

const uuidOf = (row: SheetRow) => row.Uuid;
const text = (value: string | undefined) => value ?? null;
const at = (value: string | undefined) => instantOf(value);
const updated = { sheet: 'UpdatedAt', local: 'updatedAt' } as const;

/**
 * Sheet by sheet, parents first, the phone's `_tables` in the phone's
 * order. Recordings are merged right after the notes, and memories
 * right after the albums (see [merge]).
 */
const specs: Spec<SyncedTable>[] = [
  spec({
    sheet: 'seeds',
    table: 'commitments',
    keyOf: uuidOf,
    stamp: updated,
    build: (row, { now }) => ({
      uuid: row.Uuid,
      type: row.Type ?? 'habit',
      title: row.Title ?? '',
      scheduleJson: text(row.Schedule),
      totalTarget: intOf(row.TotalTarget),
      dailyCommitment: intOf(row.DailyCommitment),
      dueDay: dayOf(row.DueDay),
      pausedAt: at(row.PausedAt),
      note: text(row.Note),
      remindAt: text(row.RemindAt),
      deadline: dayOf(row.Deadline),
      goalUuid: text(row.GoalUuid),
      archivedAt: at(row.ArchivedAt),
      archiveNote: text(row.ArchiveNote),
      deletedAt: at(row.DeletedAt),
      createdAt: at(row.CreatedAt) ?? now,
      updatedAt: at(row.UpdatedAt) ?? now,
    }),
  }),
  spec({
    sheet: 'goals',
    table: 'goals',
    keyOf: uuidOf,
    stamp: updated,
    build: (row, { now }) => ({
      uuid: row.Uuid,
      title: row.Title ?? '',
      why: row.Why ?? '',
      targetDay: dayOf(row.TargetDay),
      status: row.Status ?? 'active',
      statusNote: text(row.StatusNote),
      achievedAt: at(row.AchievedAt),
      position: intOf(row.Position) ?? 0,
      createdAt: at(row.CreatedAt) ?? now,
      updatedAt: at(row.UpdatedAt) ?? now,
      deletedAt: at(row.DeletedAt),
    }),
  }),
  spec({
    sheet: 'goalItems',
    table: 'goal_items',
    keyOf: uuidOf,
    stamp: updated,
    build: (row, { now }) => ({
      uuid: row.Uuid,
      goalUuid: row.GoalUuid ?? '',
      kind: row.Kind ?? 'step',
      body: row.Body ?? '',
      note: text(row.Note),
      doneAt: at(row.DoneAt),
      position: intOf(row.Position) ?? 0,
      commitmentUuid: text(row.CommitmentUuid),
      // An archive from before v24 has no column, and its items come in
      // top-level (GL6).
      parentUuid: text(row.ParentUuid),
      createdAt: at(row.CreatedAt) ?? now,
      updatedAt: at(row.UpdatedAt) ?? now,
      deletedAt: at(row.DeletedAt),
    }),
  }),
  spec({
    sheet: 'lists',
    table: 'lists',
    keyOf: uuidOf,
    stamp: updated,
    build: (row, { now }) => ({
      uuid: row.Uuid,
      name: row.Name ?? '',
      kind: row.Kind ?? 'plain',
      icon: text(row.Icon),
      position: intOf(row.Position) ?? 0,
      builtIn: text(row.BuiltIn),
      createdAt: at(row.CreatedAt) ?? now,
      updatedAt: at(row.UpdatedAt) ?? now,
      deletedAt: at(row.DeletedAt),
    }),
  }),
  spec({
    sheet: 'wishlist',
    table: 'wishlist_items',
    keyOf: uuidOf,
    stamp: updated,
    build: (row, { now }) => ({
      uuid: row.Uuid,
      list: row.List ?? 'buy',
      // An archive from before lists has no ListUuid; its List names the
      // shopping list, as the phone reads it.
      listUuid: text(row.ListUuid) ?? listUuidOfItem({ list: row.List ?? 'buy' }),
      title: row.Title ?? '',
      priceMinor: intOf(row.PriceMinor),
      currency: row.Currency ?? 'DZD',
      note: text(row.Note),
      targetDay: dayOf(row.TargetDay),
      mediaType: text(row.MediaType),
      link: text(row.Link),
      creator: text(row.Creator),
      startedAt: at(row.StartedAt),
      rating: ratingOf(intOf(row.Rating)),
      seedUuid: text(row.SeedUuid),
      noteUuid: text(row.NoteUuid),
      boughtAt: at(row.BoughtAt),
      position: intOf(row.Position) ?? 0,
      createdAt: at(row.CreatedAt) ?? now,
      updatedAt: at(row.UpdatedAt) ?? now,
      deletedAt: at(row.DeletedAt),
    }),
  }),
  spec({
    sheet: 'checkIns',
    table: 'check_ins',
    keyOf: uuidOf,
    stamp: updated,
    build: (row, { now }) => ({
      uuid: row.Uuid,
      commitmentUuid: row.CommitmentUuid ?? '',
      harvestDay: dayOf(row.HarvestDay) ?? '',
      quantity: intOf(row.Quantity) ?? 1,
      loggedAt: at(row.LoggedAt) ?? now,
      // An archive from before the column: as new as it was logged.
      updatedAt: at(row.UpdatedAt) ?? at(row.LoggedAt) ?? now,
      deletedAt: at(row.DeletedAt),
    }),
  }),
  spec({
    sheet: 'seedNotes',
    table: 'seed_notes',
    keyOf: uuidOf,
    stamp: updated,
    build: (row, { now }) => ({
      uuid: row.Uuid,
      commitmentUuid: row.CommitmentUuid ?? '',
      harvestDay: dayOf(row.HarvestDay) ?? '',
      body: row.Body ?? '',
      loggedAt: at(row.LoggedAt) ?? now,
      updatedAt: at(row.UpdatedAt) ?? at(row.LoggedAt) ?? now,
      deletedAt: at(row.DeletedAt),
    }),
  }),
  spec({
    sheet: 'expenses',
    table: 'expenses',
    keyOf: uuidOf,
    stamp: updated,
    build: (row, { now }) => ({
      uuid: row.Uuid,
      harvestDay: dayOf(row.HarvestDay) ?? '',
      category: row.Category ?? '',
      currency: row.Currency ?? 'DZD',
      amountMinor: intOf(row.AmountMinor) ?? 0,
      note: text(row.Note),
      loggedAt: at(row.LoggedAt) ?? now,
      updatedAt: at(row.UpdatedAt) ?? at(row.LoggedAt) ?? now,
      deletedAt: at(row.DeletedAt),
    }),
  }),
  // The categories I made, so every key my expenses use has a name.
  spec({
    sheet: 'categories',
    table: 'expense_categories',
    keyOf: uuidOf,
    stamp: updated,
    build: (row, { now }) => ({
      uuid: row.Uuid,
      name: row.Name ?? '',
      icon: row.Icon ?? '',
      // Missing from an archive made before v21; the list then orders
      // it by UpdatedAt, as it always had.
      createdAt: at(row.CreatedAt),
      updatedAt: at(row.UpdatedAt) ?? now,
      deletedAt: at(row.DeletedAt),
    }),
  }),
  spec({
    sheet: 'money',
    table: 'money_txns',
    keyOf: uuidOf,
    stamp: updated,
    build: (row, { now }) => ({
      uuid: row.Uuid,
      harvestDay: dayOf(row.HarvestDay) ?? '',
      account: row.Account ?? '',
      kind: row.Kind ?? 'manual',
      reference: text(row.Reference),
      currency: row.Currency ?? 'DZD',
      deltaMinor: intOf(row.DeltaMinor) ?? 0,
      note: text(row.Note),
      linkUuid: text(row.LinkUuid),
      loggedAt: at(row.LoggedAt) ?? now,
      updatedAt: at(row.UpdatedAt) ?? at(row.LoggedAt) ?? now,
      deletedAt: at(row.DeletedAt),
    }),
  }),
  spec({
    sheet: 'debts',
    table: 'debts',
    keyOf: uuidOf,
    stamp: updated,
    build: (row, { now }) => ({
      uuid: row.Uuid,
      person: row.Person ?? '',
      currency: row.Currency ?? 'DZD',
      amountMinor: intOf(row.AmountMinor) ?? 0,
      payOffBy: text(row.PayOffBy),
      remindAt: text(row.RemindAt),
      note: text(row.Note),
      settledAt: at(row.SettledAt),
      createdAt: at(row.CreatedAt) ?? now,
      deletedAt: at(row.DeletedAt),
      updatedAt: at(row.UpdatedAt) ?? now,
    }),
  }),
  spec({
    sheet: 'debtPayments',
    table: 'debt_payments',
    keyOf: uuidOf,
    stamp: { sheet: 'LoggedAt', local: 'loggedAt' },
    build: (row, { now }) => ({
      uuid: row.Uuid,
      debtUuid: row.DebtUuid ?? '',
      harvestDay: dayOf(row.HarvestDay) ?? '',
      amountMinor: intOf(row.AmountMinor) ?? 0,
      loggedAt: at(row.LoggedAt) ?? now,
      deletedAt: at(row.DeletedAt),
    }),
  }),
  spec({
    sheet: 'focus',
    table: 'pomodoro_sessions',
    keyOf: uuidOf,
    stamp: { sheet: 'StartedAt', local: 'startedAt' },
    build: (row, { now }) => ({
      uuid: row.Uuid,
      commitmentUuid: text(row.CommitmentUuid),
      harvestDay: dayOf(row.HarvestDay) ?? '',
      focusBlocks: intOf(row.FocusBlocks) ?? 0,
      startedAt: at(row.StartedAt) ?? now,
      endedAt: at(row.EndedAt),
    }),
  }),
  spec({
    sheet: 'ledger',
    table: 'ledger',
    keyOf: uuidOf,
    stamp: { sheet: 'LoggedAt', local: 'loggedAt' },
    build: (row, { now }) => ({
      uuid: row.Uuid,
      kind: row.Kind ?? 'xp',
      delta: intOf(row.Delta) ?? 0,
      reason: row.Reason ?? '',
      harvestDay: dayOf(row.HarvestDay) ?? '',
      loggedAt: at(row.LoggedAt) ?? now,
    }),
  }),
  // Derived state, but derived from history this device may not have,
  // so the newer copy wins like everywhere else (B-02).
  spec({
    sheet: 'streaks',
    table: 'streaks',
    keyOf: (row) => row.Scope,
    stamp: updated,
    build: (row, { now }) => ({
      scope: row.Scope,
      current: intOf(row.Current) ?? 0,
      best: intOf(row.Best) ?? 0,
      lastEarnedDay: dayOf(row.LastEarnedDay),
      freezesStored: intOf(row.FreezesStored) ?? 0,
      updatedAt: at(row.UpdatedAt) ?? now,
    }),
  }),
  spec({
    sheet: 'notes',
    table: 'notes',
    keyOf: uuidOf,
    stamp: updated,
    build: (row, { now, bodies }) => ({
      uuid: row.Uuid,
      title: row.Title ?? '',
      folder: row.Folder ?? '',
      // The `.md` wins over the cell: the vault may have been edited in
      // a text editor, and rule N4 says that has to survive.
      body: bodies.get(row.File ?? '') ?? row.Body ?? '',
      createdAt: at(row.CreatedAt) ?? now,
      updatedAt: at(row.UpdatedAt) ?? now,
      deletedAt: at(row.DeletedAt),
    }),
  }),
  spec({
    sheet: 'albums',
    table: 'albums',
    keyOf: uuidOf,
    stamp: updated,
    build: (row, { now }) => ({
      uuid: row.Uuid,
      name: row.Name ?? '',
      scheduleJson: text(row.ScheduleJson),
      remindAt: text(row.RemindAt),
      note: text(row.Note),
      createdAt: at(row.CreatedAt) ?? now,
      updatedAt: at(row.UpdatedAt) ?? now,
      deletedAt: at(row.DeletedAt),
    }),
  }),
  spec({
    sheet: 'steps',
    table: 'step_days',
    keyOf: (row) => dayOf(row.HarvestDay),
    stamp: updated,
    build: (row, { now }) => ({
      harvestDay: dayOf(row.HarvestDay),
      steps: intOf(row.Steps) ?? 0,
      lastCounter: intOf(row.LastCounter),
      updatedAt: at(row.UpdatedAt) ?? now,
    }),
  }),
  spec({
    sheet: 'weights',
    table: 'body_weights',
    keyOf: uuidOf,
    stamp: updated,
    build: (row, { now }) => ({
      uuid: row.Uuid,
      harvestDay: dayOf(row.HarvestDay) ?? '',
      grams: intOf(row.Grams) ?? 0,
      note: text(row.Note),
      measuredAt: at(row.MeasuredAt) ?? now,
      updatedAt: at(row.UpdatedAt) ?? at(row.MeasuredAt) ?? now,
      deletedAt: at(row.DeletedAt),
    }),
  }),
  spec({
    sheet: 'sleep',
    table: 'sleep_sessions',
    keyOf: uuidOf,
    stamp: updated,
    build: (row, { now }) => ({
      uuid: row.Uuid,
      harvestDay: dayOf(row.HarvestDay) ?? '',
      fellAsleepAt: at(row.FellAsleepAt) ?? now,
      wokeAt: at(row.WokeAt) ?? now,
      targetMinutes: intOf(row.TargetMinutes) ?? 0,
      restedStars: intOf(row.RestedStars),
      note: text(row.Note),
      createdAt: at(row.CreatedAt) ?? now,
      updatedAt: at(row.UpdatedAt) ?? now,
      deletedAt: at(row.DeletedAt),
    }),
  }),
  spec({
    sheet: 'exercises',
    table: 'exercises',
    keyOf: uuidOf,
    stamp: updated,
    build: (row, { now }) => ({
      uuid: row.Uuid,
      name: row.Name ?? '',
      bodyPart: text(row.BodyPart),
      equipment: text(row.Equipment),
      target: text(row.Target),
      note: text(row.Note),
      createdAt: at(row.CreatedAt) ?? now,
      updatedAt: at(row.UpdatedAt) ?? now,
      deletedAt: at(row.DeletedAt),
    }),
  }),
  spec({
    sheet: 'programs',
    table: 'programs',
    keyOf: uuidOf,
    stamp: updated,
    build: (row, { now }) => ({
      uuid: row.Uuid,
      name: row.Name ?? '',
      note: text(row.Note),
      weeks: intOf(row.Weeks),
      commitmentUuid: text(row.CommitmentUuid),
      albumUuid: text(row.AlbumUuid),
      photoPrompt: row.PhotoPrompt ?? 'after',
      createdAt: at(row.CreatedAt) ?? now,
      updatedAt: at(row.UpdatedAt) ?? now,
      deletedAt: at(row.DeletedAt),
    }),
  }),
  spec({
    sheet: 'programDays',
    table: 'program_days',
    keyOf: uuidOf,
    stamp: null,
    build: (row, _, existing) => ({
      uuid: row.Uuid,
      programUuid: row.ProgramUuid ?? '',
      name: row.Name ?? '',
      position: intOf(row.Position) ?? 0,
      week: intOf(row.Week),
      // Older archives have no column: whatever is here stays.
      accessories: 'Accessories' in row ? (row.Accessories ?? null) : (existing?.accessories ?? null),
    }),
  }),
  spec({
    sheet: 'programSlots',
    table: 'program_slots',
    keyOf: uuidOf,
    stamp: null,
    build: (row) => ({
      uuid: row.Uuid,
      dayUuid: row.DayUuid ?? '',
      exerciseId: row.ExerciseId ?? '',
      position: intOf(row.Position) ?? 0,
      restSeconds: intOf(row.RestSeconds),
      barGrams: intOf(row.BarGrams) ?? 20000,
      note: text(row.Note),
    }),
  }),
  spec({
    sheet: 'targetSets',
    table: 'target_sets',
    keyOf: uuidOf,
    stamp: null,
    build: (row) => ({
      uuid: row.Uuid,
      slotUuid: row.SlotUuid ?? '',
      position: intOf(row.Position) ?? 0,
      reps: intOf(row.Reps),
      weightGrams: intOf(row.WeightGrams),
      percentTenths: intOf(row.PercentTenths),
      openEnded: boolOf(row.OpenEnded),
    }),
  }),
  spec({
    sheet: 'trainingMaxes',
    table: 'training_maxes',
    keyOf: (row) => (row.ProgramUuid === undefined || row.ExerciseId === undefined ? null : `${row.ProgramUuid}/${row.ExerciseId}`),
    stamp: updated,
    build: (row, { now }) => ({
      programUuid: row.ProgramUuid,
      exerciseId: row.ExerciseId,
      grams: intOf(row.Grams) ?? 0,
      updatedAt: at(row.UpdatedAt) ?? now,
    }),
  }),
  spec({
    sheet: 'sessions',
    table: 'workout_sessions',
    keyOf: uuidOf,
    stamp: updated,
    build: (row, { now }) => ({
      uuid: row.Uuid,
      programUuid: text(row.ProgramUuid),
      dayUuid: text(row.DayUuid),
      title: text(row.Title),
      harvestDay: dayOf(row.HarvestDay) ?? '',
      note: text(row.Note),
      startedAt: at(row.StartedAt) ?? now,
      endedAt: at(row.EndedAt),
      pausedAt: at(row.PausedAt),
      pausedSeconds: intOf(row.PausedSeconds) ?? 0,
      updatedAt: at(row.UpdatedAt) ?? at(row.StartedAt) ?? now,
      deletedAt: at(row.DeletedAt),
    }),
  }),
  spec({
    sheet: 'sessionExercises',
    table: 'session_exercises',
    keyOf: uuidOf,
    stamp: null,
    build: (row) => ({
      uuid: row.Uuid,
      sessionUuid: row.SessionUuid ?? '',
      position: intOf(row.Position) ?? 0,
      exerciseId: row.ExerciseId ?? '',
      plannedExerciseId: text(row.PlannedExerciseId),
      slotUuid: text(row.SlotUuid),
      skipped: boolOf(row.Skipped),
      skipReason: text(row.SkipReason),
      note: text(row.Note),
      restSeconds: intOf(row.RestSeconds),
      barGrams: intOf(row.BarGrams) ?? 20000,
    }),
  }),
  spec({
    sheet: 'sets',
    table: 'workout_sets',
    keyOf: uuidOf,
    stamp: { sheet: 'LoggedAt', local: 'loggedAt' },
    build: (row, { now }) => ({
      uuid: row.Uuid,
      sessionExerciseUuid: row.SessionExerciseUuid ?? '',
      position: intOf(row.Position) ?? 0,
      weightGrams: intOf(row.WeightGrams) ?? 0,
      reps: intOf(row.Reps) ?? 0,
      done: boolOf(row.Done),
      targetLabel: text(row.TargetLabel),
      openEnded: boolOf(row.OpenEnded),
      loggedAt: at(row.LoggedAt) ?? now,
    }),
  }),
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
  // Places. A blank coordinate reads as 0 rather than failing the
  // table; the archive I wrote never has one.
  spec({
    sheet: 'savedPlaces',
    table: 'saved_places',
    keyOf: uuidOf,
    stamp: updated,
    build: (row, { now }) => ({
      uuid: row.Uuid,
      name: row.Name ?? '',
      latitude: realOf(row.Latitude) ?? 0,
      longitude: realOf(row.Longitude) ?? 0,
      radiusM: realOf(row.RadiusM) ?? 100,
      notes: text(row.Notes),
      createdAt: at(row.CreatedAt) ?? now,
      updatedAt: at(row.UpdatedAt) ?? now,
      deletedAt: at(row.DeletedAt),
    }),
  }),
  spec({
    sheet: 'locationPoints',
    table: 'location_points',
    keyOf: uuidOf,
    stamp: updated,
    build: (row, { now }) => ({
      uuid: row.Uuid,
      harvestDay: dayOf(row.HarvestDay) ?? '',
      recordedAt: at(row.RecordedAt) ?? now,
      latitude: realOf(row.Latitude) ?? 0,
      longitude: realOf(row.Longitude) ?? 0,
      accuracyM: realOf(row.AccuracyM),
      speedMps: realOf(row.SpeedMps),
      altitudeM: realOf(row.AltitudeM),
      updatedAt: at(row.UpdatedAt) ?? at(row.RecordedAt) ?? now,
      deletedAt: at(row.DeletedAt),
    }),
  }),
  spec({
    sheet: 'geotags',
    table: 'geotags',
    keyOf: uuidOf,
    stamp: updated,
    build: (row, { now }) => ({
      uuid: row.Uuid,
      targetTable: row.TargetTable ?? '',
      targetUuid: row.TargetUuid ?? '',
      harvestDay: dayOf(row.HarvestDay) ?? '',
      at: at(row.At) ?? now,
      latitude: realOf(row.Latitude),
      longitude: realOf(row.Longitude),
      accuracyM: realOf(row.AccuracyM),
      state: row.State ?? 'pending',
      updatedAt: at(row.UpdatedAt) ?? now,
      deletedAt: at(row.DeletedAt),
    }),
  }),
];

/** Before every stamp there is: a row with no clock never wins over one here. */
const epoch = Number.NEGATIVE_INFINITY;

function micros(iso: string | null | undefined): number | null {
  if (!iso) return null;
  try {
    return instantMicros(iso);
  } catch {
    return null;
  }
}

/**
 * Every local row's identity and clock. For the private tier, a row
 * this browser holds only sealed counts too: it is here, just not
 * opened yet, and the merge must not call it new.
 */
async function localStamps(db: HarvestDB, table: SyncedTable, column: string | null): Promise<Map<string, number>> {
  const stamps = new Map<string, number>();
  for (const row of (await db.rows(table).toArray()) as Record<string, unknown>[]) {
    stamps.set(recordKeyOf(table, row), column === null ? epoch : (micros(row[column] as string) ?? epoch));
  }
  if (tierOf(table) === 'private') {
    for (const sealed of await db.sealed.where('table').equals(table).toArray()) {
      if (!stamps.has(sealed.uuid)) stamps.set(sealed.uuid, column === null ? epoch : (micros(sealed.updatedAt) ?? epoch));
    }
  }
  return stamps;
}

interface Pending {
  table: SyncedTable;
  row: Record<string, unknown>;
}

/** What one sheet would do, and the rows it would write. */
interface Planned {
  count: ImportCount;
  pending: Pending[];
  /** Files to keep in this browser, by the name of their bytes. */
  files: Map<string, Uint8Array>;
  /** The same files, for the upload queue: the server may not have them. */
  uploads: PendingUpload[];
  newFiles: number;
}

function emptyCount(): ImportCount {
  return { added: 0, updated: 0, unchanged: 0, skipped: 0 };
}

/**
 * Decides one row: new, newer, or neither. Counts it either way, and
 * leaves out a row the contract would refuse.
 */
function decide(
  table: SyncedTable,
  built: Record<string, unknown>,
  local: number | undefined,
  incoming: number | null,
  planned: Planned,
): boolean {
  const parsed = tables[table].data.safeParse(built);
  if (!parsed.success) {
    planned.count.skipped++;
    return false;
  }
  if (local === undefined) {
    planned.count.added++;
  } else if (incoming !== null && incoming > local) {
    // Same stamp is not newer: an archive taken here and put straight
    // back must be a no-op.
    planned.count.updated++;
  } else {
    planned.count.unchanged++;
    return false;
  }
  planned.pending.push({ table, row: parsed.data });
  return true;
}

async function planRows(db: HarvestDB, item: Spec<SyncedTable>, rows: SheetRows, context: Context): Promise<Planned> {
  const planned: Planned = { count: emptyCount(), pending: [], files: new Map(), uploads: [], newFiles: 0 };
  const local = await localStamps(db, item.table, item.stamp?.local ?? null);
  const store = db.rows(item.table);
  for (const row of rows) {
    const key = item.keyOf(row);
    if (!key) continue;
    if (item.accept && !item.accept(row)) {
      planned.count.unchanged++;
      continue;
    }
    const stamp = local.get(key);
    const incoming = item.stamp === null ? null : micros(instantOf(row[item.stamp.sheet]));
    // Only a row that would be written needs building against what is here.
    if (stamp !== undefined && (incoming === null || incoming <= stamp)) {
      planned.count.unchanged++;
      continue;
    }
    const existing = stamp === undefined ? undefined : await store.get(primaryKeyOf(item.table, key));
    decide(item.table, item.build(row, context, existing), stamp, incoming, planned);
  }
  return planned;
}

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

async function planMemories(db: HarvestDB, bundle: ArchiveBundle, context: Context): Promise<Planned> {
  const planned: Planned = { count: emptyCount(), pending: [], files: new Map(), uploads: [], newFiles: 0 };
  const local = await localStamps(db, 'memories', 'updatedAt');
  const today = context.now.slice(0, 10);
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

async function planAttachments(db: HarvestDB, bundle: ArchiveBundle, context: Context): Promise<Planned> {
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
function noteBodies(bundle: ArchiveBundle): Map<string, string> {
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
  const result: ImportPreview = { tables: {}, files: bundle.files.size, newFiles: 0 };
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
  // No passphrase yet, or no connection: the queue keeps them for later.
  if (files) void files.upload().catch(() => undefined);
  return result;
}
