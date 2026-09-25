import { HarvestDay, defaultBarGrams, nextPosition, resolveTarget, sessionTargetLabel, type LoadUnit } from '@harvest/core';
import type { CheckInsRepository } from './check-ins';
import { readRunning, readSession, type DayTree, type SessionRow, type SessionTree, type SetRow } from './gym';
import type { Tx, Writer } from './writer';

/**
 * What finishing came to: the XP the check-in paid, zero when there was
 * none — and the program's album when it asks for a picture after the
 * session (`SessionFinisher`), for the screen to offer.
 */
export interface FinishOutcome {
  xpEarned: number;
  albumUuid: string | null;
}

/**
 * Sessions, the exercises in them and the sets in those, mirroring the
 * phone's SessionsRepository. The rule it keeps: a set is written when
 * it is ticked, not when the session ends ([[Gym]] Y3) — nothing waits
 * in memory for Finish, so a closed tab loses nothing.
 */
export class SessionsRepository {
  constructor(
    private readonly writer: Writer,
    private readonly checkIns: CheckInsRepository,
  ) {}

  private sessionRow(tx: Tx, fields: Pick<SessionRow, 'programUuid' | 'dayUuid' | 'title'>, day?: HarvestDay): SessionRow {
    const now = tx.now();
    return {
      uuid: crypto.randomUUID(),
      ...fields,
      harvestDay: (day ?? HarvestDay.of(tx.clockNow())).key,
      startedAt: now,
      endedAt: null,
      note: null,
      pausedAt: null,
      pausedSeconds: 0,
      updatedAt: now,
      deletedAt: null,
    };
  }

  /**
   * Opens a session from a program day, its targets copied in and every
   * row prefilled, so a set that went to plan is one click.
   *
   * One session at a time (Y3): if one is running — begun here, or on
   * the phone and synced — that one comes back instead of a second
   * beside it. [started] says which happened.
   */
  start(input: {
    day: DayTree;
    programUuid: string;
    trainingMaxes: ReadonlyMap<string, number>;
    /** What a percentage rounds in: a quarter kilo or a quarter pound (Y8). */
    unit?: LoadUnit;
  }): Promise<{ session: SessionTree; started: boolean }> {
    return this.writer.run(async (tx) => {
      const running = await readRunning(tx);
      if (running) return { session: running, started: false };
      const session = this.sessionRow(tx, { programUuid: input.programUuid, dayUuid: input.day.row.uuid, title: input.day.row.name });
      await tx.put('workout_sessions', session);
      const now = tx.now();
      for (const slot of input.day.slots) {
        const exerciseUuid = crypto.randomUUID();
        await tx.put('session_exercises', {
          uuid: exerciseUuid,
          sessionUuid: session.uuid,
          position: slot.row.position,
          exerciseId: slot.row.exerciseId,
          plannedExerciseId: slot.row.exerciseId,
          slotUuid: slot.row.uuid,
          skipped: false,
          skipReason: null,
          note: null,
          restSeconds: slot.row.restSeconds,
          barGrams: slot.row.barGrams,
        });
        for (const target of slot.sets) {
          const grams = resolveTarget(target, input.trainingMaxes.get(slot.row.exerciseId), input.unit);
          await tx.put('workout_sets', {
            uuid: crypto.randomUUID(),
            sessionExerciseUuid: exerciseUuid,
            position: target.position,
            weightGrams: grams ?? 0,
            reps: target.reps ?? 0,
            done: false,
            targetLabel: sessionTargetLabel(target, grams),
            openEnded: target.openEnded,
            loggedAt: now,
          });
        }
      }
      return { session: (await readSession(tx, session.uuid))!, started: true };
    });
  }

  /**
   * "Went, no numbers" (Y12): a session with nothing in it, on the day
   * that was up next, finished on the spot — so the habit is checked in
   * through Finish like any other session and *Next* moves on.
   */
  async bare(input: { programUuid: string; dayUuid: string | null; title: string }): Promise<FinishOutcome> {
    const uuid = await this.writer.run(async (tx) => {
      const session = this.sessionRow(tx, input);
      await tx.put('workout_sessions', session);
      return session.uuid;
    });
    return this.finish(uuid);
  }

