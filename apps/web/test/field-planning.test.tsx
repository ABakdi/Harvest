import { HarvestDay, freezeCost } from '@harvest/core';
import { render, screen, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter } from 'react-router';
import { describe, expect, it } from 'vitest';
import { SeedLogDialog } from '@/app/components/seed-log-dialog';
import { HarvestContext, type Harvest } from '@/app/context';
import { readFieldGauges, readTomorrow } from '@/app/data/field';
import { readStats, weekReport } from '@/app/data/stats';
import { buyFreeze } from '@/app/data/streaks';
import { DialogsProvider } from '@/app/dialogs';
import { CalendarScreen } from '@/app/screens/calendar';
import { FarmerScreen } from '@/app/screens/farmer';
import { FieldScreen } from '@/app/screens/field';
import { FakeServer } from './fake-server';
import { device } from './helpers';

// A Saturday; tomorrow is the Sunday that ends the week.
const today = HarvestDay.parse('2026-09-19');

function renderIn(h: Harvest, children: React.ReactNode, at = '/app/field') {
  render(
    <HarvestContext.Provider value={h}>
      <MemoryRouter initialEntries={[at]}>
        <DialogsProvider>{children}</DialogsProvider>
      </MemoryRouter>
    </HarvestContext.Provider>,
  );
}

async function giveCoins(h: Harvest, coins: number) {
  await h.writer.run((tx) => tx.ledger({ kind: 'coin', delta: coins, reason: 'streak:7', harvestDay: today.key }));
}

describe('tomorrow', () => {
  it('lists the habits due and the to-dos planned for it, and not the done ones', async () => {
    const h = await device(new FakeServer());
    await h.seeds.plant({ type: 'habit', title: 'Walk', schedule: { type: 'daily' } });
    await h.seeds.plant({ type: 'habit', title: 'Swim', schedule: { type: 'weekly', weekdays: new Set([1]) } });
    // Twice a week, and both done this week: not due again on Sunday.
    const gym = await h.seeds.plant({ type: 'habit', title: 'Gym', schedule: { type: 'timesPerWeek', times: 2 } });
    await h.checkIns.checkIn(gym, today.addDays(-1));
    await h.checkIns.checkIn(gym, today);
    await h.seeds.plant({ type: 'todo', title: 'Call the dentist', dueDay: '2026-09-20' });
    const done = await h.seeds.plant({ type: 'todo', title: 'Post the letter', dueDay: '2026-09-20' });
    await h.checkIns.checkIn(done, today);
    await h.seeds.plant({ type: 'project', title: 'Read', totalTarget: 300, dailyCommitment: 10 });

    const plan = await readTomorrow(h.db, today);
    expect(plan.day.key).toBe('2026-09-20');
    expect(plan.habits.map((row) => row.title)).toEqual(['Walk']);
    expect(plan.todos.map((row) => row.title)).toEqual(['Call the dentist']);
  });

  it('plans a to-do for tomorrow from the field, and removing it archives it', async () => {
    const h = await device(new FakeServer());
    renderIn(h, <FieldScreen tab="today" />);
    await userEvent.click(await screen.findByRole('button', { name: /Tomorrow ·/ }));
    const dialog = await screen.findByRole('dialog', { name: 'Tomorrow’s plan' });
    await userEvent.type(within(dialog).getByLabelText('Plant a to-do for tomorrow…'), 'Buy bread{Enter}');
    expect(await within(dialog).findByText('Buy bread')).toBeInTheDocument();
    const [row] = await h.db.rows('commitments').toArray();
    expect(row).toMatchObject({ type: 'todo', title: 'Buy bread', dueDay: '2026-09-20' });

    await userEvent.click(within(dialog).getByRole('button', { name: 'Remove “Buy bread”' }));
    expect((await h.db.rows('commitments').get(row!.uuid))?.archivedAt).not.toBeNull();
  });
});

describe('the calendar', () => {
  it('plants a to-do on the day chosen, and only on a day still to come', async () => {
    const h = await device(new FakeServer());
    renderIn(h, <CalendarScreen />, '/app/field/calendar');
    await userEvent.click(await screen.findByRole('button', { name: /Wed, Sep 23/ }));
    await userEvent.type(screen.getByLabelText('Plant a to-do for this day…'), 'Passport{Enter}');
    const rows = await h.db.rows('commitments').toArray();
    expect(rows).toMatchObject([{ type: 'todo', title: 'Passport', dueDay: '2026-09-23' }]);
    expect(await screen.findByRole('link', { name: /Passport/ })).toHaveAttribute('href', `/app/field/seed/${rows[0]!.uuid}`);

    await userEvent.click(screen.getByRole('button', { name: /Thu, Sep 17/ }));
    expect(screen.queryByLabelText('Plant a to-do for this day…')).not.toBeInTheDocument();
  });
});

describe('a project reaching its target', () => {
  it('celebrates, then goes to the barn with its history', async () => {
    const h = await device(new FakeServer());
    const seed = await h.seeds.plant({ type: 'project', title: 'Read', totalTarget: 20, dailyCommitment: 10 });
    await h.checkIns.checkIn(seed, today.previous, 12);
    render(
      <HarvestContext.Provider value={h}>
        <SeedLogDialog seed={seed} onClose={() => {}} />
      </HarvestContext.Provider>,
    );
    const box = await screen.findByLabelText('How much did you get done?');
    await userEvent.clear(box);
    await userEvent.type(box, '8');
    await userEvent.click(screen.getByRole('button', { name: 'Log' }));
    expect(await screen.findByText('Harvest complete!')).toBeInTheDocument();
    expect(screen.getByText(/fully grown — 20 logged/)).toBeInTheDocument();
    await userEvent.click(screen.getByRole('button', { name: 'Archive' }));
    const row = await h.db.rows('commitments').get(seed.uuid);
    expect(row?.archivedAt).not.toBeNull();
    expect(await h.db.rows('check_ins').where('commitmentUuid').equals(seed.uuid).count()).toBe(2);
  });
});

