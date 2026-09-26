import { describe, expect, it } from 'vitest';
import { shownVolume } from '@/app/screens/gym/shared';

/** 60 kg, stored in grams: 132.25 lb to the quarter pound. */
const set60 = { done: true, weightGrams: 60_000, reps: 1 };

/** A session's volume adds up the loads as they read (Y8). */
describe('a session volume', () => {
  it('in pounds, sums each load rounded to its quarter pound', () => {
    expect(shownVolume([set60, set60, set60, set60, set60], 'lb')).toBe(661.25);
  });

  it('in kilos, is the stored loads as they are', () => {
    expect(shownVolume([set60, set60, set60, set60, set60], 'kg')).toBe(300);
  });

  it('leaves out a set that was not done', () => {
    expect(shownVolume([set60, { ...set60, done: false }], 'lb')).toBe(132.25);
  });
});
