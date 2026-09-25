import { Blob as NodeBlob } from 'node:buffer';
import { readFileSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { strToU8, unzipSync, zipSync } from 'fflate';
import { describe, expect, it } from 'vitest';
import { ArchiveInvalid, ArchiveLimits, instantOf, isSafeRelative } from '@/app/data/archive';
import { buildWorkbook, ExportSheet, parseWorkbook, type CellValue } from '@/app/data/archive-xlsx';
import { primaryKeyOf, recordKeyOf } from '@/app/data/db';
import { buildArchive } from '@/app/data/export';
import { harvestSheets, SheetNames, sheetHeaders, sheetOrder, type ExportData } from '@/app/data/export-sheets';
import { sha256Of } from '@/app/data/files';
import { applyImport, openArchive, previewImport, totalOf } from '@/app/data/import';
import { syncedTables, type SyncedTable } from '@harvest/contracts';
import { FakeServer } from './fake-server';
import { device, testClock } from './helpers';

/**
 * Business Rules #11: my data is always exportable, and comes back. The
 * web writes the phone's archive ([[ADR-007-Archive-Format]]) and reads
 * it back under the phone's merge rules.
 */

type Device = Awaited<ReturnType<typeof device>>;

const fixtures = resolve(process.cwd(), '../../packages/contracts/fixtures/archive');

// jsdom's Blob does not survive IndexedDB's structured clone the way a
// browser's does; Node's does, so the files kept here read back.
globalThis.Blob = NodeBlob as unknown as typeof Blob;

const at = '2026-09-18T08:00:00.000Z';
const later = '2026-09-18T09:30:00.000Z';

function bytesOf(length: number, seed: number): Uint8Array<ArrayBuffer> {
  const bytes = new Uint8Array(length);
  for (let i = 0; i < length; i++) bytes[i] = (i * seed + 7) % 256;
  return bytes;
}

/** One row in nearly every table, the trash and the private tier included. */
async function seed(h: Device): Promise<void> {
  const picture = bytesOf(64, 13);
  const recording = bytesOf(40, 29);
  const pictureHash = await sha256Of(picture.slice().buffer);
  const recordingHash = await sha256Of(recording.slice().buffer);
  await h.db.files.bulkPut([
    { sha256: pictureHash, blob: new Blob([picture]), fetchedAt: at },
    { sha256: recordingHash, blob: new Blob([recording]), fetchedAt: at },
  ]);
  await h.writer.run(async (tx) => {
    await tx.put('commitments', {
      uuid: 'seed-1',
      type: 'habit',
      title: 'Read 20 pages',
      scheduleJson: '{"type":"daily"}',
      totalTarget: null,
      dailyCommitment: null,
      dueDay: null,
      pausedAt: null,
      note: 'Before bed',
      remindAt: '21:30',
      deadline: null,
      goalUuid: 'goal-1',
      archivedAt: null,
      archiveNote: null,
      deletedAt: null,
      createdAt: at,
      updatedAt: at,
    });
    await tx.put('check_ins', {
      uuid: 'check-1',
      commitmentUuid: 'seed-1',
      harvestDay: '2026-09-18',
      quantity: 1,
      loggedAt: at,
      deletedAt: null,
      updatedAt: at,
    });
    await tx.put('check_ins', {
      uuid: 'check-2',
      commitmentUuid: 'seed-1',
      harvestDay: '2026-09-17',
      quantity: 1,
      loggedAt: at,
      deletedAt: later,
      updatedAt: later,
    });
    await tx.put('seed_notes', {
      uuid: 'seednote-1',
      commitmentUuid: 'seed-1',
      harvestDay: '2026-09-18',
      body: 'Chapter four',
      loggedAt: at,
      deletedAt: null,
      updatedAt: at,
    });
    await tx.put('goals', {
      uuid: 'goal-1',
      title: 'Read more',
      why: 'Because',
      targetDay: '2026-12-31',
      status: 'active',
      statusNote: null,
      achievedAt: null,
      position: 0,
      createdAt: at,
      updatedAt: at,
      deletedAt: null,
    });
    await tx.put('goal_items', {
      uuid: 'item-1',
      goalUuid: 'goal-1',
      kind: 'step',
      body: 'Pick a book',
      note: null,
      doneAt: later,
      position: 0,
      commitmentUuid: null,
      createdAt: at,
      updatedAt: later,
      deletedAt: null,
    });
    await tx.put('wishlist_items', {
      uuid: 'wish-1',
      list: 'wish',
      title: 'Reading lamp',
      priceMinor: 350000,
      currency: 'DZD',
      note: null,
      targetDay: null,
      boughtAt: null,
      position: 0,
      createdAt: at,
      updatedAt: at,
      deletedAt: null,
    });
    await tx.put('expenses', {
      uuid: 'expense-1',
      amountMinor: 125050,
      currency: 'DZD',
      category: 'food',
      note: 'Groceries & bread <weekly>',
      harvestDay: '2026-09-18',
      loggedAt: at,
      deletedAt: null,
      updatedAt: at,
    });
    await tx.put('expenses', {
      uuid: 'expense-2',
      amountMinor: 900,
      currency: 'EUR',
      category: 'transport',
      note: null,
      harvestDay: '2026-08-02',
      loggedAt: at,
      deletedAt: later,
      updatedAt: later,
    });
    await tx.put('expense_categories', { uuid: 'cat-1', name: 'Books', icon: 'book', createdAt: at, deletedAt: null, updatedAt: at });
    await tx.put('money_txns', {
      uuid: 'money-1',
      account: 'wallet',
      deltaMinor: -125050,
      currency: 'DZD',
      note: null,
      kind: 'expense',
      reference: 'expense-1',
      linkUuid: null,
      harvestDay: '2026-09-18',
      loggedAt: at,
      deletedAt: null,
      updatedAt: at,
    });
    await tx.put('debts', {
      uuid: 'debt-1',
      person: 'Karim',
      amountMinor: 100000,
      currency: 'DZD',
      payOffBy: '2026-10-01',
      remindAt: null,
      note: null,
      settledAt: null,
      createdAt: at,
      deletedAt: null,
      updatedAt: at,
    });
    await tx.put('debt_payments', {
      uuid: 'pay-1',
      debtUuid: 'debt-1',
      amountMinor: 20000,
      harvestDay: '2026-09-18',
      loggedAt: at,
      deletedAt: null,
    });
    await tx.put('pomodoro_sessions', {
      uuid: 'focus-1',
      commitmentUuid: 'seed-1',
      focusBlocks: 2,
      harvestDay: '2026-09-18',
      startedAt: at,
      endedAt: later,
    });
    await tx.put('ledger', { uuid: 'xp-1', kind: 'xp', delta: 10, reason: 'check_in:check-1', harvestDay: '2026-09-18', loggedAt: at });
    await tx.put('streaks', { scope: 'global', current: 3, best: 7, lastEarnedDay: '2026-09-18', freezesStored: 1, updatedAt: at });
    await tx.put('kv_settings', { key: 'themeMode', valueJson: '"dark"', updatedAt: at });
    await tx.put('kv_settings', { key: 'finance.defaultCurrency', valueJson: '"DZD"', updatedAt: at });
    // The device's own bookkeeping: never in an archive.
    await tx.put('kv_settings', { key: 'streak.lastJudgedDay', valueJson: '"2026-09-18"', updatedAt: at });
    await tx.put('notes', {
      uuid: 'note-1',
      title: 'Sleep log: week 38?',
      folder: 'Health',
      body: 'Slept well.\n\n![[2026-09-18 0712.m4a]]\n',
      createdAt: at,
      updatedAt: at,
      deletedAt: null,
    });
    await tx.put('notes', {
      uuid: 'note-2',
      title: 'Old idea',
      folder: '',
      body: 'Gone now',
      createdAt: at,
      updatedAt: later,
      deletedAt: later,
    });
    await tx.put('note_attachments', {
      uuid: 'rec-1',
      noteUuid: 'note-1',
      kind: 'audio',
      fileName: '2026-09-18 0712.m4a',
      storedPath: 'note-1/2026-09-18 0712.m4a',
      durationMs: 4000,
      sizeBytes: recording.length,
      fileHash: recordingHash,
      createdAt: at,
      updatedAt: at,
      deletedAt: null,
    });
    await tx.put('albums', {
      uuid: 'album-1',
      name: 'Gym',
      scheduleJson: '{"type":"weekly","weekdays":[1,3,5]}',
      remindAt: '19:00',
      note: null,
      createdAt: at,
      updatedAt: at,
      deletedAt: null,
    });
    await tx.put('memories', {
      uuid: 'memory-1',
      albumUuid: 'album-1',
      harvestDay: '2026-09-18',
      path: 'album-1/2026-09-18-memory-1.jpg',
      kind: 'photo',
      note: 'After',
      fileHash: pictureHash,
      capturedAt: at,
      updatedAt: at,
      deletedAt: null,
    });
    await tx.put('step_days', { harvestDay: '2026-09-18', steps: 8042, lastCounter: null, updatedAt: at });
    await tx.put('body_weights', {
      uuid: 'weight-1',
      grams: 74500,
      harvestDay: '2026-09-18',
      note: null,
      measuredAt: at,
      updatedAt: at,
      deletedAt: null,
    });
    await tx.put('sleep_sessions', {
      uuid: 'sleep-1',
      harvestDay: '2026-09-17',
      fellAsleepAt: '2026-09-17T22:00:00.000Z',
      wokeAt: '2026-09-18T06:00:00.000Z',
      targetMinutes: 480,
      restedStars: 4,
      note: null,
      createdAt: at,
      updatedAt: at,
      deletedAt: null,
    });
    await tx.put('exercises', {
      uuid: 'ex-1',
      name: 'Tempo squat',
      bodyPart: 'upper legs',
      equipment: 'barbell',
      target: null,
      note: null,
      createdAt: at,
      updatedAt: at,
      deletedAt: null,
    });
    await tx.put('programs', {
      uuid: 'program-1',
      name: 'Three days',
      note: null,
      weeks: 4,
      commitmentUuid: 'seed-1',
      albumUuid: 'album-1',
      photoPrompt: 'after',
      createdAt: at,
      updatedAt: at,
      deletedAt: null,
    });
    await tx.put('program_days', { uuid: 'day-1', programUuid: 'program-1', name: 'A', position: 0, week: null, accessories: null });
    await tx.put('program_slots', {
      uuid: 'slot-1',
      dayUuid: 'day-1',
      exerciseId: 'ex-1',
      position: 0,
      restSeconds: 120,
      barGrams: 20000,
      note: null,
    });
    await tx.put('target_sets', {
      uuid: 'target-1',
      slotUuid: 'slot-1',
      position: 0,
      reps: 5,
      weightGrams: null,
      percentTenths: 750,
      openEnded: true,
    });
    await tx.put('training_maxes', { programUuid: 'program-1', exerciseId: 'ex-1', grams: 100000, updatedAt: at });
    await tx.put('workout_sessions', {
      uuid: 'session-1',
      programUuid: 'program-1',
      dayUuid: 'day-1',
      title: 'A',
      harvestDay: '2026-09-18',
      startedAt: at,
      endedAt: later,
      note: null,
      pausedAt: null,
      pausedSeconds: 0,
      updatedAt: later,
      deletedAt: null,
    });
    await tx.put('session_exercises', {
      uuid: 'se-1',
      sessionUuid: 'session-1',
      position: 0,
      exerciseId: 'ex-1',
      plannedExerciseId: null,
      slotUuid: 'slot-1',
      skipped: false,
      skipReason: null,
      note: null,
      restSeconds: null,
      barGrams: 20000,
    });
    await tx.put('workout_sets', {
      uuid: 'set-1',
      sessionExerciseUuid: 'se-1',
      position: 0,
      weightGrams: 60000,
      reps: 5,
      done: true,
      targetLabel: '75%',
      openEnded: false,
      loggedAt: at,
    });
    await tx.put('saved_places', {
      uuid: 'place-1',
      name: 'Library',
      latitude: 36.7525,
      longitude: 3.04197,
      radiusM: 80.5,
      notes: 'The good bench is by the window',
      createdAt: at,
      updatedAt: at,
      deletedAt: null,
    });
    await tx.put('location_points', {
      uuid: 'point-1',
      harvestDay: '2026-09-18',
      recordedAt: at,
      latitude: 36.7525,
      longitude: 3.04197,
      accuracyM: 8.5,
      speedMps: null,
      altitudeM: null,
      updatedAt: at,
      deletedAt: null,
    });
    await tx.put('geotags', {
      uuid: 'geo-1',
      targetTable: 'expenses',
      targetUuid: 'expense-1',
      harvestDay: '2026-09-18',
      at,
      latitude: 36.7525,
      longitude: 3.04197,
      accuracyM: 8.5,
      state: 'fixed',
      updatedAt: at,
      deletedAt: null,
    });
  });
}

/** Every row of every table, keyed, for comparing two devices. */
async function snapshot(h: Device, skip: (table: SyncedTable, key: string) => boolean = () => false) {
  const out: Record<string, Record<string, unknown>> = {};
  for (const table of syncedTables) {
    for (const row of (await h.db.rows(table).toArray()) as Record<string, unknown>[]) {
      const key = recordKeyOf(table, row);
      if (!skip(table, key)) out[`${table}/${key}`] = row;
    }
  }
  return out;
}

async function exported(h: Device, includePlaces = true) {
  return buildArchive(h.db, (hash) => h.files.get(hash), { now: new Date('2026-09-19T12:00:00.000Z'), includePlaces });
}

/** A workbook of just these sheets, zipped as an archive with [files]. */
function crafted(sheets: Record<string, CellValue[][]>, files: Record<string, Uint8Array> = {}): Uint8Array {
  const workbook = buildWorkbook(
    Object.entries(sheets).map(([name, [headers, ...rows]]) => new ExportSheet({ name, headers: headers as string[], rows })),
  );
  return zipSync({ 'harvest.xlsx': workbook, ...files });
}

function problemOf(run: () => unknown): string | null {
  try {
    run();
    return null;
  } catch (error) {
    return error instanceof ArchiveInvalid ? error.problem : String(error);
  }
}

describe('the archive the web writes', () => {
  it('is the phone layout: the same sheets, headers and order', async () => {
    const h = await device(new FakeServer());
    await seed(h);
    const { bytes } = await exported(h);
    const zip = unzipSync(bytes);
    const workbook = parseWorkbook(zip['harvest.xlsx']!);
    expect([...workbook.keys()]).toEqual([SheetNames.summary, ...sheetOrder.map((key) => SheetNames[key])]);
    const empty = harvestSheets(Object.fromEntries([['generatedAt', at], ...sheetOrder.map((key) => [key, []])]) as ExportData);
    for (const sheet of empty.slice(1)) {
      expect(workbook.get(sheet.name)!.headers).toEqual(sheet.allHeaders);
    }
    expect(workbook.get(SheetNames.savedPlaces)!.headers.slice(0, 9)).toEqual(sheetHeaders.savedPlaces);
    expect(sheetHeaders.savedPlaces).toContain('Notes');
  });

  it('keeps the totals as live formulas and the minor units as the truth', async () => {
    const h = await device(new FakeServer());
    await seed(h);
    const zip = unzipSync((await exported(h)).bytes);
    const xlsx = unzipSync(zip['harvest.xlsx']!);
    const decode = (name: string) => new TextDecoder().decode(xlsx[name]);
    const summary = decode('xl/worksheets/sheet1.xml');
    expect(summary).toContain('<f>COUNTA(Seeds!A:A)-1</f>');
    expect(summary).toContain('<f>SUMIFS(Ledger!C:C,Ledger!B:B,&quot;xp&quot;)</f>');
    // The month rows exist for each month with spending, bounded exactly.
    expect(summary).toMatch(/SUMPRODUCT\(\(LEFT\(Expenses!\$B\$2:\$B\$3,7\)/);
    const expenses = decode('xl/worksheets/sheet8.xml');
    expect(expenses).toContain('<f>E2/100</f>');
    expect(expenses).toContain('<v>125050</v>');
    expect(decode('xl/workbook.xml')).toContain('fullCalcOnLoad="1"');
  });

  it('carries the trash, the vault and the files', async () => {
    const h = await device(new FakeServer());
    await seed(h);
    const { bytes, missingFiles } = await exported(h);
    expect(missingFiles).toBe(0);
    const bundle = openArchive(bytes);
    expect(bundle.sheets.get('CheckIns')!.find((row) => row.Uuid === 'check-2')!.DeletedAt).toBe(later);
    // A deleted note keeps its row and gets no file.
    const notes = bundle.sheets.get('Notes')!;
    expect(notes.find((row) => row.Uuid === 'note-2')!.File).toBeUndefined();
    const file = notes.find((row) => row.Uuid === 'note-1')!.File!;
    expect(file).toBe('notes/Health/Sleep log- week 38-.md');
    expect(new TextDecoder().decode(bundle.files.get(file))).toContain('![[2026-09-18 0712.m4a]]');
    expect(bundle.files.get('notes/Health/2026-09-18 0712.m4a')).toHaveLength(40);
    expect(bundle.files.get('gallery/Gym/2026-09-18.jpg')).toHaveLength(64);
    // Only my preferences.
    const keys = bundle.sheets.get('Settings')!.map((row) => row.Key);
    expect(keys).toEqual(expect.arrayContaining(['themeMode', 'finance.defaultCurrency']));
    expect(keys).not.toContain('streak.lastJudgedDay');
  });

  it('leaves the location sheets out when asked to (PL6)', async () => {
    const h = await device(new FakeServer());
    await seed(h);
    const bundle = openArchive((await exported(h, false)).bytes);
    expect(bundle.sheets.get('SavedPlaces') ?? []).toEqual([]);
    expect(bundle.sheets.get('LocationPoints') ?? []).toEqual([]);
    expect(bundle.sheets.get('Geotags') ?? []).toEqual([]);
    expect(bundle.sheets.get('Expenses')).toHaveLength(2);
  });

  it('says how many private rows it could not open', async () => {
    const h = await device(new FakeServer());
    await h.db.sealed.put({
      table: 'expenses',
      uuid: 'sealed-1',
      updatedAt: at,
      deletedAt: null,
      enc: { v: 1, alg: 'A256GCM', iv: 'AAAAAAAAAAAAAAAA', ct: 'AAAA' } as never,
    });
    expect((await exported(h)).sealed).toBe(1);
  });
});

describe('an archive coming back', () => {
  it('round-trips into an empty browser, every row equal', async () => {
    const source = await device(new FakeServer());
    await seed(source);
    const target = await device(new FakeServer(), testClock('2026-09-20T12:00:00.000Z'));
    const bundle = openArchive((await exported(source)).bytes);

    const preview = await previewImport(target.writer, bundle);
    expect(await target.db.rows('commitments').count()).toBe(0);
    const result = await applyImport(target.writer, bundle);
    expect(totalOf(result)).toEqual(totalOf(preview));
    expect(totalOf(result).skipped).toBe(0);

    const bookkeeping = (table: SyncedTable, key: string) => table === 'kv_settings' && key === 'streak.lastJudgedDay';
    expect(await snapshot(target)).toEqual(await snapshot(source, bookkeeping));
    // The files are in this browser, under the names of their bytes.
    expect(await target.db.files.count()).toBe(2);
    // And sync hears of every row.
    const queued = new Set((await target.db.outbox.toArray()).map((entry) => `${entry.table}/${entry.key}`));
    expect(queued).toEqual(new Set(Object.keys(await snapshot(target))));
  });

  it('a second import of the same archive changes nothing', async () => {
    const source = await device(new FakeServer());
    await seed(source);
    const bundle = openArchive((await exported(source)).bytes);
    const again = await previewImport(source.writer, bundle);
    expect(totalOf(again).added).toBe(0);
    expect(totalOf(again).updated).toBe(0);
  });

  it('a newer copy wins, an older one is left alone, and a deletion is an edit', async () => {
    const source = await device(new FakeServer());
    await seed(source);
    const target = await device(new FakeServer());
    await target.writer.run(async (tx) => {
      // Older than the archive's deleted copy: the deletion wins.
      await tx.put('check_ins', {
        uuid: 'check-2',
        commitmentUuid: 'seed-1',
        harvestDay: '2026-09-17',
        quantity: 1,
        loggedAt: at,
        deletedAt: null,
        updatedAt: at,
      });
      // Newer than the archive's: mine stays.
      await tx.put('goals', {
        uuid: 'goal-1',
        title: 'Read much more',
        why: '',
        targetDay: null,
        status: 'active',
        statusNote: null,
        achievedAt: null,
        position: 0,
        createdAt: at,
        updatedAt: '2026-09-19T08:00:00.000Z',
        deletedAt: null,
      });
      // Not in the archive at all: never deleted for being missing.
      await tx.put('ledger', { uuid: 'xp-mine', kind: 'coin', delta: 5, reason: 'mine', harvestDay: '2026-09-19', loggedAt: at });
    });
    await applyImport(target.writer, openArchive((await exported(source)).bytes));
    expect((await target.db.rows('check_ins').get('check-2'))!.deletedAt).toBe(later);
    expect((await target.db.rows('goals').get('goal-1'))!.title).toBe('Read much more');
    expect(await target.db.rows('ledger').get('xp-mine')).toBeDefined();
  });

  it('counts a private row this browser holds sealed as already here', async () => {
    const source = await device(new FakeServer());
    await seed(source);
    const target = await device(new FakeServer());
    await target.db.sealed.put({
      table: 'expenses',
      uuid: 'expense-1',
      updatedAt: '2026-09-19T08:00:00.000Z',
      deletedAt: null,
      enc: { v: 1, alg: 'A256GCM', iv: 'AAAAAAAAAAAAAAAA', ct: 'AAAA' } as never,
    });
    const preview = await previewImport(target.writer, openArchive((await exported(source)).bytes));
    expect(preview.tables.Expenses).toMatchObject({ added: 1, unchanged: 1 });
  });

  it('carries my preferences and none of the bookkeeping (S2-04)', async () => {
    const h = await device(new FakeServer());
    const bytes = crafted({
      Settings: [
        ['Key', 'Value', 'UpdatedAt'],
        ['themeMode', '"dark"', '2026-09-05T10:00:00'],
        ['health.stepGoal', '"8000"', '2026-09-05T10:00:00'],
        ['security.appLock', '"true"', '2026-09-05T10:00:00'],
        ['streak.lastJudgedDay', '"2026-09-04"', '2026-09-05T10:00:00'],
        ['pomodoro.active', '{"x":1}', '2026-09-05T10:00:00'],
      ],
    });
    await applyImport(h.writer, openArchive(bytes));
    const keys = (await h.db.rows('kv_settings').toArray()).map((row) => row.key).sort();
    expect(keys).toEqual(['health.stepGoal', 'themeMode']);
  });

  it('reads a bare timestamp as local time and a date cell as its date', async () => {
    const h = await device(new FakeServer());
    const bytes = crafted({
      Weights: [
        ['Uuid', 'HarvestDay', 'Grams', 'MeasuredAt', 'UpdatedAt'],
        ['w1', '2026-09-05T00:00:00.000', 70000, '2026-09-05T07:12:00.000', '2026-09-05T07:12:00.000123'],
      ],
    });
    await applyImport(h.writer, openArchive(bytes));
    const row = (await h.db.rows('body_weights').get('w1'))!;
    expect(row.harvestDay).toBe('2026-09-05');
    expect(row.measuredAt).toBe(new Date(2026, 8, 5, 7, 12).toISOString());
    expect(row.updatedAt).toBe(new Date(2026, 8, 5, 7, 12).toISOString().replace('.000Z', '.000123Z'));
    expect(instantOf('2026-09-05T07:12:00+01:00')).toBe('2026-09-05T06:12:00.000Z');
  });

  it('leaves out a row the contract would refuse, and says so', async () => {
    const h = await device(new FakeServer());
    const bytes = crafted({
      Seeds: [
        ['Uuid', 'Type', 'Title', 'Schedule', 'UpdatedAt'],
        ['s1', 'habit', 'Fine', '{"type":"daily"}', '2026-09-05T10:00:00Z'],
        ['s2', 'habit', 'Broken schedule', '{"type":"sometimes"}', '2026-09-05T10:00:00Z'],
      ],
    });
    const result = await applyImport(h.writer, openArchive(bytes));
    expect(result.tables.Seeds).toMatchObject({ added: 1, skipped: 1 });
    expect(await h.db.rows('commitments').get('s2')).toBeUndefined();
  });
});

describe('what an archive is trusted with', () => {
  it('refuses what is not an archive', () => {
    expect(problemOf(() => openArchive(strToU8('not a zip at all')))).toBe('unreadable');
    expect(problemOf(() => openArchive(zipSync({ 'notes/a.md': strToU8('hi') })))).toBe('notHarvest');
    expect(problemOf(() => openArchive(zipSync({ 'harvest.xlsx': strToU8('nope') })))).toBe('badWorkbook');
  });

  it('refuses a zip whose directory promises too much, unread', () => {
    const zip = zipSync({ 'harvest.xlsx': new Uint8Array([0]), 'gallery/big.jpg': new Uint8Array([1, 2, 3]) }, { level: 0 });
    // Rewrite the central directory's uncompressed size for the picture.
    const view = new DataView(zip.buffer, zip.byteOffset, zip.byteLength);
    for (let i = 0; i < zip.length - 46; i++) {
      if (view.getUint32(i, true) !== 0x02014b50) continue;
      const nameLength = view.getUint16(i + 28, true);
      const name = new TextDecoder().decode(zip.subarray(i + 46, i + 46 + nameLength));
      if (name === 'gallery/big.jpg') view.setUint32(i + 24, ArchiveLimits.entryBytes + 1, true);
    }
    expect(problemOf(() => openArchive(zip))).toBe('tooLarge');
  });

  it('refuses a file bigger than the cap before decoding it', () => {
    const huge = { length: ArchiveLimits.archiveBytes + 1 } as Uint8Array;
    expect(problemOf(() => openArchive(huge))).toBe('tooLarge');
  });

  it('never lets a row name a path outside where it belongs', async () => {
    const h = await device(new FakeServer());
    const picture = bytesOf(32, 3);
    const bytes = crafted(
      {
        Albums: [
          ['Uuid', 'Name', 'UpdatedAt'],
          ['a1', 'Gym', '2026-09-05T10:00:00Z'],
        ],
        Memories: [
          ['Uuid', 'AlbumUuid', 'HarvestDay', 'File', 'StoredPath', 'UpdatedAt'],
          ['m1', 'a1', '2026-09-05', 'gallery/../../evil.jpg', '../../../etc/passwd.jpg', '2026-09-05T10:00:00Z'],
          ['m2', '../a1', '2026-09-05', 'x', '/abs/olute.jpg', '2026-09-05T10:00:00Z'],
        ],
        Notes: [
          ['Uuid', 'Title', 'Body', 'UpdatedAt'],
          ['n1', 'Note', 'body', '2026-09-05T10:00:00Z'],
        ],
        NoteAttachments: [
          ['Uuid', 'NoteUuid', 'FileName', 'File', 'StoredPath', 'UpdatedAt'],
          ['r1', 'n1', '../../evil.m4a', 'notes/x.m4a', '../../../somewhere.m4a', '2026-09-05T10:00:00Z'],
          ['r2', '../n1', '.hidden', 'notes/y.aac', '', '2026-09-05T10:00:00Z'],
        ],
      },
      { 'gallery/../../evil.jpg': picture },
    );
    await applyImport(h.writer, openArchive(bytes));
    const m1 = (await h.db.rows('memories').get('m1'))!;
    expect(m1.path).toBe('a1/2026-09-05-m1000000.jpg');
    // The file is kept by the name of its bytes, not the name it came
    // under; the row is stamped only once the server has it.
    expect(m1.fileHash).toBeNull();
    expect(await h.db.files.get(await sha256Of(picture.slice().buffer))).toBeDefined();
    expect((await h.db.rows('memories').get('m2'))!.path).toBe('a1/2026-09-05-m2000000.jpg');
    for (const row of await h.db.rows('note_attachments').toArray()) {
      expect(isSafeRelative(row.storedPath)).toBe(true);
      expect(row.storedPath.split('/')).toHaveLength(2);
    }
    expect((await h.db.rows('note_attachments').get('r2'))!.storedPath).toBe('n1/hidden');
    expect(isSafeRelative('a/../../x.jpg')).toBe(false);
    expect(isSafeRelative('a/./b.jpg')).toBe(false);
    expect(isSafeRelative('C:\\x.jpg')).toBe(false);
  });
});

describe('one format on two clients', () => {
  it('an archive the phone wrote comes into the web whole', async () => {
    const bytes = new Uint8Array(readFileSync(resolve(fixtures, 'phone.zip')));
    const bundle = openArchive(bytes);
    const phoneBook = parseWorkbook(unzipSync(bytes)['harvest.xlsx']!);
    const empty = harvestSheets(Object.fromEntries([['generatedAt', at], ...sheetOrder.map((key) => [key, []])]) as ExportData);
    // The same headers, derived columns and all, in the same order.
    for (const sheet of empty.slice(1)) expect(phoneBook.get(sheet.name)?.headers).toEqual(sheet.allHeaders);

    const h = await device(new FakeServer());
    const result = await applyImport(h.writer, bundle);
    expect(totalOf(result).skipped).toBe(0);
    // A row in every sheet on the phone is a row in every table here.
    for (const table of syncedTables) {
      if (table === 'note_links') continue;
      expect(await h.db.rows(table).count(), table).toBeGreaterThan(0);
    }
    const seedRow = (await h.db.rows('commitments').get('p-seed-1'))!;
    expect(seedRow.title).toBe('Walk after lunch');
    expect(seedRow.updatedAt).toBe(instantOf(bundle.sheets.get('Seeds')![0]!.UpdatedAt));
    expect((await h.db.rows('check_ins').get('p-check-2'))!.deletedAt).not.toBeNull();
    expect((await h.db.rows('workout_sets').get('p-set-1'))!.done).toBe(true);
    expect((await h.db.rows('target_sets').get('p-target-1'))!.openEnded).toBe(true);
    expect((await h.db.rows('saved_places').get('p-place-1'))!.notes).toBe('Opens at six');
    const category = (await h.db.rows('expense_categories').get('p-cat-1'))!;
    expect(category.createdAt).toBe(instantOf(bundle.sheets.get('Categories')![0]!.CreatedAt));
    expect(category.createdAt).not.toBeNull();
    expect((await h.db.rows('notes').get('p-note-1'))!.body).toContain('![[2026-09-18 0600.m4a]]');
    const memory = (await h.db.rows('memories').get('p-memory-1'))!;
    expect(memory.path).toBe('p-album-1/2026-09-18-p-memory.jpg');
    // The phone's row names no file yet; the bytes wait here under their own name.
    expect(memory.fileHash).toBeNull();
    const blob = await h.db.files.get(await sha256Of(new Uint8Array(48).fill(9).buffer));
    expect(new Uint8Array(await blob!.blob.arrayBuffer())).toEqual(new Uint8Array(48).fill(9));
    const recording = (await h.db.rows('note_attachments').get('p-rec-1'))!;
    expect(recording.storedPath).toBe('p-note-1/2026-09-18 0600.m4a');
    expect(recording.sizeBytes).toBe(32);
    expect((await h.db.rows('program_days').get(primaryKeyOf('program_days', 'p-day-1')))!.accessories).toBeNull();
  });

  it('the web fixture the phone imports is what the web writes', async () => {
    const h = await device(new FakeServer());
    await seed(h);
    const { bytes } = await exported(h);
    const path = resolve(fixtures, 'web.zip');
    if (process.env.HARVEST_WRITE_FIXTURES === '1') writeFileSync(path, bytes);
    const committed = unzipSync(new Uint8Array(readFileSync(path)));
    const fresh = unzipSync(bytes);
    expect(Object.keys(committed).sort()).toEqual(Object.keys(fresh).sort());
    expect(parseWorkbook(committed['harvest.xlsx']!)).toEqual(parseWorkbook(fresh['harvest.xlsx']!));
    for (const name of Object.keys(fresh)) if (name !== 'harvest.xlsx') expect(committed[name]).toEqual(fresh[name]);
  });
});
