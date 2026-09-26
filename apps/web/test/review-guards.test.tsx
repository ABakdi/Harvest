import { HarvestDay, weightToGrams } from '@harvest/core';
import { act, fireEvent, render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter, Route, Routes } from 'react-router';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { GoalEditor } from '@/app/components/goal-editor';
import { SeedEditor } from '@/app/components/seed-editor';
import { SeedLogDialog } from '@/app/components/seed-log-dialog';
import { SeedNoteDialog } from '@/app/components/seed-note-dialog';
import { RatesCard, localIsoString } from '@/app/components/settings-rates';
import { SleepEditor } from '@/app/components/sleep-editor';
import { WeightEditor } from '@/app/components/weight-editor';
import { HarvestContext, type Harvest } from '@/app/context';
import { metaKeys, setMeta } from '@/app/data/db';
import { atMinutes, readNights } from '@/app/data/health';
import { readSetting } from '@/app/data/settings';
import { DialogsProvider } from '@/app/dialogs';
import { BodyScreen } from '@/app/screens/body';
import { FieldScreen } from '@/app/screens/field';
import { OnboardingScreen } from '@/app/screens/onboarding';
import { PomodoroSection } from '@/app/screens/settings';
import { FakeServer } from './fake-server';
import { device } from './helpers';

/**
 * The places a press, a sync or a clock could make the browser say or
 * write something the phone would not: a double submit, a night's
 * target rewritten, a weight read in the wrong unit, a half-finished
 * welcome.
 */

const today = HarvestDay.parse('2026-09-19');

function wrap(h: Harvest, children: React.ReactNode, at = '/app/field') {
  return (
    <HarvestContext.Provider value={h}>
      <MemoryRouter initialEntries={[at]}>
        <DialogsProvider>{children}</DialogsProvider>
      </MemoryRouter>
    </HarvestContext.Provider>
  );
}

/** Two submits in the same tick: a double click, or Enter held down. */
function submitTwice(form: HTMLElement) {
  act(() => {
    fireEvent.submit(form);
    fireEvent.submit(form);
  });
}

afterEach(() => {
  vi.unstubAllGlobals();
  vi.unstubAllEnvs();
});

describe('one press, one write', () => {
  it('logs a project once however fast the second press comes', async () => {
    const h = await device(new FakeServer());
    const seed = await h.seeds.plant({ type: 'project', title: 'Read', totalTarget: 300, dailyCommitment: 10 });
    render(wrap(h, <SeedLogDialog seed={seed} onClose={() => {}} />));
    const box = await screen.findByLabelText('How much did you get done?');
    await waitFor(() => expect(screen.getByRole('button', { name: 'Log' })).toBeEnabled());
    submitTwice(box.closest('form')!);

    await waitFor(async () => expect(await h.db.rows('check_ins').count()).toBe(1));
    await new Promise((resolve) => setTimeout(resolve, 50));
    expect(await h.db.rows('check_ins').count()).toBe(1);
    const xp = (await h.db.rows('ledger').toArray()).filter((row) => row.kind === 'xp');
    expect(xp).toHaveLength(1);
  });

  it('plants one seed, creates one goal and writes one note', async () => {
    const h = await device(new FakeServer());
    render(wrap(h, <SeedEditor state={{ mode: 'plant', prefill: { type: 'todo', title: 'Call home' } }} onClose={() => {}} />));
    submitTwice((await screen.findByRole('dialog')).querySelector('form')!);
    await waitFor(async () => expect(await h.db.rows('commitments').count()).toBe(1));

    render(wrap(h, <GoalEditor goal={null} onClose={() => {}} />));
    const goalDialog = await screen.findByRole('dialog', { name: 'New goal' });
    await userEvent.type(within(goalDialog).getByLabelText('What I’m working toward'), 'Run a marathon');
    submitTwice(goalDialog.querySelector('form')!);
    await waitFor(async () => expect(await h.db.rows('goals').count()).toBe(1));

    const [seed] = await h.db.rows('commitments').toArray();
    render(wrap(h, <SeedNoteDialog seed={seed!} onClose={() => {}} />));
    const note = await screen.findByLabelText(/Note for/);
    await userEvent.type(note, 'Page 143');
    submitTwice(note.closest('form')!);
    await waitFor(async () => expect(await h.db.rows('seed_notes').count()).toBe(1));

    await new Promise((resolve) => setTimeout(resolve, 50));
    expect(await h.db.rows('commitments').count()).toBe(1);
    expect(await h.db.rows('goals').count()).toBe(1);
    expect(await h.db.rows('seed_notes').count()).toBe(1);
  });
});

