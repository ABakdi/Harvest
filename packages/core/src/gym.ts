/**
 * The arithmetic of the gym: what a percentage resolves to, what a set
 * estimates to, which records a set beats, what goes on each side of
 * the bar, and which day of a program is up. A port of
 * `apps/mobile/lib/features/gym/domain/{program,session,plates,exercise}.dart`
 * and the pure half of `sessions_repository.dart`, held to
 * `fixtures/gym.json`.
 *
 * Weights are grams, integer, for the reason money is minor units: a
 * barbell load is not a float ([[Gym]] Y8). They round in the unit I
 * read them in, so 135 lb is 135 lb and not 135.03.
 */

import { gramsPerPound } from './body.js';

export const gramsPerKg = 1000;

/** The units a load is read in — the body weight's, there is no other. */
export type LoadUnit = 'kg' | 'lb';

/** What a resolved weight is rounded to in kilos: a quarter of one (Y8). */
export const roundingGrams = 250;

/** What a bar weighs unless told otherwise. */
export const defaultBarGrams = 20 * gramsPerKg;

/** Pounds as the whole grams that read back as exactly those pounds. */
export function gramsOfPounds(pounds: number): number {
  return Math.round(pounds * gramsPerPound);
}

/** The bar a pound gym has: 45 lb, not 20 kg (Y8). */
export const defaultBarGramsLb = gramsOfPounds(45);

/** The rest to count down when nothing else has been said. */
export const defaultRestSeconds = 120;

/** The rests worth one tap; anything else is typed. */
export const restChoices: readonly number[] = [60, 90, 120, 180, 240, 300];

/** The bars a slot can be told about: EZ, Smith, Olympic, the heavy one. */
export const barChoicesGrams: readonly number[] = [10_000, 15_000, 20_000, 25_000];

/** The bars in pounds: the women's and the men's Olympic. */
export const barChoicesGramsLb: readonly number[] = [gramsOfPounds(35), gramsOfPounds(45)];

/** The bar chips for the unit on screen. */
export function barChoicesIn(unit: LoadUnit): readonly number[] {
  return unit === 'lb' ? barChoicesGramsLb : barChoicesGrams;
}

/**
 * The bar a slot really has in [unit] (`barIn`): a slot still on the
 * 20 kg default is the 45 lb bar to someone lifting in pounds; any
 * other bar is the one I set.
 */
export function barIn(barGrams: number, unit: LoadUnit): number {
  return unit === 'lb' && barGrams === defaultBarGrams ? defaultBarGramsLb : barGrams;
}

/** The plates a gym has, heaviest first, micro-plates included. */
export const defaultPlatesGrams: readonly number[] = [25_000, 20_000, 15_000, 10_000, 5_000, 2_500, 1_250, 1_000, 500, 250];

/** A pound gym's plates, heaviest first. */
export const defaultPlatesGramsLb: readonly number[] = [45, 35, 25, 10, 5, 2.5].map(gramsOfPounds);

/** The plates for the unit on screen. */
export function platesIn(unit: LoadUnit): readonly number[] {
  return unit === 'lb' ? defaultPlatesGramsLb : defaultPlatesGrams;
}

/** The catalogue's equipment names that mean "a bar with plates". */
export const barEquipment: ReadonlySet<string> = new Set(['barbell', 'ez barbell', 'olympic barbell', 'smith machine', 'trap bar']);

/** Grams as whole quarter pounds, the pound's loadable step. */
function quarterPounds(grams: number): number {
  return Math.round((grams / gramsPerPound) * 4);
}

/**
 * Rounds to something that can actually be loaded (`roundLoad`): the
 * nearest quarter kilo, or for pounds the nearest quarter pound, kept
 * as the whole grams of that many pounds so it reads back exactly.
 */
export function roundLoad(grams: number, unit: LoadUnit = 'kg'): number {
  if (unit === 'lb') return gramsOfPounds(quarterPounds(grams) / 4);
  return Math.round(grams / roundingGrams) * roundingGrams;
}

// ------------------------------------------------------------- targets

/** One row of what I am *meant* to do, as `target_sets` stores it. */
export interface TargetSetLike {
  readonly reps: number | null;
  readonly weightGrams: number | null;
  /** Percent of the training max, ×10: 82.5% is 825. */
  readonly percentTenths: number | null;
  readonly openEnded: boolean;
}

/**
 * What a target asks for in grams (`TargetSet.resolve`), a percentage
 * rounded in [unit]. Null for a percentage with no training max — a
 * question to ask, not a zero to load.
 */
