import { HarvestDay } from '@harvest/core';
import { fireEvent, render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it } from 'vitest';
import { nightFromClocks } from '@/app/components/sleep-editor';
import { HarvestContext } from '@/app/context';
import { atMinutes, readNights, readWeights, stepsHistory } from '@/app/data/health';
import { BodyScreen } from '@/app/screens/body';
import { FakeServer } from './fake-server';
import { device } from './helpers';

/**
 * Writing the body down from the browser: a night and a weight, with
 * the XP the phone pays for them and takes back, and the steps month
 * read from what the phone counted ([[Health]]).
 */

type Device = Awaited<ReturnType<typeof device>>;

async function xp(h: Device, prefix: string) {
  return (await h.db.rows('ledger').toArray()).filter((row) => row.reason.startsWith(prefix));
}

const morning = HarvestDay.parse('2026-09-19');

describe('a night, written down', () => {
  it('pays +15 XP once, and correcting the morning replaces it without paying again', async () => {
    const h = await device(new FakeServer());
    const first = await h.health.logNight({
      day: morning,
      fellAsleepAt: atMinutes(morning, -60),
      wokeAt: atMinutes(morning, 7 * 60),
      targetMinutes: 480,
      restedStars: 3,
    });
    const again = await h.health.logNight({
      day: morning,
      fellAsleepAt: atMinutes(morning, -30),
      wokeAt: atMinutes(morning, 7 * 60),
      targetMinutes: 480,
      restedStars: null,
    });

    expect(first).toBe(true);
    expect(again).toBe(false);
    // One morning, one night (H8): the second write replaced the first.
    const nights = await readNights(h.db);
    expect(nights).toHaveLength(1);
    expect(nights[0]?.restedStars).toBeNull();
    expect((await xp(h, 'sleep')).map((row) => row.delta)).toEqual([15]);
    // Queued for the phone.
    expect((await h.db.outbox.toArray()).some((entry) => entry.table === 'sleep_sessions')).toBe(true);
  });

  it('takes the XP back with a mirror row when the night is deleted', async () => {
    const h = await device(new FakeServer());
    await h.health.logNight({
      day: morning,
      fellAsleepAt: atMinutes(morning, -60),
      wokeAt: atMinutes(morning, 7 * 60),
      targetMinutes: 480,
      restedStars: null,
    });
    const [night] = await readNights(h.db);
    await h.health.removeNight(night!.uuid);

    expect(await readNights(h.db)).toEqual([]);
    const rows = await xp(h, 'sleep');
    expect(rows.map((row) => [row.reason.split(':')[0], row.delta])).toEqual(
      expect.arrayContaining([
        ['sleep', 15],
        ['sleep-undo', -15],
      ]),
    );
    expect(rows.reduce((sum, row) => sum + row.delta, 0)).toBe(0);
  });

  it('reads two clocks as a night around the morning’s midnight', () => {
    expect(nightFromClocks('23:00', '07:00')).toEqual({ asleep: -60, woke: 420 });
    expect(nightFromClocks('01:30', '09:15')).toEqual({ asleep: 90, woke: 555 });
    // A night shift: asleep at nine in the morning, up at three.
    expect(nightFromClocks('09:00', '15:00')).toEqual({ asleep: 540, woke: 900 });
    // Waking at six in the evening is outside what the phone allows.
    expect(nightFromClocks('10:00', '18:00')).toBeNull();
  });

  it('is written from the dialog, pre-filled with the night the cycle expects', async () => {
    const h = await device(new FakeServer());
    await h.settings.setBool('features.health', true);
    render(
      <HarvestContext.Provider value={h}>
        <BodyScreen />
      </HarvestContext.Provider>,
    );

    await userEvent.click(await screen.findByRole('button', { name: 'Log last night' }, { timeout: 5000 }));
    const dialog = await screen.findByRole('dialog');
    // 11 PM to 7 AM, before anyone said otherwise.
    expect(within(dialog).getByLabelText('Fell asleep')).toHaveValue('23:00');
    expect(within(dialog).getByLabelText('Woke')).toHaveValue('07:00');
    fireEvent.change(within(dialog).getByLabelText('Fell asleep'), { target: { value: '23:30' } });
    await userEvent.click(within(dialog).getByRole('button', { name: '4 stars' }));
    expect(within(dialog).getByText('7h 30m')).toBeInTheDocument();
    await userEvent.click(within(dialog).getByRole('button', { name: 'Write it down' }));

    await waitFor(async () => expect(await readNights(h.db)).toHaveLength(1));
    const [night] = await readNights(h.db);
    const today = HarvestDay.of(h.clock());
    expect(night?.harvestDay).toBe(today.key);
    expect(night?.restedStars).toBe(4);
    expect(night?.targetMinutes).toBe(480);
    expect(Date.parse(night!.wokeAt) - Date.parse(night!.fellAsleepAt)).toBe(450 * 60_000);
    expect((await xp(h, 'sleep:')).map((row) => row.delta)).toEqual([15]);
  });
});

