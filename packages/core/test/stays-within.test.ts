import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';
import { staysWithin } from '../src/index.js';

/** `fixtures/places.json` `staysWithin`: a stay across 3 AM belongs to both days. */
const data = JSON.parse(readFileSync(new URL('../fixtures/places.json', import.meta.url), 'utf8')) as {
  staysWithin: {
    why: string;
    dayStart: string;
    dayEnd: string;
    points: { latitude: number; longitude: number; at: string }[];
    result: { from: string; to: string; minutes: number }[];
  }[];
};

describe('places.json staysWithin', () => {
  it.each(data.staysWithin)('$why', ({ dayStart, dayEnd, points, result }) => {
    const stays = staysWithin(points, new Date(dayStart), new Date(dayEnd));
    expect(
      stays.map((stay) => ({
        from: stay.from.toISOString(),
        to: stay.to.toISOString(),
        minutes: stay.lengthMs / 60_000,
      })),
    ).toEqual(
      result.map((stay) => ({
        from: new Date(stay.from).toISOString(),
        to: new Date(stay.to).toISOString(),
        minutes: stay.minutes,
      })),
    );
  });
});
