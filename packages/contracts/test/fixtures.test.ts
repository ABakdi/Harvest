import { readdirSync, readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';
import {
  checkRecord,
  plainTables,
  portableSettingPrefixes,
  privateTables,
  syncedTables,
  tables,
  type SyncedTable,
} from '../src/index.js';

/**
 * The contract fixtures. The Dart suite reads the same files and checks
 * that each plaintext record's `data` has exactly the columns of its
 * Drift table, so a column added on the phone and not here (or the other
 * way round) fails one of the two.
 */
const dir = (name: string) => new URL(`../fixtures/${name}/`, import.meta.url);
const read = (name: string, file: string): unknown => JSON.parse(readFileSync(new URL(file, dir(name)), 'utf8'));
const files = (name: string) => readdirSync(dir(name)).filter((file) => file.endsWith('.json')).sort();

describe('fixtures/records', () => {
  it('has one record for every synced table, and nothing else', () => {
    expect(files('records')).toEqual([...syncedTables].sort().map((table) => `${table}.json`));
  });

  it.each(files('records'))('%s is a valid record of its table', (file) => {
    const raw = read('records', file) as { table: string };
    expect(raw.table).toBe(file.replace(/\.json$/, ''));
    const checked = checkRecord(raw);
    expect(checked.ok ? [] : checked.issues).toEqual([]);
  });

  it.each(plainTables)('%s carries data, in the clear', (table) => {
    const raw = read('records', `${table}.json`) as Record<string, unknown>;
    expect(raw.data).toBeTypeOf('object');
    expect(raw.enc).toBeUndefined();
  });

  it.each(privateTables)('%s carries only an envelope', (table) => {
    const raw = read('records', `${table}.json`) as Record<string, unknown>;
    expect(raw.data).toBeUndefined();
    expect(raw.enc).toMatchObject({ v: 1 });
  });
});

describe('fixtures/private-data', () => {
  it('has the plaintext row of every private table', () => {
    expect(files('private-data')).toEqual([...privateTables].sort().map((table) => `${table}.json`));
  });

  it.each(files('private-data'))('%s parses as its table would after decrypting', (file) => {
    const table = file.replace(/\.json$/, '') as SyncedTable;
    const parsed = tables[table].data.safeParse(read('private-data', file));
    expect(parsed.success ? [] : parsed.error.issues).toEqual([]);
  });
});

describe('fixtures/invalid', () => {
  it.each(files('invalid'))('%s is refused', (file) => {
    const { why, path, record } = read('invalid', file) as { why: string; path: string; record: unknown };
    expect(why).toBeTruthy();
    const checked = checkRecord(record);
    expect(checked.ok).toBe(false);
    // Refused for the reason the fixture names, not for some other slip.
    if (!checked.ok) expect(checked.issues.map((issue) => issue.path.join('.'))).toContain(path);
  });
});

describe('fixtures/portable-settings.json', () => {
  it('is the allow-list the contract enforces', () => {
    const { prefixes } = JSON.parse(
      readFileSync(new URL('../fixtures/portable-settings.json', import.meta.url), 'utf8'),
    ) as { prefixes: string[] };
    expect(prefixes).toEqual([...portableSettingPrefixes]);
  });
});
