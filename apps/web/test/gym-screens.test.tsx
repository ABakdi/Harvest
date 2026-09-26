import { render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter, Route, Routes } from 'react-router';
import { Toaster } from 'sonner';
import { describe, expect, it } from 'vitest';
import { HarvestContext, type Harvest } from '@/app/context';
import { readProgram, readRunning, readSession } from '@/app/data/gym';
import { DialogsProvider } from '@/app/dialogs';
import { FieldScreen } from '@/app/screens/field';
import { GymPanel } from '@/app/screens/gym';
import { ProgramEditorScreen } from '@/app/screens/gym/program-editor';
import { SessionScreen } from '@/app/screens/gym/session';
import { FakeServer } from './fake-server';
import { device } from './helpers';

/** Bench: 100 kg × 5, 100 kg × 5, 95% × 1+ — and a day of incline. */
async function withProgram(h: Harvest, { seed = false } = {}) {
  const program = await h.programs.createProgram('nSuns');
  const day = await h.programs.addDay(program.uuid, 'Day 1');
  await h.programs.addDay(program.uuid, 'Day 2');
  const slot = await h.programs.addSlot(day.uuid, '0025');
  await h.programs.addTargetSet(slot.uuid, { reps: 5, weightGrams: 100_000, percentTenths: null, openEnded: false });
  await h.programs.addTargetSet(slot.uuid, { reps: 5, weightGrams: 100_000, percentTenths: null, openEnded: false });
  await h.programs.addTargetSet(slot.uuid, { reps: 1, weightGrams: null, percentTenths: 950, openEnded: true });
  if (seed) await h.programs.plant(program.uuid, { title: 'Gym', timesPerWeek: 4, album: false });
  return (await readProgram(h.db, program.uuid))!;
}

async function aSession(h: Harvest, seed = false) {
  const tree = await withProgram(h, { seed });
  const { session } = await h.sessions.start({ day: tree.days[0]!, programUuid: tree.program.uuid, trainingMaxes: new Map() });
  return { tree, session };
}

/** Radix opens a menu from the keyboard in a test browser. */
async function openMenu(name: string) {
  (await screen.findByRole('button', { name })).focus();
  await userEvent.keyboard('{Enter}');
}

function renderAt(h: Harvest, at: string) {
  render(
    <HarvestContext.Provider value={h}>
      <MemoryRouter initialEntries={[at]}>
        <DialogsProvider>
          <Routes>
            <Route path="/app/field" element={<FieldScreen tab="today" />} />
            <Route path="/app/body/gym" element={<GymPanel />} />
            <Route path="/app/body/gym/programs/:uuid" element={<ProgramEditorScreen />} />
            <Route path="/app/body/gym/sessions/:uuid" element={<SessionScreen />} />
          </Routes>
        </DialogsProvider>
      </MemoryRouter>
      <Toaster />
    </HarvestContext.Provider>,
  );
}

