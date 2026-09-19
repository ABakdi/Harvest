import type { HarvestDB } from './db';
import type { Tx, Writer } from './writer';

/**
 * `kv_settings`, as the phone's SettingsRepository keeps it: every value
 * is JSON, and a string value is stored as a JSON string. Reads are as
 * tolerant as the phone's: a number or a bool written by an older
 * version still comes back as its text.
 */
export const settingKeys = {
  dailyHarvestGoal: 'dailyHarvestGoal',
  defaultCurrency: 'finance.defaultCurrency',
  monthlyBudget: 'finance.monthlyBudgetMinor',
  noteFolders: 'notes.folders',
} as const;

export function settingText(valueJson: string | undefined | null): string | null {
  if (valueJson === undefined || valueJson === null) return null;
  try {
    const value: unknown = JSON.parse(valueJson);
    if (value === null || value === undefined) return null;
    if (typeof value === 'string') return value;
    return typeof value === 'number' || typeof value === 'boolean' ? String(value) : JSON.stringify(value);
  } catch {
    return valueJson;
  }
}

export async function readSetting(db: HarvestDB, key: string): Promise<string | null> {
  return settingText((await db.rows('kv_settings').get(key))?.valueJson);
}

export async function writeSetting(tx: Tx, key: string, value: string): Promise<void> {
  await tx.put('kv_settings', { key, valueJson: JSON.stringify(value), updatedAt: tx.now() });
}

export class SettingsRepository {
  constructor(private readonly writer: Writer) {}

  setString(key: string, value: string): Promise<void> {
    return this.writer.run((tx) => writeSetting(tx, key, value));
  }
}
