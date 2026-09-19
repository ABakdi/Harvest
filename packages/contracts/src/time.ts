import { z } from 'zod';

/**
 * An instant on the wire: ISO-8601, UTC, with a `Z`. Any number of
 * fractional digits is allowed, because Dart writes microseconds when
 * it has them and JavaScript writes milliseconds.
 */
export const isoInstantSchema = z.iso.datetime({ message: 'Not an ISO-8601 UTC instant' });

const instantPattern = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})(?::(\d{2})(?:\.(\d+))?)?Z$/;

/**
 * Microseconds since the epoch, exactly. The conflict rule compares
 * clocks, and comparing the strings would be wrong the moment one side
 * writes `.120Z` and the other `.12Z`; going through `Date` would drop
 * Dart's microseconds and turn two different writes into a tie. An
 * epoch in microseconds stays well inside a double's exact integers
 * until the year 2255.
 */
export function instantMicros(iso: string): number {
  const match = instantPattern.exec(iso);
  if (!match) throw new RangeError(`Not an ISO-8601 UTC instant: ${iso}`);
  const [, y, mo, d, h, mi, s, fraction] = match;
  const millis = Date.UTC(Number(y), Number(mo) - 1, Number(d), Number(h), Number(mi), Number(s ?? 0));
  const micros = Number(((fraction ?? '') + '000000').slice(0, 6));
  return millis * 1000 + micros;
}

/** Whether two ISO instants name the same moment, whatever their spelling. */
export function sameInstant(a: string | null, b: string | null): boolean {
  if (a === null || b === null) return a === b;
  return instantMicros(a) === instantMicros(b);
}

/**
 * Whether [key] is a Harvest Day key, `yyyy-MM-dd`, naming a date that
 * exists. `2026-02-30` is well-formed and still not a day.
 */
export function isHarvestDayKey(key: string): boolean {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(key);
  if (!match) return false;
  const [, y, m, d] = match.map(Number) as [number, number, number, number];
  const date = new Date(Date.UTC(y, m - 1, d));
  return date.getUTCFullYear() === y && date.getUTCMonth() === m - 1 && date.getUTCDate() === d;
}
