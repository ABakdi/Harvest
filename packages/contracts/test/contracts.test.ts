import { describe, expect, it } from 'vitest';
import {
  checkRecord,
  emailSchema,
  errorBodySchema,
  errorStatus,
  instantMicros,
  isCommonPassword,
  isPortableSetting,
  loginBodySchema,
  passwordSchema,
  pullQuerySchema,
  pushBodySchema,
  registerBodySchema,
  sameInstant,
  syncedTables,
  tables,
} from '../src/index.js';

describe('errors', () => {
  it('maps every code to the status the Sync API names', () => {
    expect(errorStatus).toMatchObject({
      validation_failed: 400,
      unauthorized: 401,
      forbidden: 403,
      not_found: 404,
      conflict: 409,
      payload_too_large: 413,
      rate_limited: 429,
      internal: 500,
    });
  });

  it('parses the envelope', () => {
    expect(
      errorBodySchema.safeParse({ error: { code: 'conflict', message: 'Taken' } }).success,
    ).toBe(true);
    expect(errorBodySchema.safeParse({ error: { code: 'teapot', message: '' } }).success).toBe(false);
  });
});

describe('email', () => {
  it('normalises case and spaces', () => {
    expect(emailSchema.parse('  Me@Example.COM ')).toBe('me@example.com');
  });

  it('refuses what is not an address', () => {
    expect(emailSchema.safeParse('me@').success).toBe(false);
    expect(emailSchema.safeParse('not an email').success).toBe(false);
    expect(emailSchema.safeParse(`${'a'.repeat(250)}@b.co`).success).toBe(false);
  });
});

describe('password policy', () => {
  it('asks for ten characters and nothing else', () => {
    expect(passwordSchema.safeParse('short9char').success).toBe(true);
    expect(passwordSchema.safeParse('ninechars').success).toBe(false);
    expect(passwordSchema.safeParse('all lowercase words here').success).toBe(true);
  });

  it('refuses the common ones, whatever their case', () => {
    expect(isCommonPassword('password')).toBe(true);
    expect(isCommonPassword('1234567890')).toBe(true);
    expect(isCommonPassword('QWERTYUIOP')).toBe(true);
    expect(passwordSchema.safeParse('1234567890').success).toBe(false);
    expect(passwordSchema.safeParse('Qwertyuiop').success).toBe(false);
    expect(isCommonPassword('harvest at three in the morning')).toBe(false);
  });

  it('does not apply the policy to sign-in', () => {
    expect(loginBodySchema.safeParse({ email: 'me@example.com', password: 'old' }).success).toBe(true);
  });

  it('defaults the client to the web', () => {
    const body = registerBodySchema.parse({ email: 'me@example.com', password: 'a fine long password' });
    expect(body.client).toBe('web');
  });
});

describe('settings allow-list', () => {
  it('lets preferences through and keeps bookkeeping home', () => {
    expect(isPortableSetting('themeMode')).toBe(true);
    expect(isPortableSetting('features.places')).toBe(true);
    expect(isPortableSetting('reminders.morningTime')).toBe(true);
    expect(isPortableSetting('reminders.scheduledIds')).toBe(false);
    expect(isPortableSetting('streak.lastReconciledDay')).toBe(false);
    expect(isPortableSetting('pomodoro.active')).toBe(false);
    expect(isPortableSetting('security.lockEnabled')).toBe(false);
  });
});

describe('instants', () => {
  it('compares to the microsecond, whatever the spelling', () => {
    expect(instantMicros('2026-09-19T14:32:05.120Z')).toBe(instantMicros('2026-09-19T14:32:05.12Z'));
    expect(instantMicros('2026-09-19T14:32:05.120001Z')).toBeGreaterThan(
      instantMicros('2026-09-19T14:32:05.120Z'),
    );
    expect(instantMicros('2026-09-19T14:32:05Z')).toBe(Date.UTC(2026, 8, 19, 14, 32, 5) * 1000);
    expect(sameInstant(null, null)).toBe(true);
    expect(sameInstant('2026-09-19T14:32:05Z', null)).toBe(false);
  });
});