describe('a session in the browser', () => {
  it('logs a set that went to plan in one click, starts the rest, and celebrates the record', async () => {
    const h = await device(new FakeServer());
    const { session } = await aSession(h);
    renderAt(h, `/app/body/gym/sessions/${session.session.uuid}`);

    // Every row is prefilled with its target.
    expect(await screen.findByLabelText('Weight in kg, set 1')).toHaveValue('100');
    expect(screen.getByLabelText('Reps, set 1')).toHaveValue('5');
    await userEvent.click(screen.getByRole('button', { name: 'Log set 1' }));

    await waitFor(async () => expect((await readSession(h.db, session.session.uuid))!.doneSets).toBe(1));
    expect(screen.getByRole('timer', { name: 'Resting' })).toHaveTextContent('2:00');
    // The first set ever is the heaviest ever.
    expect(await screen.findByText('Heaviest ever: 100 kg')).toBeInTheDocument();
    expect(screen.getByText('1 of 3 sets')).toBeInTheDocument();
  });

  it('keeps a typed number, and a set that beats only the estimate says so', async () => {
    const h = await device(new FakeServer());
    const { session } = await aSession(h);
    const [first] = session.exercises[0]!.sets;
    await h.sessions.logSet(first!.uuid, { weightGrams: 100_000, reps: 5, done: true });
    renderAt(h, `/app/body/gym/sessions/${session.session.uuid}`);

    const reps = await screen.findByLabelText('Reps, set 2');
    await userEvent.clear(reps);
    await userEvent.type(reps, '8');
    await userEvent.click(screen.getByRole('button', { name: 'Log set 2' }));
    await waitFor(async () => expect((await h.db.rows('workout_sets').get(session.exercises[0]!.sets[1]!.uuid))?.reps).toBe(8));
    // Same weight, more reps: not heavier, but the best estimated single.
    expect(await screen.findByText('Best set yet — about 126.67 kg for one')).toBeInTheDocument();
  });

  it('asks before Finish leaves un-skipped sets behind, then checks the habit in (Y10, Y4)', async () => {
    const h = await device(new FakeServer());
    const { session } = await aSession(h, true);
    renderAt(h, `/app/body/gym/sessions/${session.session.uuid}`);
    await userEvent.click(await screen.findByRole('button', { name: 'Log set 1' }));
    await waitFor(async () => expect((await readSession(h.db, session.session.uuid))!.doneSets).toBe(1));

    await userEvent.click(screen.getByRole('button', { name: 'Finish' }));
    const ask = await screen.findByRole('alertdialog');
    expect(within(ask).getByText('Finish with sets left?')).toBeInTheDocument();
    expect(within(ask).getByText(/2 of 3 sets are not ticked/)).toBeInTheDocument();
    await userEvent.click(within(ask).getByRole('button', { name: 'Finish' }));

    expect(await screen.findByText('Checked in · +10 XP')).toBeInTheDocument();
    expect(await readRunning(h.db)).toBeNull();
    expect(await h.db.rows('check_ins').count()).toBe(1);
  });

  it('skips with a reason, and a skipped exercise asks nothing at Finish', async () => {
    const h = await device(new FakeServer());
    const { session } = await aSession(h);
    await h.sessions.logSet(session.exercises[0]!.sets[0]!.uuid, { weightGrams: 100_000, reps: 5, done: true });
    renderAt(h, `/app/body/gym/sessions/${session.session.uuid}`);

    await openMenu('Options for Barbell Bench Press');
    await userEvent.click(await screen.findByRole('menuitem', { name: 'Skip it' }));
    const reason = await screen.findByLabelText('Reason');
    await userEvent.type(reason, 'shoulder{Enter}');
    expect(await screen.findByText('skipped — shoulder')).toBeInTheDocument();

    await userEvent.click(screen.getByRole('button', { name: 'Finish' }));
    await waitFor(async () => expect(await readRunning(h.db)).toBeNull());
  });

  it('asks twice before discarding logged sets', async () => {
    const h = await device(new FakeServer());
    const { session } = await aSession(h);
    await h.sessions.logSet(session.exercises[0]!.sets[0]!.uuid, { weightGrams: 100_000, reps: 5, done: true });
    renderAt(h, `/app/body/gym/sessions/${session.session.uuid}`);

    await openMenu('Session options');
    await userEvent.click(await screen.findByRole('menuitem', { name: 'Drop this session' }));
    let ask = await screen.findByRole('alertdialog');
    expect(within(ask).getByText('The one set you logged goes with it.')).toBeInTheDocument();
    await userEvent.click(within(ask).getByRole('button', { name: 'Drop this session' }));
    ask = await screen.findByRole('alertdialog');
    expect(within(ask).getByText('Sure? This cannot be undone')).toBeInTheDocument();
    await userEvent.click(within(ask).getByRole('button', { name: 'Drop this session' }));
    await waitFor(async () => expect(await h.db.rows('workout_sessions').count()).toBe(0));
  });

  it('swaps an exercise from the catalogue, and remembers what the day was meant to be (Y7)', async () => {
    const h = await device(new FakeServer());
    const { session } = await aSession(h);
    renderAt(h, `/app/body/gym/sessions/${session.session.uuid}`);

    await openMenu('Options for Barbell Bench Press');
    await userEvent.click(await screen.findByRole('menuitem', { name: 'Swap it out' }));
    const picker = await screen.findByRole('dialog');
    await userEvent.type(within(picker).getByLabelText('Search by name, muscle or kit'), 'incline bench barbell');
    await userEvent.click(await within(picker).findByRole('button', { name: /^Barbell Incline Bench Press/ }, { timeout: 5000 }));
    expect(await screen.findByText('instead of Barbell Bench Press')).toBeInTheDocument();
    expect((await readSession(h.db, session.session.uuid))!.exercises[0]!.row).toMatchObject({ exerciseId: '0047', plannedExerciseId: '0025' });
  });

  it('opens an exercise on its records, the estimate named as one (Y6)', async () => {
    const h = await device(new FakeServer());
    const { session } = await aSession(h);
    await h.sessions.logSet(session.exercises[0]!.sets[0]!.uuid, { weightGrams: 100_000, reps: 5, done: true });
    await h.sessions.finish(session.session.uuid);
    const next = await h.sessions.start({ day: (await readProgram(h.db, session.session.programUuid!))!.days[0]!, programUuid: session.session.programUuid!, trainingMaxes: new Map() });
    renderAt(h, `/app/body/gym/sessions/${next.session.session.uuid}`);

    // The set is its own left-to-right island inside the sentence (Y8).
    expect(await screen.findByText((_, element) => element?.tagName === 'SPAN' && element.textContent === 'Last time: 100 kg×5')).toBeInTheDocument();
    await userEvent.click(screen.getByRole('button', { name: 'Barbell Bench Press' }));
    const detail = await screen.findByRole('dialog');
    expect(within(detail).getByText('Personal records')).toBeInTheDocument();
    // The heaviest set, and the history's one outing.
    expect(within(detail).getAllByText('100 kg×5')).toHaveLength(2);
    expect(within(detail).getAllByText('116.67 kg').length).toBeGreaterThan(0);
    expect(within(detail).getByText(/Epley/)).toBeInTheDocument();
    expect(within(detail).getByText('500 kg')).toBeInTheDocument();
  });

  it('pauses the clock, and drops a set only after asking', async () => {
    const h = await device(new FakeServer());
    const { session } = await aSession(h);
    renderAt(h, `/app/body/gym/sessions/${session.session.uuid}`);

    await userEvent.click(await screen.findByRole('button', { name: 'Pause the clock' }));
    await waitFor(async () => expect((await h.db.rows('workout_sessions').get(session.session.uuid))!.pausedAt).not.toBeNull());
    expect(await screen.findByText('Paused')).toBeInTheDocument();

    await userEvent.click(screen.getByRole('button', { name: 'Drop set 2' }));
    const ask = await screen.findByRole('alertdialog');
    await userEvent.click(within(ask).getByRole('button', { name: 'Drop this set' }));
    await waitFor(async () => expect((await readSession(h.db, session.session.uuid))!.totalSets).toBe(2));
  });

  it('works out the plates for a bar (Y9)', async () => {
    const h = await device(new FakeServer());
    const { session } = await aSession(h);
    renderAt(h, `/app/body/gym/sessions/${session.session.uuid}`);

    const [first] = await screen.findAllByRole('button', { name: 'Plates for 100 kg' });
    await userEvent.click(first!);
    const plates = await screen.findByRole('dialog');
    expect(within(plates).getByText('Per side, on a 20 kg bar')).toBeInTheDocument();
    expect(within(plates).getByText('1 × 25 kg')).toBeInTheDocument();
    expect(within(plates).getByText('1 × 15 kg')).toBeInTheDocument();
  });
});

