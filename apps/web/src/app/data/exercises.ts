import type { ExerciseLike } from '@harvest/core';
import { useLiveQuery } from 'dexie-react-hooks';
import { useEffect, useMemo, useState } from 'react';
import catalogue from './exercise-names.json';
import type { HarvestDB, Row } from './db';
import type { Writer } from './writer';

/**
 * The catalogue's names, id to name.
 *
 * The catalogue itself is reference data: borrowed, read-only, bundled,
 * and it never syncs ([[Business-Rules]] #14) — so a log that refers to
 * `0025` has no name to show until the reader has its own copy. This is
 * that copy, trimmed to the one field a reader needs, generated from
 * `apps/mobile/assets/exercises/exercises.json`. Regenerate it when the
 * catalogue moves.
 */
const names = catalogue as Record<string, string>;

/** How many exercises the catalogue has, known without loading it. */
export const catalogueSize = Object.keys(names).length;

export function catalogueName(id: string): string | null {
  const name = names[id];
  return name === undefined ? null : titleCase(name);
}

const smallWords = new Set(['a', 'an', 'and', 'at', 'by', 'for', 'in', 'of', 'on', 'or', 'the', 'to', 'with', 'vs', 'v.']);

/**
 * `barbell full squat (side pov)` → `Barbell Full Squat (Side POV)`, as
 * the phone shows the catalogue (`Exercise.displayName`): each word
 * raised after a space, a hyphen, a slash or a bracket, the small words
 * left small unless they lead. Display only: the catalogue keeps its
 * own spelling, and my own exercises keep mine.
 */
export function titleCase(text: string): string {
  return text
    .split(' ')
    .map((word, index) => (index > 0 && smallWords.has(word) ? word : raise(word)))
    .join(' ');
}

/**
 * The catalogue's initialisms, written as they are said: the JM press,
 * the EZ and SZ bars, a squat seen from the back POV. Only true
 * initialisms — `ab`, `up` and `on` are words, and single letters (the
 * V-bar, the T-bar row) are raised anyway.
 */
const initialisms = new Set(['ez', 'jm', 'pov', 'sz']);

function raise(word: string): string {
  // Each piece between a hyphen, a slash or a bracket starts a word of its own.
  return word.replace(/[^-/()]+/g, (piece) =>
    initialisms.has(piece.toLowerCase()) ? piece.toUpperCase() : piece.charAt(0).toUpperCase() + piece.slice(1),
  );
}

/**
 * Names for the exercises in a log: mine first, because an exercise I
 * wrote myself is a row that syncs, then the catalogue, then the id —
 * which at least says *something* did happen.
 */
export function useExerciseNames(db: HarvestDB): (id: string) => string {
  const mine = useLiveQuery(async () => {
    const rows = await db.rows('exercises').toArray();
    return new Map(rows.map((row) => [row.uuid, row.name]));
  }, [db]);
  return (id: string) => mine?.get(id) ?? catalogueName(id) ?? id;
}

// -------------------------------------------------------- the whole book

/** One exercise, whichever side it lives on (`Exercise`). */
export interface Exercise extends ExerciseLike {
  readonly bodyPart: string | null;
  readonly equipment: string | null;
  readonly target: string | null;
  readonly secondary: readonly string[];
  readonly steps: readonly string[];
  readonly mine: boolean;
}

export interface Catalogue {
  all: Exercise[];
  byId: Map<string, Exercise>;
  bodyParts: string[];
  equipment: string[];
}

interface RawExercise {
  id: string;
  name: string;
  bodyPart?: string | null;
  equipment?: string | null;
  target?: string | null;
  secondary?: string[];
  steps?: string[];
}

let loading: Promise<Catalogue> | null = null;

/**
 * The full catalogue — muscles, equipment, steps — for the picker and
 * the detail. It is the phone's own `exercises.json`, byte for byte,
 * loaded the first time something asks and kept: a program list and a
 * history only need names, and should not wait on 850 KB of steps.
 *
 * No media is fetched on the web: the animations are a third party's
 * files the phone fetches on open ([[ADR-008-Exercise-Catalogue]]),
 * and the web makes no request the product did not already make.
 */
