import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter, Route, Routes } from 'react-router';
import { describe, expect, it } from 'vitest';
import { HarvestContext } from '@/app/context';
import { metaKeys, setMeta } from '@/app/data/db';
import { readSetting } from '@/app/data/settings';
import { OnboardingGate, OnboardingScreen, needsOnboarding } from '@/app/screens/onboarding';
import { FakeServer } from './fake-server';
import { device } from './helpers';

/**
 * First run on the web: asked once, of an account with nothing in it,
 * and never of one that already has seeds or said it was done.
 */

type Device = Awaited<ReturnType<typeof device>>;

/** As if the first sync had come back: whatever the phone had is here now. */
async function synced(h: Device) {
  await setMeta(h.db, metaKeys.lastSyncedAt, '2026-09-19T12:00:00.000Z');
  await h.engine.refreshCounts();
}

function app(h: Device, at = '/app/field') {
  return render(
    <HarvestContext.Provider value={h}>
      <MemoryRouter initialEntries={[at]}>
        <OnboardingGate />
        <Routes>
          <Route path="/app/welcome" element={<OnboardingScreen />} />
          <Route path="/app/field" element={<p>The field</p>} />
        </Routes>
      </MemoryRouter>
    </HarvestContext.Provider>,
  );
}

describe('who is asked', () => {
  it('is only an account with no seeds and no answer on record', async () => {
    const h = await device(new FakeServer());
    expect(await needsOnboarding(h.db)).toBe(true);

    const seeded = await device(new FakeServer());
    await seeded.seeds.plant({ type: 'todo', title: 'Call home' });
    expect(await needsOnboarding(seeded.db)).toBe(false);

    const answered = await device(new FakeServer());
    await answered.settings.setString('onboarding.done', 'true');
    expect(await needsOnboarding(answered.db)).toBe(false);
  });

  it('waits for the first sync, because an empty browser is not an empty account', async () => {
    const h = await device(new FakeServer());
    app(h);
    expect(await screen.findByText('The field', {}, { timeout: 5000 })).toBeInTheDocument();

    await synced(h);
    expect(await screen.findByText('Welcome to Harvest')).toBeInTheDocument();
  });

  it('never shows the welcome to an account that already has seeds', async () => {
    const h = await device(new FakeServer());
    await h.seeds.plant({ type: 'habit', title: 'Walk' });
    await synced(h);
    app(h, '/app/welcome');
    expect(await screen.findByText('The field', {}, { timeout: 5000 })).toBeInTheDocument();
    expect(screen.queryByText('Welcome to Harvest')).not.toBeInTheDocument();
  });
});

describe('the welcome', () => {
  it('plants the chosen seeds, sets the goal and the switches, and is not asked again', async () => {
    const h = await device(new FakeServer());
    await synced(h);
    app(h, '/app/welcome');

    await userEvent.click(await screen.findByRole('button', { name: 'Next' }, { timeout: 5000 }));
    // Read and Exercise start picked; take Exercise back, add Journal.
    await userEvent.click(screen.getByRole('button', { name: 'Exercise' }));
    await userEvent.click(screen.getByRole('button', { name: 'Journal before bed' }));
    await userEvent.click(screen.getByRole('button', { name: 'Next' }));
    await userEvent.click(screen.getByRole('button', { name: 'More: Daily Harvest Goal' }));
    await userEvent.click(screen.getByRole('button', { name: 'Next' }));
    await userEvent.click(screen.getByRole('switch', { name: 'Health' }));
    await userEvent.click(screen.getByRole('button', { name: 'Start growing' }));

    expect(await screen.findByText('The field', {}, { timeout: 5000 })).toBeInTheDocument();
    // And it stays: the gate must not send the field back to the welcome
    // while its own query catches up with the answer.
    await new Promise((resolve) => setTimeout(resolve, 300));
    expect(screen.getByText('The field')).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Start growing' })).not.toBeInTheDocument();
    const seeds = await h.db.rows('commitments').toArray();
    expect(seeds.map((seed) => [seed.title, seed.type]).sort()).toEqual([
      ['Journal before bed', 'habit'],
      ['Read a book (300 pages)', 'project'],
    ]);
    const book = seeds.find((seed) => seed.type === 'project');
    expect([book?.totalTarget, book?.dailyCommitment]).toEqual([300, 10]);
    expect(await readSetting(h.db, 'dailyHarvestGoal')).toBe('4');
    expect(await readSetting(h.db, 'features.health')).toBe('true');
    // A no is written down too, not left as an absent row.
    expect(await readSetting(h.db, 'features.gym')).toBe('false');
    expect(await readSetting(h.db, 'onboarding.done')).toBe('true');
    expect(await needsOnboarding(h.db)).toBe(false);
  });

  it('skips without planting or switching anything', async () => {
    const h = await device(new FakeServer());
    await synced(h);
    app(h, '/app/welcome');

    await userEvent.click(await screen.findByRole('button', { name: 'Skip' }));
    expect(await screen.findByText('The field', {}, { timeout: 5000 })).toBeInTheDocument();
    await waitFor(async () => expect(await readSetting(h.db, 'onboarding.done')).toBe('true'));
    expect(await h.db.rows('commitments').count()).toBe(0);
    expect(await readSetting(h.db, 'features.health')).toBeNull();
  });
});