describe('the gym panel', () => {
  it('starts the day that is up next, and offers the running session back', async () => {
    const h = await device(new FakeServer());
    await withProgram(h);
    renderAt(h, '/app/body/gym');

    expect(await screen.findByText(/Next: Day 1/)).toBeInTheDocument();
    // Start waits for the weight unit, so a load is never offered in the wrong one.
    await waitFor(() => expect(screen.getByRole('button', { name: 'Start a session' })).toBeEnabled());
    await userEvent.click(screen.getByRole('button', { name: 'Start a session' }));
    const pick = await screen.findByRole('dialog');
    // The days load into the dialog after it opens.
    expect(await within(pick).findByText('Up next', { exact: false })).toBeInTheDocument();
    await userEvent.click(await within(pick).findByRole('button', { name: /Day 1/ }));
    expect(await screen.findByLabelText('Weight in kg, set 1')).toBeInTheDocument();
    expect((await readRunning(h.db))?.session.title).toBe('Day 1');
  });

  it('shows a running session first, wherever it was begun', async () => {
    const h = await device(new FakeServer());
    const { session } = await aSession(h);
    renderAt(h, '/app/body/gym');
    const resume = await screen.findByRole('link', { name: /Carry on/ });
    expect(resume).toHaveAttribute('href', `/app/body/gym/sessions/${session.session.uuid}`);
    expect(resume).toHaveTextContent('0 of 3 sets done');
  });
});

