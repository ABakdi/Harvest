import { act, render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter } from 'react-router';
import { describe, expect, it, vi } from 'vitest';
import { HarvestContext } from '@/app/context';
import { readSavedPlaces } from '@/app/data/places';
import { PlacesScreen } from '@/app/screens/places';
import { FakeServer } from './fake-server';
import { device } from './helpers';

// No WebGL in jsdom: a stub map that remembers what was drawn on it.
const { maps } = vi.hoisted(() => ({ maps: [] as unknown[] }));

vi.mock('maplibre-gl', () => {
  class StubMap {
    container: HTMLElement;
    addControl = vi.fn();
    setStyle = vi.fn();
    easeTo = vi.fn();
    fitBounds = vi.fn();
    getZoom = vi.fn(() => 12);
    setPaintProperty = vi.fn();
    remove = vi.fn();
    sources = new Map<string, { data?: unknown; setData: (data: unknown) => void }>();
    layers = new Set<string>();
    private listeners = new Map<string, (event: unknown) => void>();
    constructor(options: { container: HTMLElement }) {
      this.container = options.container;
      maps.push(this);
    }
    on(event: string, ...rest: unknown[]) {
      this.listeners.set(event, rest.at(-1) as (event: unknown) => void);
      return this;
    }
    getSource(id: string) {
      return this.sources.get(id);
    }
    addSource(id: string) {
      const source: { data?: unknown; setData: (data: unknown) => void } = {
        setData: (data) => {
          source.data = data;
        },
      };
      this.sources.set(id, source);
    }
    removeSource(id: string) {
      this.sources.delete(id);
    }
    getLayer(id: string) {
      return this.layers.has(id) ? {} : undefined;
    }
    addLayer(spec: { id: string }) {
      this.layers.add(spec.id);
    }
    removeLayer(id: string) {
      this.layers.delete(id);
    }
    emit(event: string, payload?: unknown) {
      this.listeners.get(event)?.(payload);
    }
  }
  return { default: { Map: StubMap, NavigationControl: vi.fn() } };
});

interface Stub {
  container: HTMLElement;
  layers: Set<string>;
  sources: Map<string, { data?: unknown }>;
  emit: (event: string, payload?: unknown) => void;
}

/** Saving a place by right-click: the form must never hide the map, nor the point. */
describe('the save-place form', () => {
  it('sits beside the map, with the point marked on it until it is kept', async () => {
    const h = await device(new FakeServer());
    const user = userEvent.setup();
    render(
      <MemoryRouter initialEntries={['/app/records/places']}>
        <HarvestContext.Provider value={h}>
          <PlacesScreen />
        </HarvestContext.Provider>
      </MemoryRouter>,
    );
    await screen.findByText('No trail yet');
    await waitFor(() => expect(maps.length).toBeGreaterThan(0));
    const map = maps[0] as Stub;
    act(() => {
      map.emit('style.load');
      map.emit('contextmenu', { lngLat: { lat: 36.7, lng: 3.05 }, point: { x: 100, y: 280 } });
    });

    const name = await screen.findByLabelText('Place name');
    // Not inside the map's box, where it covered most of it.
    expect(map.container.contains(name)).toBe(false);
    await waitFor(() => expect(map.layers.has('draft')).toBe(true));
    expect(map.sources.get('draft')?.data).toMatchObject({ geometry: { coordinates: [3.05, 36.7] } });

    await user.type(name, 'Le Café');
    await user.click(screen.getByRole('button', { name: 'Save place' }));
    await waitFor(async () => expect(await readSavedPlaces(h.db)).toHaveLength(1));
    // Kept: the hollow mark gives way to the saved pin.
    await waitFor(() => expect(map.layers.has('draft')).toBe(false));
  });
});
