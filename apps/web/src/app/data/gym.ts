import type { SyncedTable } from '@harvest/contracts';
import { nextProgramDay, recordsFrom, setVolumeGrams, type ExerciseRecords } from '@harvest/core';
import type { IndexableType, Table } from 'dexie';
import type { HarvestDB, Row } from './db';

export type ProgramRow = Row<'programs'>;
export type DayRow = Row<'program_days'>;
export type SlotRow = Row<'program_slots'>;
export type TargetSetRow = Row<'target_sets'>;
export type SessionRow = Row<'workout_sessions'>;
export type SessionExerciseRow = Row<'session_exercises'>;
export type SetRow = Row<'workout_sets'>;

/** Anything rows can be read from: the store, or a write's own transaction. */
export interface RowSource {
  rows<T extends SyncedTable>(table: T): Table<Row<T>, IndexableType>;
}

// --------------------------------------------------------------- programs

export interface SlotTree {
  row: SlotRow;
  sets: TargetSetRow[];
}

export interface DayTree {
  row: DayRow;
  slots: SlotTree[];
  /** Every target set in the day. */
  totalSets: number;
}

/** A program read whole, as `ProgramsRepository._hydrate` builds it. */
export interface ProgramTree {
  program: ProgramRow;
  days: DayTree[];
}

function byPosition<T extends { position: number }>(a: T, b: T): number {
  return a.position - b.position;
}

function groupBy<T>(rows: T[], key: (row: T) => string): Map<string, T[]> {
  const map = new Map<string, T[]>();
  for (const row of rows) {
    const list = map.get(key(row));
    if (list) list.push(row);
    else map.set(key(row), [row]);
  }
  return map;
}

/** Every live program, oldest first — the order the phone lists them. */
export async function readPrograms(source: RowSource): Promise<ProgramTree[]> {
  const [programs, days, slots, sets] = await Promise.all([
    source.rows('programs').toArray(),
    source.rows('program_days').toArray(),
    source.rows('program_slots').toArray(),
    source.rows('target_sets').toArray(),
  ]);
  const daysBy = groupBy(days, (day) => day.programUuid);
  const slotsBy = groupBy(slots, (slot) => slot.dayUuid);
  const setsBy = groupBy(sets, (set) => set.slotUuid);
  return programs
    .filter((program) => program.deletedAt === null)
    .sort((a, b) => a.createdAt.localeCompare(b.createdAt))
    .map((program) => ({
      program,
      days: (daysBy.get(program.uuid) ?? []).sort(byPosition).map((row) => {
        const daySlots = (slotsBy.get(row.uuid) ?? []).sort(byPosition).map((slot) => ({
          row: slot,
          sets: (setsBy.get(slot.uuid) ?? []).sort(byPosition),
        }));
        return { row, slots: daySlots, totalSets: daySlots.reduce((sum, slot) => sum + slot.sets.length, 0) };
      }),
    }));
}

export async function readProgram(source: RowSource, uuid: string): Promise<ProgramTree | null> {
  return (await readPrograms(source)).find((tree) => tree.program.uuid === uuid) ?? null;
}

/** The program a seed is, if any: finishing its session checks the seed in (Y4). */
export async function programForSeed(source: RowSource, commitmentUuid: string): Promise<ProgramTree | null> {
  return (await readPrograms(source)).find((tree) => tree.program.commitmentUuid === commitmentUuid) ?? null;
}

/** Every training max the program has, by exercise. */
export async function readTrainingMaxes(source: RowSource, programUuid: string): Promise<Map<string, number>> {
  const rows = await source.rows('training_maxes').toArray();
  return new Map(rows.filter((row) => row.programUuid === programUuid).map((row) => [row.exerciseId, row.grams]));
}

/** Exercises with a percentage set, which need a training max. */
export function percentageExercises(tree: ProgramTree): string[] {
  const ids = new Set<string>();
  for (const day of tree.days) {
    for (const slot of day.slots) if (slot.sets.some((set) => set.percentTenths !== null)) ids.add(slot.row.exerciseId);
  }
  return [...ids];
}

