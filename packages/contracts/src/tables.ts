import { z } from 'zod';
import { builtInListKeys, listKinds, mediaTypes } from './lists.js';
import { isHarvestDayKey, isoInstantSchema } from './time.js';

/**
 * The synced tables, one entry per Drift table in
 * `apps/mobile/lib/core/db/database.dart`.
 *
 * Each entry says three things:
 * - **tier**: every table is `private` since Phase 7: its rows travel
 *   only as an encrypted `enc` envelope, and the server never sees a
 *   column ([[Phase-7-Privacy-and-Currencies]], M7.1). Until then only
 *   finance and location were; the rest travelled as `data`, and rows
 *   stored that way are still handed out until a device seals them.
 * - **data**: the row itself, every column of the Drift table under its
 *   camelCase getter name, with timestamps as ISO-8601 UTC, booleans as
 *   booleans, reals as numbers and integers as integers. It is what goes
 *   *inside* the envelope, so a client can check a row after decrypting
 *   it; the server never applies it.
 * - **key**: what identifies the row. A record's `uuid` field carries
 *   it, and for most tables that is the row's own `uuid` column. A few
 *   tables are keyed by something else, and for those the record's
 *   `uuid` is that key, exactly as the phone writes it to the outbox:
 *   - `step_days`: the Harvest Day (`2026-09-19`);
 *   - `streaks`: the scope (`global`, or a commitment uuid);
 *   - `kv_settings`: the setting's key (`themeMode`);
 *   - `training_maxes`: `<programUuid>/<exerciseId>`.
 *
 * Not synced, and so not here: `outbox` (the change log is the thing
 * sync drains, not a thing it sends) and `quests` (parked, and derived).
 * The exercise catalogue is not a table at all (Business Rules #14).
 *
 * The objects are strict: a column the contract does not know is an
 * error, not something to drop quietly, because a dropped column is
 * data lost on the way to the other device.
 */

// ------------------------------------------------------------- columns

const id = z.string().min(1).max(200);
/**
 * A text column's cap, in characters: a note of a few hundred pages,
 * and no more, so one row cannot be the body limit's worth of text
 * (audit S5-02).
 */
export const maxTextLength = 500_000;
const text = z.string().max(maxTextLength);
const int = z.int();
const real = z.number();
const bool = z.boolean();
const instant = isoInstantSchema;

/**
 * A nullable column added after a release already shipped. A row sealed
 * by a device from before it (or kept in a browser's store since) has
 * no key for it at all, so a missing key reads as null instead of
 * failing the whole row.
 */
const added = <T extends z.ZodType>(column: T) => column.nullable().default(null);

/** A Harvest Day key, `yyyy-MM-dd`, that names a real calendar date. */
const day = z.string().refine(isHarvestDayKey, { message: 'Not a Harvest Day key (yyyy-MM-dd)' });

/**
 * A habit schedule, as `Schedule.toJson` writes it on the phone. Stored
 * as a JSON string in `scheduleJson`, and checked here because a
 * schedule the other device cannot parse would crash its field.
 */
export const scheduleSchema = z.discriminatedUnion('type', [
  z.object({ type: z.literal('daily') }),
  z.object({
    type: z.literal('weekly'),
    weekdays: z.array(z.int().min(1).max(7)).min(1).max(7),
  }),
  z.object({
    type: z.literal('interval'),
    everyDays: z.int().min(1),
    anchorDay: day,
  }),
  z.object({
    type: z.literal('timesPerWeek'),
    times: z.int().min(1).max(7),
  }),
]);
export type ScheduleJson = z.infer<typeof scheduleSchema>;

function parsesAs(schema: z.ZodType) {
  return (value: string) => {
    try {
      return schema.safeParse(JSON.parse(value)).success;
    } catch {
      return false;
    }
  };
}

const scheduleJson = z
  .string()
  .max(maxTextLength)
  .refine(parsesAs(scheduleSchema), { message: 'Not a valid schedule' });

