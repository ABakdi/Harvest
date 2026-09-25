import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { HarvestDay } from '@harvest/core';
import { describe, expect, it } from 'vitest';
import { loadCatalogue } from '@/app/data/exercises';
import { exerciseHistory, exerciseRecords, lastTime, nextDayOf, readProgram, readRunning, readSession, readTrainingMaxes } from '@/app/data/gym';
import { FakeServer } from './fake-server';
import { device } from './helpers';

type Device = Awaited<ReturnType<typeof device>>;

/** nSuns-ish: a day of squats (100 kg × 5, 75% × 3, 95% × 1+) and a day of bench. */
async function aProgram(h: Device) {
  const program = await h.programs.createProgram('  nSuns  ');
  const squat = await h.programs.addDay(program.uuid, 'Day 1');
  const bench = await h.programs.addDay(program.uuid, 'Day 2');
  const slot = await h.programs.addSlot(squat.uuid, '0025');
  await h.programs.addTargetSet(slot.uuid, { reps: 5, weightGrams: 100_000, percentTenths: null, openEnded: false });
  await h.programs.addTargetSet(slot.uuid, { reps: 3, weightGrams: null, percentTenths: 750, openEnded: false });
  await h.programs.addTargetSet(slot.uuid, { reps: 1, weightGrams: null, percentTenths: 950, openEnded: true });
  await h.programs.updateSlot(slot.uuid, { restSeconds: 180 });
  const pressSlot = await h.programs.addSlot(bench.uuid, '0047');
  await h.programs.addTargetSet(pressSlot.uuid, { reps: 5, weightGrams: 60_000, percentTenths: null, openEnded: false });
  return (await readProgram(h.db, program.uuid))!;
}

async function outboxFor(h: Device, table: string) {
  return (await h.db.outbox.toArray()).filter((entry) => entry.table === table);
}

/** A gym habit bound to the program, as planting does it. */
async function planted(h: Device) {
  const tree = await aProgram(h);
  await h.programs.plant(tree.program.uuid, { title: tree.program.name, timesPerWeek: 3, album: false });
  return (await readProgram(h.db, tree.program.uuid))!;
}

