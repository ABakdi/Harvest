/**
 * The app's logical day: it starts at 3:00 AM local time, not midnight,
 * so a check-in at 1 AM still counts for the evening it belongs to.
 *
 * Business rule #1, ported from `apps/mobile/lib/core/domain/harvest_day.dart`.
 *
 * Internally a day is a calendar date and nothing else. All arithmetic
 * goes through `Date.UTC`, which has no daylight saving time, so adding
 * a day is always adding a date and never adding 24 hours: the night the
 * clocks change is one day long like every other.
 */
export class HarvestDay {
  /** The local-time hour at which a new day begins. */
  static readonly boundaryHour = 3;

  private constructor(
    readonly year: number,
    readonly month: number,
    readonly day: number,
  ) {}

  /**
   * Normalises any year/month/day triple (a day of 0 or 32 included) to
   * the real calendar date it lands on.
   */
  private static fromParts(year: number, month: number, day: number): HarvestDay {
    const date = new Date(Date.UTC(year, month - 1, day));
    // Date.UTC maps years 0..99 to 1900..1999; setting it again undoes that.
    if (year >= 0 && year < 100) date.setUTCFullYear(year, month - 1, day);
    return new HarvestDay(date.getUTCFullYear(), date.getUTCMonth() + 1, date.getUTCDate());
  }

  /**
   * The Harvest Day that [moment] belongs to, read in the local time
   * zone. Pure calendar math: before the boundary hour the moment
   * belongs to the previous calendar date, whatever a DST change did to
   * the night.
   */
  static of(moment: Date): HarvestDay {
    const shift = moment.getHours() < HarvestDay.boundaryHour ? 1 : 0;
    return HarvestDay.fromParts(moment.getFullYear(), moment.getMonth() + 1, moment.getDate() - shift);
  }

  /** Today's Harvest Day. */
  static today(): HarvestDay {
    return HarvestDay.of(new Date());
  }

  /**
   * A Harvest Day from a plain calendar date (no 3 AM shift): for values
   * from date pickers and calendar grids.
   */
  static fromDate(year: number, month: number, day: number): HarvestDay {
    return HarvestDay.fromParts(year, month, day);
  }

  /** Parses a key produced by [key]; throws on anything else. */
  static parse(key: string): HarvestDay {
    const parsed = HarvestDay.tryParse(key);
    if (parsed === null) throw new RangeError(`not a Harvest Day key: ${key}`);
    return parsed;
  }

  /**
   * [parse] for stored values: null instead of throwing. As lenient as
   * the Dart original about digits (`2026-9-2` parses), and as strict
   * about the date existing (`2026-02-30` does not).
   */
  static tryParse(key: string | null | undefined): HarvestDay | null {
    if (key === null || key === undefined) return null;
    const parts = key.split('-');
    if (parts.length !== 3) return null;
    const [year, month, day] = parts.map(parseDartInt) as [number | null, number | null, number | null];
    if (year === null || month === null || day === null) return null;
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    const candidate = HarvestDay.fromParts(year, month, day);
    if (candidate.month !== month || candidate.day !== day) return null;
    return candidate;
  }

  /** Stable storage key, `yyyy-MM-dd`. */
  get key(): string {
    return `${pad(this.year, 4)}-${pad(this.month, 2)}-${pad(this.day, 2)}`;
  }

  /** Midnight (local) of the calendar date this day is labelled with. */
  toDate(): Date {
    const date = new Date(this.year, this.month - 1, this.day);
    if (this.year >= 0 && this.year < 100) date.setFullYear(this.year);
    return date;
  }

  /** The moment this Harvest Day started: 3 AM local. */
  get startsAt(): Date {
    return new Date(this.year, this.month - 1, this.day, HarvestDay.boundaryHour);
  }

  /** 1 (Monday) through 7 (Sunday), as Dart's `DateTime.weekday`. */
  get weekday(): number {
    const jsDay = new Date(Date.UTC(this.year, this.month - 1, this.day)).getUTCDay();
    return jsDay === 0 ? 7 : jsDay;
  }

  /** The Monday that starts this day's week. */
  get weekStart(): HarvestDay {
    return this.addDays(1 - this.weekday);
  }

  /** Monday through Sunday of this day's week. */
  get weekDays(): HarvestDay[] {
    const start = this.weekStart;
    return Array.from({ length: 7 }, (_, index) => start.addDays(index));
  }

  /** [n] calendar days later, or earlier for a negative [n]. */
  addDays(n: number): HarvestDay {
    return HarvestDay.fromParts(this.year, this.month, this.day + n);
  }

  get next(): HarvestDay {
    return this.addDays(1);
  }

  get previous(): HarvestDay {
    return this.addDays(-1);
  }

  /** Whole days from this to [other], positive when [other] is later. */
  daysUntil(other: HarvestDay): number {
    return Math.round((other.utcMidnight() - this.utcMidnight()) / 86_400_000);
  }

  compareTo(other: HarvestDay): number {
    return Math.sign(this.utcMidnight() - other.utcMidnight());
  }

  equals(other: HarvestDay): boolean {
    return this.year === other.year && this.month === other.month && this.day === other.day;
  }

  toString(): string {
    return `HarvestDay(${this.key})`;
  }

  toJSON(): string {
    return this.key;
  }

  private utcMidnight(): number {
    const date = new Date(Date.UTC(this.year, this.month - 1, this.day));
    if (this.year >= 0 && this.year < 100) date.setUTCFullYear(this.year);
    return date.getTime();
  }
}

/** The Harvest Day key of [moment]; what every date-keyed row stores. */
export function harvestDayKeyOf(moment: Date): string {
  return HarvestDay.of(moment).key;
}

/** Dart's `toString().padLeft(width, '0')`, sign and all. */
function pad(value: number, width: number): string {
  return String(value).padStart(width, '0');
}

/**
 * Dart's `int.tryParse` without a radix: an optional sign, then decimal
 * digits or `0x` and hex digits, surrounding whitespace allowed;
 * anything else is null. `Number()` would accept `""` and `"1e3"`,
 * which the phone would not.
 */
function parseDartInt(raw: string): number | null {
  const match = /^([+-]?)(?:0x([0-9a-f]+)|(\d+))$/i.exec(raw.trim());
  if (!match) return null;
  const [, sign, hex, decimal] = match;
  const magnitude = hex !== undefined ? parseInt(hex, 16) : Number(decimal);
  return sign === '-' ? -magnitude : magnitude;
}
