import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';
import {
  HarvestDay,
  calendarEntries,
  type CalendarCheckIn,
  type CalendarEntry,
  type CalendarSeed,
} from '../src/index.js';

/** `fixtures/calendar.json`, which the phone's calendar is held to as well. */
const data = JSON.parse(readFileSync(new URL('../fixtures/calendar.json', import.meta.url), 'utf8')) as {
  seeds: CalendarSeed[];
  checkIns: CalendarCheckIn[];
  days: { why: string; day: string; entries: CalendarEntry[] }[];
};

describe('calendar.json', () => {
  it.each(data.days)('$why', ({ day, entries }) => {
    expect(calendarEntries(data.seeds, data.checkIns, HarvestDay.parse(day))).toEqual(entries);
  });
});