describe('a weight, written down', () => {
  it('pays +5 XP for the first weigh-in of a day only, and a delete can be undone', async () => {
    const h = await device(new FakeServer());
    const first = await h.health.logWeight({ grams: 82_400, note: ' after the flu ' });
    await h.health.logWeight({ grams: 82_100, note: null });

    expect((await xp(h, 'weight:')).map((row) => row.delta)).toEqual([5]);
    expect(first.note).toBe('after the flu');

    await h.health.removeWeight(first.uuid);
    expect((await readWeights(h.db)).map((row) => row.grams)).toEqual([82_100]);
    await h.health.restoreWeight(first.uuid);
    expect(await readWeights(h.db)).toHaveLength(2);
  });

  it('stores grams whatever the field says, in the unit it is labelled with', async () => {
    const h = await device(new FakeServer());
    await h.settings.setMany({ 'features.health': 'true', 'health.weightUnit': 'lb' });
    render(
      <HarvestContext.Provider value={h}>
        <BodyScreen />
      </HarvestContext.Provider>,
    );

    await userEvent.click(await screen.findByRole('button', { name: 'Log a weight' }, { timeout: 5000 }));
    const dialog = await screen.findByRole('dialog');
    await userEvent.type(within(dialog).getByLabelText('Weight (lb)'), '181,5');
    await userEvent.click(within(dialog).getByRole('button', { name: 'Save' }));

    await waitFor(async () => expect(await readWeights(h.db)).toHaveLength(1));
    // 181.5 lb, in grams, rounded once (H4).
    expect((await readWeights(h.db))[0]?.grams).toBe(Math.round(181.5 * 453.59237));
  });

  it('keeps the stored grams when only the note is edited', async () => {
    const h = await device(new FakeServer());
    await h.settings.setBool('features.health', true);
    await h.health.logWeight({ grams: 82_463, note: null });
    render(
      <HarvestContext.Provider value={h}>
        <BodyScreen />
      </HarvestContext.Provider>,
    );

    await userEvent.click(await screen.findByRole('button', { name: /^Edit 82\.5 kg/ }, { timeout: 5000 }));
    const dialog = await screen.findByRole('dialog');
    expect(within(dialog).getByLabelText('Weight (kg)')).toHaveValue('82.46');
    await userEvent.type(within(dialog).getByLabelText('Note'), 'new scale');
    await userEvent.click(within(dialog).getByRole('button', { name: 'Save' }));

    await waitFor(async () => expect((await readWeights(h.db))[0]?.note).toBe('new scale'));
    expect((await readWeights(h.db))[0]?.grams).toBe(82_463);
  });
});

describe('the steps month', () => {
  const row = (harvestDay: string, steps: number) => ({ harvestDay, steps, lastCounter: null, updatedAt: '' });

  it('totals the finished days only, and draws the last fourteen', () => {
    const today = HarvestDay.parse('2026-09-19');
    const rows = [
      row('2026-08-01', 50_000), // Outside the thirty days.
      ...Array.from({ length: 20 }, (_, index) => row(today.addDays(-20 + index).key, 1000 * (index + 1))),
      row(today.key, 3000), // Today is not over.
    ];

    const history = stepsHistory(rows, today);
    // 1,000 + 2,000 + … + 20,000.
    expect(history?.total).toBe(210_000);
    expect(history?.average).toBe(10_500);
    expect(history?.best.steps).toBe(20_000);
    expect(history?.bars).toHaveLength(14);
    expect(history?.bars.at(-1)?.harvestDay).toBe(today.key);
  });

  it('says there is nothing yet when only today has been counted', () => {
    expect(stepsHistory([row('2026-09-19', 4000)], HarvestDay.parse('2026-09-19'))).toBeNull();
  });

  it('saves the goal and the stride, clamped to a human leg', async () => {
    const h = await device(new FakeServer());
    await h.settings.setBool('features.health', true);
    render(
      <HarvestContext.Provider value={h}>
        <BodyScreen />
      </HarvestContext.Provider>,
    );

    await userEvent.click(await screen.findByRole('button', { name: 'Step goal and stride' }, { timeout: 5000 }));
    const dialog = await screen.findByRole('dialog');
    await userEvent.type(within(dialog).getByLabelText('Daily step goal'), '8000');
    await userEvent.clear(within(dialog).getByLabelText('Stride length'));
    await userEvent.type(within(dialog).getByLabelText('Stride length'), '400');
    await userEvent.click(within(dialog).getByRole('button', { name: 'Save' }));

    await waitFor(async () => expect((await h.db.rows('kv_settings').get('health.stepGoal'))?.valueJson).toBe('"8000"'));
    expect((await h.db.rows('kv_settings').get('health.strideCm'))?.valueJson).toBe('"150"');
  });
});
