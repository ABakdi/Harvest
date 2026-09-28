import { describe, expect, it } from 'vitest';
import { buildArchive } from '@/app/data/export';
import { applyImport, openArchive } from '@/app/data/import';
import { FakeServer } from './fake-server';
import { device, syncing } from './helpers';

/** A parent's tick is drawn from its subtasks after a sync or an import ([[Goals]] GL3, Q5-44). */
describe("a parent's tick, settled again", () => {
  it('after a sync brought subtasks from two devices', async () => {
    const server = new FakeServer();
    const a = await syncing(server);
    const b = await syncing(server);
    const goal = await a.goals.create({ title: 'Move' });
    const parent = await a.goals.addItem(goal.uuid, 'Pack');
    const first = (await a.goals.addSubtask(parent.uuid, 'Books'))!;
    await a.engine.sync();
    await b.engine.sync();

    a.clock.advance(60_000);
    await a.goals.setDone(first.uuid, true);
    b.clock.advance(120_000);
    await b.goals.addSubtask(parent.uuid, 'Plates');
    await a.engine.sync();
    await b.engine.sync();
    await b.engine.sync();
    await a.engine.sync();

    for (const h of [a, b]) {
      expect((await h.db.rows('goal_items').get(parent.uuid))?.doneAt, 'Plates is still open').toBeNull();
    }
  });

  it('after an import of a ticked parent over an open subtask', async () => {
    const a = await device(new FakeServer());
    const goal = await a.goals.create({ title: 'Move' });
    const parent = await a.goals.addItem(goal.uuid, 'Pack');
    await a.goals.addSubtask(parent.uuid, 'Books');
    const built = await buildArchive(a.db, (hash) => a.files.get(hash));
    const bundle = openArchive(built.bytes);
    // Ticked, as an older app or a hand-edited sheet can leave it.
    const row = bundle.sheets.get('GoalItems')!.find((item) => item.Uuid === parent.uuid)!;
    row.DoneAt = '2026-09-19T12:00:00.000Z';

    const b = await device(new FakeServer());
    await applyImport(b.writer, bundle);
    expect((await b.db.rows('goal_items').get(parent.uuid))?.doneAt).toBeNull();
  });
});