describe('writing a program', () => {
  it('builds days, slots and sets in order, every row through the outbox', async () => {
    const h = await device(new FakeServer());
    const tree = await aProgram(h);
    expect(tree.program.name).toBe('nSuns');
    expect(tree.days.map((day) => day.row.name)).toEqual(['Day 1', 'Day 2']);
    expect(tree.days[0]!.slots[0]!.sets.map((set) => set.position)).toEqual([0, 1, 2]);
    expect(tree.days[0]!.totalSets).toBe(3);
    // A new bar does not clear the rest: only what is given changes.
    await h.programs.updateSlot(tree.days[0]!.slots[0]!.row.uuid, { barGrams: 15_000 });
    const again = (await readProgram(h.db, tree.program.uuid))!;
    expect(again.days[0]!.slots[0]!.row).toMatchObject({ restSeconds: 180, barGrams: 15_000 });
    expect(await outboxFor(h, 'target_sets')).toHaveLength(4);
  });

  it('duplicates a day with rows of its own, so editing one never edits the other', async () => {
    const h = await device(new FakeServer());
    const tree = await aProgram(h);
    await h.programs.duplicateDay(tree.days[0]!, 'Day 1 (2)');
    const after = (await readProgram(h.db, tree.program.uuid))!;
    const [original, , copy] = after.days;
    expect(copy!.row.name).toBe('Day 1 (2)');
    expect(copy!.row.position).toBe(2);
    expect(copy!.slots[0]!.sets.map((set) => set.percentTenths)).toEqual([null, 750, 950]);
    const originalIds = new Set(original!.slots.flatMap((slot) => [slot.row.uuid, ...slot.sets.map((set) => set.uuid)]));
    for (const slot of copy!.slots) {
      expect(originalIds.has(slot.row.uuid)).toBe(false);
      for (const set of slot.sets) expect(originalIds.has(set.uuid)).toBe(false);
    }
  });

  it('reorders slots and days, and takes a removed day with its slots and sets', async () => {
    const h = await device(new FakeServer());
    const tree = await aProgram(h);
    const day = tree.days[0]!;
    const second = await h.programs.addSlot(day.row.uuid, '0047');
    await h.programs.reorderSlots([second.uuid, day.slots[0]!.row.uuid]);
    await h.programs.reorderDays([tree.days[1]!.row.uuid, day.row.uuid]);
    let after = (await readProgram(h.db, tree.program.uuid))!;
    expect(after.days.map((d) => d.row.name)).toEqual(['Day 2', 'Day 1']);
    expect(after.days[1]!.slots.map((slot) => slot.row.exerciseId)).toEqual(['0047', '0025']);

    await h.programs.removeDay(day.row.uuid);
    after = (await readProgram(h.db, tree.program.uuid))!;
    expect(after.days.map((d) => d.row.name)).toEqual(['Day 2']);
    expect(await h.db.rows('target_sets').where('slotUuid').equals(day.slots[0]!.row.uuid).count()).toBe(0);
    // Structure goes for good, and says so to the server ([[Business-Rules]] #8).
    expect((await outboxFor(h, 'program_days')).some((entry) => entry.op === 'delete' && entry.key === day.row.uuid)).toBe(true);
  });

  it('plants the program as a habit, and unplanting leaves the seed standing (Y12)', async () => {
    const h = await device(new FakeServer());
    const tree = await aProgram(h);
    await h.programs.plant(tree.program.uuid, { title: 'nSuns', timesPerWeek: 4, album: true });
    const after = (await readProgram(h.db, tree.program.uuid))!;
    const seed = await h.db.rows('commitments').get(after.program.commitmentUuid!);
    expect(seed).toMatchObject({ type: 'habit', title: 'nSuns', scheduleJson: JSON.stringify({ type: 'timesPerWeek', times: 4 }) });
    const album = await h.db.rows('albums').get(after.program.albumUuid!);
    // The album rides on the habit: not scheduled on its own.
    expect(album?.scheduleJson).toBeNull();

    await h.programs.unplant(tree.program.uuid);
    expect((await readProgram(h.db, tree.program.uuid))!.program.commitmentUuid).toBeNull();
    expect(await h.db.rows('commitments').get(seed!.uuid)).toBeDefined();
  });

  it('keeps training maxes by program and exercise', async () => {
    const h = await device(new FakeServer());
    const tree = await aProgram(h);
    await h.programs.setTrainingMax(tree.program.uuid, '0025', 111_000);
    await h.programs.setTrainingMax(tree.program.uuid, '0025', 112_500);
    expect([...(await readTrainingMaxes(h.db, tree.program.uuid))]).toEqual([['0025', 112_500]]);
  });
});

