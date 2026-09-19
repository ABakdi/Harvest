import { checkRecord, type EncEnvelope } from '@harvest/contracts';
import pinned from '../../../packages/contracts/fixtures/crypto.json';
import expenseData from '../../../packages/contracts/fixtures/private-data/expenses.json';
import expenseRecord from '../../../packages/contracts/fixtures/records/expenses.json';
import { HarvestDay } from '@harvest/core';
import { describe, expect, it } from 'vitest';
import { WrongPassphraseError } from '@/app/sync/keyring';
import { FakeServer } from './fake-server';
import { device, testUser } from './helpers';

const today = HarvestDay.parse('2026-09-19');

describe('the sync engine', () => {
  it('carries a day from one browser to another, and echoes nothing back', async () => {
    const server = new FakeServer();
    const a = await device(server);
    const seed = await a.seeds.plant({ type: 'habit', title: 'Walk', schedule: { type: 'weekly', weekdays: new Set([1, 3, 5]) } });
    await a.checkIns.checkIn(seed, today);
    await a.engine.sync();

    expect(a.engine.status.phase).toBe('idle');
    expect(await a.db.outbox.count()).toBe(0);
    const stored = server.get('commitments', seed.uuid);
    expect(stored?.data).toMatchObject({ title: 'Walk', scheduleJson: '{"type":"weekly","weekdays":[1,3,5]}' });

    const b = await device(server);
    await b.engine.sync();
    expect(await b.db.rows('commitments').get(seed.uuid)).toEqual(await a.db.rows('commitments').get(seed.uuid));
    expect(await b.db.rows('check_ins').count()).toBe(1);
    expect(await b.db.rows('ledger').count()).toBe(1);
    expect((await b.db.rows('streaks').get(seed.uuid))?.current).toBe(1);
    // Merging is not a change: nothing pulled goes back up.
    expect(await b.db.outbox.count()).toBe(0);
    const pushesBefore = server.pushes;
    await b.engine.sync();
    expect(server.pushes).toBe(pushesBefore);
  });

  it('lets the later edit win on both sides, whoever syncs last', async () => {
    const server = new FakeServer();
    const a = await device(server);
    const b = await device(server);
    const seed = await a.seeds.plant({ type: 'todo', title: 'Dentist' });
    await a.engine.sync();
    await b.engine.sync();

    // B edits first, A edits later; B syncs after A.
    b.clock.set('2026-09-19T13:00:00.000Z');
    await b.seeds.edit(seed.uuid, { type: 'todo', title: 'Dentist at 4' });
    a.clock.set('2026-09-19T14:00:00.000Z');
    await a.seeds.edit(seed.uuid, { type: 'todo', title: 'Dentist on Monday' });
    await a.engine.sync();
    await b.engine.sync();
    await a.engine.sync();

    expect((await a.db.rows('commitments').get(seed.uuid))?.title).toBe('Dentist on Monday');
    expect((await b.db.rows('commitments').get(seed.uuid))?.title).toBe('Dentist on Monday');
    expect(await b.db.outbox.count()).toBe(0);
  });

  it('purges on every device what one of them emptied from the trash', async () => {
    const server = new FakeServer();
    const a = await device(server);
    const b = await device(server);
    const note = await a.notes.create({ title: 'Scratch', body: 'gone soon' });
    await a.engine.sync();
    await b.engine.sync();
    expect(await b.db.rows('notes').get(note.uuid)).toBeDefined();

    a.clock.advance(60_000);
    await a.notes.remove(note.uuid);
    a.clock.advance(60_000);
    await a.notes.emptyTrash();
    await a.engine.sync();
    expect(server.get('notes', note.uuid)).toMatchObject({ purged: true });
    expect(server.get('notes', note.uuid)?.data).toBeUndefined();

    await b.engine.sync();
    expect(await b.db.rows('notes').get(note.uuid)).toBeUndefined();
  });

  it('keeps an invalid row home and does not send it again until it changes', async () => {
    const server = new FakeServer();
    const a = await device(server);
    // A row the contract refuses, slipped past the writer as a bad import would.
    await a.db.rows('notes').put({
      uuid: 'n1',
      title: 't',
      folder: '',
      body: '',
      createdAt: 'yesterday',
      updatedAt: '2026-09-19T12:00:00.000Z',
      deletedAt: null,
    });
    await a.db.outbox.add({ table: 'notes', key: 'n1', op: 'upsert', queuedAt: '2026-09-19T12:00:00.000Z' });
    await a.engine.sync();
    expect(a.engine.status.invalid).toBe(1);
    const pushes = server.pushes;
    await a.engine.sync();
    expect(server.pushes).toBe(pushes);
  });

  it('pages a long pull, and remembers where it stopped', async () => {
    const server = new FakeServer();
    const a = await device(server);
    for (let i = 0; i < 7; i++) await a.notes.create({ title: `Note ${i}` });
    await a.engine.sync();

    const b = await device(server);
    Object.assign(b.engine, { pullLimit: 3 });
    await b.engine.sync();
    expect(await b.db.rows('notes').count()).toBe(7);
    expect(await b.db.meta.get('cursor')).toEqual({ key: 'cursor', value: 7 });
  });
});

