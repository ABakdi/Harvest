import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';
import { oneNotePerDay, seedNoteOfDay, type SeedNoteLike } from '../src/index.js';

/** `fixtures/seed-notes.json`, which the phone's seed notes are held to as well. */
const data = JSON.parse(readFileSync(new URL('../fixtures/seed-notes.json', import.meta.url), 'utf8')) as {
  cases: { why: string; rows: SeedNoteLike[]; seed: string; day: string; note: string | null; extras: string[] }[];
};

describe('seed-notes.json', () => {
  it.each(data.cases)('$why', ({ rows, seed, day, note, extras }) => {
    const found = seedNoteOfDay(rows, seed, day);
    expect(found.note?.uuid ?? null).toBe(note);
    expect(found.extras.map((row) => row.uuid).sort()).toEqual([...extras].sort());
    const kept = oneNotePerDay(rows).filter((row) => row.commitmentUuid === seed && row.harvestDay === day);
    expect(kept.map((row) => row.uuid)).toEqual(note === null ? [] : [note]);
  });
});
