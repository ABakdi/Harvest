import { HarvestDay } from '@harvest/core';
import { act, render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter, useLocation } from 'react-router';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { HarvestContext } from '@/app/context';
import { LocationNote } from '@/app/components/location-note';
import { readDay, readMappedDays, readSavedPlaces, SavedPlaceRepository } from '@/app/data/places';
import { readSetting } from '@/app/data/settings';
import { GalleryScreen } from '@/app/screens/gallery';
import { PlacesScreen } from '@/app/screens/places';
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
      notes: null,
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
      fileHash: null,
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
    expect(screen.getByText(/^1 picture · a seed on the field/)).toBeInTheDocument();
    expect(screen.getByText(/ones from the phone arrive once it has synced them/i)).toBeInTheDocument();
  });
});

describe('saved places', () => {
  it('saves, edits and forgets a place, fixing its name and note', async () => {
    const h = await device(new FakeServer());
    const repo = new SavedPlaceRepository(h.writer);

    const row = await repo.add({ name: '  Le Café  ', latitude: 36.7, longitude: 3.05, notes: ' best espresso ' });
    expect(row.name).toBe('Le Café');
    expect(row.notes).toBe('best espresso');

    let saved = await readSavedPlaces(h.db);
    expect(saved).toHaveLength(1);
    expect(saved[0]?.radiusM).toBe(100);

    await repo.update(row.uuid, { notes: 'espresso, and a bench' });
    saved = await readSavedPlaces(h.db);
    expect(saved[0]?.notes).toBe('espresso, and a bench');

    await repo.delete(row.uuid);
    saved = await readSavedPlaces(h.db);
    expect(saved).toHaveLength(0);
    // A soft delete: the row is still there for the sync.
    const kept = (await h.db.rows('saved_places').get(row.uuid)) as { deletedAt: string | null } | undefined;
    expect(kept?.deletedAt).not.toBeNull();
  });
});

describe('a location note', () => {
  async function withMemoryGeotag(geotag: Record<string, unknown> | null) {
    const h = await device(new FakeServer());
    await h.db.rows('memories').put({
      uuid: 'm1',
      albumUuid: 'a1',
      harvestDay: today.key,
      path: 'gallery/m1.jpg',
      kind: 'photo',
      note: 'After the session',
      fileHash: null,
      capturedAt: `${today.key}T18:00:00.000Z`,
      updatedAt: '',
      deletedAt: null,
    });
    if (geotag) await h.db.rows('geotags').put(geotag as never);
    return h;
  }

  function LocationProbe() {
    const location = useLocation();
    return <span data-testid="probe">{location.search}</span>;
  }

  const renderNote = (h: Awaited<ReturnType<typeof withMemoryGeotag>>) =>
    render(
      <MemoryRouter initialEntries={['/app/records/gallery']}>
        <HarvestContext.Provider value={h}>
          <LocationNote table="memories" uuid="m1" />
          <LocationProbe />
        </HarvestContext.Provider>
      </MemoryRouter>,
    );

  it('renders nothing when the row has no geotag at all', async () => {
    const h = await withMemoryGeotag(null);
    renderNote(h);
    expect(screen.queryByRole('button')).not.toBeInTheDocument();
  });

  it('names the saved place when the geotag has a fix, and links to its day on the map', async () => {
    const h = await withMemoryGeotag({
      uuid: 'g1',
      targetTable: 'memories',
      targetUuid: 'm1',
      harvestDay: today.key,
      at: `${today.key}T10:00:00.000Z`,
      latitude: 36.75,
      longitude: 3.06,
      accuracyM: 20,
      state: 'fixed',
      updatedAt: '',
      deletedAt: null,
    });
    await h.db.rows('saved_places').put({
      uuid: 'home',
      name: 'Home',
      latitude: 36.75,
      longitude: 3.06,
      radiusM: 100,
      notes: null,
      createdAt: '',
      updatedAt: '',
      deletedAt: null,
    });
    renderNote(h);

    const chip = await screen.findByRole('button', { name: /Home ·/ });
    await userEvent.click(chip);
    expect(screen.getByTestId('probe')).toHaveTextContent('?day=2026-09-19&table=memories&uuid=m1');
  });

  it('falls back to the coordinates, and says where a sonar-less action stood', async () => {
    const h = await withMemoryGeotag({
      uuid: 'g1',
      targetTable: 'memories',
      targetUuid: 'm1',
      harvestDay: today.key,
      at: `${today.key}T10:00:00.000Z`,
      latitude: 36.7,
      longitude: 3.05,
      accuracyM: 20,
      state: 'fixed',
      updatedAt: '',
      deletedAt: null,
    });
    renderNote(h);
    expect(await screen.findByRole('button', { name: /36\.7000, 3\.0500 ·/ })).toBeInTheDocument();
  });

  it('says a muted line when the geotag never got a fix', async () => {
    const h = await withMemoryGeotag({
      uuid: 'g1',
      targetTable: 'memories',
      targetUuid: 'm1',
      harvestDay: today.key,
      at: `${today.key}T10:00:00.000Z`,
      latitude: null,
      longitude: null,
      accuracyM: null,
      state: 'unavailable',
      updatedAt: '',
      deletedAt: null,
    });
    renderNote(h);
    expect(await screen.findByText('No location recorded')).toBeInTheDocument();
  });
});

