import { HarvestDay } from '@harvest/core';
import { act, render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter } from 'react-router';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { HarvestContext } from '@/app/context';
import { GeotagSetting } from '@/app/components/geotag-setting';
import { LocationNote } from '@/app/components/location-note';
import { Geotagger, geotagUuid, type Locator, type WebFix } from '@/app/data/geotags';
import {
  LocationHistoryRepository,
  readDay,
  readSavedPlaces,
  readSpan,
  SavedPlaceRepository,
} from '@/app/data/places';
import { PlacesScreen } from '@/app/screens/places';
import { FakeServer } from './fake-server';
import { device } from './helpers';

type Device = Awaited<ReturnType<typeof device>>;

const today = HarvestDay.parse('2026-09-19');

function point(uuid: string, day: string, minutes: number, latitude: number, longitude: number, accuracyM: number | null = 12) {
  return {
    uuid,
    harvestDay: day,
    recordedAt: new Date(Date.parse(`${day}T09:00:00.000Z`) + minutes * 60_000).toISOString(),
    latitude,
    longitude,
    accuracyM,
    speedMps: null,
    altitudeM: null,
    updatedAt: '2026-09-19T08:00:00.000Z',
    deletedAt: null,
  };
}

function place(uuid: string, name: string, latitude: number, longitude: number) {
  return { uuid, name, latitude, longitude, radiusM: 100, notes: null, createdAt: '2026-09-19T08:00:00.000Z', updatedAt: '2026-09-19T08:00:00.000Z', deletedAt: null };
}

/** A note written the way every repository writes: through the writer. */
function writeNote(h: Device, uuid = crypto.randomUUID(), title = 'Idea') {
  return h.writer.run(async (tx) => {
    await tx.put('notes', { uuid, title, folder: '', body: '', createdAt: tx.now(), updatedAt: tx.now(), deletedAt: null });
    return uuid;
  });
}

async function geotaggingOn(h: Device, places = true) {
  await h.settings.setBool('features.places', places);
  await h.settings.setBool('web.geotagging', true);
}

/** A locator that answers what the test says, and counts how often it was asked. */
function fakeLocator(current: WebFix | null, lastKnown: WebFix | null = null) {
  const calls = { current: 0, lastKnown: 0 };
  const locator: Locator = {
    current: () => {
      calls.current++;
      return Promise.resolve(current);
    },
    lastKnown: () => {
      calls.lastKnown++;
      return Promise.resolve(lastKnown);
    },
  };
  return { locator, calls };
}

describe('geotag ids', () => {
  it('are the version-5 ids the phone derives, so an action is never tagged twice', () => {
    // uuid.uuid5(NAMESPACE_URL, 'harvest:geotag:expenses:0b7e…6666')
    expect(geotagUuid('expenses', '0b7e7f3e-1111-4222-8333-444455556666')).toBe('10705694-cd4b-5684-ae09-680b29d2d30d');
  });
});

