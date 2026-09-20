import { HarvestDay } from '@harvest/core';
import { render, screen } from '@testing-library/react';
import { MemoryRouter } from 'react-router';
import { describe, expect, it } from 'vitest';
import { HarvestContext } from '@/app/context';
import { readDay, readMappedDays } from '@/app/data/places';
import { GalleryScreen } from '@/app/screens/gallery';
import { FakeServer } from './fake-server';
import { device } from './helpers';

const today = HarvestDay.parse('2026-09-19');

/** A point on the trail, `minutes` after 9am. */
function point(uuid: string, minutes: number, latitude: number, longitude: number) {
  return {
    uuid,
    harvestDay: today.key,
    recordedAt: new Date(Date.parse(`${today.key}T09:00:00.000Z`) + minutes * 60_000).toISOString(),
    latitude,
    longitude,
    accuracyM: 12,
    speedMps: null,
    altitudeM: null,
    updatedAt: '',
    deletedAt: null,
  };
}

describe('a day on the map', () => {
  it('measures the trail and finds the stay, naming it when a place claims it', async () => {
    const h = await device(new FakeServer());
    await h.db.rows('saved_places').put({
      uuid: 'home',
      name: 'Home',
      latitude: 36.75,
      longitude: 3.06,
      radiusM: 100,
      createdAt: '',
      updatedAt: '',
      deletedAt: null,
    });
    await h.db.rows('location_points').bulkPut([
      point('p1', 0, 36.75, 3.06),
      point('p2', 20, 36.7501, 3.0601),
      // Four hundred metres away, an hour later.
      point('p3', 80, 36.7536, 3.06),
    ]);

    const day = await readDay(h.db, today);
    expect(day.points).toHaveLength(3);
    expect(Math.round(day.metres)).toBeGreaterThan(300);
    expect(day.stays).toHaveLength(1);
    expect(day.stays[0]?.place?.name).toBe('Home');
  });

  it('pins an action where it happened, and counts the ones with no place', async () => {
    const h = await device(new FakeServer());
    await h.db.rows('expenses').put({
      uuid: 'e1',
      amountMinor: 300_00,
      currency: 'DZD',
      category: 'food',
      note: 'Coffee',
      harvestDay: today.key,
      loggedAt: `${today.key}T10:00:00.000Z`,
      deletedAt: null,
      updatedAt: '',
    });
    await h.db.rows('geotags').bulkPut([
      {
        uuid: 'g1',
        targetTable: 'expenses',
        targetUuid: 'e1',
        harvestDay: today.key,
        at: `${today.key}T10:00:00.000Z`,
        latitude: 36.7,
        longitude: 3.05,
        accuracyM: 20,
        state: 'fixed',
        updatedAt: '',
        deletedAt: null,
      },
      {
        uuid: 'g2',
        targetTable: 'notes',
        targetUuid: 'n1',
        harvestDay: today.key,
        at: `${today.key}T11:00:00.000Z`,
        latitude: null,
        longitude: null,
        accuracyM: null,
        // A fix that never came: the action stands anyway (PL3).
        state: 'unavailable',
        updatedAt: '',
        deletedAt: null,
      },
    ]);

    const day = await readDay(h.db, today);
    expect(day.pins).toHaveLength(1);
    expect(day.pins[0]).toMatchObject({ table: 'expenses', label: 'Coffee' });
    expect(day.unavailable).toBe(1);
    expect(await readMappedDays(h.db)).toEqual([today.key]);
  });
});

describe('the gallery', () => {
  it('says what an album holds, and where its pictures still are', async () => {
    const h = await device(new FakeServer());
    await h.db.rows('albums').put({
      uuid: 'a1',
      name: 'Gym',
      scheduleJson: JSON.stringify({ type: 'daily' }),
      remindAt: null,
      note: null,
      createdAt: '',
      updatedAt: '',
      deletedAt: null,
    });
    await h.db.rows('memories').put({
      uuid: 'm1',
      albumUuid: 'a1',
      harvestDay: today.key,
      path: 'gallery/m1.jpg',
      kind: 'photo',
      note: 'After the session',
      capturedAt: `${today.key}T18:00:00.000Z`,
      updatedAt: '',
      deletedAt: null,
    });

    render(
      <MemoryRouter initialEntries={['/app/records/gallery']}>
        <HarvestContext.Provider value={h}>
          <GalleryScreen />
        </HarvestContext.Provider>
      </MemoryRouter>,
    );

    expect(await screen.findByText('Gym')).toBeInTheDocument();
    expect(screen.getByText('1 picture · a seed on the field')).toBeInTheDocument();
    expect(screen.getByText(/pictures themselves stay on the phone/i)).toBeInTheDocument();
  });
});
