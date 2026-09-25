import { render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter, Route, Routes } from 'react-router';
import { Toaster } from 'sonner';
import { describe, expect, it } from 'vitest';
import { HarvestContext, type Harvest } from '@/app/context';
import { lastTime, readProgram, readSession } from '@/app/data/gym';
import { DialogsProvider } from '@/app/dialogs';
import { GymPanel } from '@/app/screens/gym';
import { SessionScreen } from '@/app/screens/gym/session';
import { FakeServer } from './fake-server';
import { device } from './helpers';

/** Bench: 100 kg × 5, three times, planted with an album. */
async function withProgram(h: Harvest, photoPrompt: 'never' | 'before' | 'after' = 'after') {
  const program = await h.programs.createProgram('nSuns');
  const day = await h.programs.addDay(program.uuid, 'Day 1');
  const slot = await h.programs.addSlot(day.uuid, '0025');
  for (let i = 0; i < 3; i += 1) {
    await h.programs.addTargetSet(slot.uuid, { reps: 5, weightGrams: 100_000, percentTenths: null, openEnded: false });
  }
  await h.programs.plant(program.uuid, { title: 'Gym', timesPerWeek: 4, album: true });
  await h.programs.updateProgram(program.uuid, { photoPrompt });
  return (await readProgram(h.db, program.uuid))!;
}

async function aSession(h: Harvest, photoPrompt: 'never' | 'before' | 'after' = 'after') {
  const tree = await withProgram(h, photoPrompt);
  const { session } = await h.sessions.start({ day: tree.days[0]!, programUuid: tree.program.uuid, trainingMaxes: new Map() });
  return { tree, session };
}

function renderAt(h: Harvest, at: string) {
  render(
    <HarvestContext.Provider value={h}>
      <MemoryRouter initialEntries={[at]}>
        <DialogsProvider>
          <Routes>
            <Route path="/app/body/gym" element={<GymPanel />} />
            <Route path="/app/body/gym/sessions/:uuid" element={<SessionScreen />} />
          </Routes>
        </DialogsProvider>
      </MemoryRouter>
      <Toaster />
    </HarvestContext.Provider>,
  );
}

async function openMenu(name: string) {
  (await screen.findByRole('button', { name })).focus();
  await userEvent.keyboard('{Enter}');
}

describe('positions after a drop and an add', () => {
  it('a set takes the next position, not the count, as the phone does', async () => {
    const h = await device(new FakeServer());
    const { session } = await aSession(h);
    const exercise = session.exercises[0]!;
    await h.sessions.removeSet(exercise.sets[1]!.uuid);
    await h.sessions.addSet(exercise.row.uuid);

    const sets = (await readSession(h.db, session.session.uuid))!.exercises[0]!.sets;
    // Counting would have written [0, 2, 2].
    expect(sets.map((set) => set.position)).toEqual([0, 2, 3]);
  });

  it('days, slots and target sets never repeat a position either', async () => {
    const h = await device(new FakeServer());
    const program = await h.programs.createProgram('P');
    const days = [];
    for (const name of ['a', 'b', 'c']) days.push(await h.programs.addDay(program.uuid, name));
    const slots = [];
    for (const id of ['0001', '0002', '0003']) slots.push(await h.programs.addSlot(days[0]!.uuid, id));
    const sets = [];
    for (const reps of [5, 3, 1]) {
      sets.push(await h.programs.addTargetSet(slots[0]!.uuid, { reps, weightGrams: 50_000, percentTenths: null, openEnded: false }));
    }

    await h.programs.removeDay(days[1]!.uuid);
    await h.programs.removeSlot(slots[1]!.uuid);
    await h.programs.removeTargetSet(sets[1]!.uuid);
    await h.programs.addDay(program.uuid, 'd');
    await h.programs.addSlot(days[0]!.uuid, '0004');
    await h.programs.addTargetSet(slots[0]!.uuid, { reps: 8, weightGrams: 50_000, percentTenths: null, openEnded: false });

    const tree = (await readProgram(h.db, program.uuid))!;
    expect(tree.days.map((day) => day.row.position)).toEqual([0, 2, 3]);
    expect(tree.days[0]!.slots.map((slot) => slot.row.position)).toEqual([0, 2, 3]);
    expect(tree.days[0]!.slots[0]!.sets.map((set) => set.position)).toEqual([0, 2, 3]);
  });
});

