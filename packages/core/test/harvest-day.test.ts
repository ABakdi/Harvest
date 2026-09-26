import { afterEach, describe, expect, it } from 'vitest';
import { HarvestDay, harvestDayKeyOf } from '../src/index.js';

describe('HarvestDay', () => {
  const zone = process.env.TZ;
  afterEach(() => {
    if (zone === undefined) delete process.env.TZ;
    else process.env.TZ = zone;
  });

  it('reads an instant in the local zone, whatever that zone is', () => {
    const instant = new Date('2026-09-19T01:30:00Z');
    process.env.TZ = 'UTC';
    expect(harvestDayKeyOf(instant)).toBe('2026-09-18');
    process.env.TZ = 'Africa/Algiers'; // UTC+1: 02:30 local, still before 3 AM
    expect(harvestDayKeyOf(instant)).toBe('2026-09-18');
    process.env.TZ = 'Asia/Tokyo'; // UTC+9: 10:30 local
    expect(harvestDayKeyOf(instant)).toBe('2026-09-19');
  });

  it('counts a DST night as one day in a zone that has them', () => {
    process.env.TZ = 'Europe/Paris';
    const before = HarvestDay.of(new Date(2026, 2, 28, 12));
    const after = HarvestDay.of(new Date(2026, 2, 29, 12));
    expect(before.daysUntil(after)).toBe(1);
    expect(before.next.equals(after)).toBe(true);
    expect(HarvestDay.of(new Date(2026, 2, 29, 1, 30)).key).toBe('2026-03-28');
    // 2:30 on the spring-forward night does not exist; the clock reads
    // 3:30 and the new day has begun.
    expect(HarvestDay.of(new Date(2026, 2, 29, 2, 30)).key).toBe('2026-03-29');
    expect(after.startsAt.getHours()).toBe(3);
  });

  it('parses, compares and serialises', () => {
    const a = HarvestDay.parse('2026-09-19');
    const b = HarvestDay.fromDate(2026, 9, 20);
    expect(a.compareTo(b)).toBe(-1);
    expect(b.compareTo(a)).toBe(1);
    expect(a.compareTo(HarvestDay.parse('2026-09-19'))).toBe(0);
    expect(JSON.stringify({ day: a })).toBe('{"day":"2026-09-19"}');
    expect(() => HarvestDay.parse('2026-02-30')).toThrow(RangeError);
  });
});
