import { render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter, Route, Routes } from 'react-router';
import { describe, expect, it } from 'vitest';
import { HarvestContext, type Harvest } from '@/app/context';
import { readProgram, readSession } from '@/app/data/gym';
import { DialogsProvider } from '@/app/dialogs';
import { ProgramEditorScreen } from '@/app/screens/gym/program-editor';
import { SessionScreen } from '@/app/screens/gym/session';
import { FakeServer } from './fake-server';
import { device } from './helpers';

/** 135 lb and 40 lb, as the phone stores them: the whole grams of those pounds. */
const lb135 = 61_235;
const lb40 = 18_144;

/** Bench in pounds: 135 × 5, 40 × 10, and 75% × 5 of a 225 lb training max. */
async function inPounds(h: Harvest) {
  await h.settings.setMany({ 'health.weightUnit': 'lb' });
  const program = await h.programs.createProgram('Pounds');
  const day = await h.programs.addDay(program.uuid, 'Day 1');
  const slot = await h.programs.addSlot(day.uuid, '0025');
  await h.programs.addTargetSet(slot.uuid, { reps: 5, weightGrams: lb135, percentTenths: null, openEnded: false });
  await h.programs.addTargetSet(slot.uuid, { reps: 10, weightGrams: lb40, percentTenths: null, openEnded: false });
  await h.programs.addTargetSet(slot.uuid, { reps: 5, weightGrams: null, percentTenths: 750, openEnded: false });
  await h.programs.setTrainingMax(program.uuid, '0025', 102_058);
  return (await readProgram(h.db, program.uuid))!;
}

function renderAt(h: Harvest, at: string) {
  render(
    <HarvestContext.Provider value={h}>
      <MemoryRouter initialEntries={[at]}>
        <DialogsProvider>
          <Routes>
            <Route path="/app/body/gym/programs/:uuid" element={<ProgramEditorScreen />} />
            <Route path="/app/body/gym/sessions/:uuid" element={<SessionScreen />} />
          </Routes>
        </DialogsProvider>
      </MemoryRouter>
    </HarvestContext.Provider>,
  );
}

/** Pounds are first-class (Y8): they round, load and read back as pounds. */
describe('a pound gym', () => {
  it('resolves a percentage in pounds and labels it as the phone does', async () => {
    const h = await device(new FakeServer());
    const tree = await inPounds(h);
    const { session } = await h.sessions.start({
      day: tree.days[0]!,
      programUuid: tree.program.uuid,
      trainingMaxes: new Map([['0025', 102_058]]),
      unit: 'lb',
    });
    const sets = (await readSession(h.db, session.session.uuid))!.exercises[0]!.sets;
    expect(sets.map((set) => [set.weightGrams, set.targetLabel])).toEqual([
      [lb135, '61.23×5'],
      [lb40, '18.14×10'],
      // 75% of 225 lb is 168.75 lb — not 168.8, not a quarter kilo off.
      [76_544, '76.54×5'],
    ]);
  });

  it('shows 135 lb as 135, and loads 45s on a 45 lb bar', async () => {
    const h = await device(new FakeServer());
    const tree = await inPounds(h);
    const { session } = await h.sessions.start({ day: tree.days[0]!, programUuid: tree.program.uuid, trainingMaxes: new Map(), unit: 'lb' });
    renderAt(h, `/app/body/gym/sessions/${session.session.uuid}`);

    expect(await screen.findByLabelText('Weight in lb, set 1', {}, { timeout: 5000 })).toHaveValue('135');
    await userEvent.click(screen.getByRole('button', { name: 'Plates for 135 lb' }));
    const plates = await screen.findByRole('dialog');
    expect(await within(plates).findByText('Per side, on a 45 lb bar')).toBeInTheDocument();
    expect(within(plates).getByText('1 × 45 lb')).toBeInTheDocument();
  });

  it('says the bar alone is over when the target is lighter than it', async () => {
    const h = await device(new FakeServer());
    const tree = await inPounds(h);
    const { session } = await h.sessions.start({ day: tree.days[0]!, programUuid: tree.program.uuid, trainingMaxes: new Map(), unit: 'lb' });
    renderAt(h, `/app/body/gym/sessions/${session.session.uuid}`);

    expect(await screen.findByText('135×5', {}, { timeout: 5000 })).toBeInTheDocument();
    await userEvent.click(await screen.findByRole('button', { name: 'Plates for 40 lb' }));
    const plates = await screen.findByRole('dialog');
    expect(await within(plates).findByText('Just the bar')).toBeInTheDocument();
    expect(within(plates).getByText('Lighter than the bar: the bar alone is 5 lb over.')).toBeInTheDocument();
  });

  it('offers pound bars, with the 20 kg default read as the 45 lb bar', async () => {
    const h = await device(new FakeServer());
    const tree = await inPounds(h);
    renderAt(h, `/app/body/gym/programs/${tree.program.uuid}`);

    await userEvent.click(await screen.findByText('barbell bench press', {}, { timeout: 5000 }));
    const bars = await screen.findByRole('radiogroup', { name: 'The bar' });
    // The unit is a setting, read as the dialog opens.
    await within(bars).findByRole('radio', { name: '45 lb' }, { timeout: 5000 });
    const choices = within(bars).getAllByRole('radio');
    expect(choices.map((choice) => choice.textContent)).toEqual(['35 lb', '45 lb']);
    expect(within(bars).getByRole('radio', { name: '45 lb' })).toHaveAttribute('aria-checked', 'true');

    await userEvent.click(within(bars).getByRole('radio', { name: '35 lb' }));
    await waitFor(async () => expect((await readProgram(h.db, tree.program.uuid))!.days[0]!.slots[0]!.row.barGrams).toBe(15_876));
  });
});
