import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';
import {
  estimatedOneRepMax,
  filterExercises,
  finishQuestion,
  formatPercentTenths,
  loadFieldValue,
  nextPosition,
  nextProgramDay,
  noRecords,
  barChoicesIn,
  barIn,
  defaultBarGramsLb,
  platesFor,
  platesIn,
  recordsBeatenBy,
  recordsFrom,
  reorderedUuids,
  resolveTarget,
  roundLoad,
  sessionElapsedSeconds,
  sessionTargetLabel,
  storedLabelGrams,
  storedLabelKg,
  usesBar,
  type ExerciseLike,
  type LoadUnit,
  type LoggedSetLike,
  type PlateStack,
  type RecordKind,
  type TargetSetLike,
} from '../src/index.js';

/**
 * The gym's arithmetic, held to the fixture the phone's
 * `test/contracts/gym_rules_test.dart` reads as well.
 */
function fixture<T>(name: string): T {
  return JSON.parse(readFileSync(new URL(`../fixtures/${name}.json`, import.meta.url), 'utf8')) as T;
}

interface Spec {
  roundLoad: { grams: number; unit?: LoadUnit; rounded: number }[];
  targets: { why: string; unit?: LoadUnit; target: TargetSetLike; trainingMaxGrams: number | null; grams: number | null; label: string }[];
  labelsRead: { why: string; label: string; unit: LoadUnit; grams: number | null }[];
  percents: { tenths: number; text: string }[];
  fieldValues: { grams: number; unit: 'kg' | 'lb'; text: string }[];
  estimates: { why: string; weightGrams: number; reps: number; estimate: number | null }[];
  records: {
    why: string;
    sets: LoggedSetLike[];
    sessionVolumes: number[];
    heaviest: number | null;
    bestSet: number | null;
    bestSetEstimate: number | null;
    bestSessionVolumeGrams: number;
  }[];
  beaten: {
    why: string;
    records: { heaviestGrams: number | null; bestSetEstimate: number | null };
    set: LoggedSetLike;
    kinds: RecordKind[];
  }[];
  plates: {
    why: string;
    unit?: LoadUnit;
    targetGrams: number;
    barGrams: number;
    stacks: PlateStack[];
    totalGrams: number;
    shortfallGrams: number;
    overGrams: number;
  }[];
  poundGym: { bar: number; bars: number[]; plates: number[] };
  barsIn: { why: string; barGrams: number; unit: LoadUnit; bar: number }[];
  bars: { name: string; equipment: string | null; usesBar: boolean }[];
  catalogue: ExerciseLike[];
  searches: { why: string; search: string; bodyPart: string | null; equipment: string | null; ids: string[] }[];
  nextDays: { why: string; days: string[]; last: string | null; next: string | null }[];
  clocks: {
    why: string;
    startedAt: string;
    endedAt: string | null;
    pausedAt: string | null;
    pausedSeconds: number;
    now: string;
    seconds: number;
  }[];
  reorders: { uuids: string[]; from: number; to: number; result: string[] }[];
  nextPositions: { positions: number[]; next: number; why: string }[];
}

const spec = fixture<Spec>('gym');

describe('loads', () => {
  it('round to a quarter of the unit they are read in (Y8)', () => {
    for (const entry of spec.roundLoad) expect(roundLoad(entry.grams, entry.unit)).toBe(entry.rounded);
  });

  it('resolve, and are labelled the way the phone stores them', () => {
    for (const entry of spec.targets) {
      const grams = resolveTarget(entry.target, entry.trainingMaxGrams, entry.unit);
      expect(grams, entry.why).toBe(entry.grams);
      expect(sessionTargetLabel(entry.target, grams), entry.why).toBe(entry.label);
    }
  });

  it('read a stored label back as kilograms', () => {
    expect(storedLabelKg('83.25×5')).toEqual({ kg: 83.25, reps: '5' });
    expect(storedLabelKg('95.0%×1+')).toBeNull();
    expect(storedLabelKg('×1')).toBeNull();
  });

  it('read a stored label back in the unit on screen', () => {
    for (const entry of spec.labelsRead) expect(storedLabelGrams(entry.label, entry.unit), entry.why).toBe(entry.grams);
  });

  it('write percentages and field values as the phone does', () => {
    for (const entry of spec.percents) expect(formatPercentTenths(entry.tenths)).toBe(entry.text);
    for (const entry of spec.fieldValues) expect(loadFieldValue(entry.grams, entry.unit)).toBe(entry.text);
  });
});

