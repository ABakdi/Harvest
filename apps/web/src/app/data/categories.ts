import type { HarvestDB, Row } from './db';
import { presetCategories } from './money';
import type { Writer } from './writer';

export type CategoryRow = Row<'expense_categories'>;

/**
 * The icons a custom category can pick from, by the keys the phone
 * stores (`categoryIconRegistry` in `expense_sheet.dart`).
 */
export const categoryIconKeys = [
  'restaurant',
  'bus',
  'receipt',
  'bag',
  'heart',
  'movie',
  'category',
  'coffee',
  'home',
  'car',
  'gift',
  'pets',
  'school',
  'fitness',
  'phone',
  'games',
  'travel',
  'baby',
  'tools',
  'music',
] as const;

/** When a category was made; a row from before `createdAt` falls back to its last edit. */
const madeAt = (row: CategoryRow) => row.createdAt ?? row.updatedAt;

/**
 * The live custom categories, oldest first, the order the phone lists
 * them in — by when each was made, so a restore (which bumps
 * `updatedAt` for sync) keeps its place.
 */
export async function readCategories(db: HarvestDB): Promise<CategoryRow[]> {
  return (await db.rows('expense_categories').toArray())
    .filter((row) => row.deletedAt === null)
    .sort((a, b) => madeAt(a).localeCompare(madeAt(b)));
}

/** Why a name cannot be a new category: empty, or already one. */
export function categoryNameProblem(name: string, existing: readonly CategoryRow[]): 'empty' | 'taken' | null {
  const trimmed = name.trim();
  if (!trimmed) return 'empty';
  const lower = trimmed.toLowerCase();
  if ((presetCategories as readonly string[]).includes(lower)) return 'taken';
  return existing.some((row) => row.name.toLowerCase() === lower) ? 'taken' : null;
}

/**
 * Custom expense categories, as `FinancesRepository` keeps them: a name
 * that doubles as the key stored on expenses, and an icon key. The
 * phone creates and deletes them and never renames one — a rename would
 * leave every expense filed under the old name — so neither does this.
 */
export class CategoriesRepository {
  constructor(private readonly writer: Writer) {}

  create(name: string, icon: string): Promise<string> {
    return this.writer.run(async (tx) => {
      const uuid = crypto.randomUUID();
      await tx.put('expense_categories', {
        uuid,
        name: name.trim(),
        icon,
        createdAt: tx.now(),
        deletedAt: null,
        updatedAt: tx.now(),
      });
      return uuid;
    });
  }

  /** A soft delete; expenses already filed under it keep the name. */
  remove(uuid: string): Promise<void> {
    return this.writer.run(async (tx) => {
      await tx.patch('expense_categories', uuid, { deletedAt: tx.now(), updatedAt: tx.now() });
    });
  }

  /** The Undo after [remove]. */
  restore(uuid: string): Promise<void> {
    return this.writer.run(async (tx) => {
      await tx.patch('expense_categories', uuid, { deletedAt: null, updatedAt: tx.now() });
    });
  }
}