// The map needs WebGL, which jsdom does not have; a stub stands in for
// maplibre while the screen's wiring is tested: the empty state, the
// right-click save, the layer switch and the pin a location link names.
const { mapInstances } = vi.hoisted(() => ({ mapInstances: [] as unknown[] }));

vi.mock('maplibre-gl', () => {
  class MockMap {
    addControl = vi.fn();
    setStyle = vi.fn();
    easeTo = vi.fn();
    fitBounds = vi.fn();
    getZoom = vi.fn(() => 12);
    setPaintProperty = vi.fn();
    isStyleLoaded = vi.fn(() => true);
    remove = vi.fn();
    private sources = new Map<string, { setData: ReturnType<typeof vi.fn> }>();
    private layers = new Set<string>();
    private listeners = new Map<string, (event: unknown) => void>();
    constructor() {
      mapInstances.push(this);
    }
    on(event: string, cb: (event: unknown) => void) {
      this.listeners.set(event, cb);
      return this;
    }
    once(event: string, cb: (event: unknown) => void) {
      this.listeners.set(`once:${event}`, cb);
      return this;
    }
    getSource(id: string) {
      return this.sources.get(id);
    }
    addSource(id: string, spec: Record<string, unknown>) {
      this.sources.set(id, { ...spec, setData: vi.fn() });
      return this;
    }
    removeSource(id: string) {
      this.sources.delete(id);
    }
    getLayer(id: string) {
      return this.layers.has(id) ? {} : undefined;
    }
    addLayer(spec: { id: string }) {
      this.layers.add(spec.id);
      return this;
    }
    removeLayer(id: string) {
      this.layers.delete(id);
    }
    emit(event: string, payload?: unknown) {
      const cb = this.listeners.get(event);
      if (cb) cb(payload);
      const onceCb = this.listeners.get(`once:${event}`);
      if (onceCb) onceCb(payload);
    }
  }
  return { default: { Map: MockMap, NavigationControl: vi.fn(), Popup: vi.fn(() => ({ remove: vi.fn() })) } };
});

describe('the places screen (map stubbed)', () => {
  const renderPlaces = (h: Awaited<ReturnType<typeof device>>, path = '/app/records/places') =>
    render(
      <MemoryRouter initialEntries={[path]}>
        <HarvestContext.Provider value={h}>
          <PlacesScreen />
        </HarvestContext.Provider>
      </MemoryRouter>,
    );

  beforeEach(() => {
    mapInstances.length = 0;
  });

  it('asks for a trail until one exists or a place is kept', async () => {
    const h = await device(new FakeServer());
    renderPlaces(h);
    expect(await screen.findByText('No trail yet')).toBeInTheDocument();
  });

  it('drops a pin from a right-click, saves it, and switches to satellite', async () => {
    const h = await device(new FakeServer());
    const user = userEvent.setup();
    renderPlaces(h);

    // An empty day: no trail, no pins — but the map is still there to
    // point at, and the empty state asks for the first place to be kept.
    await screen.findByText('No trail yet');
    // The map's module loads lazily, after the timeline can already show.
    await waitFor(() => expect(mapInstances.length).toBeGreaterThan(0));
    const map = mapInstances[0] as { emit: (event: string, payload?: unknown) => void };
    act(() => {
      map.emit('contextmenu', { lngLat: { lat: 36.7, lng: 3.05 } });
    });

    await user.type(screen.getByLabelText('Place name'), 'Le Café');
    await user.type(screen.getByLabelText('Notes'), 'best espresso');
    await user.click(screen.getByRole('button', { name: 'Save place' }));

    // The saved place leaves the empty state and counts itself in.
    expect(await screen.findByText('1 saved place')).toBeInTheDocument();
    const saved = await readSavedPlaces(h.db);
    expect(saved).toHaveLength(1);
    expect(saved[0]).toMatchObject({ name: 'Le Café', notes: 'best espresso', latitude: 36.7, longitude: 3.05 });

    // Streets ⇄ satellite, remembered in the shared setting.
    const layers = screen.getByRole('button', { name: /Map view/ });
    expect(layers).toHaveTextContent('Streets');
    await user.click(layers);
    expect(layers).toHaveTextContent('Satellite');
    const setting = await readSetting(h.db, 'places.mapBase');
    expect(setting).toBe('satellite');
  });

  it('brings forward the pin a location link names', async () => {
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
    await h.db.rows('geotags').put({
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
    });

    renderPlaces(h, `/app/records/places?day=${today.key}&table=expenses&uuid=e1`);
    const pin = await screen.findByRole('button', { name: /Coffee/ });
    expect(pin).toHaveAttribute('aria-pressed', 'true');
  });
});