describe('writes beneath a session', () => {
  it('ticking a set moves the session on too, in the same write (`_touch`)', async () => {
    const h = await device(new FakeServer());
    const { session } = await aSession(h);
    h.clock.advance(60_000);
    await h.sessions.logSet(session.exercises[0]!.sets[0]!.uuid, { weightGrams: 100_000, reps: 5, done: true });

    const row = await h.db.rows('workout_sessions').get(session.session.uuid);
    expect(row!.updatedAt).toBe('2026-09-19T12:01:00.000Z');
    const queued = await h.db.outbox.toArray();
    expect(queued.some((entry) => entry.table === 'workout_sessions' && entry.key === session.session.uuid)).toBe(true);
  });
});

describe('last time', () => {
  it('an exercise done twice in a session answers with the earlier position', async () => {
    const h = await device(new FakeServer());
    const { session } = await aSession(h, 'never');
    await h.sessions.addExercise(session.session.uuid, '0025');
    const tree = (await readSession(h.db, session.session.uuid))!;
    const [planned, again] = tree.exercises;
    // The later row is moved to the top, so store order and position disagree.
    await h.db.rows('session_exercises').update(again!.row.uuid, { position: -1 });
    await h.sessions.logSet(planned!.sets[0]!.uuid, { weightGrams: 100_000, reps: 5, done: true });
    await h.sessions.logSet(again!.sets[0]!.uuid, { weightGrams: 60_000, reps: 10, done: true });
    await h.sessions.finish(session.session.uuid);

    expect((await lastTime(h.db, '0025')).map((set) => set.weightGrams)).toEqual([60_000]);
  });
});

describe('words', () => {
  it('dropping a session with nothing logged says nothing is lost', async () => {
    const h = await device(new FakeServer());
    const { session } = await aSession(h, 'never');
    renderAt(h, `/app/body/gym/sessions/${session.session.uuid}`);
    await openMenu('Session options');
    await userEvent.click(await screen.findByRole('menuitem', { name: 'Drop this session' }));
    const ask = await screen.findByRole('alertdialog');
    expect(within(ask).getByText('Nothing is logged yet, so nothing is lost.')).toBeInTheDocument();
  });

  it('the history counts one set as one set', async () => {
    const h = await device(new FakeServer());
    const { session } = await aSession(h, 'never');
    await h.sessions.logSet(session.exercises[0]!.sets[0]!.uuid, { weightGrams: 100_000, reps: 5, done: true });
    await h.sessions.finish(session.session.uuid);
    renderAt(h, '/app/body/gym');
    expect(await screen.findByText(/^1 set · /)).toBeInTheDocument();
  });

  it('the history plural uses every Arabic form', async () => {
    const { default: i18n } = await import('@/i18n');
    const t = i18n.getFixedT('ar');
    expect(t('gym.summary', { count: 1, volume: 'x' })).toBe('مجموعة واحدة · x');
    expect(t('gym.summary', { count: 2, volume: 'x' })).toBe('مجموعتان · x');
    expect(t('gym.summary', { count: 5, volume: 'x' })).toBe('5 مجموعات · x');
    expect(t('gym.summary', { count: 11, volume: 'x' })).toBe('11 مجموعة · x');
  });
});

