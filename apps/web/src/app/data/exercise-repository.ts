import type { Exercise } from './exercises';
import type { Row } from './db';
import type { Writer } from './writer';

/*
 * The writing side of the exercises, apart from the catalogue's names
 * so the store can hold it without the gym's name list in the first
 * bundle (P6-10).
 */

export function mineToExercise(row: Row<'exercises'>): Exercise {
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