  /**
   * Takes back the bare sessions a hand tick wrote on [day] when the
   * tick is undone — finished and empty; a session with anything in it
   * is never touched.
   */
  discardBareOn(programUuid: string, day: string): Promise<number> {
    return this.writer.run(async (tx) => {
      const sessions = (await tx.rows('workout_sessions').where('harvestDay').equals(day).toArray()).filter(
        (row) => row.programUuid === programUuid && row.endedAt !== null && row.deletedAt === null,
      );
      let discarded = 0;
      for (const session of sessions) {
        if ((await tx.rows('session_exercises').where('sessionUuid').equals(session.uuid).count()) > 0) continue;
        await tx.purge('workout_sessions', session.uuid);
        discarded += 1;
      }
      return discarded;
    });
  }

  /**
   * Ticks a set, or unticks it — and writes it, now. The session is
   * touched in the same write, as the phone's `_touch` does, so the
   * other device sees the session itself move on.
   */
  logSet(uuid: string, input: { weightGrams: number; reps: number; done: boolean }): Promise<void> {
    return this.writer.run(async (tx) => {
      const set = await tx.patch('workout_sets', uuid, { ...input, loggedAt: tx.now() });
      const exercise = set ? await tx.get('session_exercises', set.sessionExerciseUuid) : undefined;
      if (exercise) await tx.patch('workout_sessions', exercise.sessionUuid, { updatedAt: tx.now() });
    });
  }

  private async insertSet(tx: Tx, sessionExerciseUuid: string): Promise<void> {
    const existing = (await tx.rows('workout_sets').where('sessionExerciseUuid').equals(sessionExerciseUuid).toArray()).sort(
      (a, b) => a.position - b.position,
    );
    const last: SetRow | undefined = existing[existing.length - 1];
    await tx.put('workout_sets', {
      uuid: crypto.randomUUID(),
      sessionExerciseUuid,
      position: nextPosition(existing),
      // The last set's numbers: the one I add is usually one more of it.
      weightGrams: last?.weightGrams ?? 0,
      reps: last?.reps ?? 0,
      done: false,
      targetLabel: null,
      openEnded: false,
      loggedAt: tx.now(),
    });
  }

  addSet(sessionExerciseUuid: string): Promise<void> {
    return this.writer.run((tx) => this.insertSet(tx, sessionExerciseUuid));
  }

  /** Structure, not history: a dropped set goes for good. */
  removeSet(uuid: string): Promise<void> {
    return this.writer.run((tx) => tx.purge('workout_sets', uuid));
  }

  /**
   * Skips an exercise with its reason, or puts it back and clears the
   * reason, which no longer applies to anything (Y7).
   */
  skipExercise(uuid: string, skipped: boolean, reason: string | null = null): Promise<void> {
    return this.writer.run(async (tx) => {
      await tx.patch('session_exercises', uuid, { skipped, skipReason: skipped ? reason?.trim() || null : null });
    });
  }

  /** Swaps the exercise; the planned one stays, so history knows the day (Y7). */
  replaceExercise(uuid: string, exerciseId: string): Promise<void> {
    return this.writer.run(async (tx) => {
      await tx.patch('session_exercises', uuid, { exerciseId });
    });
  }

  addExercise(sessionUuid: string, exerciseId: string): Promise<void> {
    return this.writer.run(async (tx) => {
      const uuid = crypto.randomUUID();
      await tx.put('session_exercises', {
        uuid,
        sessionUuid,
        position: nextPosition(await tx.rows('session_exercises').where('sessionUuid').equals(sessionUuid).toArray()),
        exerciseId,
        plannedExerciseId: null,
        slotUuid: null,
        skipped: false,
        skipReason: null,
        note: null,
        restSeconds: null,
        barGrams: defaultBarGrams,
      });
      await this.insertSet(tx, uuid);
    });
  }