export function resolveTarget(set: TargetSetLike, trainingMaxGrams?: number | null, unit: LoadUnit = 'kg'): number | null {
  if (set.weightGrams !== null) return set.weightGrams;
  if (set.percentTenths === null) return null;
  if (trainingMaxGrams === undefined || trainingMaxGrams === null) return null;
  return roundLoad((trainingMaxGrams * set.percentTenths) / 1000, unit);
}

/** A Dart `double.toString()`: a whole number keeps its `.0`. */
function dartDouble(value: number): string {
  return Number.isInteger(value) ? value.toFixed(1) : String(value);
}

/**
 * The label a session row keeps of what the set was asked to be
 * (`SessionsRepository._labelFor`): `83.25×5`, `75.0%×1+`, `×5`. Stored
 * as text, so it must be the phone's text to the character.
 */
export function sessionTargetLabel(set: TargetSetLike, grams: number | null): string {
  const reps = set.openEnded ? `${set.reps ?? 1}+` : `${set.reps ?? 1}`;
  if (grams !== null) return `${(grams / 1000).toFixed(2)}×${reps}`;
  if (set.percentTenths !== null) return `${dartDouble(set.percentTenths / 10)}%×${reps}`;
  return `×${reps}`;
}

/** The weight half of a stored label, in kilograms; null when it has none. */
export function storedLabelKg(label: string): { kg: number; reps: string } | null {
  if (!label.includes('×')) return null;
  const parts = label.split('×');
  const first = parts[0] ?? '';
  if (!/^-?\d+(\.\d+)?$/.test(first)) return null;
  return { kg: Number(first), reps: parts[parts.length - 1] ?? '' };
}

/**
 * The grams a stored label asks for, read in [unit] (`storedLabelGrams`).
 * A label keeps kilos to two places, ten grams at worst from the load,
 * so rounding in the unit on screen gives the pounds back exactly.
 */
export function storedLabelGrams(label: string, unit: LoadUnit): number | null {
  const parsed = storedLabelKg(label);
  if (!parsed) return null;
  return roundLoad(Math.round(parsed.kg * 1000), unit);
}

/** Percent tenths as a percentage: `82.5%`, `75%` (`formatPercent`). */
export function formatPercentTenths(tenths: number): string {
  const whole = Math.trunc(tenths / 10);
  const rest = tenths % 10;
  return rest === 0 ? `${whole}%` : `${whole}.${rest}%`;
}

/**
 * A weight as it goes into a text field (`loadFieldValue`): plain digits
 * and a dot, rounded to two places, trailing zeros gone.
 */
export function loadFieldValue(grams: number, unit: 'kg' | 'lb'): string {
  const value = unit === 'kg' ? grams / 1000 : grams / 453.59237;
  const rounded = Math.round(value * 100) / 100;
  if (Number.isInteger(rounded)) return rounded.toFixed(0);
  return rounded.toFixed(2).replace(/0+$/, '').replace(/\.$/, '');
}

// -------------------------------------------------------------- records

/** One logged set, as `workout_sets` stores it. */
export interface LoggedSetLike {
  readonly weightGrams: number;
  readonly reps: number;
  readonly done: boolean;
}

/** Weight × reps; zero for anything not actually done. */
export function setVolumeGrams(set: LoggedSetLike): number {
  return set.done ? set.weightGrams * set.reps : 0;
}

/**
 * Estimated one-rep max by **Epley**, `w × (1 + reps ÷ 30)` — labelled
 * as an estimate wherever it appears (Y6). A single estimates to itself.
 */
export function estimatedOneRepMax(weightGrams: number, reps: number): number | null {
  if (weightGrams <= 0 || reps <= 0) return null;
  if (reps === 1) return weightGrams;
  return Math.round(weightGrams * (1 + reps / 30));
}

/** The three records worth keeping, per exercise. */
export interface ExerciseRecords<T extends LoggedSetLike = LoggedSetLike> {
  /** The most weight moved for at least one rep. */
  readonly heaviest: T | null;
  /** The highest estimated 1RM from any single set. */
  readonly bestSet: T | null;
  readonly bestSetEstimate: number | null;
  /** The most weight × reps in one session. */
  readonly bestSessionVolumeGrams: number;
}

export const noRecords: ExerciseRecords = Object.freeze({
  heaviest: null,
  bestSet: null,
  bestSetEstimate: null,
  bestSessionVolumeGrams: 0,
});

/**
 * The records, worked out from the log (`recordsFrom`) — derived, never
 * the only copy, so deleting a bad set corrects them (Y5).
 * [sessionVolumes] is each session's volume for this exercise.
 */