/** Any JSON at all: a setting's value is whatever the phone encoded. */
const anyJson = z.string().max(maxTextLength).refine(parsesAs(z.unknown()), { message: 'Not valid JSON' });

// -------------------------------------------------------------- registry

/**
 * `plain` is what a table was before Phase 7, when its rows could travel
 * as `data`; no table is plain now, and the word stays for the rows
 * stored that way before, which a client still reads ([[Sync-API]]).
 */
export type Tier = 'plain' | 'private';

export interface TableSpec<S extends z.ZodObject = z.ZodObject> {
  readonly tier: Tier;
  readonly data: S;
  /** The record `uuid` a row of this table travels under. */
  readonly keyOf: (data: z.output<S>) => string;
}

function secret<S extends z.ZodObject>(
  data: S,
  keyOf: (row: z.output<S>) => string = (row) => (row as { uuid: string }).uuid,
): TableSpec<S> {
  return { tier: 'private', data, keyOf };
}

export const tables = {
  // --------------------------------------------------------- the field
  commitments: secret(
    z.strictObject({
      uuid: id,
      type: z.enum(['habit', 'project', 'todo']),
      title: text,
      scheduleJson: scheduleJson.nullable(),
      totalTarget: int.nullable(),
      dailyCommitment: int.nullable(),
      dueDay: day.nullable(),
      pausedAt: instant.nullable(),
      note: text.nullable(),
      remindAt: text.nullable(),
      deadline: day.nullable(),
      goalUuid: id.nullable(),
      archivedAt: instant.nullable(),
      archiveNote: text.nullable(),
      deletedAt: instant.nullable(),
      createdAt: instant,
      updatedAt: instant,
    }),
  ),
  check_ins: secret(
    z.strictObject({
      uuid: id,
      commitmentUuid: id,
      harvestDay: day,
      quantity: int,
      loggedAt: instant,
      deletedAt: instant.nullable(),
      updatedAt: instant,
    }),
  ),
  seed_notes: secret(
    z.strictObject({
      uuid: id,
      commitmentUuid: id,
      harvestDay: day,
      body: text,
      loggedAt: instant,
      deletedAt: instant.nullable(),
      updatedAt: instant,
    }),
  ),

  // ---------------------------------------------------- notes, gallery
  notes: secret(
    z.strictObject({
      uuid: id,
      title: text,
      folder: text,
      body: text,
      createdAt: instant,
      updatedAt: instant,
      deletedAt: instant.nullable(),
    }),
  ),
  note_links: secret(
    z.strictObject({
      uuid: id,
      fromUuid: id,
      toTitle: text,
      toUuid: id.nullable(),
    }),
  ),
  note_attachments: secret(
    z.strictObject({
      uuid: id,
      noteUuid: id,
      kind: text,
      fileName: text,
      storedPath: text,
      durationMs: int.nullable(),
      sizeBytes: int,
      fileHash: text.nullable(),
      createdAt: instant,
      updatedAt: instant,
      deletedAt: instant.nullable(),
    }),
  ),
  albums: secret(
    z.strictObject({
      uuid: id,
      name: text,
      scheduleJson: scheduleJson.nullable(),
      remindAt: text.nullable(),
      note: text.nullable(),
      createdAt: instant,
      updatedAt: instant,
      deletedAt: instant.nullable(),
    }),
  ),
  memories: secret(
    z.strictObject({
      uuid: id,
      albumUuid: id,
      harvestDay: day,
      path: text,
      kind: z.enum(['photo', 'video']),
      note: text.nullable(),
      fileHash: text.nullable(),
      capturedAt: instant,
      updatedAt: instant,
      deletedAt: instant.nullable(),
    }),
  ),

  // ------------------------------------------------------------ health
  step_days: secret(
    z.strictObject({
      harvestDay: day,
      steps: int,
      lastCounter: int.nullable(),
      updatedAt: instant,
    }),
    (row) => row.harvestDay,
  ),
  body_weights: secret(
    z.strictObject({
      uuid: id,
      grams: int,
      harvestDay: day,
      note: text.nullable(),
      measuredAt: instant,
      updatedAt: instant,
      deletedAt: instant.nullable(),
    }),
  ),
  sleep_sessions: secret(
    z.strictObject({
      uuid: id,
      harvestDay: day,
      fellAsleepAt: instant,
      wokeAt: instant,
      targetMinutes: int,
      restedStars: z.int().min(1).max(5).nullable(),
      note: text.nullable(),
      createdAt: instant,
      updatedAt: instant,
      deletedAt: instant.nullable(),
    }),
  ),

  // --------------------------------------------------------------- gym
  exercises: secret(
    z.strictObject({
      uuid: id,
      name: text,
      bodyPart: text.nullable(),
      equipment: text.nullable(),
      target: text.nullable(),
      note: text.nullable(),
      createdAt: instant,
      updatedAt: instant,
      deletedAt: instant.nullable(),
    }),
  ),
  programs: secret(
    z.strictObject({
      uuid: id,
      name: text,
      note: text.nullable(),
      weeks: int.nullable(),
      commitmentUuid: id.nullable(),
      albumUuid: id.nullable(),
      photoPrompt: z.enum(['after', 'before', 'never']),
      createdAt: instant,
      updatedAt: instant,
      deletedAt: instant.nullable(),
    }),
  ),
  program_days: secret(
    z.strictObject({
      uuid: id,
      programUuid: id,
      name: text,
      position: int,
      week: int.nullable(),
      accessories: text.nullable(),
    }),
  ),
  program_slots: secret(
    z.strictObject({
      uuid: id,
      dayUuid: id,
      exerciseId: id,
      position: int,
      restSeconds: int.nullable(),
      barGrams: int,
      note: text.nullable(),
    }),
  ),
  target_sets: secret(
    z.strictObject({
      uuid: id,
      slotUuid: id,
      position: int,
      reps: int.nullable(),
      weightGrams: int.nullable(),
      percentTenths: int.nullable(),
      openEnded: bool,
    }),
  ),
  training_maxes: secret(
    z.strictObject({
      programUuid: id,
      exerciseId: id,
      grams: int,
      updatedAt: instant,
    }),
    (row) => `${row.programUuid}/${row.exerciseId}`,
  ),
  workout_sessions: secret(
    z.strictObject({
      uuid: id,
      programUuid: id.nullable(),
      dayUuid: id.nullable(),
      title: text.nullable(),
      harvestDay: day,
      startedAt: instant,
      endedAt: instant.nullable(),
      note: text.nullable(),
      pausedAt: instant.nullable(),
      pausedSeconds: int,
      updatedAt: instant,
      deletedAt: instant.nullable(),
    }),
  ),
  session_exercises: secret(
    z.strictObject({
      uuid: id,
      sessionUuid: id,
      position: int,
      exerciseId: id,
      plannedExerciseId: id.nullable(),
      slotUuid: id.nullable(),
      skipped: bool,
      skipReason: text.nullable(),
      note: text.nullable(),
      restSeconds: int.nullable(),
      barGrams: int,
    }),
  ),
  workout_sets: secret(
    z.strictObject({
      uuid: id,
      sessionExerciseUuid: id,
      position: int,
      weightGrams: int,
      reps: int,
      done: bool,
      targetLabel: text.nullable(),
      openEnded: bool,
      loggedAt: instant,
    }),
  ),

  // ------------------------------------------------------ gamification
  streaks: secret(
    z.strictObject({
      scope: id,
      current: int,
      best: int,
      lastEarnedDay: day.nullable(),
      freezesStored: int,
      updatedAt: instant,
    }),
    (row) => row.scope,
  ),
  ledger: secret(
    z.strictObject({
      uuid: id,
      kind: z.enum(['xp', 'coin']),
      delta: int,
      reason: text,
      harvestDay: day,
      loggedAt: instant,
    }),
  ),
  pomodoro_sessions: secret(
    z.strictObject({
      uuid: id,
      commitmentUuid: id.nullable(),
      focusBlocks: int,
      harvestDay: day,
      startedAt: instant,
      endedAt: instant.nullable(),
    }),
  ),

  // ------------------------------------------------------------- goals
  goals: secret(
    z.strictObject({
      uuid: id,
      title: text,
      why: text,
      targetDay: day.nullable(),
      status: z.enum(['active', 'achieved', 'dropped']),
      statusNote: text.nullable(),
      achievedAt: instant.nullable(),
      position: int,
      createdAt: instant,
      updatedAt: instant,
      deletedAt: instant.nullable(),
    }),
  ),
  goal_items: secret(
    z.strictObject({
      uuid: id,
      goalUuid: id,
      kind: z.enum(['need', 'step']),
      body: text,
      note: text.nullable(),
      doneAt: instant.nullable(),
      position: int,
      commitmentUuid: id.nullable(),
      // Added in v24: the task a subtask belongs to ([[Goals]] GL8).
      // Older clients omit it, and their items read as top-level.
      parentUuid: added(id),
      createdAt: instant,
      updatedAt: instant,
      deletedAt: instant.nullable(),
    }),
  ),

  // -------------------------------------------------------------- lists
  lists: secret(
    z.strictObject({
      uuid: id,
      name: text,
      kind: z.enum(listKinds),
      icon: text.nullable(),
      position: int,
      builtIn: z.enum(builtInListKeys).nullable(),
      createdAt: instant,
      updatedAt: instant,
      deletedAt: instant.nullable(),
    }),
  ),
  // The table keeps the Wishlist's name so the beta devices and archives
  // out there keep working; its rows are every list's items ([[Lists]]).
  wishlist_items: secret(
    z.strictObject({
      uuid: id,
      // Before lists, which of the two shopping lists; still written
      // (`buy` for To buy, `wish` for every other list) for beta clients.
      list: z.enum(['buy', 'wish']),
      // The rest arrived with lists (v23), after v3.0.0-beta.3 had synced
      // items without them. A null list is read from `list`.
      listUuid: added(id),
      title: text,
      priceMinor: int.nullable(),
      currency: text,
      note: text.nullable(),
      targetDay: day.nullable(),
      mediaType: added(z.enum(mediaTypes)),
      link: added(text),
      creator: added(text),
      startedAt: added(instant),
      rating: added(z.int().min(1).max(5)),
      seedUuid: added(id),
      noteUuid: added(id),
      // Done, for every kind: bought, finished or ticked.
      boughtAt: instant.nullable(),
      position: int,
      createdAt: instant,
      updatedAt: instant,
      deletedAt: instant.nullable(),
    }),
  ),

  // ---------------------------------------------------------- settings
  kv_settings: secret(
    z.strictObject({
      key: id,
      valueJson: anyJson,
      updatedAt: instant,
    }),
    (row) => row.key,
  ),

  // ---------------------------------------------------------- finances
  expenses: secret(
    z.strictObject({
      uuid: id,
      amountMinor: int,
      currency: text,
      category: text,
      note: text.nullable(),
      harvestDay: day,
      loggedAt: instant,
      deletedAt: instant.nullable(),
      updatedAt: instant,
    }),
  ),
  expense_categories: secret(
    z.strictObject({
      uuid: id,
      name: text,
      icon: text,
      // Added in v21, after v3.0.0-beta.1 had sealed categories without
      // it. Null orders by updatedAt, as every category did before.
      createdAt: added(instant),
      deletedAt: instant.nullable(),
      updatedAt: instant,
    }),
  ),
  money_txns: secret(
    z.strictObject({
      uuid: id,
      account: text,
      deltaMinor: int,
      currency: text,
      note: text.nullable(),
      kind: text,
      reference: text.nullable(),
      linkUuid: id.nullable(),
      harvestDay: day,
      loggedAt: instant,
      deletedAt: instant.nullable(),
      updatedAt: instant,
    }),
  ),
  debts: secret(
    z.strictObject({
      uuid: id,
      person: text,
      amountMinor: int,
      currency: text,
      payOffBy: text.nullable(),
      remindAt: text.nullable(),
      note: text.nullable(),
      settledAt: instant.nullable(),
      createdAt: instant,
      deletedAt: instant.nullable(),
      updatedAt: instant,
    }),
  ),
  debt_payments: secret(
    z.strictObject({
      uuid: id,
      debtUuid: id,
      amountMinor: int,
      harvestDay: day,
      loggedAt: instant,
      deletedAt: instant.nullable(),
    }),
  ),

  // ------------------------------------------------------------ places
  location_points: secret(
    z.strictObject({
      uuid: id,
      harvestDay: day,
      recordedAt: instant,
      latitude: real,
      longitude: real,
      accuracyM: real.nullable(),
      speedMps: real.nullable(),
      altitudeM: real.nullable(),
      updatedAt: instant,
      deletedAt: instant.nullable(),
    }),
  ),
  /**
   * The trail, one row per day (Phase 7, M7.3), in place of a row per
   * point: the server sees one row that changes a few times a day, not
   * the moment of every point. Its record key is `key`, a keyed hash of
   * the day the devices agree on (`trailKeyOf`), so not even the day is
   * in the clear. A point is never dropped from a day by a newer copy
   * that lacks it; it goes by its own `deletedAt`.
   */
  trail_days: secret(
    z.strictObject({
      key: id,
      harvestDay: day,
      points: z
        .array(
          z.strictObject({
            uuid: id,
            recordedAt: instant,
            latitude: real,
            longitude: real,
            accuracyM: real.nullable(),
            speedMps: real.nullable(),
            altitudeM: real.nullable(),
            updatedAt: instant,
            deletedAt: instant.nullable(),
          }),
        )
        .max(20_000),
      updatedAt: instant,
    }),
    (row) => row.key,
  ),
  geotags: secret(
    z.strictObject({
      uuid: id,
      targetTable: text,
      targetUuid: id,
      harvestDay: day,
      at: instant,
      latitude: real.nullable(),
      longitude: real.nullable(),
      accuracyM: real.nullable(),
      state: z.enum(['pending', 'fixed', 'unavailable']),
      updatedAt: instant,
      deletedAt: instant.nullable(),
    }),
  ),
  saved_places: secret(
    z.strictObject({
      uuid: id,
      name: text,
      latitude: real,
      longitude: real,
      radiusM: real,
      // Added in v20, after v3.0.0-beta.1 had sealed places without it.
      notes: added(text),
      createdAt: instant,
      updatedAt: instant,
      deletedAt: instant.nullable(),
    }),
  ),
} as const satisfies Record<string, TableSpec>;

export type SyncedTable = keyof typeof tables;

/**
 * Tables no device sends any more, kept so what 3.1 stored can still be
 * opened: `location_points`, a row a point, gave way to `trail_days`
 * (Phase 7, M7.3). A push of one is refused (`retired_table`), and the
 * server deletes what it holds of them when a device says it has sealed
 * everything (`POST /v1/sync/sealed`).
 */
export const retiredTables: readonly SyncedTable[] = ['location_points'];

export const syncedTables = Object.keys(tables) as [SyncedTable, ...SyncedTable[]];

export const syncedTableSchema = z.enum(syncedTables);

/** The row type of [table], as `data` carries it. */
export type TableData<T extends SyncedTable> = z.output<(typeof tables)[T]['data']>;

export const privateTables = syncedTables.filter((name) => tables[name].tier === 'private');

export function isSyncedTable(name: string): name is SyncedTable {
  return Object.hasOwn(tables, name);
}

export function tierOf(table: SyncedTable): Tier {
  return tables[table].tier;
}

/** Whether [table]'s rows carry a column of that name. */
export function hasColumn(table: SyncedTable, column: string): boolean {
  return Object.hasOwn(tables[table].data.shape, column);
}
