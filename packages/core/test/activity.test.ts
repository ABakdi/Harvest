import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';
import {
  HarvestDay,
  activityShade,
  activityWindow,
  dayActivity,
  type ActivityAlbum,
  type ActivityCheckIn,
  type ActivityMemory,
  type ActivitySeed,
} from '../src/index.js';

/** `fixtures/activity.json`, which the phone's heat-map is held to as well. */
const data = JSON.parse(readFileSync(new URL('../fixtures/activity.json', import.meta.url), 'utf8')) as {
  window: { today: string; start: string; end: string }[];
  activity: {
    today: string;
    seeds: ActivitySeed[];
    albums: ActivityAlbum[];
    checkIns: ActivityCheckIn[];
    memories: ActivityMemory[];
    heights: Record<string, number>;
  };
  shade: { actions: number; goal: number; inStreak: boolean; shade: number }[];
};

describe('activity.json', () => {
  it.each(data.window)('the window around $today', ({ today, start, end }) => {
    const window = activityWindow(HarvestDay.parse(today));
    expect([window.start.key, window.end.key]).toEqual([start, end]);
  });

  it('each day is as high as its productive actions', () => {
    const { today, heights, ...input } = data.activity;
    const { start, end } = activityWindow(HarvestDay.parse(today));
    expect(dayActivity(input, start, end)).toEqual(heights);
  });

  it.each(data.shade)(
    '$actions of $goal (streak: $inStreak) is shaded $shade',
    ({ actions, goal, inStreak, shade }) => {
      expect(activityShade(actions, goal, inStreak)).toBeCloseTo(shade, 10);
    },
  );
});