describe('running a session', () => {
  it('copies the day in, prefilled, with percentages resolved to a quarter kilo', async () => {
    const h = await device(new FakeServer());
    const tree = await aProgram(h);
    await h.programs.setTrainingMax(tree.program.uuid, '0025', 111_000);
    const { session, started } = await h.sessions.start({
      day: tree.days[0]!,
      programUuid: tree.program.uuid,
      trainingMaxes: await readTrainingMaxes(h.db, tree.program.uuid),
    });
    expect(started).toBe(true);
    expect(session.session).toMatchObject({ title: 'Day 1', harvestDay: '2026-09-19', endedAt: null });
    const [exercise] = session.exercises;
    expect(exercise!.row).toMatchObject({ exerciseId: '0025', plannedExerciseId: '0025', restSeconds: 180 });
    expect(exercise!.sets.map((set) => [set.weightGrams, set.reps, set.targetLabel, set.openEnded])).toEqual([
      [100_000, 5, '100.00×5', false],
      [83_250, 3, '83.25×3', false],
      [105_500, 1, '105.50×1+', true],
    ]);
  });

  it('runs one session at a time, whichever device began it (Y3)', async () => {
    const h = await device(new FakeServer());
    const tree = await aProgram(h);
    // A session the phone began and synced.
    await h.db.rows('workout_sessions').put({
      uuid: 'phone',
      programUuid: tree.program.uuid,
      dayUuid: tree.days[1]!.row.uuid,
      title: 'Day 2',
      harvestDay: '2026-09-19',
      startedAt: '2026-09-19T11:00:00.000Z',
      endedAt: null,
      note: null,
      pausedAt: null,
      pausedSeconds: 0,
      updatedAt: '2026-09-19T11:00:00.000Z',
      deletedAt: null,
    });
    const { session, started } = await h.sessions.start({ day: tree.days[0]!, programUuid: tree.program.uuid, trainingMaxes: new Map() });
    expect(started).toBe(false);
    expect(session.session.uuid).toBe('phone');
    expect(await h.db.rows('workout_sessions').count()).toBe(1);
  });

  it('writes a set the moment it is ticked, and keeps the pauses off the clock', async () => {
    const h = await device(new FakeServer());
    const tree = await aProgram(h);
    const { session } = await h.sessions.start({ day: tree.days[0]!, programUuid: tree.program.uuid, trainingMaxes: new Map() });
    const set = session.exercises[0]!.sets[0]!;
    await h.sessions.logSet(set.uuid, { weightGrams: 102_500, reps: 5, done: true });
    expect(await h.db.rows('workout_sets').get(set.uuid)).toMatchObject({ weightGrams: 102_500, done: true });

    h.clock.advance(60_000);
    await h.sessions.pause(session.session.uuid);
    h.clock.advance(300_000);
    await h.sessions.resume(session.session.uuid);
    expect((await h.db.rows('workout_sessions').get(session.session.uuid))!.pausedSeconds).toBe(300);
  });

  it('adds a set like the last one, drops one, swaps and skips with a reason (Y7)', async () => {
    const h = await device(new FakeServer());
    const tree = await aProgram(h);
    const { session } = await h.sessions.start({ day: tree.days[1]!, programUuid: tree.program.uuid, trainingMaxes: new Map() });
    const exercise = session.exercises[0]!;
    await h.sessions.addSet(exercise.row.uuid);
    let after = (await readSession(h.db, session.session.uuid))!.exercises[0]!;
    expect(after.sets.map((set) => [set.position, set.weightGrams, set.reps])).toEqual([
      [0, 60_000, 5],
      [1, 60_000, 5],
    ]);
    await h.sessions.removeSet(after.sets[1]!.uuid);
    await h.sessions.replaceExercise(exercise.row.uuid, '0033');
    await h.sessions.skipExercise(exercise.row.uuid, true, '  shoulder  ');
    after = (await readSession(h.db, session.session.uuid))!.exercises[0]!;
    expect(after.sets).toHaveLength(1);
    expect(after.row).toMatchObject({ exerciseId: '0033', plannedExerciseId: '0047', skipped: true, skipReason: 'shoulder' });
    // Putting it back clears the reason: it no longer applies to anything.
    await h.sessions.skipExercise(exercise.row.uuid, false);
    expect((await readSession(h.db, session.session.uuid))!.exercises[0]!.row.skipReason).toBeNull();
  });

  it('pays the gym habit on Finish, once, and nothing on Start (Y4)', async () => {
    const h = await device(new FakeServer());
    const tree = await planted(h);
    const { session } = await h.sessions.start({ day: tree.days[0]!, programUuid: tree.program.uuid, trainingMaxes: new Map() });
    expect(await h.db.rows('check_ins').count()).toBe(0);

    expect(await h.sessions.finish(session.session.uuid)).toMatchObject({ xpEarned: 10 });
    const checkIns = await h.db.rows('check_ins').toArray();
    expect(checkIns).toHaveLength(1);
    expect(checkIns[0]).toMatchObject({ commitmentUuid: tree.program.commitmentUuid, harvestDay: '2026-09-19' });

    // A second session the same day checks nothing in twice.
    const second = await h.sessions.start({ day: tree.days[1]!, programUuid: tree.program.uuid, trainingMaxes: new Map() });
    expect(await h.sessions.finish(second.session.session.uuid)).toMatchObject({ xpEarned: 0 });
    expect(await h.db.rows('check_ins').count()).toBe(1);
  });

  it('checks in on the session’s own day, and ends a paused session at the pause', async () => {
    const h = await device(new FakeServer());
    h.clock.set('2026-09-19T23:30:00.000Z');
    const tree = await planted(h);
    const { session } = await h.sessions.start({ day: tree.days[0]!, programUuid: tree.program.uuid, trainingMaxes: new Map() });
    await h.sessions.pause(session.session.uuid);
    // Past midnight, before 3 AM: still last night's session.
    h.clock.set('2026-09-20T01:30:00.000Z');
    await h.sessions.finish(session.session.uuid);
    const row = (await h.db.rows('workout_sessions').get(session.session.uuid))!;
    expect(row.endedAt).toBe('2026-09-19T23:30:00.000Z');
    expect(row.pausedAt).toBeNull();
    expect((await h.db.rows('check_ins').toArray())[0]!.harvestDay).toBe(row.harvestDay);
  });

  it('pays nothing for a program that is not a seed, or whose seed was archived', async () => {
    const h = await device(new FakeServer());
    const tree = await planted(h);
    await h.seeds.archive(tree.program.commitmentUuid!, null);
    const { session } = await h.sessions.start({ day: tree.days[0]!, programUuid: tree.program.uuid, trainingMaxes: new Map() });
    expect(await h.sessions.finish(session.session.uuid)).toMatchObject({ xpEarned: 0 });
  });

  it('discards a session with everything in it', async () => {
    const h = await device(new FakeServer());
    const tree = await aProgram(h);
    const { session } = await h.sessions.start({ day: tree.days[0]!, programUuid: tree.program.uuid, trainingMaxes: new Map() });
    await h.sessions.discard(session.session.uuid);
    expect(await readRunning(h.db)).toBeNull();
    expect(await h.db.rows('workout_sets').count()).toBe(0);
    expect(await h.db.rows('session_exercises').count()).toBe(0);
  });
});