export function recordsFrom<T extends LoggedSetLike>(sets: Iterable<T>, sessionVolumes: Iterable<number> = []): ExerciseRecords<T> {
  let heaviest: T | null = null;
  let bestSet: T | null = null;
  let bestEstimate: number | null = null;
  for (const set of sets) {
    if (!set.done || set.reps <= 0 || set.weightGrams <= 0) continue;
    if (heaviest === null || set.weightGrams > heaviest.weightGrams) heaviest = set;
    const estimate = estimatedOneRepMax(set.weightGrams, set.reps);
    if (estimate !== null && (bestEstimate === null || estimate > bestEstimate)) {
      bestEstimate = estimate;
      bestSet = set;
    }
  }
  let bestVolume = 0;
  let any = false;
  for (const volume of sessionVolumes) {
    bestVolume = any ? Math.max(bestVolume, volume) : volume;
    any = true;
  }
  return { heaviest, bestSet, bestSetEstimate: bestEstimate, bestSessionVolumeGrams: bestVolume };
}

export type RecordKind = 'heaviest' | 'estimated';

/**
 * Which records [set] beats, against the records as they stood *before*
 * it, so a set cannot beat itself (`recordsBeatenBy`).
 */
export function recordsBeatenBy(set: LoggedSetLike, records: ExerciseRecords): RecordKind[] {
  if (!set.done || set.reps <= 0 || set.weightGrams <= 0) return [];
  const beaten: RecordKind[] = [];
  if (records.heaviest === null || set.weightGrams > records.heaviest.weightGrams) beaten.push('heaviest');
  const estimate = estimatedOneRepMax(set.weightGrams, set.reps);
  if (estimate !== null && (records.bestSetEstimate === null || estimate > records.bestSetEstimate)) beaten.push('estimated');
  return beaten;
}

// --------------------------------------------------------------- plates

export interface PlateStack {
  readonly grams: number;
  readonly perSide: number;
}

export interface PlatePlan {
  readonly stacks: readonly PlateStack[];
  readonly barGrams: number;
  /** What the plan really weighs; the target unless the gym cannot make it. */
  readonly totalGrams: number;
  /** Grams short of the target — non-zero when the plates run out. */
  readonly shortfallGrams: number;
  /** Grams the empty bar is over a target lighter than it — never hidden. */
  readonly overGrams: number;
}

/**
 * What goes on each side of the bar (`platesFor`): greedy, heaviest
 * first. Never loads more than asked, and never pretends a target below
 * the bar is achievable — it says how much the bar alone is over.
 * Pounds count in whole quarter pounds, so a 45 lb plate fits the
 * 45 lb it was asked for however the grams fell.
 */
export function platesFor(
  targetGrams: number,
  barGrams = defaultBarGrams,
  unit: LoadUnit = 'kg',
  plates: readonly number[] = platesIn(unit),
): PlatePlan {
  const pounds = unit === 'lb';
  const step = pounds ? quarterPounds : (grams: number) => grams;
  const perSideTarget = (step(targetGrams) - step(barGrams)) / 2;
  if (perSideTarget <= 0) {
    return { stacks: [], barGrams, totalGrams: barGrams, shortfallGrams: 0, overGrams: perSideTarget < 0 ? barGrams - targetGrams : 0 };
  }
  let remaining = perSideTarget;
  const stacks: PlateStack[] = [];
  let loadedPerSide = 0;
  for (const plate of plates) {
    const count = Math.trunc(remaining / step(plate));
    if (count <= 0) continue;
    stacks.push({ grams: plate, perSide: count });
    remaining -= count * step(plate);
    loadedPerSide += count * step(plate);
  }
  if (remaining === 0) return { stacks, barGrams, totalGrams: targetGrams, shortfallGrams: 0, overGrams: 0 };
  const total = barGrams + (pounds ? gramsOfPounds(loadedPerSide / 2) : loadedPerSide * 2);
  return { stacks, barGrams, totalGrams: total, shortfallGrams: targetGrams - total, overGrams: 0 };
}

// ------------------------------------------------------------ exercises

/** An exercise, from the catalogue or one of mine. */
export interface ExerciseLike {
  readonly id: string;
  readonly name: string;
  readonly bodyPart?: string | null;
  readonly equipment?: string | null;
  readonly target?: string | null;
  readonly secondary?: readonly string[];
  readonly mine?: boolean;
}

/**
 * Whether there is a bar to load, and so a bar weight and plates (Y9).
 * Mine say so in their equipment or their name.
 */
export function usesBar(exercise: ExerciseLike): boolean {
  const gear = (exercise.equipment ?? '').toLowerCase();
  if (barEquipment.has(gear)) return true;
  const words = `${gear} ${exercise.name.toLowerCase()}`;
  return words.includes('barbell') || words.includes('smith machine');
}

/** Everything a search looks at, lowercased once. */
export function exerciseHaystack(exercise: ExerciseLike): string {
  return [exercise.name, exercise.bodyPart, exercise.equipment, exercise.target, ...(exercise.secondary ?? [])]
    .filter((part): part is string => typeof part === 'string')
    .join(' ')
    .toLowerCase();
}