describe('the program editor', () => {
  it('adds a day, and a percentage set asks for a training max', async () => {
    const h = await device(new FakeServer());
    const tree = await withProgram(h);
    renderAt(h, `/app/body/gym/programs/${tree.program.uuid}`);

    expect(await screen.findByText('1 exercise needs a training max')).toBeInTheDocument();
    await userEvent.click(screen.getByRole('button', { name: 'Add a day' }));
    const name = await screen.findByLabelText('Name of the day');
    expect(name).toHaveValue('Day 3');
    await userEvent.click(within(screen.getByRole('dialog')).getByRole('button', { name: 'Add a day' }));
    await waitFor(async () => expect((await readProgram(h.db, tree.program.uuid))!.days).toHaveLength(3));

    await userEvent.click(screen.getByRole('button', { name: 'Training maxes' }));
    const input = await screen.findByLabelText('Barbell Bench Press', {}, { timeout: 5000 });
    await userEvent.type(input, '111{Enter}');
    await waitFor(async () => expect((await h.db.rows('training_maxes').toArray())[0]?.grams).toBe(111_000));
  });

  it('duplicates a day in one click', async () => {
    const h = await device(new FakeServer());
    const tree = await withProgram(h);
    renderAt(h, `/app/body/gym/programs/${tree.program.uuid}`);
    await openMenu('Options for Day 1');
    await userEvent.click(await screen.findByRole('menuitem', { name: 'Duplicate' }));
    expect(await screen.findByText('Day 1 (2)')).toBeInTheDocument();
  });
});

describe('a gym seed on the field (Y12)', () => {
  it('asks which of two things happened, and "went, no numbers" is a session that checks it in', async () => {
    const h = await device(new FakeServer());
    const tree = await withProgram(h, { seed: true });
    renderAt(h, '/app/field');

    await userEvent.click(await screen.findByRole('button', { name: 'Check in “Gym”' }));
    const ask = await screen.findByRole('dialog');
    expect(within(ask).getByText('Start the session')).toBeInTheDocument();
    await userEvent.click(within(ask).getByRole('button', { name: /Went, no numbers/ }));

    await waitFor(async () => expect(await h.db.rows('check_ins').count()).toBe(1));
    const [session] = await h.db.rows('workout_sessions').toArray();
    expect(session).toMatchObject({ programUuid: tree.program.uuid, title: 'Day 1' });
    expect(session!.endedAt).not.toBeNull();
  });
});