describe('geotagging what the browser does (PL2, PL3)', () => {
  it('tags nothing while the switch is off, which it is until turned on', async () => {
    const h = await device(new FakeServer());
    await h.settings.setBool('features.places', true);
    await writeNote(h);
    expect(await h.db.rows('geotags').count()).toBe(0);
  });

  it('tags nothing while Places itself is off, whatever this browser says (PL1)', async () => {
    const h = await device(new FakeServer());
    await geotaggingOn(h, false);
    await writeNote(h);
    expect(await h.db.rows('geotags').count()).toBe(0);
  });

  it('writes the geotag only once resolved, in the phone’s shape, with one fresh fix', async () => {
    const h = await device(new FakeServer());
    const { locator, calls } = fakeLocator({ latitude: 36.7, longitude: 3.05, accuracyM: 18, at: h.clock() });
    const tagger = new Geotagger(h.db, h.writer, h.clock, locator);
    await geotaggingOn(h);

    // Nothing beside the action inside its transaction: no pending row exists to sync.
    const written = await h.writer.run(async (tx) => {
      const uuid = crypto.randomUUID();
      await tx.put('notes', { uuid, title: 'Idea', folder: '', body: '', createdAt: tx.now(), updatedAt: tx.now(), deletedAt: null });
      return { uuid, tag: await tx.get('geotags', geotagUuid('notes', uuid)) };
    });
    expect(written.tag).toBeUndefined();

    await tagger.settled;
    const tag = await h.db.rows('geotags').get(geotagUuid('notes', written.uuid));
    expect(tag).toMatchObject({
      targetTable: 'notes',
      targetUuid: written.uuid,
      harvestDay: today.key,
      at: '2026-09-19T12:00:00.000Z',
      state: 'fixed',
      latitude: 36.7,
      longitude: 3.05,
      accuracyM: 18,
    });
    expect(calls.current).toBe(1);

    // One outbox entry, for the resolved row: nothing pending ever travels.
    const queued = (await h.db.outbox.toArray()).filter((row) => row.table === 'geotags');
    expect(queued).toHaveLength(1);
  });

  it('does not tag an edit, only the insert', async () => {
    const h = await device(new FakeServer());
    const { locator } = fakeLocator(null);
    new Geotagger(h.db, h.writer, h.clock, locator);
    const uuid = await writeNote(h);
    await geotaggingOn(h);
    await h.writer.run((tx) => tx.patch('notes', uuid, { title: 'Better idea' }));
    expect(await h.db.rows('geotags').count()).toBe(0);
  });

  it('prefers a fresh, sharp trail point and never asks the browser', async () => {
    const h = await device(new FakeServer());
    const { locator, calls } = fakeLocator(null);
    const tagger = new Geotagger(h.db, h.writer, h.clock, locator);
    await geotaggingOn(h);
    // A minute before the pinned clock (12:00Z): 180 minutes after 09:00Z is 12:00Z.
    await h.db.rows('location_points').put(point('p1', today.key, 179, 36.75, 3.06));
    const uuid = await writeNote(h);
    await tagger.settled;
    expect(await h.db.rows('geotags').get(geotagUuid('notes', uuid))).toMatchObject({ state: 'fixed', latitude: 36.75 });
    expect(calls.current).toBe(0);
  });

  it('takes a last known position only when it is from the last ten minutes', async () => {
    const h = await device(new FakeServer());
    const recent = fakeLocator(null, { latitude: 1, longitude: 2, accuracyM: 30, at: new Date(h.clock().getTime() - 5 * 60_000) });
    let tagger = new Geotagger(h.db, h.writer, h.clock, recent.locator);
    await geotaggingOn(h);
    const first = await writeNote(h);
    await tagger.settled;
    expect(await h.db.rows('geotags').get(geotagUuid('notes', first))).toMatchObject({ state: 'fixed', latitude: 1 });

    const stale = fakeLocator(null, { latitude: 1, longitude: 2, accuracyM: 30, at: new Date(h.clock().getTime() - 20 * 60_000) });
    tagger = new Geotagger(h.db, h.writer, h.clock, stale.locator);
    const second = await writeNote(h);
    await tagger.settled;
    // No place, and the action stands all the same (PL3).
    expect(await h.db.rows('geotags').get(geotagUuid('notes', second))).toMatchObject({ state: 'unavailable', latitude: null });
    expect(await h.db.rows('notes').get(second)).toBeDefined();
  });
});

describe('the location chip (PL8)', () => {
  const renderNote = (h: Device) =>
    render(
      <MemoryRouter>
        <HarvestContext.Provider value={h}>
          <LocationNote table="notes" uuid="n1" />
        </HarvestContext.Provider>
      </MemoryRouter>,
    );

  const tag = (state: 'pending' | 'fixed' | 'unavailable') => ({
    uuid: 'g1',
    targetTable: 'notes',
    targetUuid: 'n1',
    harvestDay: today.key,
    at: `${today.key}T10:00:00.000Z`,
    latitude: state === 'fixed' ? 36.75 : null,
    longitude: state === 'fixed' ? 3.06 : null,
    accuracyM: null,
    state,
    updatedAt: '2026-09-19T08:00:00.000Z',
    deletedAt: null,
  });

  it('says it is still looking while the geotag is pending, never "no location"', async () => {
    const h = await device(new FakeServer());
    await h.db.rows('geotags').put(tag('pending'));
    renderNote(h);
    expect(await screen.findByText('Finding the place…')).toBeInTheDocument();
    expect(screen.queryByText('No location recorded')).not.toBeInTheDocument();
  });

  it('names the saved place from its first render, never the coordinates first', async () => {
    const h = await device(new FakeServer());
    await h.db.rows('geotags').put(tag('fixed'));
    await h.db.rows('saved_places').put(place('home', 'Home', 36.75, 3.06));
    renderNote(h);
    const chip = await screen.findByRole('button');
    expect(chip).toHaveTextContent(/^Home ·/);
  });
});