/** Newest first, the phone's order: the start, then the later write. */
function newestFirst(a: SessionRow, b: SessionRow): number {
  return b.startedAt.localeCompare(a.startedAt) || b.updatedAt.localeCompare(a.updatedAt);
}

/**
 * The day after the last one finished, wrapping at the end (Y11).
 * Derived from the log, so a discarded session moves nothing.
 */
export async function nextDayOf(source: RowSource, tree: ProgramTree): Promise<DayTree | null> {
  const sessions = (await source.rows('workout_sessions').toArray())
    .filter((row) => row.programUuid === tree.program.uuid && row.endedAt !== null && row.deletedAt === null)
    .sort(newestFirst);
  const last = sessions[0]?.dayUuid ?? null;
  const next = nextProgramDay(
    tree.days.map((day) => ({ uuid: day.row.uuid, position: day.row.position, day })),
    last,
  );
  return next?.day ?? null;
}

/**
 * The album a program's picture goes to, if it is still there to take
 * one (`GalleryRepository.albumOnce`): an album since deleted or in the
 * trash is not asked for anything.
 */
export async function albumForPicture(source: RowSource, albumUuid: string | null): Promise<Row<'albums'> | null> {
  if (!albumUuid) return null;
  const album = await source.rows('albums').get(albumUuid);
  return album && album.deletedAt === null ? album : null;
}

// --------------------------------------------------------------- sessions

export interface ExerciseInSession {
  row: SessionExerciseRow;
  sets: SetRow[];
}

/** One session read whole. */
export interface SessionTree {
  session: SessionRow;
  exercises: ExerciseInSession[];
  doneSets: number;
  totalSets: number;
  volumeGrams: number;
}

async function hydrate(source: RowSource, rows: SessionRow[]): Promise<SessionTree[]> {
  if (rows.length === 0) return [];
  const wanted = new Set(rows.map((row) => row.uuid));
  const exercises = (await source.rows('session_exercises').toArray()).filter((row) => wanted.has(row.sessionUuid));
  const exerciseUuids = new Set(exercises.map((row) => row.uuid));
  const sets = (await source.rows('workout_sets').toArray()).filter((row) => exerciseUuids.has(row.sessionExerciseUuid));
  const setsBy = groupBy(sets, (set) => set.sessionExerciseUuid);
  const exercisesBy = groupBy(exercises, (row) => row.sessionUuid);
  return rows.map((session) => {
    const list = (exercisesBy.get(session.uuid) ?? []).sort(byPosition).map((row) => ({
      row,
      sets: (setsBy.get(row.uuid) ?? []).sort(byPosition),
    }));
    let doneSets = 0;
    let totalSets = 0;
    let volumeGrams = 0;
    for (const exercise of list) {
      totalSets += exercise.sets.length;
      for (const set of exercise.sets) {
        if (set.done) doneSets += 1;
        volumeGrams += setVolumeGrams(set);
      }
    }
    return { session, exercises: list, doneSets, totalSets, volumeGrams };
  });
}

export async function readSession(source: RowSource, uuid: string): Promise<SessionTree | null> {
  const row = await source.rows('workout_sessions').get(uuid);
  if (!row) return null;
  return (await hydrate(source, [row]))[0] ?? null;
}

/**
 * The session still running, if there is one — whichever device began
 * it. An unfinished session is one with no end: that is the resume (Y3).
 */
export async function readRunning(source: RowSource): Promise<SessionTree | null> {
  const running = (await source.rows('workout_sessions').toArray())
    .filter((row) => row.endedAt === null && row.deletedAt === null)
    .sort(newestFirst);
  const first = running[0];
  return first ? ((await hydrate(source, [first]))[0] ?? null) : null;
}

/** One finished session, as the history list reads it. */
export interface SessionView extends SessionTree {
  programName: string | null;
  dayName: string | null;
}