describe('streak freezes', () => {
  it('costs coins, and refuses without enough or with a full shed', async () => {
    const h = await device(new FakeServer());
    expect(await buyFreeze(h.writer, today)).toBe(false);
    await giveCoins(h, 250);
    expect(await buyFreeze(h.writer, today)).toBe(true);
    expect(await buyFreeze(h.writer, today)).toBe(true);
    // Two stored is the most; the last fifty coins stay.
    expect(await buyFreeze(h.writer, today)).toBe(false);
    expect((await h.db.rows('streaks').get('global'))?.freezesStored).toBe(2);
    const spent = await h.db.rows('ledger').where('reason').equals('freeze:buy').toArray();
    expect(spent.map((row) => row.delta)).toEqual([-freezeCost, -freezeCost]);
  });

  it('is bought from the farmer', async () => {
    const h = await device(new FakeServer());
    await giveCoins(h, 120);
    renderIn(h, <FarmerScreen />, '/app/farmer');
    await userEvent.click(await screen.findByRole('button', { name: 'Buy a freeze · 100 coins' }));
    expect(await screen.findByText('Streak freezes: 1 of 2')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Buy a freeze · 100 coins' })).toBeDisabled();
    expect(screen.getByText('Earn 50 coins at a 7-day streak.')).toBeInTheDocument();
  });
});

describe('the week’s report', () => {
  it('finds the best and the quietest day, the XP, and where the money went', () => {
    const report = weekReport(
      today,
      [
        { commitmentUuid: 'a', harvestDay: '2026-09-15', deletedAt: null },
        { commitmentUuid: 'b', harvestDay: '2026-09-15', deletedAt: null },
        { commitmentUuid: 'a', harvestDay: '2026-09-16', deletedAt: null },
        { commitmentUuid: 'a', harvestDay: '2026-09-10', deletedAt: null },
      ],
      [
        { kind: 'xp', delta: 10, harvestDay: '2026-09-15' },
        { kind: 'xp', delta: 30, harvestDay: '2026-09-12' },
        { kind: 'coin', delta: 50, harvestDay: '2026-09-15' },
      ],
      [
        { harvestDay: '2026-09-16', deletedAt: null, category: 'food', currency: 'DZD', amountMinor: 500 },
        { harvestDay: '2026-09-17', deletedAt: null, category: 'transport', currency: 'DZD', amountMinor: 900 },
        { harvestDay: '2026-09-18', deletedAt: '2026-09-18T10:00:00.000Z', category: 'bills', currency: 'DZD', amountMinor: 9000 },
      ],
      { defaultCurrency: 'DZD' },
    );
    expect(report.xp).toBe(10);
    expect(report.best.key).toBe('2026-09-15');
    expect(report.worst?.key).toBe('2026-09-14');
    expect(report.topCategory).toBe('transport');
  });

  it('shows the report, the projects and the best streak with the farmer’s stats', async () => {
    const h = await device(new FakeServer());
    const walk = await h.seeds.plant({ type: 'habit', title: 'Walk', schedule: { type: 'daily' } });
    const read = await h.seeds.plant({ type: 'project', title: 'Read', totalTarget: 300, dailyCommitment: 10 });
    await h.checkIns.checkIn(walk, today);
    await h.checkIns.checkIn(read, today, 10);

    const stats = await readStats(h.db, today);
    expect(stats.projects).toEqual([{ uuid: read.uuid, title: 'Read', total: 10, target: 300 }]);
    expect(stats.week.xp).toBe(30);

    renderIn(h, <FarmerScreen />, '/app/farmer');
    expect(await screen.findByText('This week')).toBeInTheDocument();
    expect(screen.getByText('Best: Saturday')).toBeInTheDocument();
    expect(screen.getByText('10 of 300')).toBeInTheDocument();
    expect(screen.getByRole('link', { name: /Walk/ })).toHaveAttribute('href', `/app/field/seed/${walk.uuid}`);
  });
});

describe('the field', () => {
  it('shows what is left of the day’s budget, and the sleep owed when Health is on', async () => {
    const h = await device(new FakeServer());
    expect(await readFieldGauges(h.db, today)).toEqual({ budgetLeft: null, sleepOwed: null });
    await h.settings.setString('finance.monthlyBudgetMinor', '1200000');
    await h.settings.setString('features.health', 'true');
    const gauges = await readFieldGauges(h.db, today);
    // Twelve thousand over the twelve days left of September.
    expect(gauges.budgetLeft).toBe(100000);
    expect(gauges.sleepOwed).toBeNull();

    renderIn(h, <FieldScreen tab="today" />);
    expect(await screen.findByRole('link', { name: /left today/ })).toHaveAttribute('href', '/app/granary');
  });

  it('shows today’s note on the card and opens the seed’s history from it', async () => {
    const h = await device(new FakeServer());
    const seed = await h.seeds.plant({ type: 'habit', title: 'Walk', schedule: { type: 'daily' } });
    await h.seedNotes.write(seed.uuid, today, 'around the lake');
    renderIn(h, <FieldScreen tab="today" />);
    expect(await screen.findByText('around the lake')).toBeInTheDocument();
    expect(screen.getByRole('link', { name: 'Walk' })).toHaveAttribute('href', `/app/field/seed/${seed.uuid}`);
  });
});
