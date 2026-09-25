import { render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter, Route, Routes } from 'react-router';
import { describe, expect, it } from 'vitest';
import { HarvestContext, type Harvest } from '@/app/context';
import { DialogsProvider } from '@/app/dialogs';
import { GoalScreen } from '@/app/screens/goal';
import { FakeServer } from './fake-server';
import { device } from './helpers';

function wrap(h: Harvest, goal: string) {
  return (
    <HarvestContext.Provider value={h}>
      <MemoryRouter initialEntries={[`/app/field/goals/${goal}`]}>
        <DialogsProvider>
          <Routes>
            <Route path="/app/field/goals/:uuid" element={<GoalScreen />} />
          </Routes>
        </DialogsProvider>
      </MemoryRouter>
    </HarvestContext.Provider>
  );
}

describe('planting from a goal', () => {
  it('opens a fresh editor for each item and links the item pressed', async () => {
    const h = await device(new FakeServer());
    const goal = await h.goals.create({ title: 'Move house' });
    const need = await h.goals.addItem(goal.uuid, 'Boxes', 'need');
    const step = await h.goals.addItem(goal.uuid, 'Call the landlord', 'step');
    render(wrap(h, goal.uuid));
    const user = userEvent.setup();

    await user.click(await screen.findByRole('button', { name: /Plant “Boxes”/ }));
    let dialog = await screen.findByRole('dialog');
    expect(within(dialog).getByRole('textbox', { name: 'Title' })).toHaveValue('Boxes');
    await user.click(within(dialog).getByRole('button', { name: 'Cancel' }));
    await waitFor(() => expect(screen.queryByRole('dialog')).toBeNull());

    await user.click(screen.getByRole('button', { name: /Plant “Call the landlord”/ }));
    dialog = await screen.findByRole('dialog');
    expect(within(dialog).getByRole('textbox', { name: 'Title' })).toHaveValue('Call the landlord');
    await user.click(within(dialog).getByRole('button', { name: 'Plant a seed' }));

    await waitFor(async () => expect((await h.db.rows('goal_items').get(step.uuid))?.commitmentUuid).toBeTruthy());
    const seed = (await h.db.rows('commitments').toArray())[0]!;
    expect(seed.title).toBe('Call the landlord');
    expect((await h.db.rows('goal_items').get(step.uuid))?.commitmentUuid).toBe(seed.uuid);
    expect((await h.db.rows('goal_items').get(need.uuid))?.commitmentUuid).toBeNull();
  });
});