describe('spans, stays and forgetting', () => {
  it('reads a week as one trail, with the stays of every day in it', async () => {
    const h = await device(new FakeServer());
    const monday = today.weekStart;
    await h.db.rows('location_points').bulkPut([
      point('a1', monday.key, 0, 36.75, 3.06),
      point('a2', monday.key, 30, 36.7501, 3.0601),
      point('b1', monday.addDays(2).key, 0, 36.8, 3.1),
      point('b2', monday.addDays(2).key, 30, 36.8001, 3.1001),
      // The week after: not in it.
      point('c1', monday.addDays(7).key, 0, 36.9, 3.2),
    ]);
    const week = await readSpan(h.db, { from: monday, to: monday.addDays(6) });
    expect(week.points.map((p) => p.uuid)).toEqual(['a1', 'a2', 'b1', 'b2']);
    expect(week.stays).toHaveLength(2);
  });

  it('names a stay: a claimed one renames its place, any other becomes one', async () => {
    const h = await device(new FakeServer());
    const repo = new SavedPlaceRepository(h.writer);
    await h.db.rows('location_points').bulkPut([point('a1', today.key, 0, 36.75, 3.06), point('a2', today.key, 30, 36.7501, 3.0601)]);

    let [stay] = (await readDay(h.db, today)).stays;
    await repo.nameStay(stay!, 'Office');
    let saved = await readSavedPlaces(h.db);
    expect(saved).toHaveLength(1);
    expect(saved[0]).toMatchObject({ name: 'Office', radiusM: 100 });

    [stay] = (await readDay(h.db, today)).stays;
    expect(stay?.place?.name).toBe('Office');
    await repo.nameStay(stay!, 'Work');
    saved = await readSavedPlaces(h.db);
    expect(saved.map((row) => row.name)).toEqual(['Work']);
  });

  it('edits how far a place reaches, and a forget can be undone', async () => {
    const h = await device(new FakeServer());
    const repo = new SavedPlaceRepository(h.writer);
    const row = await repo.add({ name: 'Park', latitude: 36.7, longitude: 3.05 });
    await repo.update(row.uuid, { radiusM: 250 });
    expect((await readSavedPlaces(h.db))[0]?.radiusM).toBe(250);
    await repo.update(row.uuid, { radiusM: -5 });
    expect((await readSavedPlaces(h.db))[0]?.radiusM).toBe(250);

    await repo.delete(row.uuid);
    expect(await readSavedPlaces(h.db)).toHaveLength(0);
    await repo.restore(row.uuid);
    expect(await readSavedPlaces(h.db)).toHaveLength(1);
  });

  it('deletes a day’s trail softly, and its undo brings back only those points (PL4)', async () => {
    const h = await device(new FakeServer());
    const history = new LocationHistoryRepository(h.writer);
    await h.db.rows('location_points').bulkPut([
      point('p1', today.key, 0, 36.75, 3.06),
      { ...point('p0', today.key, 10, 36.75, 3.06), deletedAt: '2026-09-01T00:00:00.000Z' },
      point('q1', today.addDays(-1).key, 0, 36.75, 3.06),
    ]);
    const at = await history.deleteDay(today);
    expect((await readDay(h.db, today)).points).toHaveLength(0);
    expect((await readDay(h.db, today.addDays(-1))).points).toHaveLength(1);

    await history.restoreDay(today, at);
    expect((await readDay(h.db, today)).points.map((p) => p.uuid)).toEqual(['p1']);
  });

  it('deletes all location history for good, and sync hears of every purge', async () => {
    const h = await device(new FakeServer());
    await h.db.rows('location_points').put(point('p1', today.key, 0, 36.75, 3.06));
    await h.db.rows('saved_places').put(place('home', 'Home', 36.75, 3.06));
    await h.db.rows('geotags').put({
      uuid: 'g1',
      targetTable: 'notes',
      targetUuid: 'n1',
      harvestDay: today.key,
      at: `${today.key}T10:00:00.000Z`,
      latitude: 36.75,
      longitude: 3.06,
      accuracyM: null,
      state: 'fixed',
      updatedAt: '2026-09-19T08:00:00.000Z',
      deletedAt: null,
    });
    await new LocationHistoryRepository(h.writer).deleteAll();
    expect(await h.db.rows('location_points').count()).toBe(0);
    expect(await h.db.rows('geotags').count()).toBe(0);
    expect(await h.db.rows('saved_places').count()).toBe(0);
    const purged = (await h.db.outbox.toArray()).filter((row) => row.op === 'delete').map((row) => `${row.table}:${row.key}`);
    expect(purged.sort()).toEqual(['geotags:g1', 'location_points:p1', 'saved_places:home']);
  });
});

