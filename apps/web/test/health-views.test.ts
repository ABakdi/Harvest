import { HarvestDay, fallbackCycle } from '@harvest/core';
import { describe, expect, it } from 'vitest';
import { readNights, readSteps, readWeights, sleepSummary, weightSummary } from '@/app/data/health';
import { readPrograms, readSessions } from '@/app/data/gym';
import { catalogueName } from '@/app/data/exercises';
import { FakeServer } from './fake-server';
import { device } from './helpers';

/**
 * The body and the gym are views: nothing here writes. What they owe
 * the reader is that the numbers match the phone's, which they do by
 * going through `packages/core` and the same rows (W2).
 */
async function seeded() {
  const h = await device(new FakeServer());
  const night = (day: string, minutes: number, stars: number | null) => ({
    uuid: `n-${day}`,
    harvestDay: day,
    fellAsleepAt: `${day}T23:00:00.000Z`,
    wokeAt: new Date(Date.parse(`${day}T23:00:00.000Z`) + minutes * 60_000).toISOString(),
    targetMinutes: 480,
    restedStars: stars,
    note: null,
    createdAt: `${day}T23:00:00.000Z`,
    updatedAt: `${day}T23:00:00.000Z`,
    deletedAt: null,
  });
  await h.db.rows('sleep_sessions').bulkPut([
    night('2026-09-17', 420, 3),
    night('2026-09-18', 400, null),
    // Deleted nights are not nights.
    { ...night('2026-09-16', 60, null), deletedAt: '2026-09-17T00:00:00.000Z' },
  ]);
  await h.db.rows('body_weights').bulkPut([
    { uuid: 'w1', grams: 82_000, harvestDay: '2026-09-17', note: null, measuredAt: '2026-09-17T07:00:00.000Z', updatedAt: '', deletedAt: null },
    { uuid: 'w2', grams: 81_400, harvestDay: '2026-09-18', note: null, measuredAt: '2026-09-18T07:00:00.000Z', updatedAt: '', deletedAt: null },
  ]);
  await h.db.rows('step_days').bulkPut([
    { harvestDay: '2026-09-18', steps: 9000, lastCounter: null, updatedAt: '' },
    { harvestDay: '2026-09-19', steps: 12_000, lastCounter: null, updatedAt: '' },
  ]);
  return h;
}

describe('the body, read', () => {
  it('leaves out deleted nights and owes what the shortfalls add up to', async () => {
    const h = await seeded();
    const nights = await readNights(h.db);
    expect(nights.map((night) => night.harvestDay)).toEqual(['2026-09-18', '2026-09-17']);

    const summary = sleepSummary(nights, { cycle: fallbackCycle, overrides: {} }, HarvestDay.parse('2026-09-19'));
    // 80 short, then 60 short.
    expect(summary.debt.minutes).toBe(140);
    expect(summary.averageMinutes).toBe(410);
    expect(summary.last?.harvestDay).toBe('2026-09-18');
  });

  it('reads weights oldest first and says which way they went', async () => {
    const h = await seeded();
    const rows = await readWeights(h.db);
    expect(rows.map((row) => row.grams)).toEqual([82_000, 81_400]);

    const summary = weightSummary(rows, 30);
    expect(summary.latest?.grams).toBe(81_400);
    // The trend follows the average line, not the raw dots: 82.0 to
    // (82.0 + 81.4) / 2, which is 300 g rather than 600.
    expect(summary.trend?.gramsChanged).toBe(-300);
  });

  it('reads step days oldest first', async () => {
    const h = await seeded();
    const rows = await readSteps(h.db);
    expect(rows.map((row) => row.steps)).toEqual([9000, 12_000]);
  });
});

describe('the gym, read', () => {
  it('lists a program by its days, and a day by what it asks for', async () => {
    const h = await device(new FakeServer());
    await h.db.rows('programs').put({
      uuid: 'p1',
      name: 'Upper/Lower',
      note: null,
      weeks: null,
      commitmentUuid: null,
      albumUuid: null,
      photoPrompt: 'after',
      createdAt: '',
      updatedAt: '',
      deletedAt: null,
    });
    await h.db.rows('program_days').bulkPut([
      { uuid: 'd2', programUuid: 'p1', name: 'Lower', position: 1, week: null, accessories: null },
      { uuid: 'd1', programUuid: 'p1', name: 'Upper', position: 0, week: null, accessories: null },
    ]);
    await h.db.rows('program_slots').bulkPut([
      { uuid: 's2', dayUuid: 'd1', exerciseId: '0025', position: 1, restSeconds: null, barGrams: 20_000, note: null },
      { uuid: 's1', dayUuid: 'd1', exerciseId: '0001', position: 0, restSeconds: null, barGrams: 20_000, note: null },
    ]);

    const [view] = await readPrograms(h.db);
    expect(view?.days.map((day) => day.row.name)).toEqual(['Upper', 'Lower']);
    expect(view?.days[0]?.slots.map((slot) => slot.row.exerciseId)).toEqual(['0001', '0025']);
    // The catalogue is bundled, not synced, so the reader has its names.
    expect(catalogueName('0001')).toBe('3/4 sit-up');
    expect(catalogueName('nope')).toBeNull();
  });

  it('counts only ticked sets, and only finished sessions', async () => {
    const h = await device(new FakeServer());
    const session = (uuid: string, day: string, endedAt: string | null) => ({
      uuid,
      programUuid: null,
      dayUuid: null,
      title: 'Push',
      harvestDay: day,
      startedAt: `${day}T17:00:00.000Z`,
      endedAt,
      note: null,
      pausedAt: null,
      pausedSeconds: 0,
      updatedAt: '',
      deletedAt: null,
    });
    await h.db.rows('workout_sessions').bulkPut([
      session('s1', '2026-09-18', '2026-09-18T18:00:00.000Z'),
      session('s2', '2026-09-19', null),
    ]);
    await h.db.rows('session_exercises').put({
      uuid: 'e1',
      sessionUuid: 's1',
      position: 0,
      exerciseId: '0001',
      plannedExerciseId: null,
      slotUuid: null,
      skipped: false,
      skipReason: null,
      note: null,
      restSeconds: null,
      barGrams: 20_000,
    });
    await h.db.rows('workout_sets').bulkPut([
      { uuid: 'x1', sessionExerciseUuid: 'e1', position: 0, weightGrams: 60_000, reps: 5, done: true, targetLabel: null, openEnded: false, loggedAt: '' },
      { uuid: 'x2', sessionExerciseUuid: 'e1', position: 1, weightGrams: 60_000, reps: 5, done: false, targetLabel: null, openEnded: false, loggedAt: '' },
    ]);

    const views = await readSessions(h.db);
    expect(views.map((view) => view.session.uuid)).toEqual(['s1']);
    expect(views[0]?.doneSets).toBe(1);
    expect(views[0]?.volumeGrams).toBe(300_000);
  });
});
