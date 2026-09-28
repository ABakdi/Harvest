import { describe, expect, it } from 'vitest';
import { isSafeRelativePath } from '../src/paths.js';
import { checkRecord } from '../src/sync.js';

const memory = (path: string) => ({
  table: 'memories',
  uuid: 'm1',
  updatedAt: '2026-09-20T10:00:00.000Z',
  deletedAt: '2026-09-20T10:00:00.000Z',
  data: {
    uuid: 'm1',
    albumUuid: 'a1',
    harvestDay: '2026-09-20',
    path,
    kind: 'photo',
    note: null,
    fileHash: null,
    capturedAt: '2026-09-20T10:00:00.000Z',
    updatedAt: '2026-09-20T10:00:00.000Z',
    deletedAt: '2026-09-20T10:00:00.000Z',
  },
});

describe('paths into a device’s storage (S6-08)', () => {
  it.each(['a.jpg', 'album/2026-09-20-1.jpg', 'attachments/memo.m4a'])('takes %s', (path) => {
    expect(isSafeRelativePath(path)).toBe(true);
  });

  it.each(['', '/data/data/app/databases/harvest.sqlite', '../x.jpg', 'a/../../x', 'a//b', 'a/./b', 'C:\\x', 'a\\b', 'x/'])(
    'refuses %j',
    (path) => {
      expect(isSafeRelativePath(path)).toBe(false);
    },
  );

  it('a memory naming a path outside the storage is refused on push', () => {
    const refused = checkRecord(memory('/data/data/app/databases/harvest.sqlite'));
    expect(refused.ok).toBe(false);
    const taken = checkRecord(memory('album/one.jpg'));
    expect(taken.ok, JSON.stringify(taken)).toBe(true);
  });
});