// The map needs WebGL, which jsdom does not have. This stub behaves the
// way the real one does where it matters here: a new style clears every
// source and layer the app added, and `style.load` says when it is ready.
const { maps } = vi.hoisted(() => ({ maps: [] as unknown[] }));

vi.mock('maplibre-gl', () => {
  class StubMap {
    addControl = vi.fn();
    easeTo = vi.fn();
    fitBounds = vi.fn();
    getZoom = vi.fn(() => 12);
    setPaintProperty = vi.fn();
    remove = vi.fn();
    styles: unknown[] = [];
    sources = new Map<string, { setData: ReturnType<typeof vi.fn> }>();
    layers = new Map<string, Record<string, unknown>>();
    private listeners = new Map<string, ((event: unknown) => void)[]>();
    constructor(options: { style: unknown }) {
      this.styles.push(options.style);
      maps.push(this);
    }
    on(event: string, layerOrCb: unknown, cb?: (event: unknown) => void) {
      const listener = (cb ?? layerOrCb) as (event: unknown) => void;
      const name = cb ? `${event}:${layerOrCb as string}` : event;
      this.listeners.set(name, [...(this.listeners.get(name) ?? []), listener]);
      return this;
    }
    setStyle = vi.fn((style: unknown, options?: { diff?: boolean }) => {
      this.styles.push(style);
      if (options?.diff === false) {
        this.sources.clear();
        this.layers.clear();
      }
    });
    getSource(id: string) {
      return this.sources.get(id);
    }
    addSource(id: string) {
      if (this.sources.has(id)) throw new Error(`source ${id} exists`);
      this.sources.set(id, { setData: vi.fn() });
    }
    removeSource(id: string) {
      this.sources.delete(id);
    }
    getLayer(id: string) {
      return this.layers.get(id);
    }
    addLayer(spec: { id: string; source?: string }) {
      if (this.layers.has(spec.id)) throw new Error(`layer ${spec.id} exists`);
      if (spec.source && !this.sources.has(spec.source)) throw new Error(`no source ${spec.source}`);
      this.layers.set(spec.id, spec);
    }
    removeLayer(id: string) {
      this.layers.delete(id);
    }
    emit(event: string, payload?: unknown) {
      for (const listener of this.listeners.get(event) ?? []) listener(payload);
    }
  }
  return { default: { Map: StubMap, NavigationControl: vi.fn() } };
});

interface Stub {
  styles: unknown[];
  layers: Map<string, Record<string, unknown>>;
  setStyle: ReturnType<typeof vi.fn>;
  fitBounds: ReturnType<typeof vi.fn>;
  emit: (event: string, payload?: unknown) => void;
}

