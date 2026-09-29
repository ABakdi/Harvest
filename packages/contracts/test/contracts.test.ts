import { describe, expect, it } from 'vitest';
import {
  nameIsPassword,
  checkRecord,
  retiredTables,
  checkRow,
  emailSchema,
  errorBodySchema,
  errorStatus,
  instantMicros,
  isCommonPassword,
  isLegacySetting,
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

  it('refuses a common one dressed up with digits, symbols or leetspeak (W6-40)', () => {
    for (const weak of ['password12', 'Password123!', 'p@ssw0rd', 'P@ssw0rd2024', 'dragon1234', 'Qwerty123!!', 'l3tm31n99']) {
      expect(isCommonPassword(weak), weak).toBe(true);
      expect(passwordSchema.safeParse(weak.padEnd(10, '1')).success, weak).toBe(false);
    }
    for (const strong of ['correct horse battery', 'Tamarind-orchard-7', 'harvest at three in the morning', 'zq8#Lm2!pV']) {
      expect(isCommonPassword(strong), strong).toBe(false);
      expect(passwordSchema.safeParse(strong).success, strong).toBe(true);
    }
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

  it('still takes what a 3.0.0 phone pushes, without it being portable', () => {
    for (const key of ['assist.provider', 'assist.baseUrl', 'assist.model', 'places.styleUrl']) {
      expect(isPortableSetting(key)).toBe(false);
      expect(isLegacySetting(key)).toBe(true);
      const record = {
        table: 'kv_settings',
        uuid: key,
        updatedAt: '2026-09-19T10:00:00Z',
        deletedAt: null,
        enc: { v: 2, iv: 'AAAAAAAAAAAAAAAA', ct: 'c2VhbGVk' },
      };
      expect(checkRecord(record).ok).toBe(true);
    }
    expect(isLegacySetting('places.mapBase')).toBe(false);
    expect(isLegacySetting('security.lockEnabled')).toBe(false);
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
  it('knows 37 tables, and not the outbox or quests', () => {
    expect(syncedTables).toHaveLength(37);
    expect(syncedTables).toContain('trail_days');
    expect(syncedTables).toContain('lists');
    expect(syncedTables).toContain('wishlist_items');
    expect(syncedTables).not.toContain('outbox');
    expect(syncedTables).not.toContain('quests');
  });

  it('puts every table on the private tier (Phase 7)', () => {
    expect(syncedTables.filter((t) => tables[t].tier !== 'private')).toEqual([]);
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

  it('reads a goal item synced before subtasks existed as top-level', () => {
    const item = {
      uuid: 'a8c3f6e1-7d4b-4a9c-b2e5-9d6a3c8f1e45',
      goalUuid: '4e9b2d7f-1a5c-4d3e-8b6a-2f9d5e1c7b38',
      kind: 'step',
      body: 'Register for the 10 km',
      note: null,
      doneAt: null,
      position: 0,
      commitmentUuid: null,
      createdAt: '2026-09-01T07:03:00.000Z',
      updatedAt: '2026-09-01T07:03:00.000Z',
      deletedAt: null,
    };
    expect(tables.goal_items.data.parse(item).parentUuid).toBeNull();
    const parent = '5f1c3a8e-2b7d-4e9a-9c6b-3d8e1f4a7b20';
    expect(tables.goal_items.data.parse({ ...item, parentUuid: parent }).parentUuid).toBe(parent);
    expect(tables.goal_items.data.safeParse({ ...item, parentUuid: 7 }).success).toBe(false);
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

  const enc = { v: 2, iv: 'AAAAAAAAAAAAAAAA', ct: 'c2VhbGVk' };
  const note = { ...base, table: 'notes', uuid: 'n1' };
  const name = 'a'.repeat(64);

  it('refuses a row in the clear as sealed_required, whatever its table', () => {
    for (const table of ['notes', 'kv_settings', 'expenses', 'step_days']) {
      const checked = checkRecord({ ...base, table, uuid: 'locale', data: { anything: true } });
      expect(checked.ok).toBe(false);
      if (!checked.ok) expect(checked.issues).toContainEqual(expect.objectContaining({ path: ['data'], code: 'sealed_required' }));
    }
  });

  it('takes a sealed row, and the name of the file it names in the clear', () => {
    expect(checkRecord({ ...note, enc }).ok).toBe(true);
    expect(checkRecord({ ...note, table: 'memories', enc, file: name }).ok).toBe(true);
    expect(checkRecord({ ...note, table: 'note_attachments', enc, file: name }).ok).toBe(true);
  });

  it('refuses a file name on a table that names none, or on a tombstone', () => {
    expect(checkRecord({ ...note, enc, file: name }).ok).toBe(false);
    expect(checkRecord({ ...note, table: 'memories', purged: true, file: name }).ok).toBe(false);
  });
});

describe('retired tables (M7.3)', () => {
  const enc = { v: 2, iv: 'AAAAAAAAAAAAAAAA', ct: 'c2VhbGVk' };
  const point = { table: 'location_points', uuid: 'p1', updatedAt: '2026-09-19T10:00:00.000Z', deletedAt: null };

  it('refuses a trail point, sealed or not, and still takes its tombstone', () => {
    expect(retiredTables).toEqual(['location_points']);
    const checked = checkRecord({ ...point, enc });
    expect(checked.ok).toBe(false);
    if (!checked.ok) expect(checked.issues[0]?.code).toBe('retired_table');
    expect(checkRecord({ ...point, purged: true }).ok).toBe(true);
  });

  it('still opens one 3.1 sealed, so its points can move into their day', () => {
    expect(tables.location_points.tier).toBe('private');
  });
});

describe('checkRow', () => {
  const record = { table: 'kv_settings' as const, uuid: 'locale', updatedAt: '2026-09-19T10:00:00.000Z', deletedAt: null };

  it('reports where an opened row went wrong', () => {
    const checked = checkRow(record, { key: 'locale', valueJson: 'not json', updatedAt: record.updatedAt });
    expect(checked.ok).toBe(false);
    if (!checked.ok) expect(checked.issues[0]?.path).toEqual(['data', 'valueJson']);
  });

  it('accepts the same instant spelled differently', () => {
    const checked = checkRow(
      { ...record, updatedAt: '2026-09-19T10:00:00Z' },
      { key: 'locale', valueJson: '"ar"', updatedAt: '2026-09-19T10:00:00.000Z' },
    );
    expect(checked.ok).toBe(true);
  });

  it('refuses a path out of the device’s storage', () => {
    const memory = {
      uuid: 'm1',
      albumUuid: 'a1',
      harvestDay: '2026-09-19',
      path: '../../etc/passwd',
      kind: 'photo',
      note: null,
      fileHash: null,
      capturedAt: '2026-09-19T10:00:00.000Z',
      updatedAt: '2026-09-19T10:00:00.000Z',
      deletedAt: null,
    };
    const checked = checkRow({ ...record, table: 'memories', uuid: 'm1' }, memory);
    expect(checked.ok).toBe(false);
    if (!checked.ok) expect(checked.issues[0]?.path).toEqual(['data', 'path']);
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

describe('a display name that is the password', () => {
  const body = { email: 'maya@example.com', password: 'Tamarind-orchard-7', client: 'mobile' as const };

  it('is refused at sign-up, as a password manager filling it would', () => {
    const parsed = registerBodySchema.safeParse({ ...body, displayName: ' Tamarind-orchard-7 ' });
    expect(parsed.success).toBe(false);
    expect(parsed.error?.issues[0]?.path).toEqual(['displayName']);
    expect(parsed.error?.issues[0]?.message).toBe('not_the_password');
  });

  it('lets any other name, or none, through', () => {
    expect(registerBodySchema.safeParse({ ...body, displayName: 'Maya' }).success).toBe(true);
    expect(registerBodySchema.safeParse(body).success).toBe(true);
    expect(nameIsPassword(undefined, 'x')).toBe(false);
  });
});
