import { HarvestDay } from '@harvest/core';
import { render, screen } from '@testing-library/react';
import { MemoryRouter } from 'react-router';
import { describe, expect, it } from 'vitest';
import { HarvestContext } from '@/app/context';
import { readMonth } from '@/app/data/calendar';
import { readStats } from '@/app/data/stats';
import { CalendarScreen } from '@/app/screens/calendar';
import { FakeServer } from './fake-server';
import { device } from './helpers';

const today = HarvestDay.parse('2026-09-19');

/**
 * The month and the run: both are the log, counted. What they owe is
 * the same answer the field gives for a day, and the same count the
 * streak is judged by.
 */
describe('the calendar', () => {
  it('puts a habit on the days it is due, and a to-do on its deadline', async () => {
    const h = await device(new FakeServer());
    const habit = await h.seeds.plant({ type: 'habit', title: 'Walk', schedule: { type: 'weekly', weekdays: new Set([6]) } });
    const todo = await h.seeds.plant({ type: 'todo', title: 'Passport', deadline: '2026-09-24' });

    const month = await readMonth(h.db, today);
    // Saturdays in September 2026, from the day it was planted.
    const walkDays = [...month.values()]
      .filter((day) => day.entries.some((entry) => entry.row.uuid === habit.uuid))
      .map((day) => day.day.key);
    expect(walkDays).toEqual(['2026-09-19', '2026-09-26']);

    const deadline = month.get('2026-09-24');
    expect(deadline?.entries.some((entry) => entry.deadline && entry.row.uuid === todo.uuid)).toBe(true);
  });

  it('keeps a to-do on its planned day, done or not, as the phone does', async () => {
    const h = await device(new FakeServer());
    const todo = await h.seeds.plant({ type: 'todo', title: 'Call the bank', dueDay: '2026-09-20' });

    const month = await readMonth(h.db, today);
    const days = [...month.values()]
      .filter((day) => day.entries.some((entry) => !entry.deadline && entry.row.uuid === todo.uuid))
      .map((day) => day.day.key);
    expect(days).toEqual(['2026-09-20']);
  });

  it('keeps projects off the grid, since they are due every day', async () => {
    const h = await device(new FakeServer());
    await h.seeds.plant({ type: 'project', title: 'Read', totalTarget: 300, dailyCommitment: 10 });
    const month = await readMonth(h.db, today);
    expect([...month.values()].every((day) => day.entries.length === 0)).toBe(true);
  });

  it('marks the day it was asked about', async () => {
    const h = await device(new FakeServer());
    render(
      <MemoryRouter initialEntries={['/app/field/calendar']}>
        <HarvestContext.Provider value={h}>
          <CalendarScreen />
        </HarvestContext.Provider>
      </MemoryRouter>,
    );
    expect(await screen.findByText('September 2026')).toBeInTheDocument();
    expect(screen.getByText('Nothing due that day.')).toBeInTheDocument();
  });
});

describe('the run so far', () => {
  it('counts a day by its productive actions, in whole weeks', async () => {
    const h = await device(new FakeServer());
    const seed = await h.seeds.plant({ type: 'habit', title: 'Walk', schedule: { type: 'daily' } });
    await h.checkIns.checkIn(seed, today);

    const stats = await readStats(h.db, today);
    expect(stats.heat).toHaveLength(17 * 7);
    expect(stats.heat.at(-1)?.day.weekday).toBe(7);
    expect(stats.heat.find((day) => day.key === today.key)?.actions).toBe(1);
    expect(stats.busiest).toBe(1);
    expect(stats.seeds[0]).toMatchObject({ title: 'Walk', current: 1 });
    expect(stats.checkIns).toBe(1);
  });
});