  /** Today's rest for this exercise; the program is not rewritten. */
  setExerciseRest(uuid: string, seconds: number | null): Promise<void> {
    return this.writer.run(async (tx) => {
      await tx.patch('session_exercises', uuid, { restSeconds: seconds });
    });
  }

  setExerciseNote(uuid: string, note: string | null): Promise<void> {
    return this.writer.run(async (tx) => {
      await tx.patch('session_exercises', uuid, { note: note?.trim() || null });
    });
  }

  setSessionNote(uuid: string, note: string | null): Promise<void> {
    return this.writer.run(async (tx) => {
      await tx.patch('workout_sessions', uuid, { note: note?.trim() || null, updatedAt: tx.now() });
    });
  }

  /** Stops the clock. Sets can still be ticked: a pause is about the time. */
  pause(uuid: string): Promise<void> {
    return this.writer.run(async (tx) => {
      const row = await tx.get('workout_sessions', uuid);
      if (!row || row.endedAt !== null || row.pausedAt !== null) return;
      const now = tx.now();
      await tx.put('workout_sessions', { ...row, pausedAt: now, updatedAt: now });
    });
  }

  /** Starts the clock again, banking the pause that just ended. */
  resume(uuid: string): Promise<void> {
    return this.writer.run(async (tx) => {
      const row = await tx.get('workout_sessions', uuid);
      if (!row || row.pausedAt === null) return;
      const seconds = Math.max(0, Math.floor((tx.clockNow().getTime() - Date.parse(row.pausedAt)) / 1000));
      await tx.put('workout_sessions', { ...row, pausedAt: null, pausedSeconds: row.pausedSeconds + seconds, updatedAt: tx.now() });
    });
  }

  /**
   * Ends a session and pays what it earned (`SessionFinisher`): the
   * program's habit is checked in on the session's own Harvest Day (Y4).
   * Starting checks nothing in, abandoning checks nothing in, and
   * finishing twice pays once — the check-in is once a day anyway.
   */
  async finish(uuid: string, endedAt: string | null = null): Promise<FinishOutcome> {
    const session = await this.writer.run(async (tx) => {
      const row = await tx.get('workout_sessions', uuid);
      if (!row) return null;
      const now = tx.now();
      // Finished while paused, it ends at the pause: the minutes since were not training.
      // [endedAt] ends a session left running past its day at its last set, not now (Y3).
      const next = { ...row, endedAt: endedAt ?? row.pausedAt ?? now, pausedAt: null, updatedAt: now };
      await tx.put('workout_sessions', next);
      return next;
    });
    if (!session?.programUuid) return { xpEarned: 0, albumUuid: null };
    const program = await this.writer.db.rows('programs').get(session.programUuid);
    if (!program || program.deletedAt !== null) return { xpEarned: 0, albumUuid: null };
    const albumUuid = program.photoPrompt === 'after' ? program.albumUuid : null;
    if (!program.commitmentUuid) return { xpEarned: 0, albumUuid };
    const seed = await this.writer.db.rows('commitments').get(program.commitmentUuid);
    // A seed archived or deleted since is not an error: the workout happened either way.
    if (!seed || seed.archivedAt !== null || seed.deletedAt !== null) return { xpEarned: 0, albumUuid };
    const plan = await this.checkIns.checkIn(seed, HarvestDay.parse(session.harvestDay));
    return { xpEarned: plan.xpEarned, albumUuid };
  }

  /** Throws the session away, sets and all. The screen asks first. */
  discard(uuid: string): Promise<void> {
    return this.writer.run(async (tx) => {
      const exercises = await tx.rows('session_exercises').where('sessionUuid').equals(uuid).toArray();
      for (const exercise of exercises) {
        const sets = await tx.rows('workout_sets').where('sessionExerciseUuid').equals(exercise.uuid).toArray();
        for (const set of sets) await tx.purge('workout_sets', set.uuid);
        await tx.purge('session_exercises', exercise.uuid);
      }
      await tx.purge('workout_sessions', uuid);
    });
  }
}