describe('records', () => {
  it('estimate by Epley (Y6)', () => {
    for (const entry of spec.estimates) expect(estimatedOneRepMax(entry.weightGrams, entry.reps), entry.why).toBe(entry.estimate);
  });

  it('are derived from the log (Y5)', () => {
    for (const entry of spec.records) {
      const records = recordsFrom(entry.sets, entry.sessionVolumes);
      expect(records.heaviest, entry.why).toBe(entry.heaviest === null ? null : entry.sets[entry.heaviest]);
      expect(records.bestSet, entry.why).toBe(entry.bestSet === null ? null : entry.sets[entry.bestSet]);
      expect(records.bestSetEstimate, entry.why).toBe(entry.bestSetEstimate);
      expect(records.bestSessionVolumeGrams, entry.why).toBe(entry.bestSessionVolumeGrams);
    }
  });

  it('are beaten the moment a set is ticked, never by the set itself', () => {
    for (const entry of spec.beaten) {
      const records = {
        ...noRecords,
        heaviest:
          entry.records.heaviestGrams === null ? null : { weightGrams: entry.records.heaviestGrams, reps: 1, done: true },
        bestSetEstimate: entry.records.bestSetEstimate,
      };
      expect(recordsBeatenBy(entry.set, records), entry.why).toEqual(entry.kinds);
    }
  });
});

describe('the plate calculator', () => {
  it('loads greedily and says when it falls short', () => {
    for (const entry of spec.plates) {
      const plan = platesFor(entry.targetGrams, entry.barGrams, entry.unit);
      expect(plan.stacks, entry.why).toEqual(entry.stacks);
      expect(plan.totalGrams, entry.why).toBe(entry.totalGrams);
      expect(plan.shortfallGrams, entry.why).toBe(entry.shortfallGrams);
      expect(plan.overGrams, entry.why).toBe(entry.overGrams);
    }
  });

  it('knows a pound gym (Y8)', () => {
    expect(defaultBarGramsLb).toBe(spec.poundGym.bar);
    expect(barChoicesIn('lb')).toEqual(spec.poundGym.bars);
    expect(platesIn('lb')).toEqual(spec.poundGym.plates);
    for (const entry of spec.barsIn) expect(barIn(entry.barGrams, entry.unit), entry.why).toBe(entry.bar);
  });

  it('belongs to exercises with a bar (Y9)', () => {
    for (const entry of spec.bars) expect(usesBar({ id: 'x', ...entry }), entry.name).toBe(entry.usesBar);
  });
});

describe('the catalogue', () => {
  it('searches every word, mine first', () => {
    for (const entry of spec.searches) {
      const found = filterExercises(spec.catalogue, entry).map((exercise) => exercise.id);
      expect(found, entry.why).toEqual(entry.ids);
    }
  });
});

describe('sessions', () => {
  it('go round the program (Y11)', () => {
    for (const entry of spec.nextDays) {
      const days = entry.days.map((uuid, position) => ({ uuid, position }));
      expect(nextProgramDay(days, entry.last)?.uuid ?? null, entry.why).toBe(entry.next);
    }
    // Position decides, not the order the rows came in.
    expect(nextProgramDay([{ uuid: 'C', position: 2 }, { uuid: 'A', position: 0 }, { uuid: 'B', position: 1 }], 'B')?.uuid).toBe('C');
  });

  it('keep time without the pauses', () => {
    for (const entry of spec.clocks) expect(sessionElapsedSeconds(entry, entry.now), entry.why).toBe(entry.seconds);
  });

  it('reorder the way a drag reports it', () => {
    for (const entry of spec.reorders) expect(reorderedUuids(entry.uuids, entry.from, entry.to)).toEqual(entry.result);
  });

  it('add after the highest position, so a drop never repeats one', () => {
    for (const entry of spec.nextPositions) {
      expect(nextPosition(entry.positions.map((position) => ({ position }))), entry.why).toBe(entry.next);
    }
  });

  it('ask before Finish leaves un-skipped sets behind (Y10)', () => {
    const set = (done: boolean) => ({ done });
    expect(finishQuestion([{ skipped: false, sets: [set(false)] }]).kind).toBe('empty');
    expect(finishQuestion([{ skipped: false, sets: [set(true), set(false)] }])).toEqual({ kind: 'incomplete', done: 1, left: 1, planned: 2 });
    // A skipped exercise's sets were never going to happen.
    expect(finishQuestion([{ skipped: false, sets: [set(true)] }, { skipped: true, sets: [set(false), set(false)] }]).kind).toBe('none');
  });
});
