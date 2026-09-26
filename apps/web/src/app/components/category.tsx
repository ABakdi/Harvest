import type { TFunction } from 'i18next';
import { presetCategories } from '../data/money';

/** A preset category in the reader's language; a custom one by its own name. */
export function categoryLabel(t: TFunction, key: string): string {
  return (presetCategories as readonly string[]).includes(key) ? t(`money.cat.${key}`) : key;
}