describe('the day that is up next', () => {
  it('follows finished sessions only, and goes round (Y11)', async () => {
    const h = await device(new FakeServer());
    const tree = await aProgram(h);
    expect((await nextDayOf(h.db, tree))?.row.name).toBe('Day 1');
    const first = await h.sessions.start({ day: tree.days[0]!, programUuid: tree.program.uuid, trainingMaxes: new Map() });
    // Running is not finished: the pointer waits for Finish.
    expect((await nextDayOf(h.db, tree))?.row.name).toBe('Day 1');
    await h.sessions.finish(first.session.session.uuid);
    expect((await nextDayOf(h.db, tree))?.row.name).toBe('Day 2');
    h.clock.advance(60_000);
    const second = await h.sessions.start({ day: tree.days[1]!, programUuid: tree.program.uuid, trainingMaxes: new Map() });
    await h.sessions.finish(second.session.session.uuid);
    expect((await nextDayOf(h.db, tree))?.row.name).toBe('Day 1');
  });
});

describe('went, no numbers (Y12)', () => {
  it('is a finished, empty session on the day up next that checks the seed in, and goes with the tick', async () => {
    const h = await device(new FakeServer());
    const tree = await planted(h);
    const outcome = await h.sessions.bare({ programUuid: tree.program.uuid, dayUuid: tree.days[0]!.row.uuid, title: 'Day 1' });
    expect(outcome.xpEarned).toBe(10);
    const [session] = await h.db.rows('workout_sessions').toArray();
    expect(session).toMatchObject({ dayUuid: tree.days[0]!.row.uuid, endedAt: '2026-09-19T12:00:00.000Z' });
    expect((await nextDayOf(h.db, tree))?.row.name).toBe('Day 2');

    const seed = (await h.db.rows('commitments').get(tree.program.commitmentUuid!))!;
    await h.checkIns.undo(seed, HarvestDay.parse('2026-09-19'));
    expect(await h.sessions.discardBareOn(tree.program.uuid, '2026-09-19')).toBe(1);
    expect(await h.db.rows('workout_sessions').count()).toBe(0);
  });

  it('never takes back a session with anything in it', async () => {
    const h = await device(new FakeServer());
    const tree = await planted(h);
    const { session } = await h.sessions.start({ day: tree.days[0]!, programUuid: tree.program.uuid, trainingMaxes: new Map() });
    await h.sessions.finish(session.session.uuid);
    expect(await h.sessions.discardBareOn(tree.program.uuid, '2026-09-19')).toBe(0);
  });
});

