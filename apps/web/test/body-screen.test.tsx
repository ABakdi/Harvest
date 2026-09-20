import { render, screen } from '@testing-library/react';
import { describe, expect, it } from 'vitest';
import { HarvestContext } from '@/app/context';
import { BodyScreen } from '@/app/screens/body';
import { FakeServer } from './fake-server';
import { device } from './helpers';

/**
 * The Body tab drawn against rows a phone would have synced: the point
 * is that a view of somebody else's writing still reads, and says
 * where the writing happens.
 */
async function bodyWith(seed: (h: Awaited<ReturnType<typeof device>>) => Promise<void>) {
  const harvest = await device(new FakeServer());
  await seed(harvest);
  render(
    <HarvestContext.Provider value={harvest}>
      <BodyScreen />
    </HarvestContext.Provider>,
  );
  return harvest;
}

describe('the Body tab', () => {
  it('shows last night, what is owed and the average', async () => {
    await bodyWith(async (h) => {
      await h.db.rows('sleep_sessions').put({
        uuid: 'n1',
        harvestDay: '2026-09-19',
        fellAsleepAt: '2026-09-18T23:00:00.000Z',
        wokeAt: '2026-09-19T06:00:00.000Z',
        targetMinutes: 480,
        restedStars: 4,
        note: null,
        createdAt: '2026-09-19T06:00:00.000Z',
        updatedAt: '2026-09-19T06:00:00.000Z',
        deletedAt: null,
      });
    });

    // Seven hours slept: the headline, the two-week average and the
    // night's own row all say so.
    expect(await screen.findAllByText('7h 0m')).not.toHaveLength(0);
    // An hour short of the eight-hour target is an hour owed.
    expect(screen.getByText('Owed to yourself')).toBeInTheDocument();
    expect(screen.getByText('1h 0m')).toBeInTheDocument();
    expect(screen.getByLabelText('4 stars')).toBeInTheDocument();
  });

  it('says which way the weight went, and never whether that is good', async () => {
    await bodyWith(async (h) => {
      await h.db.rows('body_weights').bulkPut([
        { uuid: 'w1', grams: 82_000, harvestDay: '2026-09-10', note: null, measuredAt: '2026-09-10T07:00:00.000Z', updatedAt: '', deletedAt: null },
        { uuid: 'w2', grams: 81_000, harvestDay: '2026-09-18', note: null, measuredAt: '2026-09-18T07:00:00.000Z', updatedAt: '', deletedAt: null },
      ]);
    });

    expect(await screen.findByText('81 kg')).toBeInTheDocument();
    // The span is the one the entries actually cover, not the window
    // asked for: eight days, on the average line, and no word about
    // whether down is good ([[Health]] H5).
    expect(screen.getByText('Down 1 kg over 8 days')).toBeInTheDocument();
  });

  it('counts today against the goal, and says who counted it', async () => {
    await bodyWith(async (h) => {
      await h.db.rows('kv_settings').put({ key: 'health.stepGoal', valueJson: '"8000"', updatedAt: '' });
      await h.db.rows('step_days').put({ harvestDay: '2026-09-19', steps: 9500, lastCounter: null, updatedAt: '' });
    });

    expect(await screen.findByText('9,500')).toBeInTheDocument();
    expect(screen.getByText('of 8,000')).toBeInTheDocument();
    expect(screen.getByText(/counted by the phone/i)).toBeInTheDocument();
  });

  it('says where a night is written when there are none', async () => {
    await bodyWith(async () => {});
    expect(await screen.findByText(/a night is written from bed/i)).toBeInTheDocument();
  });
});