export interface ExerciseFilter {
  readonly search: string;
  readonly bodyPart?: string | null;
  readonly equipment?: string | null;
}

/** Dart's `String.compareTo`: code units, not the locale. */
function compareText(a: string, b: string): number {
  return a < b ? -1 : a > b ? 1 : 0;
}

/**
 * The exercises matching a filter (`filterExercises`): every word must
 * match somewhere; mine first, then names that start with the search,
 * then the rest by name.
 */
export function filterExercises<T extends ExerciseLike>(all: readonly T[], filter: ExerciseFilter): T[] {
  const words = filter.search
    .toLowerCase()
    .split(/\s+/)
    .filter((word) => word.length > 0);
  const matched = all.filter((exercise) => {
    if (filter.bodyPart && exercise.bodyPart !== filter.bodyPart) return false;
    if (filter.equipment && exercise.equipment !== filter.equipment) return false;
    if (words.length === 0) return true;
    const haystack = exerciseHaystack(exercise);
    return words.every((word) => haystack.includes(word));
  });
  const needle = filter.search.trim().toLowerCase();
  return matched.sort((a, b) => {
    const aMine = a.mine === true;
    const bMine = b.mine === true;
    if (aMine !== bMine) return aMine ? -1 : 1;
    if (needle.length > 0) {
      const aStarts = a.name.toLowerCase().startsWith(needle);
      const bStarts = b.name.toLowerCase().startsWith(needle);
      if (aStarts !== bStarts) return aStarts ? -1 : 1;
    }
    return compareText(a.name.toLowerCase(), b.name.toLowerCase());
  });
}

// ------------------------------------------------------------- programs

/**
 * The day after the last one finished, wrapping at the end (Y11,
 * `SessionsRepository.nextDay`). A program with nothing finished — or
 * whose last day was since deleted — starts at the top.
 */
export function nextProgramDay<T extends { readonly uuid: string; readonly position: number }>(
  days: readonly T[],
  lastFinishedDayUuid: string | null,
): T | null {
  if (days.length === 0) return null;
  const sorted = [...days].sort((a, b) => a.position - b.position);
  const index = sorted.findIndex((day) => day.uuid === lastFinishedDayUuid);
  if (index < 0) return sorted[0]!;
  return sorted[(index + 1) % sorted.length]!;
}

/**
 * Where a new row goes: after the highest live position, not at the
 * count. Counting repeats a position once a row has been dropped from
 * the middle — sets 0, 1, 2, drop 1, add, and two rows would claim 2
 * (`nextPosition`).
 */
export function nextPosition(rows: Iterable<{ readonly position: number }>): number {
  let next = 0;
  for (const row of rows) next = Math.max(next, row.position + 1);
  return next;
}

/** The order after moving the item at [from] to [to] (`reorderedUuids`). */
export function reorderedUuids(uuids: readonly string[], from: number, to: number): string[] {
  const next = [...uuids];
  const [moved] = next.splice(from, 1);
  next.splice(to, 0, moved!);
  return next;
}

// ------------------------------------------------------------- sessions

export interface SessionClockLike {
  readonly startedAt: string | Date;
  readonly endedAt: string | Date | null;
  readonly pausedAt: string | Date | null;
  /** The pauses that have already ended, added up. */
  readonly pausedSeconds: number;
}

function ms(value: string | Date): number {
  return typeof value === 'string' ? Date.parse(value) : value.getTime();
}

/**
 * Whole seconds on the clock (`WorkoutSession.elapsedAt`): from the
 * start to now, the end or the pause, less every pause that finished.
 */
export function sessionElapsedSeconds(session: SessionClockLike, now: string | Date): number {
  const until = session.endedAt ?? session.pausedAt ?? now;
  const net = ms(until) - ms(session.startedAt) - session.pausedSeconds * 1000;
  return net <= 0 ? 0 : Math.floor(net / 1000);
}

/**
 * What Finish has to ask about (Y10): sets on exercises I skipped were
 * never going to happen; the unticked rest are [left] of [planned].
 */
export function finishQuestion(exercises: readonly { readonly skipped: boolean; readonly sets: readonly { readonly done: boolean }[] }[]): {
  kind: 'empty' | 'incomplete' | 'none';
  done: number;
  left: number;
  planned: number;
} {
  let done = 0;
  let planned = 0;
  for (const exercise of exercises) {
    done += exercise.sets.filter((set) => set.done).length;
    if (!exercise.skipped) planned += exercise.sets.length;
  }
  const left = planned - done;
  const kind = done === 0 ? 'empty' : left > 0 ? 'incomplete' : 'none';
  return { kind, done, left, planned };
}