describe('records', () => {
  it('come from the log: last time, the three records, and the history', async () => {
    const h = await device(new FakeServer());
    const tree = await aProgram(h);
    const run = async (sets: [number, number][]) => {
      const { session } = await h.sessions.start({ day: tree.days[1]!, programUuid: tree.program.uuid, trainingMaxes: new Map() });
      const exercise = session.exercises[0]!;
      for (let i = 1; i < sets.length; i++) await h.sessions.addSet(exercise.row.uuid);
      const rows = (await readSession(h.db, session.session.uuid))!.exercises[0]!.sets;
      for (const [i, [weightGrams, reps]] of sets.entries()) await h.sessions.logSet(rows[i]!.uuid, { weightGrams, reps, done: true });
      await h.sessions.finish(session.session.uuid);
      h.clock.advance(86_400_000);
    };
    await run([
      [60_000, 5],
      [60_000, 5],
    ]);
    await run([
      [70_000, 1],
      [62_500, 5],
    ]);

    expect((await lastTime(h.db, '0047')).map((set) => set.weightGrams)).toEqual([70_000, 62_500]);
    const records = await exerciseRecords(h.db, '0047');
    expect(records.heaviest?.weightGrams).toBe(70_000);
    expect(records.bestSetEstimate).toBe(72_917);
    expect(records.bestSessionVolumeGrams).toBe(600_000);
    const history = await exerciseHistory(h.db, '0047');
    expect(history.map((outing) => [outing.day, outing.volumeGrams])).toEqual([
      ['2026-09-20', 382_500],
      ['2026-09-19', 600_000],
    ]);
  });
});

describe('the catalogue', () => {
  it('is the phone’s own file, byte for byte, and reference data only (Business rule 14)', async () => {
    const web = readFileSync(join(__dirname, '../src/app/data/exercise-catalogue.json'), 'utf8');
    const phone = readFileSync(join(__dirname, '../../mobile/assets/exercises/exercises.json'), 'utf8');
    expect(web).toBe(phone);
    const book = await loadCatalogue();
    expect(book.all).toHaveLength(1324);
    expect(book.byId.get('0001')?.name).toBe('3/4 sit-up');
    expect(book.bodyParts).toContain('back');
  });

  it('keeps my own exercises beside it, as rows that travel', async () => {
    const h = await device(new FakeServer());
    const mine = await h.exercises.create({ name: ' Belt squat ', equipment: 'leverage machine' });
    expect(mine).toMatchObject({ name: 'Belt squat', mine: true });
    expect(await outboxFor(h, 'exercises')).toHaveLength(1);
    await h.exercises.remove(mine.id);
    expect((await h.db.rows('exercises').get(mine.id))!.deletedAt).not.toBeNull();
  });
});