describe('the places screen', () => {
  beforeEach(() => {
    maps.length = 0;
  });

  const renderPlaces = (h: Device) =>
    render(
      <MemoryRouter initialEntries={['/app/records/places']}>
        <HarvestContext.Provider value={h}>
          <PlacesScreen />
        </HarvestContext.Provider>
      </MemoryRouter>,
    );

  async function withTrail() {
    const h = await device(new FakeServer());
    await h.db.rows('location_points').bulkPut([
      point('p1', today.key, 0, 36.75, 3.06),
      point('p2', today.key, 30, 36.7501, 3.0601),
      point('y1', today.addDays(-1).key, 0, 36.8, 3.1),
      point('y2', today.addDays(-1).key, 45, 36.8001, 3.1001),
    ]);
    await h.db.rows('saved_places').put(place('cafe', 'Le Café', 36.7, 3.05));
    return h;
  }

  it('redraws everything after a switch of base, names included, over a satellite style that has glyphs (PL9)', async () => {
    const h = await withTrail();
    const user = userEvent.setup();
    renderPlaces(h);
    await screen.findByText('2 points');
    // The map's module loads lazily, after the timeline can already show.
    await waitFor(() => expect(maps.length).toBeGreaterThan(0));
    const map = maps[0] as Stub;

    act(() => map.emit('style.load'));
    for (const id of ['trail', 'stays', 'saved', 'saved-names', 'actions']) expect(map.layers.has(id)).toBe(true);

    await user.click(screen.getByRole('button', { name: /Map view/ }));
    await waitFor(() =>
      expect(map.setStyle).toHaveBeenCalledWith(expect.objectContaining({ name: 'Esri World Imagery' }), { diff: false }),
    );
    const satellite = map.styles.at(-1) as { glyphs?: string; sources: Record<string, { attribution?: string }> };
    expect(satellite.glyphs).toBe('https://tiles.openfreemap.org/fonts/{fontstack}/{range}.pbf');
    expect(satellite.sources.satellite?.attribution).toMatch(/Esri/);
    // The new style has none of the app's layers until it loads…
    expect(map.layers.size).toBe(0);
    act(() => map.emit('style.load'));
    // …and then all of them again, the names set in a font the glyphs serve.
    for (const id of ['trail', 'stays', 'saved', 'saved-names', 'actions']) expect(map.layers.has(id)).toBe(true);
    expect((map.layers.get('saved-names')?.layout as Record<string, unknown>)['text-font']).toEqual(['Noto Sans Regular']);

    // And back to streets: the same again, and nothing lost.
    await user.click(screen.getByRole('button', { name: /Map view/ }));
    await waitFor(() => expect(map.setStyle).toHaveBeenLastCalledWith('https://tiles.openfreemap.org/styles/liberty', { diff: false }));
    act(() => map.emit('style.load'));
    for (const id of ['trail', 'stays', 'saved', 'saved-names', 'actions']) expect(map.layers.has(id)).toBe(true);
  });

  it('shows a week of trails together, frames them, and steps a week at a time', async () => {
    const h = await withTrail();
    const user = userEvent.setup();
    renderPlaces(h);
    await screen.findByText('2 points');

    await user.click(screen.getByRole('radio', { name: 'Week' }));
    expect(await screen.findByText('4 points')).toBeInTheDocument();
    // Two stays, one a day, each with its day in the timeline.
    expect(screen.getAllByRole('button', { name: /Name this stay/ })).toHaveLength(2);
    // The map's module loads lazily, after the timeline can already show.
    await waitFor(() => expect(maps.length).toBeGreaterThan(0));
    const map = maps[0] as Stub;
    await waitFor(() => expect(map.fitBounds).toHaveBeenCalled());

    await user.click(screen.getByRole('button', { name: 'Earlier' }));
    expect(await screen.findByText('0 points')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Later' })).toBeEnabled();
  });

  it('names a stay from the timeline, which keeps it as a saved place', async () => {
    const h = await withTrail();
    const user = userEvent.setup();
    renderPlaces(h);
    await screen.findByText('2 points');

    await user.click(screen.getByRole('button', { name: /Name this stay/ }));
    await user.type(screen.getByLabelText('Place name'), 'Office');
    const reach = screen.getByLabelText(/Reach/);
    await user.clear(reach);
    await user.type(reach, '150');
    await user.click(screen.getByRole('button', { name: 'Save place' }));

    await waitFor(async () => expect((await readSavedPlaces(h.db)).map((row) => row.name)).toContain('Office'));
    const office = (await readSavedPlaces(h.db)).find((row) => row.name === 'Office');
    expect(office).toMatchObject({ radiusM: 150, latitude: expect.closeTo(36.75, 3) as number });
    // The stay now carries the place's name.
    expect(await screen.findByRole('button', { name: /Office.*Name this stay/ })).toBeInTheDocument();
  });

  it('opens a saved place from the list, edits it and forgets it', async () => {
    const h = await withTrail();
    const user = userEvent.setup();
    renderPlaces(h);
    const list = await screen.findByRole('region', { name: 'Saved places' });
    await user.click(within(list).getByRole('button', { name: /Le Café/ }));

    const card = screen.getByRole('dialog', { name: 'Le Café' });
    await user.click(within(card).getByRole('button', { name: 'Edit place' }));
    const notes = screen.getByLabelText('Notes');
    await user.type(notes, 'the bench by the old olive tree');
    await user.click(screen.getByRole('button', { name: 'Save' }));
    await waitFor(async () => expect((await readSavedPlaces(h.db))[0]?.notes).toBe('the bench by the old olive tree'));

    await user.click(within(screen.getByRole('region', { name: 'Saved places' })).getByRole('button', { name: /Le Café/ }));
    await user.click(within(screen.getByRole('dialog', { name: 'Le Café' })).getByRole('button', { name: 'Forget' }));
    await waitFor(async () => expect(await readSavedPlaces(h.db)).toHaveLength(0));
  });

  it('deletes the day’s trail, and asks before deleting all of it', async () => {
    const h = await withTrail();
    const user = userEvent.setup();
    renderPlaces(h);
    await screen.findByText('2 points');

    await user.click(screen.getByRole('button', { name: "Delete this day's trail" }));
    expect(await screen.findByText('0 points')).toBeInTheDocument();
    expect((await readDay(h.db, today.addDays(-1))).points).toHaveLength(2);

    await user.click(screen.getByRole('button', { name: 'Delete all location history' }));
    const dialog = await screen.findByRole('alertdialog');
    expect(within(dialog).getByText(/cannot be undone/)).toBeInTheDocument();
    await user.click(within(dialog).getByRole('button', { name: 'Cancel' }));
    expect(await h.db.rows('location_points').count()).toBe(4);

    await user.click(screen.getByRole('button', { name: 'Delete all location history' }));
    await user.click(within(await screen.findByRole('alertdialog')).getByRole('button', { name: 'Delete everything' }));
    await waitFor(async () => expect(await h.db.rows('location_points').count()).toBe(0));
    expect(await h.db.rows('saved_places').count()).toBe(0);
  });
});

describe('the geotagging switch', () => {
  const renderSetting = (h: Device) =>
    render(
      <MemoryRouter>
        <HarvestContext.Provider value={h}>
          <GeotagSetting />
        </HarvestContext.Provider>
      </MemoryRouter>,
    );

  function stubGeolocation(answer: 'granted' | 'refused') {
    const getCurrentPosition = vi.fn(
      (ok: PositionCallback, fail: PositionErrorCallback) => {
        if (answer === 'granted') {
          ok({ coords: { latitude: 36.7, longitude: 3.05, accuracy: 10 }, timestamp: Date.now() } as GeolocationPosition);
        } else {
          fail({ code: 1, PERMISSION_DENIED: 1, message: 'denied' } as GeolocationPositionError);
        }
      },
    );
    Object.defineProperty(navigator, 'geolocation', { value: { getCurrentPosition }, configurable: true });
    return getCurrentPosition;
  }

  it('waits for Places to be on, and is off until turned on', async () => {
    const h = await device(new FakeServer());
    renderSetting(h);
    const toggle = await screen.findByRole('switch', { name: 'Geotag what I do here' });
    expect(toggle).toBeDisabled();
    expect(screen.getByText('Turn Places on first.')).toBeInTheDocument();

    await h.settings.setBool('features.places', true);
    await waitFor(() => expect(toggle).toBeEnabled());
    expect(toggle).not.toBeChecked();
  });

  it('asks the browser once when turned on, and keeps the switch on this device', async () => {
    const h = await device(new FakeServer());
    await h.settings.setBool('features.places', true);
    const asked = stubGeolocation('granted');
    const user = userEvent.setup();
    renderSetting(h);
    const toggle = await screen.findByRole('switch', { name: 'Geotag what I do here' });
    await waitFor(() => expect(toggle).toBeEnabled());
    await user.click(toggle);
    await waitFor(() => expect(toggle).toBeChecked());
    expect(asked).toHaveBeenCalledTimes(1);
    // A device's own switch: stored, and never queued for the other devices.
    const outbox = await h.db.outbox.toArray();
    expect(outbox.some((row) => row.key === 'web.geotagging')).toBe(false);
  });

  it('stays off when the browser is refused its location', async () => {
    const h = await device(new FakeServer());
    await h.settings.setBool('features.places', true);
    stubGeolocation('refused');
    const user = userEvent.setup();
    renderSetting(h);
    const toggle = await screen.findByRole('switch', { name: 'Geotag what I do here' });
    await waitFor(() => expect(toggle).toBeEnabled());
    await user.click(toggle);
    await waitFor(() => expect(toggle).toBeEnabled());
    expect(toggle).not.toBeChecked();
    expect((await h.db.rows('kv_settings').get('web.geotagging'))?.valueJson ?? null).toBeNull();
  });
});
