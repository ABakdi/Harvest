import { fireEvent, render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { strToU8, unzipSync, zipSync } from 'fflate';
import { HarvestDay } from '@harvest/core';
import { MemoryRouter, Route, Routes } from 'react-router';
import { Toaster } from 'sonner';
import { describe, expect, it } from 'vitest';
import { buildWorkbook, ExportSheet, parseWorkbook } from '@/app/data/archive-xlsx';
import { buildArchive } from '@/app/data/export';
import { SheetNames, sheetHeaders } from '@/app/data/export-sheets';
import { loadGoals } from '@/app/data/goal-views';
import { applyImport, openArchive } from '@/app/data/import';
import { HarvestContext, type Harvest } from '@/app/context';
import { DialogsProvider } from '@/app/dialogs';
import { GoalScreen } from '@/app/screens/goal';
import { GoalsBoard } from '@/app/screens/goals-board';
import { RecordsTabs } from '@/app/screens/records';
import { FakeServer } from './fake-server';
import { device } from './helpers';

/**
 * Requirements, tasks and subtasks ([[Goals]] GL2, GL7, GL8): one level
 * deep, a parent drawn from its subtasks, and the lot kept together
 * through delete, undo, sync and the archive.
 */

type Device = Awaited<ReturnType<typeof device>>;

const today = HarvestDay.parse('2026-09-19');

const item = async (h: Device, uuid: string) => (await h.db.rows('goal_items').get(uuid))!;

/** A goal with a task "Run a 10 km race" holding three subtasks. */
async function race(h: Device) {
  const goal = await h.goals.create({ title: 'Half marathon' });
  const task = await h.goals.addItem(goal.uuid, 'Run a 10 km race', 'step');
  const find = (await h.goals.addSubtask(task.uuid, 'Find a race'))!;
  const register = (await h.goals.addSubtask(task.uuid, 'Register'))!;
  const run = (await h.goals.addSubtask(task.uuid, 'Run it'))!;
  return { goal, task, find, register, run };
}

describe('subtasks in the repository', () => {
  it('adds a subtask one level deep, with its parent’s kind, at the end', async () => {
    const h = await device(new FakeServer());
    const goal = await h.goals.create({ title: 'Half marathon' });
    const plan = await h.goals.addItem(goal.uuid, 'A training plan', 'need');
    const pick = (await h.goals.addSubtask(plan.uuid, 'Pick one'))!;
    const print = (await h.goals.addSubtask(plan.uuid, '  Print it '))!;
    expect(pick).toMatchObject({ parentUuid: plan.uuid, kind: 'need', position: 0, goalUuid: goal.uuid });
    expect(print).toMatchObject({ parentUuid: plan.uuid, kind: 'need', position: 1, body: 'Print it' });
    // A subtask has no subtasks of its own (GL8).
    expect(await h.goals.addSubtask(pick.uuid, 'Deeper')).toBeNull();
    expect(await h.db.rows('goal_items').count()).toBe(3);
    // A new top-level item is placed among top-level items only.
    expect((await h.goals.addItem(goal.uuid, 'Shoes', 'need')).position).toBe(1);
  });

  it('keeps a parent’s tick drawn from its subtasks: the latest tick, or null', async () => {
    const h = await device(new FakeServer());
    const { task, find, register, run } = await race(h);
    await h.goals.setDone(find.uuid, true);
    h.clock.advance(60_000);
    await h.goals.setDone(run.uuid, true);
    expect((await item(h, task.uuid)).doneAt).toBeNull();
    h.clock.advance(60_000);
    await h.goals.setDone(register.uuid, true);
    const last = (await item(h, register.uuid)).doneAt;
    expect((await item(h, task.uuid)).doneAt).toBe(last);

    h.clock.advance(60_000);
    await h.goals.setDone(find.uuid, false);
    expect((await item(h, task.uuid)).doneAt).toBeNull();
  });

  it('an open subtask added to a ticked task reopens it', async () => {
    const h = await device(new FakeServer());
    const { task, find, register, run } = await race(h);
    for (const sub of [find, register, run]) await h.goals.setDone(sub.uuid, true);
    expect((await item(h, task.uuid)).doneAt).not.toBeNull();
    await h.goals.addSubtask(task.uuid, 'Collect the bib');
    expect((await item(h, task.uuid)).doneAt).toBeNull();
  });

  it('ticking a parent ticks every live subtask, and un-ticking un-ticks them', async () => {
    const h = await device(new FakeServer());
    const { task, find, register, run } = await race(h);
    await h.goals.setDone(find.uuid, true);
    const early = (await item(h, find.uuid)).doneAt;
    await h.goals.deleteItem(run.uuid);
    h.clock.advance(60_000);
    const queued = await h.db.outbox.count();

    await h.goals.setDone(task.uuid, true);
    // The one already ticked keeps its tick; the deleted one is left alone.
    expect((await item(h, find.uuid)).doneAt).toBe(early);
    expect((await item(h, register.uuid)).doneAt).toBe('2026-09-19T12:01:00.000Z');
    expect((await item(h, run.uuid)).doneAt).toBeNull();
    expect((await item(h, task.uuid)).doneAt).toBe('2026-09-19T12:01:00.000Z');
    expect(await h.db.outbox.count()).toBeGreaterThan(queued);

    await h.goals.setDone(task.uuid, false);
    for (const sub of [task, find, register]) expect((await item(h, sub.uuid)).doneAt).toBeNull();
  });

  it('reorders subtasks within their task', async () => {
    const h = await device(new FakeServer());
    const { goal, task, find, register, run } = await race(h);
    await h.goals.reorderItems([run.uuid, find.uuid, register.uuid]);
    const [view] = await loadGoals(h.db);
    expect(view!.goal.uuid).toBe(goal.uuid);
    expect(view!.subtasks.get(task.uuid)!.map((sub) => sub.body)).toEqual(['Run it', 'Find a race', 'Register']);
    expect(view!.steps.map((step) => step.body)).toEqual(['Run a 10 km race']);
  });

  it('lifts a subtask to a task of its own, and the task it left settles', async () => {
    const h = await device(new FakeServer());
    const { goal, task, find, register, run } = await race(h);
    await h.goals.addItem(goal.uuid, 'Taper', 'step');
    await h.goals.setDone(find.uuid, true);
    await h.goals.setDone(register.uuid, true);
    await h.goals.setDone(run.uuid, false);

    await h.goals.liftItem(run.uuid);
    expect(await item(h, run.uuid)).toMatchObject({ parentUuid: null, position: 2, kind: 'step' });
    // What is left is all ticked, so the task is done.
    expect((await item(h, task.uuid)).doneAt).toBe((await item(h, register.uuid)).doneAt);
    // A top-level item has nothing to be lifted from.
    await h.goals.liftItem(task.uuid);
    expect((await item(h, task.uuid)).parentUuid).toBeNull();
  });

  it('moves an item without subtasks under another, where it takes that item’s kind', async () => {
    const h = await device(new FakeServer());
    const { goal, task, find, register, run } = await race(h);
    for (const sub of [find, register, run]) await h.goals.setDone(sub.uuid, true);
    const shoes = await h.goals.addItem(goal.uuid, 'Shoes', 'need');
    const other = await h.goals.create({ title: 'Car' });
    const save = await h.goals.addItem(other.uuid, 'Save');

    expect(await h.goals.nestItem(shoes.uuid, task.uuid)).toBe(true);
    expect(await item(h, shoes.uuid)).toMatchObject({ parentUuid: task.uuid, kind: 'step', position: 3 });
    // An open subtask reopens the task it joins.
    expect((await item(h, task.uuid)).doneAt).toBeNull();

    // Refused: a parent, under a subtask, under itself, across goals.
    expect(await h.goals.nestItem(task.uuid, shoes.uuid)).toBe(false);
    const lone = await h.goals.addItem(goal.uuid, 'Stretch', 'step');
    expect(await h.goals.nestItem(lone.uuid, find.uuid)).toBe(false);
    expect(await h.goals.nestItem(lone.uuid, lone.uuid)).toBe(false);
    expect(await h.goals.nestItem(save.uuid, task.uuid)).toBe(false);
    const withSubtask = await h.goals.addItem(goal.uuid, 'Plan', 'need');
    await h.goals.addSubtask(withSubtask.uuid, 'Pick');
    expect(await h.goals.nestItem(withSubtask.uuid, task.uuid)).toBe(false);
    expect((await item(h, lone.uuid)).parentUuid).toBeNull();
  });

  it('deletes a task with its subtasks under one stamp, and undo brings back exactly those', async () => {
    const h = await device(new FakeServer());
    const { task, find, register, run } = await race(h);
    await h.goals.deleteItem(run.uuid);
    h.clock.advance(60_000);

    await h.goals.deleteItem(task.uuid);
    const stamp = (await item(h, task.uuid)).deletedAt;
    expect(stamp).not.toBeNull();
    expect((await item(h, find.uuid)).deletedAt).toBe(stamp);
    expect((await item(h, register.uuid)).deletedAt).toBe(stamp);
    expect((await item(h, run.uuid)).deletedAt).not.toBe(stamp);

    await h.goals.restoreItem(task.uuid);
    for (const sub of [task, find, register]) expect((await item(h, sub.uuid)).deletedAt).toBeNull();
    expect((await item(h, run.uuid)).deletedAt).not.toBeNull();
  });

  it('deleting the last open subtask completes its task', async () => {
    const h = await device(new FakeServer());
    const { task, find, register, run } = await race(h);
    await h.goals.setDone(find.uuid, true);
    await h.goals.setDone(register.uuid, true);
    await h.goals.deleteItem(run.uuid);
    expect((await item(h, task.uuid)).doneAt).not.toBeNull();
    await h.goals.restoreItem(run.uuid);
    expect((await item(h, task.uuid)).doneAt).toBeNull();
  });

  it('a goal deleted and restored takes its subtasks along', async () => {
    const h = await device(new FakeServer());
    const { goal, find } = await race(h);
    await h.goals.delete(goal.uuid);
    expect((await item(h, find.uuid)).deletedAt).not.toBeNull();
    await h.goals.restore(goal.uuid);
    expect((await item(h, find.uuid)).deletedAt).toBeNull();
  });

  it('a planted subtask’s check-in ticks it and can complete its task; undo reopens it (GL3)', async () => {
    const h = await device(new FakeServer());
    const { goal, task, find, register, run } = await race(h);
    await h.goals.setDone(find.uuid, true);
    await h.goals.setDone(register.uuid, true);
    const seed = await h.seeds.plant({ type: 'todo', title: 'Run it', goalUuid: goal.uuid }, run.uuid);

    await h.checkIns.checkIn(seed, today);
    expect((await item(h, run.uuid)).doneAt).not.toBeNull();
    expect((await item(h, task.uuid)).doneAt).toBe((await item(h, run.uuid)).doneAt);

    await h.checkIns.undo(seed, today);
    expect((await item(h, run.uuid)).doneAt).toBeNull();
    expect((await item(h, task.uuid)).doneAt).toBeNull();
  });

  it('a planted task’s check-in ticks its subtasks with it', async () => {
    const h = await device(new FakeServer());
    const { goal, task, find, register, run } = await race(h);
    const seed = await h.seeds.plant({ type: 'todo', title: 'Run a 10 km race', goalUuid: goal.uuid }, task.uuid);
    await h.checkIns.checkIn(seed, today);
    for (const sub of [task, find, register, run]) expect((await item(h, sub.uuid)).doneAt).not.toBeNull();
    await h.checkIns.undo(seed, today);
    for (const sub of [task, find, register, run]) expect((await item(h, sub.uuid)).doneAt).toBeNull();
  });

  it('counts subtasks in their task’s place, and answers “what now?” with the first open one', async () => {
    const h = await device(new FakeServer());
    const { goal, task, find, register } = await race(h);
    await h.goals.addItem(goal.uuid, 'Shoes', 'need');
    await h.goals.setDone(find.uuid, true);
    const [view] = await loadGoals(h.db);
    expect(view!.progress).toMatchObject({ done: 1, total: 4 });
    expect(view!.next?.uuid).toBe(register.uuid);
    expect(view!.nextParent?.uuid).toBe(task.uuid);
  });

  it('carries subtasks to another browser', async () => {
    const server = new FakeServer();
    const a = await device(server);
    const { task, find } = await race(a);
    await a.engine.sync();
    expect(server.get('goal_items', find.uuid)?.data).toMatchObject({ parentUuid: task.uuid });
    const b = await device(server);
    await b.engine.sync();
    expect(await item(b, find.uuid)).toEqual(await item(a, find.uuid));
  });
});

describe('subtasks in the archive', () => {
  it('writes ParentUuid and reads it back', async () => {
    const a = await device(new FakeServer());
    const { task, find } = await race(a);
    const { bytes } = await buildArchive(a.db, () => Promise.resolve(null), { now: new Date('2026-09-19T12:00:00.000Z'), includePlaces: false });
    const book = parseWorkbook(unzipSync(bytes)['harvest.xlsx']!);
    const sheet = book.get(SheetNames.goalItems)!;
    expect(sheet.headers.slice(0, sheetHeaders.goalItems.length)).toEqual(sheetHeaders.goalItems);
    expect(sheetHeaders.goalItems).toContain('ParentUuid');

    const b = await device(new FakeServer());
    await applyImport(b.writer, openArchive(bytes));
    expect((await item(b, find.uuid)).parentUuid).toBe(task.uuid);
    expect((await item(b, task.uuid)).parentUuid).toBeNull();
  });

  it('reads an archive from before subtasks as top-level items', async () => {
    const at = '2026-09-18T08:00:00.000Z';
    const old = sheetHeaders.goalItems.filter((header) => header !== 'ParentUuid');
    const workbook = buildWorkbook([
      new ExportSheet({
        name: SheetNames.goals,
        headers: sheetHeaders.goals,
        rows: [['g1', 'Read more', '', null, 'active', null, null, 0, at, at, null]],
      }),
      new ExportSheet({
        name: SheetNames.goalItems,
        headers: old,
        rows: [['i1', 'g1', 'step', 'Pick a book', null, null, 0, null, at, at, null]],
      }),
    ]);
    const h = await device(new FakeServer());
    await applyImport(h.writer, openArchive(zipSync({ 'harvest.xlsx': workbook, 'readme.txt': strToU8('') })));
    expect(await item(h, 'i1')).toMatchObject({ body: 'Pick a book', parentUuid: null });
  });
});

function show(h: Harvest, goal: string) {
  return render(
    <HarvestContext.Provider value={h}>
      <MemoryRouter initialEntries={[`/app/field/goals/${goal}`]}>
        <DialogsProvider>
          <Routes>
            <Route path="/app/field/goals" element={<GoalsBoard />} />
            <Route path="/app/field/goals/:uuid" element={<GoalScreen />} />
          </Routes>
        </DialogsProvider>
      </MemoryRouter>
      <Toaster />
    </HarvestContext.Provider>,
  );
}

async function menu(name: string) {
  const user = userEvent.setup();
  (await screen.findByRole('button', { name })).focus();
  await user.keyboard('{Enter}');
  return user;
}

describe('the goal screen', () => {
  it('names the sections, indents subtasks and counts them on the task', async () => {
    const h = await device(new FakeServer());
    const { goal, find } = await race(h);
    await h.goals.setDone(find.uuid, true);
    show(h, goal.uuid);
    expect(await screen.findByRole('heading', { name: 'Requirements — what it takes' })).toBeInTheDocument();
    expect(screen.getByRole('heading', { name: 'Tasks' })).toBeInTheDocument();
    const subtasks = screen.getByRole('list', { name: 'Subtasks of “Run a 10 km race”' });
    expect(within(subtasks).getAllByRole('checkbox')).toHaveLength(3);
    expect(screen.getByLabelText('Subtasks: 1 of 3 done')).toHaveTextContent('1 of 3');
  });

  it('ticks a task and all its subtasks with one click', async () => {
    const h = await device(new FakeServer());
    const { goal, task, find, register, run } = await race(h);
    show(h, goal.uuid);
    fireEvent.click(await screen.findByRole('checkbox', { name: /Run a 10 km race/ }));
    await waitFor(async () => {
      for (const sub of [task, find, register, run]) expect((await item(h, sub.uuid)).doneAt).not.toBeNull();
    });
    await waitFor(() => expect(screen.getByRole('checkbox', { name: /Register/ })).toBeChecked());
  });

  it('adds subtasks inline from the item’s menu, one after another', async () => {
    const h = await device(new FakeServer());
    const goal = await h.goals.create({ title: 'Half marathon' });
    const plan = await h.goals.addItem(goal.uuid, 'A training plan', 'need');
    show(h, goal.uuid);
    const user = await menu('Options for “A training plan”');
    await user.click(await screen.findByRole('menuitem', { name: 'Add a subtask' }));
    const input = await screen.findByRole('textbox', { name: 'Add a subtask to “A training plan”' });
    await user.type(input, 'Pick one{Enter}');
    await user.type(input, 'Print it{Enter}');
    await waitFor(async () => {
      const [view] = await loadGoals(h.db);
      expect(view!.subtasks.get(plan.uuid)?.map((sub) => [sub.body, sub.kind])).toEqual([
        ['Pick one', 'need'],
        ['Print it', 'need'],
      ]);
    });
  });

  it('lifts a subtask to a task of its own from its menu', async () => {
    const h = await device(new FakeServer());
    const { goal, run } = await race(h);
    show(h, goal.uuid);
    const user = await menu('Options for “Run it”');
    await user.click(await screen.findByRole('menuitem', { name: 'Make it a task of its own' }));
    await waitFor(async () => expect((await item(h, run.uuid)).parentUuid).toBeNull());
  });

  it('removes a task with its subtasks, and undo brings them back', async () => {
    const h = await device(new FakeServer());
    const { goal, task, find } = await race(h);
    show(h, goal.uuid);
    const user = await menu('Options for “Run a 10 km race”');
    await user.click(await screen.findByRole('menuitem', { name: 'Remove' }));
    expect(await screen.findByText('Removed, with its 3 subtasks')).toBeInTheDocument();
    expect((await item(h, find.uuid)).deletedAt).not.toBeNull();
    fireEvent.click(await screen.findByRole('button', { name: 'Undo' }));
    await waitFor(async () => expect((await item(h, task.uuid)).deletedAt).toBeNull());
    expect((await item(h, find.uuid)).deletedAt).toBeNull();
  });

  it('moves a subtask within its task with Alt+↓, keeping the keyboard on it', async () => {
    const h = await device(new FakeServer());
    const { goal, task } = await race(h);
    show(h, goal.uuid);
    const box = await screen.findByRole('checkbox', { name: /Find a race/ });
    expect(box).toHaveAttribute('aria-keyshortcuts', 'Alt+ArrowUp Alt+ArrowDown');
    box.focus();
    fireEvent.keyDown(box, { key: 'ArrowDown', altKey: true });
    await waitFor(async () => {
      const [view] = await loadGoals(h.db);
      expect(view!.subtasks.get(task.uuid)!.map((sub) => sub.body)).toEqual(['Register', 'Find a race', 'Run it']);
    });
    await waitFor(() => expect(screen.getByRole('checkbox', { name: /Find a race/ })).toHaveFocus());
    // Alt+↑ on the first one goes nowhere.
    const first = screen.getByRole('checkbox', { name: /Register/ });
    fireEvent.keyDown(first, { key: 'ArrowUp', altKey: true });
    const [view] = await loadGoals(h.db);
    expect(view!.subtasks.get(task.uuid)![0]!.body).toBe('Register');
  });

  it('moves an item under another one of the same goal', async () => {
    const h = await device(new FakeServer());
    const { goal, task } = await race(h);
    const shoes = await h.goals.addItem(goal.uuid, 'Shoes', 'need');
    show(h, goal.uuid);
    const user = await menu('Options for “Shoes”');
    await user.click(await screen.findByRole('menuitem', { name: 'Move under another item…' }));
    const dialog = await screen.findByRole('dialog', { name: 'Move “Shoes” under…' });
    await user.click(within(dialog).getByRole('button', { name: /Run a 10 km race/ }));
    await waitFor(async () => expect(await item(h, shoes.uuid)).toMatchObject({ parentUuid: task.uuid, kind: 'step' }));
    // A task with subtasks is not offered the move.
    const again = await menu('Options for “Run a 10 km race”');
    expect(await screen.findByRole('menuitem', { name: 'Add a subtask' })).toBeInTheDocument();
    expect(screen.queryByRole('menuitem', { name: 'Move under another item…' })).toBeNull();
    await again.keyboard('{Escape}');
  });
});

describe('the board', () => {
  it('rings subtasks in their task’s place and names the next open subtask', async () => {
    const h = await device(new FakeServer());
    const { goal, find } = await race(h);
    await h.goals.setDone(find.uuid, true);
    render(
      <HarvestContext.Provider value={h}>
        <MemoryRouter initialEntries={['/app/field/goals']}>
          <DialogsProvider>
            <GoalsBoard />
          </DialogsProvider>
        </MemoryRouter>
      </HarvestContext.Provider>,
    );
    expect(await screen.findByText('Register · in “Run a 10 km race”')).toBeInTheDocument();
    expect(screen.getAllByLabelText('1 of 3 done').length).toBeGreaterThan(0);
    expect(goal.title).toBe('Half marathon');
  });
});

describe('the Records tabs', () => {
  it('read Notes · Lists · Gallery · Places', async () => {
    const h = await device(new FakeServer());
    await h.settings.setMany({ 'features.notes': 'true', 'features.lists': 'true', 'features.gallery': 'true', 'features.places': 'true' });
    render(
      <HarvestContext.Provider value={h}>
        <MemoryRouter>
          <RecordsTabs />
        </MemoryRouter>
      </HarvestContext.Provider>,
    );
    await screen.findByRole('link', { name: 'Places' });
    expect(screen.getAllByRole('link').map((link) => link.textContent)).toEqual(['Notes', 'Lists', 'Gallery', 'Places']);
  });
});