describe('a night written down again', () => {
  it('keeps the target it was first written against, and its note (Business rule 3)', async () => {
    const h = await device(new FakeServer());
    await h.health.logNight({
      day: today,
      fellAsleepAt: atMinutes(today, -60),
      wokeAt: atMinutes(today, 420),
      targetMinutes: 480,
      restedStars: 3,
      note: 'Late coffee',
    });
    // My hours changed since; correcting the night must not rewrite it.
    await h.health.logNight({
      day: today,
      fellAsleepAt: atMinutes(today, -30),
      wokeAt: atMinutes(today, 420),
      targetMinutes: 420,
      restedStars: 4,
    });
    const [night] = await readNights(h.db);
    expect(night).toMatchObject({ targetMinutes: 480, note: 'Late coffee', restedStars: 4 });
  });

  it('shows the time between the instants it saves, on the night the clocks go back', async () => {
    vi.stubEnv('TZ', 'Europe/Paris');
    const h = await device(new FakeServer());
    const morning = HarvestDay.parse('2026-10-25');
    render(wrap(h, <SleepEditor day={morning} night={null} onClose={() => {}} />));
    fireEvent.change(await screen.findByLabelText('Fell asleep'), { target: { value: '23:00' } });
    fireEvent.change(screen.getByLabelText('Woke'), { target: { value: '07:00' } });
    // Eight hours on the clock face, nine slept: 03:00 came round twice.
    expect(await screen.findByText('9h 0m')).toBeInTheDocument();
    await userEvent.click(screen.getByRole('button', { name: 'Write it down' }));
    await waitFor(async () => expect(await readNights(h.db)).toHaveLength(1));
    const [night] = await readNights(h.db);
    expect((Date.parse(night!.wokeAt) - Date.parse(night!.fellAsleepAt)) / 60_000).toBe(9 * 60);
  });
});

describe('a weight edited across units', () => {
  it('reads the unchanged number in the new unit once the unit is switched', async () => {
    const h = await device(new FakeServer());
    const weight = await h.health.logWeight({ grams: 82_460, note: null });
    const view = render(wrap(h, <WeightEditor weight={weight} unit="kg" onClose={() => {}} />));
    const box = await screen.findByLabelText('Weight (kg)');
    const shown = (box as HTMLInputElement).value;
    // The toggle writes the setting; the page hands the new unit down.
    view.rerender(wrap(h, <WeightEditor weight={weight} unit="lb" onClose={() => {}} />));
    await userEvent.click(screen.getByRole('button', { name: 'Save' }));
    await waitFor(async () =>
      expect((await h.db.rows('body_weights').get(weight.uuid))?.grams).toBe(weightToGrams('lb', Number(shown))),
    );
  });

  it('keeps the exact grams when only the note changes', async () => {
    const h = await device(new FakeServer());
    const weight = await h.health.logWeight({ grams: 82_460, note: null });
    render(wrap(h, <WeightEditor weight={weight} unit="kg" onClose={() => {}} />));
    await userEvent.type(await screen.findByLabelText('Note'), 'After the run');
    await userEvent.click(screen.getByRole('button', { name: 'Save' }));
    await waitFor(async () => expect((await h.db.rows('body_weights').get(weight.uuid))?.note).toBe('After the run'));
    expect((await h.db.rows('body_weights').get(weight.uuid))?.grams).toBe(82_460);
  });
});

describe('a project done for today', () => {
  it('still offers to log, and does not call the button "Undo"', async () => {
    const h = await device(new FakeServer());
    const seed = await h.seeds.plant({ type: 'project', title: 'Read', totalTarget: 300, dailyCommitment: 10 });
    await h.checkIns.checkIn(seed, today, 10);
    render(wrap(h, <FieldScreen tab="today" />));
    await userEvent.click(await screen.findByRole('button', { name: 'Log progress on “Read”' }));
    expect(await screen.findByRole('dialog', { name: 'Log progress' })).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: /Undo/ })).not.toBeInTheDocument();
  });
});