describe('the picture a program asks for', () => {
  it('after: finishing offers the album a picture, and yes opens its capture', async () => {
    const h = await device(new FakeServer());
    const { session } = await aSession(h, 'after');
    await h.sessions.logSet(session.exercises[0]!.sets[0]!.uuid, { weightGrams: 100_000, reps: 5, done: true });
    renderAt(h, `/app/body/gym/sessions/${session.session.uuid}`);

    await userEvent.click(await screen.findByRole('button', { name: 'Finish' }));
    await userEvent.click(within(await screen.findByRole('alertdialog')).getByRole('button', { name: 'Finish' }));

    const offer = await screen.findByRole('alertdialog', { name: 'Picture?' });
    expect(within(offer).getByText('One for the album, while you are still here.')).toBeInTheDocument();
    await userEvent.click(within(offer).getByRole('button', { name: 'Take it' }));
    expect(await screen.findByRole('dialog', { name: 'Add to Gym' })).toBeInTheDocument();
  });

  it('"not now" closes the offer and does not ask again', async () => {
    const h = await device(new FakeServer());
    const { session } = await aSession(h, 'after');
    renderAt(h, `/app/body/gym/sessions/${session.session.uuid}`);
    await userEvent.click(await screen.findByRole('button', { name: 'Finish' }));
    await userEvent.click(within(await screen.findByRole('alertdialog')).getByRole('button', { name: 'Finish' }));

    const offer = await screen.findByRole('alertdialog', { name: 'Picture?' });
    await userEvent.click(within(offer).getByRole('button', { name: 'Not now' }));
    await waitFor(() => expect(screen.queryByRole('alertdialog')).toBeNull());
    expect(screen.queryByRole('dialog', { name: 'Add to Gym' })).toBeNull();
  });

  it('an album in the trash is not asked for anything', async () => {
    const h = await device(new FakeServer());
    const { tree, session } = await aSession(h, 'after');
    await h.gallery.deleteAlbum(tree.program.albumUuid!);
    renderAt(h, `/app/body/gym/sessions/${session.session.uuid}`);
    await userEvent.click(await screen.findByRole('button', { name: 'Finish' }));
    await userEvent.click(within(await screen.findByRole('alertdialog')).getByRole('button', { name: 'Finish' }));

    expect(await screen.findByRole('button', { name: 'Start a session' })).toBeInTheDocument();
    expect(screen.queryByRole('alertdialog', { name: 'Picture?' })).toBeNull();
  });

  it('before: starting a day offers the picture ahead of the first set', async () => {
    const h = await device(new FakeServer());
    await withProgram(h, 'before');
    renderAt(h, '/app/body/gym');
    await userEvent.click(await screen.findByRole('button', { name: 'Start a session' }));
    // The days load into the dialog after it opens: wait for the one to start.
    await userEvent.click(await screen.findByRole('button', { name: /Day 1/ }, { timeout: 5000 }));

    expect(await screen.findByLabelText('Weight in kg, set 1')).toBeInTheDocument();
    const offer = await screen.findByRole('alertdialog', { name: 'Picture?' });
    await userEvent.click(within(offer).getByRole('button', { name: 'Not now' }));
    await waitFor(() => expect(screen.queryByRole('alertdialog')).toBeNull());
  });

  it('after is not asked on the way in, and before is not asked on the way out', async () => {
    const h = await device(new FakeServer());
    const { session } = await aSession(h, 'before');
    renderAt(h, `/app/body/gym/sessions/${session.session.uuid}`);
    await userEvent.click(await screen.findByRole('button', { name: 'Finish' }));
    await userEvent.click(within(await screen.findByRole('alertdialog')).getByRole('button', { name: 'Finish' }));
    expect(await screen.findByRole('button', { name: 'Start a session' })).toBeInTheDocument();
    expect(screen.queryByRole('alertdialog', { name: 'Picture?' })).toBeNull();
  });
});

describe('a set row', () => {
  it('takes a weight and reps changed elsewhere together', async () => {
    const h = await device(new FakeServer());
    const { session } = await aSession(h, 'never');
    renderAt(h, `/app/body/gym/sessions/${session.session.uuid}`);
    expect(await screen.findByLabelText('Weight in kg, set 1')).toHaveValue('100');

    await h.sessions.logSet(session.exercises[0]!.sets[0]!.uuid, { weightGrams: 105_000, reps: 3, done: false });
    await waitFor(() => expect(screen.getByLabelText('Weight in kg, set 1')).toHaveValue('105'));
    expect(screen.getByLabelText('Reps, set 1')).toHaveValue('3');
  });
});
