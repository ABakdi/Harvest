import { HarvestDay } from '@harvest/core';
import { render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter, Route, Routes } from 'react-router';
import { Toaster } from 'sonner';
import { describe, expect, it } from 'vitest';
import { HarvestContext, type Harvest } from '@/app/context';
import { readProgram, readSession } from '@/app/data/gym';
import { DialogsProvider } from '@/app/dialogs';
import { GymPanel } from '@/app/screens/gym';
import { SessionScreen } from '@/app/screens/gym/session';
import { sessionClockText } from '@/app/screens/gym/shared';
import { FakeServer } from './fake-server';
import { device } from './helpers';

/**
 * A session left running past its own Harvest Day (Y3 resumes it): it
 * is asked about on the way in, finishing it names the day it checks
 * in on, and its clock reads hours and days rather than minutes.
 */
async function staleSession(h: Harvest) {
  const program = await h.programs.createProgram('nSuns');
  const day = await h.programs.addDay(program.uuid, 'Day 1');
  const slot = await h.programs.addSlot(day.uuid, '0025');
  await h.programs.addTargetSet(slot.uuid, { reps: 5, weightGrams: 100_000, percentTenths: null, openEnded: false });
  await h.programs.addTargetSet(slot.uuid, { reps: 5, weightGrams: 100_000, percentTenths: null, openEnded: false });
  await h.programs.plant(program.uuid, { title: 'Gym', timesPerWeek: 4, album: false });
  const tree = (await readProgram(h.db, program.uuid))!;
  const { session } = await h.sessions.start({ day: tree.days[0]!, programUuid: tree.program.uuid, trainingMaxes: new Map() });
  await h.sessions.logSet(session.exercises[0]!.sets[0]!.uuid, { weightGrams: 100_000, reps: 5, done: true });
  // Started, a set ticked, then left open for five days.
  const uuid = session.session.uuid;
  await h.db.rows('workout_sessions').update(uuid, { harvestDay: '2026-09-14', startedAt: '2026-09-14T17:00:00.000Z' });
  const setUuid = session.exercises[0]!.sets[0]!.uuid;
  await h.db.rows('workout_sets').update(setUuid, { loggedAt: '2026-09-14T17:20:00.000Z' });
  return uuid;
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

describe('a session left running past its day', () => {
  it('is asked about on the way in, and finishes on its own day at its last set', async () => {
    const h = await device(new FakeServer());
    const uuid = await staleSession(h);
    renderAt(h, `/app/body/gym/sessions/${uuid}`);

    const ask = await screen.findByRole('alertdialog');
    expect(within(ask).getByText(/Still open from/)).toBeInTheDocument();
    expect(within(ask).getByText(/1 of 2 sets logged/)).toBeInTheDocument();
    // The clock says days, not 7000 minutes.
    expect(screen.getByText('5 days')).toBeInTheDocument();
    await userEvent.click(within(ask).getByRole('button', { name: /Finish as of/ }));

    await waitFor(async () => expect((await readSession(h.db, uuid))!.session.endedAt).not.toBeNull());
    const { session } = (await readSession(h.db, uuid))!;
    // Ended at the last set, not at the click eleven days on.
    expect(session.endedAt).toBe('2026-09-14T17:20:00.000Z');
    const checkIns = await h.db.rows('check_ins').toArray();
    expect(checkIns.map((row) => row.harvestDay)).toEqual(['2026-09-14']);
    expect(await screen.findByText(/Checked in for .*Sep.*14/)).toBeInTheDocument();
  });

  it('drops with one more question when sets are logged, the prompt being the first', async () => {
    const h = await device(new FakeServer());
    const uuid = await staleSession(h);
    renderAt(h, `/app/body/gym/sessions/${uuid}`);

    let ask = await screen.findByRole('alertdialog');
    await userEvent.click(within(ask).getByRole('button', { name: 'Drop this session' }));
    ask = await screen.findByRole('alertdialog');
    expect(within(ask).getByText('Sure? This cannot be undone')).toBeInTheDocument();
    await userEvent.click(within(ask).getByRole('button', { name: 'Drop this session' }));
    await waitFor(async () => expect(await h.db.rows('workout_sessions').count()).toBe(0));
    expect(await h.db.rows('check_ins').count()).toBe(0);
  });

  it('reads hours past the hour', () => {
    expect(sessionClockText(65)).toBe('1:05');
    expect(sessionClockText(3600 + 4 * 60 + 5)).toBe('1:04:05');
    expect(sessionClockText(958_630)).toBe('266:17:10');
    expect(HarvestDay.parse('2026-09-14').daysUntil(HarvestDay.parse('2026-09-19'))).toBe(5);
  });
});