describe('the registry', () => {
  it('knows 35 tables, and not the outbox or quests', () => {
    expect(syncedTables).toHaveLength(35);
    expect(syncedTables).toContain('wishlist_items');
    expect(syncedTables).not.toContain('outbox');
    expect(syncedTables).not.toContain('quests');
  });

  it('puts finance and location on the private tier, and nothing else', () => {
    expect(syncedTables.filter((t) => tables[t].tier === 'private').sort()).toEqual(
      [
        'debt_payments',
        'debts',
        'expense_categories',
        'expenses',
        'geotags',
        'location_points',
        'money_txns',
        'saved_places',
      ].sort(),
    );
  });
});

describe('columns added after a release', () => {
  const place = {
    uuid: '6a2d9f5c-1b8e-4d4a-a7c3-5f9e2b6d8a14',
    name: 'Home',
    latitude: 36.7538,
    longitude: 3.0588,
    radiusM: 100,
    createdAt: '2026-09-10T20:00:00.000Z',
    updatedAt: '2026-09-10T20:00:00.000Z',
    deletedAt: null,
  };

  it('reads a place sealed before notes existed as having none', () => {
    const parsed = tables.saved_places.data.safeParse(place);
    expect(parsed.success).toBe(true);
    if (parsed.success) expect(parsed.data.notes).toBeNull();
  });

  it('still keeps notes that are there, and still refuses the wrong type', () => {
    expect(tables.saved_places.data.parse({ ...place, notes: 'By the olive tree' }).notes).toBe('By the olive tree');
    expect(tables.saved_places.data.safeParse({ ...place, notes: 4 }).success).toBe(false);
  });

  it('reads a category sealed before createdAt existed as having none', () => {
    const category = {
      uuid: '3b7e9a2d-4c1f-4b8e-a6d9-1c4f7b3e9d58',
      name: 'Books',
      icon: 'book',
      deletedAt: null,
      updatedAt: '2026-09-02T10:00:00.000Z',
    };
    expect(tables.expense_categories.data.parse(category).createdAt).toBeNull();
    const made = '2026-08-28T18:30:00.000Z';
    expect(tables.expense_categories.data.parse({ ...category, createdAt: made }).createdAt).toBe(made);
    expect(tables.expense_categories.data.safeParse({ ...category, createdAt: 'yesterday' }).success).toBe(false);
  });
});

describe('checkRecord', () => {
  const base = {
    table: 'kv_settings',
    uuid: 'locale',
    updatedAt: '2026-09-19T10:00:00.000Z',
    deletedAt: null,
  };

  it('accepts a purged tombstone with neither data nor enc', () => {
    expect(checkRecord({ ...base, purged: true }).ok).toBe(true);
    expect(checkRecord({ ...base, table: 'expenses', purged: true }).ok).toBe(true);
  });

  it('still keeps a purged device setting home', () => {
    expect(checkRecord({ ...base, uuid: 'lock.armed', purged: true }).ok).toBe(false);
  });

  it('reports where a record went wrong', () => {
    const checked = checkRecord({ ...base, data: { key: 'locale', valueJson: 'not json', updatedAt: base.updatedAt } });
    expect(checked.ok).toBe(false);
    if (!checked.ok) expect(checked.issues[0]?.path).toEqual(['data', 'valueJson']);
  });

  it('accepts the same instant spelled differently', () => {
    const checked = checkRecord({
      ...base,
      updatedAt: '2026-09-19T10:00:00Z',
      data: { key: 'locale', valueJson: '"ar"', updatedAt: '2026-09-19T10:00:00.000Z' },
    });
    expect(checked.ok).toBe(true);
  });
});

describe('push and pull bodies', () => {
  it('caps a push at 500 records', () => {
    const record = { table: 'notes', uuid: 'x' };
    expect(pushBodySchema.safeParse({ deviceId: 'd', records: Array(500).fill(record) }).success).toBe(true);
    expect(pushBodySchema.safeParse({ deviceId: 'd', records: Array(501).fill(record) }).success).toBe(false);
  });

  it('reads the pull query from strings, with defaults', () => {
    expect(pullQuerySchema.parse({})).toEqual({ after: 0, limit: 500 });
    expect(pullQuerySchema.parse({ after: '12', limit: '1000' })).toEqual({ after: 12, limit: 1000 });
    expect(pullQuerySchema.safeParse({ limit: '0' }).success).toBe(false);
    expect(pullQuerySchema.safeParse({ limit: '1001' }).success).toBe(false);
    expect(pullQuerySchema.safeParse({ after: '-1' }).success).toBe(false);
  });
});