describe('the fetched rate', () => {
  it('is stamped as the phone stamps it: local wall time, no offset', async () => {
    expect(localIsoString(new Date(2026, 8, 19, 7, 5, 3, 9))).toBe('2026-09-19T07:05:03.009');
    const h = await device(new FakeServer());
    const get = vi.fn(() => Promise.resolve(new Response(JSON.stringify({ rates: { USD: 1.17 } }), { status: 200 })));
    vi.stubGlobal('fetch', get);
    render(wrap(h, <RatesCard />));
    const button = await screen.findByRole('button', { name: 'Fetch' });
    act(() => {
      fireEvent.click(button);
      fireEvent.click(button);
    });
    await waitFor(async () => expect(await readSetting(h.db, 'rate.usdPerEur')).toBe('1.17'));
    expect(get).toHaveBeenCalledTimes(1);
    const at = await readSetting(h.db, 'rate.usdPerEurAt');
    expect(at).toMatch(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}$/);
  });
});

describe('the welcome', () => {
  it('writes all of its answer or none of it', async () => {
    const h = await device(new FakeServer());
    await setMeta(h.db, metaKeys.lastSyncedAt, '2026-09-19T12:00:00.000Z');
    await h.engine.refreshCounts();
    // The last write of the answer fails.
    const refuse = (_key: unknown, row: { key: string }) => {
      if (row.key === 'onboarding.done') throw new Error('disk full');
    };
    h.db.rows('kv_settings').hook('creating', refuse);
    render(
      wrap(
        h,
        <Routes>
          <Route path="/app/welcome" element={<OnboardingScreen />} />
          <Route path="/app/field" element={<p>The field</p>} />
        </Routes>,
        '/app/welcome',
      ),
    );
    for (let page = 0; page < 3; page++) await userEvent.click(await screen.findByRole('button', { name: 'Next' }));
    await userEvent.click(screen.getByRole('button', { name: 'Start growing' }));
    await waitFor(() => expect(screen.getByRole('button', { name: 'Start growing' })).toBeEnabled());
    // Nothing planted, so the welcome is still owed.
    expect(await h.db.rows('commitments').count()).toBe(0);
    expect(await readSetting(h.db, 'dailyHarvestGoal')).toBeNull();

    h.db.rows('kv_settings').hook('creating').unsubscribe(refuse);
    await userEvent.click(screen.getByRole('button', { name: 'Start growing' }));
    expect(await screen.findByText('The field')).toBeInTheDocument();
    expect(await h.db.rows('commitments').count()).toBe(2);
    expect(await readSetting(h.db, 'onboarding.done')).toBe('true');
  });
});

describe('the body routes', () => {
  it('open on the tab the path names, even with the screen still up', async () => {
    const h = await device(new FakeServer());
    await h.settings.setBool('features.health', true);
    await h.settings.setBool('features.gym', true);
    const view = render(wrap(h, <BodyScreen />, '/app/body'));
    expect(await screen.findByRole('tab', { name: 'Health', selected: true })).toBeInTheDocument();
    view.rerender(wrap(h, <BodyScreen tab="gym" />, '/app/body'));
    expect(await screen.findByRole('tab', { name: 'Training', selected: true })).toBeInTheDocument();
    view.rerender(wrap(h, <BodyScreen tab="health" />, '/app/body'));
    expect(await screen.findByRole('tab', { name: 'Health', selected: true })).toBeInTheDocument();
  });
});

describe('the focus steppers', () => {
  it('count every quick press, and stop at the edge', async () => {
    const h = await device(new FakeServer());
    render(wrap(h, <PomodoroSection />));
    const more = await screen.findByRole('button', { name: 'More: Short break' });
    await waitFor(() => expect(more).toBeEnabled());
    // Each press is its own event, faster than the stored value is
    // read back.
    fireEvent.click(more);
    fireEvent.click(more);
    fireEvent.click(more);
    await waitFor(async () => expect(await readSetting(h.db, 'pomodoro.shortBreakMinutes')).toBe('8'));

    const less = screen.getByRole('button', { name: 'Less: Blocks before a long break' });
    await waitFor(() => expect(less).toBeEnabled());
    for (let press = 0; press < 5; press++) fireEvent.click(less);
    await waitFor(async () => expect(await readSetting(h.db, 'pomodoro.blocksPerLongBreak')).toBe('2'));
  });
});