export async function readSessions(db: HarvestDB, limit = 40): Promise<SessionView[]> {
  const [sessions, programs, days] = await Promise.all([
    db.rows('workout_sessions').toArray(),
    db.rows('programs').toArray(),
    db.rows('program_days').toArray(),
  ]);
  const finished = sessions
    .filter((session) => session.deletedAt === null && session.endedAt !== null)
    .sort((a, b) => b.harvestDay.localeCompare(a.harvestDay) || newestFirst(a, b))
    .slice(0, limit);
  return (await hydrate(db, finished)).map((tree) => ({
    ...tree,
    programName: programs.find((program) => program.uuid === tree.session.programUuid)?.name ?? null,
    dayName: days.find((day) => day.uuid === tree.session.dayUuid)?.name ?? null,
  }));
}

// ---------------------------------------------------------------- records

/** One day I did an exercise, and what came of it. */
export interface ExerciseOuting {
  day: string;
  sets: SetRow[];
  volumeGrams: number;
  bestEstimate: number | null;
}

/** Every appearance of an exercise, with its session. */
async function appearances(source: RowSource, exerciseId: string) {
  const [exercises, sessions, sets] = await Promise.all([
    source.rows('session_exercises').toArray(),
    source.rows('workout_sessions').toArray(),
    source.rows('workout_sets').toArray(),
  ]);
  const mine = exercises.filter((row) => row.exerciseId === exerciseId);
  const byUuid = new Map(sessions.map((row) => [row.uuid, row]));
  const setsBy = groupBy(
    sets.filter((set) => set.done),
    (set) => set.sessionExerciseUuid,
  );
  return mine
    .map((row) => ({ row, session: byUuid.get(row.sessionUuid), sets: (setsBy.get(row.uuid) ?? []).sort(byPosition) }))
    .filter((entry): entry is { row: SessionExerciseRow; session: SessionRow; sets: SetRow[] } => entry.session !== undefined && entry.session.deletedAt === null);
}

/**
 * Every ticked set of an exercise, and each session's volume of it —
 * the running session's included, so a second heavy set is measured
 * against the first (`SessionsRepository.records`).
 */
export async function exerciseRecords(source: RowSource, exerciseId: string): Promise<ExerciseRecords<SetRow>> {
  const all = await appearances(source, exerciseId);
  const sets: SetRow[] = [];
  const volumes = new Map<string, number>();
  for (const { row, sets: list } of all) {
    for (const set of list) {
      sets.push(set);
      volumes.set(row.sessionUuid, (volumes.get(row.sessionUuid) ?? 0) + setVolumeGrams(set));
    }
  }
  return recordsFrom(sets, volumes.values());
}

/** Finished sessions that logged this exercise, newest first. */
function finishedAppearances(all: Awaited<ReturnType<typeof appearances>>) {
  const seen = new Set<string>();
  return all
    .filter((entry) => entry.session.endedAt !== null)
    // Within a session, the earliest position first: the exercise done
    // twice in one session answers with its first appearance, as the
    // phone reads it, whatever order the rows came out of the store.
    .sort((a, b) => newestFirst(a.session, b.session) || byPosition(a.row, b.row))
    .filter((entry) => {
      if (seen.has(entry.session.uuid)) return false;
      seen.add(entry.session.uuid);
      return true;
    });
}

/** What I did last time: the ticked sets of the latest finished session. */
export async function lastTime(source: RowSource, exerciseId: string): Promise<SetRow[]> {
  return finishedAppearances(await appearances(source, exerciseId))[0]?.sets ?? [];
}

/** One entry per session that logged something of this exercise. */
export async function exerciseHistory(source: RowSource, exerciseId: string, limit = 30): Promise<ExerciseOuting[]> {
  return finishedAppearances(await appearances(source, exerciseId))
    .slice(0, limit)
    .filter((entry) => entry.sets.length > 0)
    .map((entry) => ({
      day: entry.session.harvestDay,
      sets: entry.sets,
      volumeGrams: entry.sets.reduce((sum, set) => sum + setVolumeGrams(set), 0),
      bestEstimate: recordsFrom(entry.sets).bestSetEstimate,
    }));
}
