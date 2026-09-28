import * as maplibregl from 'maplibre-gl';
// The map's worker, bundled with what it imports: from v6 it is its own
// module, which it looks for beside the library's file, not beside ours.
import mapWorkerUrl from 'maplibre-gl/dist/maplibre-gl-worker.mjs?worker&url';
import { type GeoJSONSourceSpecification, type Map as MapLibreMap, type StyleSpecification } from 'maplibre-gl';
import { LayersIcon, LocateFixedIcon } from 'lucide-react';
import { useEffect, useRef, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { boundsOf, type DayPlaces, type SavedPlaceRow } from '../../data/places';
import { background } from '@/lib/actions';
import { pinColor, savedColor, stayColor, type MapBase } from './bits';
import 'maplibre-gl/dist/maplibre-gl.css';

/** The street view: free and open, and it never learns the trail ([[ADR-010-Maps]]). */
const streetStyleUrl = 'https://tiles.openfreemap.org/styles/liberty';

/** The fonts the saved places' names are set in, served beside the street tiles. */
const glyphsUrl = 'https://tiles.openfreemap.org/fonts/{fontstack}/{range}.pbf';
const labelFont = ['Noto Sans Regular'];

/**
 * The satellite view, Esri World Imagery — the same tiles the phone
 * uses, and no Google anywhere ([[ADR-010-Maps]]). It carries the street
 * base's glyphs: a style without them refuses any layer with text, and
 * the saved places would lose their names over the imagery. Its
 * attribution is the one Esri requires, always shown (PL9).
 */
const satelliteStyle: StyleSpecification = {
  version: 8,
  name: 'Esri World Imagery',
  glyphs: glyphsUrl,
  sources: {
    satellite: {
      type: 'raster',
      tiles: [
        'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
      ],
      tileSize: 256,
      attribution:
        'Powered by Esri — Source: Esri, Maxar, Earthstar Geographics, and the GIS User Community',
    },
  },
  layers: [
    { id: 'background', type: 'background', paint: { 'background-color': '#0b0f1a' } },
    { id: 'satellite', type: 'raster', source: 'satellite' },
  ],
};

/**
 * The street style's road shields compare each road's `ref_length` with
 * a number, and most roads have none: every tile then logged "Expected
 * value to be of type number, but found null". Asking first whether the
 * road has one keeps the same shields and silences the rest (P6-15).
 */
export function quietShields(_previous: StyleSpecification | undefined, next: StyleSpecification): StyleSpecification {
  return {
    ...next,
    layers: next.layers.map((layer) => {
      const filter = 'filter' in layer ? (layer.filter as unknown) : undefined;
      if (!Array.isArray(filter) || filter[0] !== 'all' || !JSON.stringify(filter).includes('["get","ref_length"]')) return layer;
      return { ...layer, filter: ['all', ['has', 'ref_length'], ...(filter.slice(1) as unknown[])] } as typeof layer;
    }),
  };
}

/** A base's style, and how it goes on: the streets with their shields quieted. */
function applyBase(instance: MapLibreMap, base: MapBase): void {
  if (base === 'satellite') instance.setStyle(satelliteStyle, { diff: false });
  else instance.setStyle(streetStyleUrl, { diff: false, transformStyle: quietShields });
}

/** Runs [work] once the browser has a quiet moment; the answer cancels it. */
function whenIdle(work: () => void): () => void {
  if ('requestIdleCallback' in window) {
    const id = window.requestIdleCallback(work, { timeout: 400 });
    return () => window.cancelIdleCallback(id);
  }
  const id = setTimeout(work, 0);
  return () => clearTimeout(id);
}

interface Drawn {
  day: DayPlaces;
  saved: SavedPlaceRow[];
  selected: string | null;
  here: { latitude: number; longitude: number } | null;
  /** The point being saved, marked while its form is open. */
  draft: { latitude: number; longitude: number } | null;
}

type GeoData = GeoJSONSourceSpecification['data'];

/** Puts a GeoJSON source's data in, adding the source the first time. */
function feed(instance: MapLibreMap, id: string, data: GeoData): void {
  if (!instance.getSource(id)) {
    instance.addSource(id, { type: 'geojson', data: { type: 'FeatureCollection', features: [] } });
  }
  // The map applies it on its own time; a failure only means a stale layer.
  background(instance.getSource<maplibregl.GeoJSONSource>(id)?.setData(data));
}

function point(longitude: number, latitude: number) {
  return { type: 'Point' as const, coordinates: [longitude, latitude] };
}

/**
 * Everything the app draws over the base: the trail, the stays, the
 * saved places with their names, the actions, and the blue dot. It
 * adds what a fresh style lacks and refreshes what is there, so it
 * serves both a change of data and a change of base.
 */
function drawMap(instance: MapLibreMap, { day, saved, selected, here, draft }: Drawn): void {
  feed(instance, 'trail', {
    type: 'Feature',
    properties: {},
    geometry: { type: 'LineString', coordinates: day.points.map((p) => [p.longitude, p.latitude]) },
  });
  if (!instance.getLayer('trail')) {
    instance.addLayer({
      id: 'trail',
      type: 'line',
      source: 'trail',
      layout: { 'line-cap': 'round', 'line-join': 'round' },
      paint: { 'line-color': '#1F8A46', 'line-width': 4, 'line-opacity': 0.85 },
    });
  }

  // Where I stayed: soft circles, under everything else.
  feed(instance, 'stays', {
    type: 'FeatureCollection',
    features: day.stays.map((stay) => ({ type: 'Feature', properties: {}, geometry: point(stay.longitude, stay.latitude) })),
  });
  if (!instance.getLayer('stays')) {
    instance.addLayer({
      id: 'stays',
      type: 'circle',
      source: 'stays',
      paint: {
        'circle-radius': 14,
        'circle-color': stayColor,
        'circle-opacity': 0.25,
        'circle-stroke-color': stayColor,
        'circle-stroke-width': 1,
      },
    });
  }

  // The places I kept: red pins with their names, below everything
  // that happened on a day.
  feed(instance, 'saved', {
    type: 'FeatureCollection',
    features: saved.map((place) => ({
      type: 'Feature',
      properties: { uuid: place.uuid, name: place.name },
      geometry: point(place.longitude, place.latitude),
    })),
  });
  if (!instance.getLayer('saved')) {
    instance.addLayer({
      id: 'saved',
      type: 'circle',
      source: 'saved',
      paint: {
        'circle-radius': 8,
        'circle-color': savedColor,
        'circle-stroke-color': '#FFFFFF',
        'circle-stroke-width': 2,
      },
    });
  }
  if (!instance.getLayer('saved-names')) {
    instance.addLayer({
      id: 'saved-names',
      type: 'symbol',
      source: 'saved',
      layout: {
        'text-field': ['get', 'name'],
        'text-font': labelFont,
        'text-size': 12.5,
        'text-anchor': 'top',
        'text-offset': [0, 1.4],
        'text-max-width': 12,
      },
      paint: {
        'text-color': '#202124',
        'text-halo-color': '#FFFFFF',
        'text-halo-width': 1.5,
      },
    });
  }

  // The actions, as circles coloured by what they were.
  feed(instance, 'actions', {
    type: 'FeatureCollection',
    features: day.pins.map((pin) => ({
      type: 'Feature',
      properties: { id: pin.geotag.uuid, color: pinColor(pin.table) },
      geometry: point(pin.longitude, pin.latitude),
    })),
  });
  if (!instance.getLayer('actions')) {
    instance.addLayer({
      id: 'actions',
      type: 'circle',
      source: 'actions',
      paint: {
        'circle-radius': 6,
        'circle-color': ['get', 'color'],
        'circle-stroke-color': '#FFFFFF',
        'circle-stroke-width': 2,
      },
    });
  }
  // The picked pin grows a little; the paint follows the selection,
  // which changes without new geometry.
  instance.setPaintProperty('actions', 'circle-radius', ['case', ['==', ['get', 'id'], selected ?? ''], 9, 6]);

  // "You are here", from the browser's own geolocation: an accuracy
  // ring, a white border, a solid dot in the Google blue.
  if (here) {
    const at = point(here.longitude, here.latitude);
    feed(instance, 'here', {
      type: 'FeatureCollection',
      features: [
        { type: 'Feature', properties: { kind: 'ring' }, geometry: at },
        { type: 'Feature', properties: { kind: 'dot' }, geometry: at },
      ],
    });
    if (!instance.getLayer('here-ring')) {
      instance.addLayer({
        id: 'here-ring',
        type: 'circle',
        source: 'here',
        filter: ['==', ['get', 'kind'], 'ring'],
        paint: { 'circle-radius': 22, 'circle-color': '#1A73E8', 'circle-opacity': 0.15 },
      });
      instance.addLayer({
        id: 'here-dot',
        type: 'circle',
        source: 'here',
        filter: ['==', ['get', 'kind'], 'dot'],
        paint: {
          'circle-radius': 9,
          'circle-color': '#1A73E8',
          'circle-stroke-color': '#FFFFFF',
          'circle-stroke-width': 3,
        },
      });
    }
  } else {
    for (const id of ['here-ring', 'here-dot']) if (instance.getLayer(id)) instance.removeLayer(id);
    if (instance.getSource('here')) instance.removeSource('here');
  }

  // The point a right-click picked, in the saved places' red, hollow
  // until it is kept: the form sits beside the map, never over it.
  if (draft) {
    feed(instance, 'draft', { type: 'Feature', properties: {}, geometry: point(draft.longitude, draft.latitude) });
    if (!instance.getLayer('draft')) {
      instance.addLayer({
        id: 'draft',
        type: 'circle',
        source: 'draft',
        paint: { 'circle-radius': 8, 'circle-color': '#FFFFFF', 'circle-stroke-color': savedColor, 'circle-stroke-width': 3 },
      });
    }
  } else {
    if (instance.getLayer('draft')) instance.removeLayer('draft');
    if (instance.getSource('draft')) instance.removeSource('draft');
  }
}

interface DayMapProps extends Drawn {
  /** Which span is on the map; a new one frames its trail once. */
  spanKey: string;
  base: MapBase;
  onSelect: (uuid: string) => void;
  onPlace: (place: SavedPlaceRow) => void;
  onSave: (latitude: number, longitude: number) => void;
  onLocate: () => void;
  onBaseChange: (base: MapBase) => void;
}

/**
 * The span, drawn: the trail as one line, the stays as circles, every
 * action as a pin, the places I kept as red pins with their names, and
 * the blue dot where I am now. Right-click drops a new pin to save; a
 * saved pin opens its card.
 *
 * A change of base replaces the whole style, and with it everything the
 * app drew; every `style.load` — the first and each one after a swap —
 * draws it all again.
 *
 * The map is the only thing on this screen that needs a connection.
 * Without one the tiles stay blank and the timeline below still lists
 * everything, because all of it is local ([[Places]]).
 */
export function DayMap({ day, saved, base, selected, here, draft, spanKey, onSelect, onPlace, onSave, onLocate, onBaseChange }: DayMapProps) {
  const { t } = useTranslation();
  const holder = useRef<HTMLDivElement>(null);
  const map = useRef<MapLibreMap | null>(null);
  const baseNow = useRef(base);
  const shownBase = useRef(base);
  const ready = useRef(false);
  const redraw = useRef<() => void>(() => undefined);
  const flewTo = useRef<string | null>(null);
  const flewHere = useRef(false);
  const framed = useRef<string | null>(null);
  const handlers = useRef({ onSelect, onPlace, onSave });
  const savedRef = useRef(saved);
  const [born, setBorn] = useState(false);
  // The latest callbacks, kept places and base, refreshed after every
  // paint: the map's own listeners read them only when events fire.
  useEffect(() => {
    handlers.current = { onSelect, onPlace, onSave };
    savedRef.current = saved;
    baseNow.current = base;
  });

  // The map is born once, in whichever view is on, after the screen
  // around it has drawn: its first frame is the heaviest work here.
  useEffect(() => {
    const node = holder.current;
    if (!node) return;
    let instance: MapLibreMap | null = null;
    const cancel = whenIdle(() => {
      maplibregl.setWorkerUrl(mapWorkerUrl);
      const created = new maplibregl.Map({
        container: node,
        center: [3.06, 36.75],
        zoom: 10,
        attributionControl: { compact: true },
      });
      instance = created;
      shownBase.current = baseNow.current;
      applyBase(created, shownBase.current);
      // Zoom on the left: the right-hand corner is the locate and base buttons'.
      created.addControl(new maplibregl.NavigationControl({ showCompass: false }), 'top-left');
      created.on('style.load', () => {
        ready.current = true;
        redraw.current();
      });
      created.on('contextmenu', (event) => {
        const { lngLat } = event;
        handlers.current.onSave(lngLat.lat, lngLat.lng);
      });
      // A tap on a day's pin or a kept pin picks it; the layer names are
      // the ones drawMap uses.
      created.on('click', 'actions', (event) => {
        const id = event.features?.[0]?.properties?.id as string | undefined;
        if (id) handlers.current.onSelect(id);
      });
      created.on('click', 'saved', (event) => {
        const uuid = event.features?.[0]?.properties?.uuid as string | undefined;
        if (!uuid) return;
        const place = savedRef.current.find((p) => p.uuid === uuid);
        if (place) handlers.current.onPlace(place);
      });
      map.current = created;
      setBorn(true);
    });
    return () => {
      cancel();
      instance?.remove();
      map.current = null;
      ready.current = false;
    };
  }, []);

  // Streets ⇄ satellite: a whole new style, not a diff — a diff keeps
  // nothing the app added — and nothing is drawn until it has loaded.
  useEffect(() => {
    const instance = map.current;
    if (!instance || shownBase.current === base) return;
    shownBase.current = base;
    ready.current = false;
    applyBase(instance, base);
  }, [base, born]);

  // What is on the map, redrawn when it changes — now if the style is
  // ready, or by the next `style.load`.
  useEffect(() => {
    const instance = map.current;
    if (!instance) return;
    redraw.current = () => drawMap(instance, { day, saved, selected, here, draft });
    if (ready.current) redraw.current();
  }, [day, saved, selected, here, draft, born]);

  // Where to look: the pin a link or a tap named, else the whole span
  // once when it first shows, and the dot when I asked for it.
  useEffect(() => {
    const instance = map.current;
    if (!instance) return;
    if (selected) {
      const pin = day.pins.find((p) => p.geotag.uuid === selected);
      if (pin && flewTo.current !== selected) {
        flewTo.current = selected;
        framed.current = spanKey;
        instance.easeTo({ center: [pin.longitude, pin.latitude], zoom: Math.max(instance.getZoom(), 15) });
      }
      return;
    }
    flewTo.current = null;
    if (framed.current === spanKey) return;
    const spots = [
      ...day.points.map((p) => [p.longitude, p.latitude] as [number, number]),
      ...day.pins.map((p) => [p.longitude, p.latitude] as [number, number]),
    ];
    const bounds = boundsOf(spots);
    if (bounds === null) return;
    framed.current = spanKey;
    instance.fitBounds(bounds, { padding: 48, maxZoom: 16 });
  }, [day, selected, spanKey, born]);

  useEffect(() => {
    const instance = map.current;
    if (!instance || !here || flewHere.current) return;
    flewHere.current = true;
    instance.easeTo({ center: [here.longitude, here.latitude], zoom: 17 });
  }, [here, born]);

  return (
    <div ref={holder} className="relative h-80 w-full overflow-hidden rounded-2xl border">
      <div className="absolute end-3 top-3 z-10 flex flex-col items-end gap-2">
        <button
          type="button"
          onClick={onLocate}
          title={t('places.locateMe')}
          aria-label={t('places.locateMe')}
          className="rounded-full border bg-card p-2.5 text-muted-foreground shadow hover:text-foreground focus-visible:ring-2 focus-visible:ring-ring max-md:p-3"
        >
          <LocateFixedIcon className="size-5" aria-hidden />
        </button>
        <button
          type="button"
          onClick={() => onBaseChange(base === 'satellite' ? 'streets' : 'satellite')}
          title={t('places.layers')}
          aria-label={t('places.layers')}
          className="flex items-center gap-1.5 rounded-full border bg-card px-3 py-2 text-muted-foreground shadow hover:text-foreground focus-visible:ring-2 focus-visible:ring-ring max-md:min-h-11"
        >
          <LayersIcon className="size-4" aria-hidden />
          <span className="text-xs font-bold capitalize">
            {base === 'satellite' ? t('places.satellite') : t('places.streets')}
          </span>
        </button>
      </div>
    </div>
  );
}
