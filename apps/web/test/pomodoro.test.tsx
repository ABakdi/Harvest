import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter } from 'react-router';
import { describe, expect, it } from 'vitest';
import { PomodoroChip } from '@/app/components/pomodoro-timer';
import { HarvestContext, type Harvest } from '@/app/context';
import { advance, defaultPomodoroConfig, pomodoroKeys, readActive, readPomodoroConfig } from '@/app/data/pomodoro';
import { PomodoroScreen } from '@/app/screens/pomodoro';
import { FakeServer } from './fake-server';
import { device } from './helpers';

const minute = 60_000;

async function xpFor(h: Harvest, sessionUuid: string) {
  const rows = await h.db.rows('ledger').where('reason').equals(`pomodoro:${sessionUuid}`).toArray();
  return rows.reduce((sum, row) => sum + row.delta, 0);
}

describe('the focus timer', () => {
  it('reads the phone’s lengths, and its defaults when they are not set', async () => {
    const h = await device(new FakeServer());
    expect(await readPomodoroConfig(h.db)).toEqual(defaultPomodoroConfig);
    await h.settings.setString(pomodoroKeys.focus, '50');
    await h.settings.setString(pomodoroKeys.blocksPerLong, 'two');
    expect(await readPomodoroConfig(h.db)).toMatchObject({ focusMinutes: 50, blocksPerLongBreak: 4 });
  });

  it('starts a session row and keeps the running timer on this device only', async () => {
    const h = await device(new FakeServer());
    const snapshot = await h.pomodoro.start(null);
    const row = await h.db.rows('pomodoro_sessions').get(snapshot.sessionUuid);
    expect(row).toMatchObject({ focusBlocks: 0, harvestDay: '2026-09-19', endedAt: null, commitmentUuid: null });
    expect(snapshot.endsAt).toBe('2026-09-19T12:25:00.000Z');
    const queued = await h.db.outbox.toArray();
    expect(queued.some((entry) => entry.table === 'pomodoro_sessions')).toBe(true);
    expect(queued.some((entry) => entry.key === pomodoroKeys.active)).toBe(false);
  });

  it('pays five XP per finished focus block, once, and starts the break', async () => {
    const h = await device(new FakeServer());
    const { sessionUuid } = await h.pomodoro.start(null);
    h.clock.advance(25 * minute);
    const [first, second] = await Promise.all([h.pomodoro.evaluate(), h.pomodoro.evaluate()]);
    expect([first?.blocks.length ?? 0, second?.blocks.length ?? 0].sort()).toEqual([0, 1]);
    expect(await xpFor(h, sessionUuid)).toBe(5);
    expect((await h.db.rows('pomodoro_sessions').get(sessionUuid))?.focusBlocks).toBe(1);
    expect(await readActive(h.db)).toMatchObject({ phase: 'shortBreak', blocksDone: 1, endsAt: '2026-09-19T12:30:00.000Z' });
  });

  it('waits after a break for the next block to be started', async () => {
    const h = await device(new FakeServer());
    await h.pomodoro.start(null);
    h.clock.advance(31 * minute);
    const step = await h.pomodoro.evaluate();
    expect(step?.breakOver).toBe(true);
    expect(await readActive(h.db)).toMatchObject({ phase: 'focus', endsAt: null, pausedRemaining: 25 * 60, userPaused: false });
    await h.pomodoro.resume();
    expect((await readActive(h.db))?.endsAt).toBe('2026-09-19T12:56:00.000Z');
  });

  it('takes the long break after the configured number of blocks', () => {
    const config = { ...defaultPomodoroConfig, blocksPerLongBreak: 2 };
    const step = advance(
      {
        sessionUuid: 's',
        phase: 'focus',
        blocksDone: 1,
        commitmentUuid: null,
        endsAt: '2026-09-19T12:00:00.000Z',
        pausedRemaining: null,
        userPaused: false,
      },
      config,
      new Date('2026-09-19T12:00:01.000Z'),
    );
    expect(step.next).toMatchObject({ phase: 'longBreak', blocksDone: 2, endsAt: '2026-09-19T12:15:00.000Z' });
  });

  it('pauses with the time left, and resumes from it', async () => {
    const h = await device(new FakeServer());
    await h.pomodoro.start(null);
    h.clock.advance(10 * minute);
    await h.pomodoro.pause();
    expect(await readActive(h.db)).toMatchObject({ endsAt: null, pausedRemaining: 15 * 60, userPaused: true });
    h.clock.advance(60 * minute);
    expect(await h.pomodoro.evaluate()).toBeNull();
    await h.pomodoro.resume();
    expect((await readActive(h.db))?.endsAt).toBe('2026-09-19T13:25:00.000Z');
  });

  it('abandons without XP, and ends the session', async () => {
    const h = await device(new FakeServer());
    const { sessionUuid } = await h.pomodoro.start(null);
    h.clock.advance(20 * minute);
    await h.pomodoro.abandon();
    expect(await readActive(h.db)).toBeNull();
    expect(await xpFor(h, sessionUuid)).toBe(0);
    expect((await h.db.rows('pomodoro_sessions').get(sessionUuid))?.endedAt).toBe('2026-09-19T12:20:00.000Z');
  });

  it('offers the seed a check-in only after a fruitful session', async () => {
    const h = await device(new FakeServer());
    const seed = await h.seeds.plant({ type: 'habit', title: 'Write', schedule: { type: 'daily' } });
    await h.pomodoro.start(seed.uuid);
    expect(await h.pomodoro.finish()).toBeNull();
    await h.pomodoro.start(seed.uuid);
    h.clock.advance(26 * minute);
    await h.pomodoro.evaluate();
    expect(await h.pomodoro.finish()).toBe(seed.uuid);
  });

  it('runs from the screen: start, the header chip, and a finish that checks the seed in', async () => {
    const h = await device(new FakeServer());
    const seed = await h.seeds.plant({ type: 'habit', title: 'Write', schedule: { type: 'daily' } });
    render(
      <HarvestContext.Provider value={h}>
        <MemoryRouter initialEntries={[`/app/field/focus?seed=${seed.uuid}`]}>
          <PomodoroChip />
          <PomodoroScreen />
        </MemoryRouter>
      </HarvestContext.Provider>,
    );
    expect(await screen.findByText('Write')).toBeInTheDocument();
    expect(screen.getByText('25:00')).toBeInTheDocument();
    await userEvent.click(screen.getByRole('button', { name: 'Start focus' }));
    expect(await screen.findByRole('link', { name: 'Focus timer, 25:00 left' })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Abandon' })).toBeInTheDocument();

    // A block passes while the tab is away; the chip settles it.
    h.clock.advance(25 * minute);
    await h.pomodoro.evaluate();
    await userEvent.click(await screen.findByRole('button', { name: 'Finish session' }));
    await screen.findByRole('button', { name: 'Start focus' });
    const checkIns = await h.db.rows('check_ins').where('commitmentUuid').equals(seed.uuid).toArray();
    expect(checkIns).toHaveLength(1);
  });
});
