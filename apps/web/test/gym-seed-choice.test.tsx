import { render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter, Route, Routes } from 'react-router';
import { describe, expect, it } from 'vitest';
import { HarvestContext } from '@/app/context';
import { DialogsProvider } from '@/app/dialogs';
import { PomodoroScreen } from '@/app/screens/pomodoro';
import { FakeServer } from './fake-server';
import { device } from './helpers';

/**
 * Gym rule Y12 wherever a seed is checked in, not only on the field: a
 * gym seed is ticked by a session, so finishing a focus block on one
 * asks the same two-way question instead of writing a bare check-in.
 */

const minute = 60_000;

/** Found patiently: the whole suite runs these side by side. */
const patient = { timeout: 5000 };

type Harvest = Awaited<ReturnType<typeof device>>;

async function gymSeed(h: Harvest) {
  const program = await h.programs.createProgram('nSuns');
  const day = await h.programs.addDay(program.uuid, 'Day 1');
  await h.programs.addSlot(day.uuid, '0025');
  await h.programs.plant(program.uuid, { title: 'Gym', timesPerWeek: 4, album: false });
  const seed = (await h.db.rows('commitments').toArray()).find((row) => row.title === 'Gym')!;
  return { program, seed };
}

function renderFocus(h: Harvest, seedUuid: string) {
  render(
    <HarvestContext.Provider value={h}>
      <MemoryRouter initialEntries={[`/app/field/focus?seed=${seedUuid}`]}>
        <DialogsProvider>
          <Routes>
            <Route path="/app/field/focus" element={<PomodoroScreen />} />
            <Route path="/app/field" element={<p>The field</p>} />
            <Route path="/app/body/gym/sessions/:uuid" element={<p>The session</p>} />
          </Routes>
        </DialogsProvider>
      </MemoryRouter>
    </HarvestContext.Provider>,
  );
}

async function finishABlock(h: Harvest) {
  await userEvent.click(await screen.findByRole('button', { name: 'Start focus' }, patient));
  // Running before the clock moves, or the block is counted from later.
  await screen.findByRole('button', { name: 'Abandon' }, patient);
  h.clock.advance(25 * minute);
  await h.pomodoro.evaluate();
  await userEvent.click(await screen.findByRole('button', { name: 'Finish session' }, patient));
}

describe('a gym seed after a focus block (Y12)', () => {
  it('asks, and "went, no numbers" is a finished session that checks it in', async () => {
    const h = await device(new FakeServer());
    const { program, seed } = await gymSeed(h);
    renderFocus(h, seed.uuid);
    await finishABlock(h);

    const ask = await screen.findByRole('dialog', {}, patient);
    // Nothing is ticked before the question is answered.
    expect(await h.db.rows('check_ins').count()).toBe(0);
    await userEvent.click(within(ask).getByRole('button', { name: /Went, no numbers/ }));

    expect(await screen.findByText('The field', {}, patient)).toBeInTheDocument();
    await waitFor(async () => expect(await h.db.rows('check_ins').where('commitmentUuid').equals(seed.uuid).count()).toBe(1));
    const [session] = await h.db.rows('workout_sessions').toArray();
    expect(session).toMatchObject({ programUuid: program.uuid, title: 'Day 1' });
    expect(session!.endedAt).not.toBeNull();
  });

  it('starts the seed’s own program when asked to', async () => {
    const h = await device(new FakeServer());
    const { seed } = await gymSeed(h);
    renderFocus(h, seed.uuid);
    await finishABlock(h);

    await userEvent.click(within(await screen.findByRole('dialog', {}, patient)).getByRole('button', { name: /Start the session/ }));
    // One program, one day: the day to start is offered, and is one click.
    // The choice closes as the day picker opens: ask the screen, not the first dialog found.
    await userEvent.click(await screen.findByRole('button', { name: /Day 1/ }, patient));
    expect(await screen.findByText('The session', {}, patient)).toBeInTheDocument();
    expect(await h.db.rows('check_ins').count()).toBe(0);
  });

  it('checks any other habit in directly, as before', async () => {
    const h = await device(new FakeServer());
    await gymSeed(h);
    const write = await h.seeds.plant({ type: 'habit', title: 'Write', schedule: { type: 'daily' } });
    renderFocus(h, write.uuid);
    await finishABlock(h);
    expect(await screen.findByText('The field', {}, patient)).toBeInTheDocument();
    expect(screen.queryByRole('dialog')).not.toBeInTheDocument();
    expect(await h.db.rows('check_ins').where('commitmentUuid').equals(write.uuid).count()).toBe(1);
  });
});