export function loadCatalogue(): Promise<Catalogue> {
  loading ??= import('./exercise-catalogue.json?raw').then(({ default: raw }) => {
    const all = (JSON.parse(raw) as RawExercise[]).map(
      (entry): Exercise => ({
        id: entry.id,
        name: titleCase(entry.name),
        bodyPart: entry.bodyPart ?? null,
        equipment: entry.equipment ?? null,
        target: entry.target ?? null,
        secondary: entry.secondary ?? [],
        steps: entry.steps ?? [],
        mine: false,
      }),
    );
    const sortedSet = (values: (string | null)[]) => [...new Set(values.filter((v): v is string => v !== null))].sort();
    return {
      all,
      byId: new Map(all.map((exercise) => [exercise.id, exercise])),
      bodyParts: sortedSet(all.map((exercise) => exercise.bodyPart)),
      equipment: sortedSet(all.map((exercise) => exercise.equipment)),
    };
  });
  return loading;
}

export function useCatalogue(): Catalogue | undefined {
  const [book, setBook] = useState<Catalogue>();
  useEffect(() => {
    let live = true;
    void loadCatalogue().then((loaded) => live && setBook(loaded));
    return () => {
      live = false;
    };
  }, []);
  return book;
}

function mineToExercise(row: Row<'exercises'>): Exercise {
  return {
    id: row.uuid,
    name: row.name,
    bodyPart: row.bodyPart,
    equipment: row.equipment,
    target: row.target,
    secondary: [],
    steps: [],
    mine: true,
  };
}

/** Mine and the catalogue's as one list, mine first; undefined while loading. */
export function useAllExercises(db: HarvestDB): Exercise[] | undefined {
  const book = useCatalogue();
  const mine = useLiveQuery(async () => (await db.rows('exercises').toArray()).filter((row) => row.deletedAt === null), [db]);
  return useMemo(() => (book && mine ? [...mine.map(mineToExercise), ...book.all] : undefined), [book, mine]);
}

/**
 * One exercise by id, whichever side it lives on. Before the catalogue
 * has loaded, a catalogue id is at least its name.
 */
export function useExercise(db: HarvestDB, id: string | null): Exercise | null | undefined {
  const book = useCatalogue();
  const mine = useLiveQuery(async () => (id ? ((await db.rows('exercises').get(id)) ?? null) : null), [db, id]);
  if (id === null) return null;
  if (mine) return mineToExercise(mine);
  const known = book?.byId.get(id);
  if (known) return known;
  const name = catalogueName(id);
  if (name) {
    return { id, name, bodyPart: null, equipment: null, target: null, secondary: [], steps: [], mine: false };
  }
  return mine === undefined || !book ? undefined : null;
}

/**
 * The exercises I added myself: unlike the catalogue these are my data,
 * and they travel ([[Business-Rules]] #14).
 */
export class ExercisesRepository {
  constructor(private readonly writer: Writer) {}

  create(input: { name: string; bodyPart?: string | null; equipment?: string | null; target?: string | null }): Promise<Exercise> {
    return this.writer.run(async (tx) => {
      const now = tx.now();
      const row: Row<'exercises'> = {
        uuid: crypto.randomUUID(),
        name: input.name.trim(),
        bodyPart: input.bodyPart?.trim() || null,
        equipment: input.equipment?.trim() || null,
        target: input.target?.trim() || null,
        note: null,
        createdAt: now,
        updatedAt: now,
        deletedAt: null,
      };
      await tx.put('exercises', row);
      return mineToExercise(row);
    });
  }

  /** Soft: a log that names it still has its name. */
  remove(uuid: string): Promise<void> {
    return this.writer.run(async (tx) => {
      const now = tx.now();
      await tx.patch('exercises', uuid, { deletedAt: now, updatedAt: now });
    });
  }
}
