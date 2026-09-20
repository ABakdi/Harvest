import type { HarvestDB, Row } from './db';

export type ProgramRow = Row<'programs'>;
export type SessionRow = Row<'workout_sessions'>;
export type SessionExerciseRow = Row<'session_exercises'>;
export type SetRow = Row<'workout_sets'>;

/** A program with its days, and what each day asks for. */
export interface ProgramView {
  program: ProgramRow;
  days: { uuid: string; name: string; position: number; exercises: string[] }[];
}

export async function readPrograms(db: HarvestDB): Promise<ProgramView[]> {
  const [programs, days, slots] = await Promise.all([
    db.rows('programs').toArray(),
    db.rows('program_days').toArray(),
    db.rows('program_slots').toArray(),
  ]);
  const byDay = new Map<string, Row<'program_slots'>[]>();
  for (const slot of slots) {
    const list = byDay.get(slot.dayUuid) ?? [];
    list.push(slot);
    byDay.set(slot.dayUuid, list);
  }
  return programs
    .filter((program) => program.deletedAt === null)
    .sort((a, b) => a.name.localeCompare(b.name))
    .map((program) => ({
      program,
      days: days
        .filter((day) => day.programUuid === program.uuid)
        .sort((a, b) => a.position - b.position)
        .map((day) => ({
          uuid: day.uuid,
          name: day.name,
          position: day.position,
          exercises: (byDay.get(day.uuid) ?? []).sort((a, b) => a.position - b.position).map((slot) => slot.exerciseId),
        })),
    }));
}

/** One finished session, as the history list reads it. */
export interface SessionView {
  session: SessionRow;
  programName: string | null;
  dayName: string | null;
  exercises: { row: SessionExerciseRow; sets: SetRow[] }[];
  doneSets: number;
  volumeGrams: number;
}

export async function readSessions(db: HarvestDB, limit = 40): Promise<SessionView[]> {
  const [sessions, programs, days, exercises, sets] = await Promise.all([
    db.rows('workout_sessions').toArray(),
    db.rows('programs').toArray(),
    db.rows('program_days').toArray(),
    db.rows('session_exercises').toArray(),
    db.rows('workout_sets').toArray(),
  ]);
  const setsByExercise = new Map<string, SetRow[]>();
  for (const set of sets) {
    const list = setsByExercise.get(set.sessionExerciseUuid) ?? [];
    list.push(set);
    setsByExercise.set(set.sessionExerciseUuid, list);
  }
  return sessions
    .filter((session) => session.deletedAt === null && session.endedAt !== null)
    .sort((a, b) => b.harvestDay.localeCompare(a.harvestDay) || b.startedAt.localeCompare(a.startedAt))
    .slice(0, limit)
    .map((session) => {
      const rows = exercises
        .filter((exercise) => exercise.sessionUuid === session.uuid)
        .sort((a, b) => a.position - b.position)
        .map((row) => ({
          row,
          sets: (setsByExercise.get(row.uuid) ?? []).sort((a, b) => a.position - b.position),
        }));
      let doneSets = 0;
      let volumeGrams = 0;
      for (const { sets: list } of rows) {
        for (const set of list) {
          if (!set.done) continue;
          doneSets += 1;
          volumeGrams += set.weightGrams * set.reps;
        }
      }
      return {
        session,
        programName: programs.find((program) => program.uuid === session.programUuid)?.name ?? null,
        dayName: days.find((day) => day.uuid === session.dayUuid)?.name ?? null,
        exercises: rows,
        doneSets,
        volumeGrams,
      };
    });
}
