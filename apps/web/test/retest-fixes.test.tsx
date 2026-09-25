import { HarvestDay } from '@harvest/core';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { cleanup, fireEvent, render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import type { ReactNode } from 'react';
import { MemoryRouter, Route, Routes } from 'react-router';
import { Toaster } from 'sonner';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { boot, localDb, wipeLocal } from '@/app/app-root';
import { SeedLogDialog } from '@/app/components/seed-log-dialog';
import { HarvestContext, type Harvest } from '@/app/context';
import { metaKeys, setMeta } from '@/app/data/db';
import { titleCase } from '@/app/data/exercises';
import { readProgram, readTrainingMaxes } from '@/app/data/gym';
import { DialogsProvider } from '@/app/dialogs';
import { FieldScreen } from '@/app/screens/field';
import { ProgramEditorScreen } from '@/app/screens/gym/program-editor';
import { NotesScreen } from '@/app/screens/notes';
import { RecordsView } from '@/app/screens/records';
import { api, refreshSession, resetApiForTests } from '@/lib/api';
import { FakeServer } from './fake-server';
import { device, testUser } from './helpers';

/** What a hands-on pass over the deployed web still found. */

// Radix's switch measures itself; jsdom has nothing to measure with.
globalThis.ResizeObserver ??= class {
  observe() {}
  unobserve() {}
  disconnect() {}
};

function show(h: Harvest, children: ReactNode, at = '/app/field') {
  render(
    <QueryClientProvider client={new QueryClient({ defaultOptions: { queries: { retry: false } } })}>
      <HarvestContext.Provider value={h}>
        <MemoryRouter initialEntries={[at]}>
          <DialogsProvider>{children}</DialogsProvider>
          <Toaster />
        </MemoryRouter>
      </HarvestContext.Provider>
    </QueryClientProvider>,
  );
}

afterEach(() => {
  vi.restoreAllMocks();
  resetApiForTests();
  localStorage.clear();
  sessionStorage.clear();
});

// ------------------------------------------------------------------ gym

/** Bench at 60 kg × 5, and 75% × 5 of a 100 kg training max. */
async function bench(h: Harvest) {
  const program = await h.programs.createProgram('Strength');
  const day = await h.programs.addDay(program.uuid, 'Day 1');
  const slot = await h.programs.addSlot(day.uuid, '0025');
  await h.programs.addTargetSet(slot.uuid, { reps: 5, weightGrams: 60_000, percentTenths: null, openEnded: false });
  await h.programs.addTargetSet(slot.uuid, { reps: 5, weightGrams: null, percentTenths: 750, openEnded: false });
  await h.programs.setTrainingMax(program.uuid, '0025', 100_000);
  return program.uuid;
}

function editor(h: Harvest, uuid: string) {
  show(
    h,
    <Routes>
      <Route path="/app/body/gym/programs/:uuid" element={<ProgramEditorScreen />} />
    </Routes>,
    `/app/body/gym/programs/${uuid}`,
  );
}

const firstSet = async (h: Harvest, uuid: string) => (await readProgram(h.db, uuid))!.days[0]!.slots[0]!.sets[0]!;

describe('a load seeded in the unit on screen (Y8)', () => {
  it('opens a 60 kg set in a pound gym as 132.25 lb, and saving it untouched keeps 60 kg', async () => {
    const h = await device(new FakeServer());
    await h.settings.setMany({ 'health.weightUnit': 'lb' });
    const uuid = await bench(h);
    editor(h, uuid);
    await userEvent.click(await screen.findByText('Barbell Bench Press', {}, { timeout: 5000 }));
    await userEvent.click(await screen.findByRole('button', { name: 'Edit 132.25 lb × 5' }));
    const dialog = await screen.findByRole('dialog', { name: 'Edit the set' });
    // The dialog reads the unit itself; it must not draw kilos first.
    expect(within(dialog).getByLabelText('Weight')).toHaveValue('132.25');
    await userEvent.click(within(dialog).getByRole('button', { name: 'Save' }));
    await waitFor(() => expect(screen.queryByRole('dialog', { name: 'Edit the set' })).toBeNull());
    expect((await firstSet(h, uuid)).weightGrams).toBe(60_000);
  });

  it('re-seeds an untouched field when the unit arrives late', async () => {
    const h = await device(new FakeServer());
    const uuid = await bench(h);
    editor(h, uuid);
    await userEvent.click(await screen.findByText('Barbell Bench Press', {}, { timeout: 5000 }));
    await userEvent.click(await screen.findByRole('button', { name: 'Edit 60 kg × 5' }));
    const dialog = await screen.findByRole('dialog', { name: 'Edit the set' });
    const field = within(dialog).getByLabelText('Weight');
    expect(field).toHaveValue('60');
    // The phone's setting lands by sync while the dialog is open.
    await h.settings.setMany({ 'health.weightUnit': 'lb' });
    await waitFor(() => expect(field).toHaveValue('132.25'));
    await userEvent.click(within(dialog).getByRole('button', { name: 'Save' }));
    await waitFor(() => expect(screen.queryByRole('dialog', { name: 'Edit the set' })).toBeNull());
    expect((await firstSet(h, uuid)).weightGrams).toBe(60_000);
  });

  it('keeps what was typed when the unit changes after typing', async () => {
    const h = await device(new FakeServer());
    const uuid = await bench(h);
    editor(h, uuid);
    await userEvent.click(await screen.findByText('Barbell Bench Press', {}, { timeout: 5000 }));
    await userEvent.click(await screen.findByRole('button', { name: 'Edit 60 kg × 5' }));
    const field = within(await screen.findByRole('dialog', { name: 'Edit the set' })).getByLabelText('Weight');
    await userEvent.clear(field);
    await userEvent.type(field, '70');
    await h.settings.setMany({ 'health.weightUnit': 'lb' });
    await screen.findByRole('radio', { name: 'lb' });
    expect(field).toHaveValue('70');
  });

  it('opens a training max in pounds and leaves it alone when left untouched', async () => {
    const h = await device(new FakeServer());
    await h.settings.setMany({ 'health.weightUnit': 'lb' });
    const uuid = await bench(h);
    editor(h, uuid);
    await userEvent.click(await screen.findByRole('button', { name: 'Training maxes' }, { timeout: 5000 }));
    const dialog = await screen.findByRole('dialog', { name: 'Training maxes' });
    const field = await within(dialog).findByLabelText('Barbell Bench Press');
    expect(field).toHaveValue('220.5');
    fireEvent.blur(field);
    await new Promise((resolve) => setTimeout(resolve, 50));
    expect((await readTrainingMaxes(h.db, uuid)).get('0025')).toBe(100_000);
  });

  it('saves a rounded load with one click: the hint stays through the blur', async () => {
    const h = await device(new FakeServer());
    await h.settings.setMany({ 'health.weightUnit': 'kg' });
    const uuid = await bench(h);
    editor(h, uuid);
    await userEvent.click(await screen.findByText('Barbell Bench Press', {}, { timeout: 5000 }));
    await userEvent.click(await screen.findByRole('button', { name: 'Edit 60 kg × 5' }));
    const dialog = await screen.findByRole('dialog', { name: 'Edit the set' });
    const field = within(dialog).getByLabelText('Weight');
    await userEvent.clear(field);
    await userEvent.type(field, '61.3');
    const hint = 'Kept as 61.25 kg, the nearest weight a bar can hold.';
    expect(within(dialog).getByText(hint)).toBeInTheDocument();
    fireEvent.blur(field);
    // Still there: were it to go, Save would jump up under the pointer.
    expect(field).toHaveValue('61.25');
    expect(within(dialog).getByText(hint)).toBeInTheDocument();
    await userEvent.click(within(dialog).getByRole('button', { name: 'Save' }));
    await waitFor(async () => expect((await firstSet(h, uuid)).weightGrams).toBe(61_250));
    // And the next keystroke clears it.
  });

  it('keeps each set label whole and left to right', async () => {
    const h = await device(new FakeServer());
    await h.settings.setMany({ 'health.weightUnit': 'lb' });
    const uuid = await bench(h);
    editor(h, uuid);
    const label = await screen.findByText('132.25 lb × 5', {}, { timeout: 5000 });
    expect(label.tagName).toBe('BDI');
    expect(label).toHaveAttribute('dir', 'ltr');
    expect(label).toHaveClass('whitespace-nowrap');
  });
});

describe('catalogue names (titleCase)', () => {
  it('writes the initialisms as they are said, and leaves words be', () => {
    expect(titleCase('barbell jm bench press')).toBe('Barbell JM Bench Press');
    expect(titleCase('ez barbell curl')).toBe('EZ Barbell Curl');
    expect(titleCase('cable reverse grip triceps pushdown (sz-bar)')).toBe('Cable Reverse Grip Triceps Pushdown (SZ-Bar)');
    expect(titleCase('barbell full squat (back pov)')).toBe('Barbell Full Squat (Back POV)');
    expect(titleCase('cable seated high row (v-bar)')).toBe('Cable Seated High Row (V-Bar)');
    expect(titleCase('barbell standing ab rollerout')).toBe('Barbell Standing Ab Rollerout');
    expect(titleCase('push-up on a ball')).toBe('Push-Up on a Ball');
  });
});

// ---------------------------------------------------------------- notes

function notesAt(h: Harvest, at: string) {
  vi.spyOn(api, 'assistStatus').mockResolvedValue({ available: false, model: null, usedToday: 0, dailyLimit: 50 });
  show(
    h,
    <Routes>
      <Route path="/app/records" element={<NotesScreen />} />
      <Route path="/app/records/:uuid" element={<NotesScreen />} />
    </Routes>,
    at,
  );
}

/**
 * Types into a note and "reloads" before anything reached IndexedDB:
 * the flush on the way out is made to lose the race, as it does in a
 * browser navigating away.
 */
async function typeThenReload(h: Awaited<ReturnType<typeof device>>, uuid: string, text: string) {
  notesAt(h, `/app/records/${uuid}`);
  h.clock.advance(5_000);
  const update = vi.spyOn(h.notes, 'update').mockImplementation(() => new Promise(() => {}));
  await userEvent.type(await screen.findByLabelText('Note'), text);
  fireEvent(window, new Event('pagehide'));
  cleanup();
  update.mockRestore();
  expect((await h.db.rows('notes').get(uuid))?.body).toBe('');
}

describe('typing a reload cuts off (W4-02)', () => {
  beforeEach(() => localStorage.clear());

  it('comes back when the same note is opened again', async () => {
    const h = await device(new FakeServer());
    await h.settings.setString('features.notes', 'true');
    const { uuid } = await h.notes.create({ title: 'Walk' });
    await typeThenReload(h, uuid, 'By the river');

    notesAt(h, `/app/records/${uuid}`);
    expect((await screen.findAllByText('By the river')).length).toBeGreaterThan(0);
    await waitFor(async () => expect((await h.db.rows('notes').get(uuid))?.body).toBe('By the river'));
    // Once back in the note, the kept copy is let go.
    expect(Object.keys(localStorage).filter((key) => key.startsWith('harvest.noteDraft.'))).toEqual([]);
  });

  it('comes back when the reload lands on the list, so no empty Untitled is left', async () => {
    const h = await device(new FakeServer());
    await h.settings.setString('features.notes', 'true');
    // "New note", then the first keystrokes, then the reload.
    const { uuid } = await h.notes.create();
    await typeThenReload(h, uuid, '# Groceries');

    notesAt(h, '/app/records');
    await waitFor(async () => expect((await h.db.rows('notes').get(uuid))?.body).toBe('# Groceries'));
    // Listed with what was typed, not as an empty note.
    expect((await screen.findAllByText('Groceries')).length).toBeGreaterThan(0);
  });

  it('never puts back typing older than the note', async () => {
    const h = await device(new FakeServer());
    await h.settings.setString('features.notes', 'true');
    const { uuid } = await h.notes.create({ title: 'Walk' });
    await typeThenReload(h, uuid, 'Old draft');
    // Another device wrote the note since.
    h.clock.advance(60_000);
    await h.notes.update(uuid, { body: 'From the phone' });

    notesAt(h, `/app/records/${uuid}`);
    expect((await screen.findAllByText('From the phone')).length).toBeGreaterThan(0);
    expect((await h.db.rows('notes').get(uuid))?.body).toBe('From the phone');
    expect(localStorage.length).toBe(0);
  });
});

// ---------------------------------------------------------------- field

describe('the daily harvest, past its goal', () => {
  it('says the goal is met instead of "4 of 3"', async () => {
    const h = await device(new FakeServer());
    const day = HarvestDay.parse('2026-09-19');
    for (const title of ['Read', 'Walk', 'Stretch', 'Write']) {
      const seed = await h.seeds.plant({ type: 'habit', title });
      await h.checkIns.checkIn(seed, day);
    }
    show(h, <FieldScreen tab="today" />);
    expect(await screen.findByText('4 actions — the daily harvest goal is met')).toBeInTheDocument();
    expect(screen.queryByText(/4 of 3/)).toBeNull();
  });
});

describe('a log cut by the total that completes the project (X4-02)', () => {
  it('still says how many were left out', async () => {
    const h = await device(new FakeServer());
    const seed = await h.seeds.plant({ type: 'project', title: 'Read', totalTarget: 20, dailyCommitment: 20 });
    show(h, <SeedLogDialog seed={seed} onClose={() => {}} />);
    const box = await screen.findByLabelText('How much did you get done?');
    await waitFor(() => expect(screen.getByRole('button', { name: 'Log' })).toBeEnabled());
    fireEvent.change(box, { target: { value: '25' } });
    await userEvent.click(screen.getByRole('button', { name: 'Log' }));
    expect(await screen.findByText('Harvest complete!')).toBeInTheDocument();
    expect(await screen.findByText('Logged 20; 5 over the cap left out')).toBeInTheDocument();
  });
});

// -------------------------------------------------------------- records

describe('a records view opened by link while it is off', () => {
  const at = async (path: string, on: Record<string, string>) => {
    const h = await device(new FakeServer());
    await h.settings.setMany(on);
    show(
      h,
      <Routes>
        <Route path="/app/records/gallery" element={<RecordsView feature="gallery">the gallery</RecordsView>} />
        <Route path="/app/records/places" element={<RecordsView feature="places">the map</RecordsView>} />
      </Routes>,
      path,
    );
  };

  it('says the Gallery is off, with the tabs to what is on', async () => {
    await at('/app/records/gallery', { 'features.notes': 'true' });
    expect(await screen.findByText('The Gallery is switched off')).toBeInTheDocument();
    expect(screen.queryByText('the gallery')).toBeNull();
    expect(await screen.findByRole('link', { name: 'Notes' })).toBeInTheDocument();
  });

  it('says Places are off', async () => {
    await at('/app/records/places', { 'features.gallery': 'true' });
    expect(await screen.findByText('Places are switched off')).toBeInTheDocument();
    expect(screen.queryByText('the map')).toBeNull();
  });

  it('says all three are off, as /app/records does', async () => {
    await at('/app/records/places', {});
    expect(await screen.findByText('Notes, the Gallery and Places are switched off')).toBeInTheDocument();
  });

  it('opens the view while it is on', async () => {
    await at('/app/records/places', { 'features.places': 'true' });
    expect(await screen.findByText('the map')).toBeInTheDocument();
  });
});

// -------------------------------------------------------------- the boot

const ok = () => Response.json({ accessToken: 'fresh', expiresIn: 900, user: testUser });
const answer = (status: number) =>
  new Response(JSON.stringify({ error: { code: status === 429 ? 'rate_limited' : 'internal', message: 'no' } }), {
    status,
    headers: { 'content-type': 'application/json' },
  });

describe('opening the app when the refresh is turned away', () => {
  beforeEach(async () => {
    await wipeLocal();
    const db = localDb();
    await db.open();
    await setMeta(db, metaKeys.user, testUser);
  });

  it('opens from this browser on a 429, signed in, like offline', async () => {
    vi.spyOn(globalThis, 'fetch').mockResolvedValue(answer(429));
    const state = await boot();
    expect(state).toMatchObject({ kind: 'ready', offline: true });
    if (state.kind === 'ready') expect(state.harvest.user.id).toBe(testUser.id);
  });

  it('opens on a 5xx too, and only a 401 signs out', async () => {
    vi.spyOn(globalThis, 'fetch').mockResolvedValue(answer(503));
    expect(await boot()).toMatchObject({ kind: 'ready', offline: true });
    resetApiForTests();
    vi.spyOn(globalThis, 'fetch').mockResolvedValue(answer(401));
    expect(await boot()).toMatchObject({ kind: 'signedOut' });
  });

  it('backs off: a refresh turned away is not asked again at once', async () => {
    const fetch = vi.spyOn(globalThis, 'fetch').mockResolvedValue(answer(429));
    await expect(refreshSession()).rejects.toMatchObject({ status: 429 });
    await expect(refreshSession()).rejects.toMatchObject({ status: 429 });
    expect(fetch).toHaveBeenCalledTimes(1);
  });

  it('keeps the access token in memory only: nothing a script could read survives a reload', async () => {
    vi.spyOn(globalThis, 'fetch').mockResolvedValue(ok());
    expect(await boot()).toMatchObject({ kind: 'ready', offline: false });
    expect(sessionStorage.length).toBe(0);
    expect(localStorage.getItem('harvest.access')).toBeNull();
  });
});