describe('the private tier', () => {
  const expense = { amountMinor: 45_000, currency: 'DZD', category: 'food', note: 'Couscous', fromWallet: false, day: today.key };

  it('leaves only an envelope on the server, and opens on a browser with the passphrase', async () => {
    const server = new FakeServer();
    const a = await device(server);
    await a.keyring.unlock('olive trees in october', testUser.syncSalt);
    const uuid = await a.money.log(expense);
    await a.engine.sync();

    const stored = server.get('expenses', uuid)!;
    expect(stored.data).toBeUndefined();
    expect(stored.enc).toMatchObject({ v: 1 });
    expect(JSON.stringify(stored)).not.toContain('Couscous');
    const { seq: _seq, ...record } = stored;
    expect(checkRecord(record).ok).toBe(true);

    // A browser without the passphrase keeps the row sealed and says so.
    const b = await device(server);
    await b.engine.sync();
    expect(await b.db.rows('expenses').count()).toBe(0);
    expect(b.engine.status.sealed).toBe(1);

    await expect(b.keyring.unlock('the wrong words', testUser.syncSalt)).rejects.toBeInstanceOf(WrongPassphraseError);
    await b.keyring.unlock('olive trees in october', testUser.syncSalt);
    expect(await b.engine.openSealed()).toBe(1);
    expect(await b.db.rows('expenses').get(uuid)).toEqual(await a.db.rows('expenses').get(uuid));
    expect(b.engine.status.sealed).toBe(0);
    expect(await b.db.outbox.count()).toBe(0);
  });

  it('opens a row the phone sealed, once the passphrase is typed', async () => {
    const server = new FakeServer();
    server.stored.set(`expenses/${expenseRecord.uuid}`, {
      table: 'expenses',
      uuid: expenseRecord.uuid,
      updatedAt: expenseRecord.updatedAt,
      deletedAt: expenseRecord.deletedAt,
      enc: expenseRecord.enc as EncEnvelope,
      seq: 1,
    });
    const b = await device(server, undefined, { ...testUser, syncSalt: pinned.syncSalt });
    await b.engine.sync();
    expect(b.engine.status.sealed).toBe(1);
    await b.keyring.unlock(pinned.passphrase, pinned.syncSalt);
    await b.engine.openSealed();
    expect(await b.db.rows('expenses').get(expenseRecord.uuid)).toEqual(expenseData);
  });

  it('holds private writes until the passphrase is set, and sends the rest meanwhile', async () => {
    const server = new FakeServer();
    const a = await device(server);
    await a.money.log(expense);
    await a.notes.create({ title: 'Plain' });
    await a.engine.sync();

    expect(server.stored.size).toBeGreaterThan(0);
    expect([...server.stored.values()].some((record) => record.table === 'expenses')).toBe(false);
    expect(a.engine.status.locked).toBeGreaterThan(0);

    await a.keyring.unlock('olive trees in october', testUser.syncSalt);
    await a.engine.sync();
    expect([...server.stored.values()].filter((record) => record.table === 'expenses')).toHaveLength(1);
    expect(a.engine.status.locked).toBe(0);
  });
});
