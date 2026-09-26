import { HarvestDay, type Stay } from '@harvest/core';
import { useLiveQuery } from 'dexie-react-hooks';
import maplibregl, { type GeoJSONSourceSpecification, type Map as MapLibreMap, type StyleSpecification } from 'maplibre-gl';
import {
  CameraIcon,
  ChevronLeftIcon,
  ChevronRightIcon,
  CoinsIcon,
  DumbbellIcon,
  FileTextIcon,
  LayersIcon,
  LocateFixedIcon,
  MapPinIcon,
  SproutIcon,
  Trash2Icon,
} from 'lucide-react';
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { useSearchParams } from 'react-router';
import { useTranslation } from 'react-i18next';
import { toast } from 'sonner';
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from '@/components/ui/alert-dialog';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Textarea } from '@/components/ui/textarea';
import { ToggleGroup, ToggleGroupItem } from '@/components/ui/toggle-group';
import { cn } from '@/lib/utils';
import { formatDate, formatDay, formatNumber } from '@/lib/format';
import { EmptyState } from '../components/bits';
import { useHarvest, useHarvestDay } from '../context';
import {
  type DayPlaces,
  type PlacesSpan,
  type SavedPlaceRow,
  LocationHistoryRepository,
  readMappedDays,
  readSavedPlaces,
  readSpan,
  SavedPlaceRepository,
} from '../data/places';
import { readSetting } from '../data/settings';
import { RecordsTabs } from './records';
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

const icons: Record<string, typeof MapPinIcon> = {
  expenses: CoinsIcon,
  money_txns: CoinsIcon,
  memories: CameraIcon,
  notes: FileTextIcon,
  check_ins: SproutIcon,
  commitments: SproutIcon,
  workout_sessions: DumbbellIcon,
};

/** A pin's colour, the same roles the phone draws ([[Places]]). */
const actionColor: Record<string, string> = {
  expenses: '#DC2626',
  money_txns: '#DC2626',
  debts: '#DC2626',
  debt_payments: '#DC2626',
  memories: '#0D9488',
  albums: '#0D9488',
  notes: '#7C3AED',
  note_attachments: '#7C3AED',
  seed_notes: '#7C3AED',
  check_ins: '#1F8A46',
  workout_sessions: '#1F8A46',
};
const defaultActionColor = '#1F8A46';
const stayColor = '#0D9488';
const savedColor = '#EA4335';

function pinColor(table: string): string {
  return actionColor[table] ?? defaultActionColor;
}

/** `4.2 km`, or metres while it is still a walk across a car park. */
function useDistance(): (metres: number) => string {
  const { t } = useTranslation();
  return (metres) =>
    metres >= 1000
      ? t('places.km', { value: formatNumber(metres / 1000, { maximumFractionDigits: 1 }) })
      : t('places.m', { value: formatNumber(Math.round(metres)) });
}

function time(at: string | Date): string {
  return formatDate(at, { hour: '2-digit', minute: '2-digit' });
}

export type MapBase = 'streets' | 'satellite';

/** The saved map view, remembered like the phone's places.mapBase. */
function useMapBase(): { base: MapBase; setBase: (base: MapBase) => void } {
  const { db, settings } = useHarvest();
  const stored = useLiveQuery(() => readSetting(db, 'places.mapBase'), [db]);
  // The setting arrives after the first paint; until then, and only
  // until the toggle is used, the streets fallback shows.
  const adopted = stored === 'satellite' || stored === 'streets' ? stored : null;
  const [fallback, setFallback] = useState<MapBase>('streets');
  const change = useCallback(
    (next: MapBase) => {
      setFallback(next);
      void settings.setString('places.mapBase', next);
    },
    [settings],
  );
  return { base: adopted ?? fallback, setBase: change };
}

type PlacesRange = 'day' | 'week' | 'month';

/** The days a range covers around [anchor], as the phone's date strip counts them. */
function spanOf(range: PlacesRange, anchor: HarvestDay): PlacesSpan {
  switch (range) {
    case 'day':
      return { from: anchor, to: anchor };
    case 'week':
      return { from: anchor.weekStart, to: anchor.weekStart.addDays(6) };
    case 'month':
      return { from: HarvestDay.fromDate(anchor.year, anchor.month, 1), to: HarvestDay.fromDate(anchor.year, anchor.month + 1, 0) };
  }
}

function stepAnchor(range: PlacesRange, anchor: HarvestDay, direction: number): HarvestDay {
  switch (range) {
    case 'day':
      return anchor.addDays(direction);
    case 'week':
      return anchor.addDays(7 * direction);
    case 'month':
      return HarvestDay.fromDate(anchor.year, anchor.month + direction, 1);
  }
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
  instance.getSource<maplibregl.GeoJSONSource>(id)?.setData(data);
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
function DayMap({ day, saved, base, selected, here, draft, spanKey, onSelect, onPlace, onSave, onLocate, onBaseChange }: DayMapProps) {
  const { t } = useTranslation();
  const holder = useRef<HTMLDivElement>(null);
  const map = useRef<MapLibreMap | null>(null);
  const bootBase = useRef(base);
  const shownBase = useRef(base);
  const ready = useRef(false);
  const redraw = useRef<() => void>(() => undefined);
  const flewTo = useRef<string | null>(null);
  const flewHere = useRef(false);
  const framed = useRef<string | null>(null);
  const handlers = useRef({ onSelect, onPlace, onSave });
  const savedRef = useRef(saved);
  // The latest callbacks and kept places, refreshed after every paint:
  // the map's own listeners read them only when events fire.
  useEffect(() => {
    handlers.current = { onSelect, onPlace, onSave };
    savedRef.current = saved;
  });

  // The map is born once, in whichever view is on.
  useEffect(() => {
    if (!holder.current || map.current) return;
    const instance = new maplibregl.Map({
      container: holder.current,
      style: bootBase.current === 'satellite' ? satelliteStyle : streetStyleUrl,
      center: [3.06, 36.75],
      zoom: 10,
      attributionControl: { compact: true },
    });
    // Zoom on the left: the right-hand corner is the locate and base buttons'.
    instance.addControl(new maplibregl.NavigationControl({ showCompass: false }), 'top-left');
    instance.on('style.load', () => {
      ready.current = true;
      redraw.current();
    });
    instance.on('contextmenu', (event) => {
      const { lngLat } = event;
      handlers.current.onSave(lngLat.lat, lngLat.lng);
    });
    // A tap on a day's pin or a kept pin picks it; the layer names are
    // the ones drawMap uses.
    instance.on('click', 'actions', (event) => {
      const id = event.features?.[0]?.properties?.id as string | undefined;
      if (id) handlers.current.onSelect(id);
    });
    instance.on('click', 'saved', (event) => {
      const uuid = event.features?.[0]?.properties?.uuid as string | undefined;
      if (!uuid) return;
      const place = savedRef.current.find((p) => p.uuid === uuid);
      if (place) handlers.current.onPlace(place);
    });
    map.current = instance;
    return () => {
      instance.remove();
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
    instance.setStyle(base === 'satellite' ? satelliteStyle : streetStyleUrl, { diff: false });
  }, [base]);

  // What is on the map, redrawn when it changes — now if the style is
  // ready, or by the next `style.load`.
  useEffect(() => {
    const instance = map.current;
    if (!instance) return;
    redraw.current = () => drawMap(instance, { day, saved, selected, here, draft });
    if (ready.current) redraw.current();
  }, [day, saved, selected, here, draft]);

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
    if (spots.length === 0) return;
    framed.current = spanKey;
    const lngs = spots.map(([lng]) => lng);
    const lats = spots.map(([, lat]) => lat);
    instance.fitBounds(
      [
        [Math.min(...lngs), Math.min(...lats)],
        [Math.max(...lngs), Math.max(...lats)],
      ],
      { padding: 48, maxZoom: 16 },
    );
  }, [day, selected, spanKey]);

  useEffect(() => {
    const instance = map.current;
    if (!instance || !here || flewHere.current) return;
    flewHere.current = true;
    instance.easeTo({ center: [here.longitude, here.latitude], zoom: 17 });
  }, [here]);

  return (
    <div ref={holder} className="relative h-80 w-full overflow-hidden rounded-2xl border">
      <div className="absolute right-3 top-3 z-10 flex flex-col items-end gap-2">
        <button
          type="button"
          onClick={onLocate}
          title={t('places.locateMe')}
          aria-label={t('places.locateMe')}
          className="rounded-full border bg-card p-2.5 text-muted-foreground shadow hover:text-foreground focus-visible:ring-2 focus-visible:ring-ring"
        >
          <LocateFixedIcon className="size-5" aria-hidden />
        </button>
        <button
          type="button"
          onClick={() => onBaseChange(base === 'satellite' ? 'streets' : 'satellite')}
          title={t('places.layers')}
          aria-label={t('places.layers')}
          className="flex items-center gap-1.5 rounded-full border bg-card px-3 py-2 text-muted-foreground shadow hover:text-foreground focus-visible:ring-2 focus-visible:ring-ring"
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

function minutesLabel(t: ReturnType<typeof useTranslation>['t'], ms: number): string {
  const minutes = Math.round(ms / 60_000);
  return minutes >= 60
    ? t('places.hoursMinutes', { hours: Math.floor(minutes / 60), minutes: minutes % 60 })
    : t('places.minutes', { count: minutes });
}

/**
 * The span's own timeline: the stays and the actions, in the order they
 * happened. A stay is a button that names it; an action flies the map
 * to its pin.
 */
function Timeline({
  day,
  showDays,
  selected,
  onSelect,
  onStay,
}: {
  day: DayPlaces;
  showDays: boolean;
  selected: string | null;
  onSelect: (uuid: string) => void;
  onStay: (stay: Stay) => void;
}) {
  const { t } = useTranslation();
  if (day.stays.length === 0 && day.pins.length === 0) {
    return <p className="px-1 text-sm text-muted-foreground">{showDays ? t('places.nothingInSpan') : t('places.nothingHere')}</p>;
  }
  const dayOf = (at: string | Date) => (showDays ? `${formatDay(HarvestDay.of(new Date(at)).key)} · ` : '');
  const entries = [
    ...day.stays.map((stay) => ({ at: stay.from.getTime(), stay, pin: null })),
    ...day.pins.map((pin) => ({ at: Date.parse(pin.geotag.at), stay: null, pin })),
  ].sort((a, b) => a.at - b.at);

  return (
    <ul className="flex flex-col divide-y rounded-xl border bg-card">
      {entries.map(({ stay, pin }) => {
        if (stay) {
          return (
            <li key={`stay-${stay.from.toISOString()}-${stay.latitude}`}>
              <button
                type="button"
                onClick={() => onStay(stay)}
                title={t('places.nameStay')}
                className="flex w-full items-center gap-3 px-4 py-2.5 text-start outline-none hover:bg-accent focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-ring"
              >
                <MapPinIcon className="size-4 shrink-0" style={{ color: stayColor }} aria-hidden />
                <span className="flex min-w-0 flex-1 flex-col">
                  <span className="truncate font-bold">{stay.place?.name ?? t('places.stay')}</span>
                  <span className="text-xs text-muted-foreground tabular">
                    {dayOf(stay.from)}
                    <span dir="ltr">
                      {time(stay.from)}–{time(stay.to)}
                    </span>{' '}
                    · {minutesLabel(t, stay.lengthMs)}
                  </span>
                </span>
                <span className="sr-only">{t('places.nameStay')}</span>
              </button>
            </li>
          );
        }
        if (!pin) return null;
        const Icon = icons[pin.table] ?? MapPinIcon;
        return (
          <li key={pin.geotag.uuid}>
            <button
              type="button"
              onClick={() => onSelect(pin.geotag.uuid)}
              className={cn(
                'flex w-full items-center gap-3 px-4 py-2.5 text-start outline-none hover:bg-accent focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-ring',
                pin.geotag.uuid === selected && 'bg-accent',
              )}
              aria-pressed={pin.geotag.uuid === selected}
            >
              <Icon className="size-4 shrink-0" style={{ color: pinColor(pin.table) }} aria-hidden />
              <span className="flex min-w-0 flex-1 flex-col">
                <span className="truncate font-bold">{pin.label || t(`places.tables.${pin.table}`, { defaultValue: pin.table })}</span>
                <span className="text-xs text-muted-foreground tabular">
                  {dayOf(pin.geotag.at)}
                  {time(pin.geotag.at)}
                </span>
              </span>
            </button>
          </li>
        );
      })}
    </ul>
  );
}

/** How far a saved place reaches, in metres: a room, a street, a village. */
const minRadiusM = 10;
const maxRadiusM = 5000;

/** Name, note and reach behind saving a place, and editing one. */
function PlaceForm({
  initial,
  onCancel,
  onSave,
}: {
  initial: SavedPlaceRow | null;
  onCancel: () => void;
  onSave: (name: string, notes: string, radiusM: number) => void;
}) {
  const { t } = useTranslation();
  const [name, setName] = useState(initial?.name ?? '');
  const [notes, setNotes] = useState(initial?.notes ?? '');
  const [radius, setRadius] = useState(String(initial?.radiusM ?? 100));
  const [tried, setTried] = useState(false);
  const radiusM = Number(radius);
  const radiusOk = Number.isFinite(radiusM) && radiusM >= minRadiusM && radiusM <= maxRadiusM;
  const submit = () => {
    if (!name.trim() || !radiusOk) {
      setTried(true);
      return;
    }
    onSave(name.trim(), notes.trim(), Math.round(radiusM));
  };
  return (
    // Beside the map, not over it: a card laid on the map hid most of it
    // and the very point being saved. The point stays marked above.
    <div className="rounded-2xl border bg-card p-3 shadow-sm">
      <form
        onSubmit={(event) => {
          event.preventDefault();
          submit();
        }}
        aria-label={initial ? t('places.editPlace') : t('places.savePlace')}
        className="flex flex-col gap-2"
      >
        <LabelText>{initial ? t('places.editPlace') : t('places.savePlace')}</LabelText>
        <div className="grid gap-2 sm:grid-cols-2">
          <Input
            autoFocus
            value={name}
            onChange={(event) => setName(event.target.value)}
            placeholder={t('places.placeNameHint')}
            aria-label={t('places.placeName')}
            aria-invalid={tried && !name.trim()}
            className={cn(tried && !name.trim() && 'ring-2 ring-destructive')}
          />
          <Textarea
            value={notes}
            onChange={(event) => setNotes(event.target.value)}
            placeholder={t('places.placeNotesHint')}
            aria-label={t('places.placeNotes')}
            rows={1}
            className="min-h-9 resize-none"
          />
        </div>
        <label className="flex flex-wrap items-center gap-2 text-sm">
          <span className="font-bold">{t('places.radius')}</span>
          <Input
            type="number"
            inputMode="numeric"
            min={minRadiusM}
            max={maxRadiusM}
            step={10}
            value={radius}
            onChange={(event) => setRadius(event.target.value)}
            aria-invalid={tried && !radiusOk}
            className={cn('w-28', tried && !radiusOk && 'ring-2 ring-destructive')}
          />
          <span className="text-xs text-muted-foreground">{t('places.radiusHint', { min: minRadiusM, max: maxRadiusM })}</span>
        </label>
        <div className="flex justify-end gap-2">
          <Button type="button" variant="ghost" size="sm" onClick={onCancel}>
            {t('common.cancel')}
          </Button>
          <Button type="submit" size="sm">
            {initial ? t('common.save') : t('places.savePlace')}
          </Button>
        </div>
      </form>
    </div>
  );
}

function LabelText({ children }: { children: React.ReactNode }) {
  return <p className="text-sm font-extrabold">{children}</p>;
}

/** One saved place, on a card: its name, its note, and what to do with it. */
function PlaceCard({
  place,
  onClose,
  onEdit,
  onForget,
}: {
  place: SavedPlaceRow;
  onClose: () => void;
  onEdit: () => void;
  onForget: () => void;
}) {
  const { t } = useTranslation();
  const distance = useDistance();
  return (
    <div
      role="dialog"
      aria-label={place.name}
      className="absolute inset-x-3 bottom-3 z-10 flex flex-col gap-2 rounded-2xl border bg-card p-4 shadow-lg"
    >
      <div className="flex items-center gap-2">
        <MapPinIcon className="size-5 shrink-0" style={{ color: savedColor }} aria-hidden />
        <h3 className="min-w-0 flex-1 truncate text-lg font-extrabold">{place.name}</h3>
      </div>
      {place.notes && <p className="text-sm">{place.notes}</p>}
      <p className="text-xs text-muted-foreground tabular">
        <span dir="ltr">
          {place.latitude.toFixed(4)}, {place.longitude.toFixed(4)}
        </span>{' '}
        · {t('places.reach', { distance: distance(place.radiusM) })}
      </p>
      <div className="flex justify-end gap-2">
        <Button variant="ghost" size="sm" onClick={onClose}>
          {t('common.close')}
        </Button>
        <Button variant="ghost" size="sm" onClick={onForget}>
          {t('places.forgetPlace')}
        </Button>
        <Button size="sm" onClick={onEdit}>
          {t('places.editPlace')}
        </Button>
      </div>
    </div>
  );
}

/**
 * Places: where I went, and what I did there — a day, a week or a
 * month at a time — and the places I kept, and where I am now.
 *
 * The trail is recorded on the phone and nowhere else — a browser has
 * no business following anyone around ([[Places]]).
 */
export function PlacesScreen() {
  const { t } = useTranslation();
  const { db, writer } = useHarvest();
  const distance = useDistance();
  const today = useHarvestDay();
  const [searchParams, setSearchParams] = useSearchParams();
  const focusDay = searchParams.get('day');
  const focus = useMemo(() => {
    const table = searchParams.get('table');
    const uuid = searchParams.get('uuid');
    return table && uuid ? { table, uuid } : null;
  }, [searchParams]);
  const [key, setKey] = useState(focusDay ?? today.key);
  const [range, setRange] = useState<PlacesRange>('day');
  const anchor = HarvestDay.tryParse(key) ?? today;
  const span = spanOf(range, anchor);
  const spanKey = `${span.from.key}..${span.to.key}`;
  const mapped = useLiveQuery(() => readMappedDays(db), [db]);
  const places = useLiveQuery(() => readSpan(db, span), [db, spanKey]);
  const saved = useLiveQuery(() => readSavedPlaces(db), [db]);
  const { base, setBase } = useMapBase();
  const repo = useMemo(() => new SavedPlaceRepository(writer), [writer]);
  const history = useMemo(() => new LocationHistoryRepository(writer), [writer]);

  // The pin a location link names — derived, once its day's pins sit on
  // the map — and the pin the user picked on top of it.
  const focusedUuid = useMemo(() => {
    if (!focus || !places) return null;
    const match = places.pins.find(
      (pin) => pin.geotag.targetTable === focus.table && pin.geotag.targetUuid === focus.uuid,
    );
    return match?.geotag.uuid ?? null;
  }, [focus, places]);
  const [picked, setPicked] = useState<string | null>(null);
  const selected = picked ?? focusedUuid;

  const [here, setHere] = useState<{ latitude: number; longitude: number } | null>(null);
  const [card, setCard] = useState<SavedPlaceRow | null>(null);
  const [draft, setDraft] = useState<{ latitude: number; longitude: number; edit?: SavedPlaceRow } | null>(null);
  const [confirmAll, setConfirmAll] = useState(false);

  const onSave = useCallback((latitude: number, longitude: number) => {
    setCard(null);
    setDraft({ latitude, longitude });
  }, []);
  const onPlace = useCallback((place: SavedPlaceRow) => {
    setDraft(null);
    setCard(place);
  }, []);
  const onSelect = useCallback((uuid: string) => setPicked(uuid), []);

  /** A stay a place already claims edits that place; any other is saved where it stood. */
  const onStay = useCallback(
    (stay: Stay) => {
      setCard(null);
      const claimed = stay.place ? saved?.find((row) => row.uuid === stay.place?.uuid) : undefined;
      if (claimed) setDraft({ latitude: claimed.latitude, longitude: claimed.longitude, edit: claimed });
      else setDraft({ latitude: stay.latitude, longitude: stay.longitude });
    },
    [saved],
  );

  const onLocate = useCallback(() => {
    if (typeof navigator === 'undefined' || !('geolocation' in navigator)) {
      toast.error(t('places.locateFailed'));
      return;
    }
    navigator.geolocation.getCurrentPosition(
      (position) =>
        setHere({ latitude: position.coords.latitude, longitude: position.coords.longitude }),
      () => toast.error(t('places.locateFailed')),
      { enableHighAccuracy: true, timeout: 15_000 },
    );
  }, [t]);

  // Picking a span is the user saying "here"; a location link's focus
  // is only a way in, so its parameters fall away.
  const moveTo = (next: HarvestDay, nextRange: PlacesRange = range) => {
    setPicked(null);
    setKey(next.key);
    setRange(nextRange);
    if (focus || focusDay) void setSearchParams({}, { replace: true });
  };

  const deleteDay = async () => {
    const day = span.from;
    const at = await history.deleteDay(day);
    toast(t('places.dayDeleted'), {
      action: { label: t('common.undo'), onClick: () => void history.restoreDay(day, at) },
    });
  };

  const noTrail = mapped && mapped.length === 0 && (!saved || saved.length === 0);
  const canGoForward = span.to.compareTo(today) < 0;
  const spanLabel =
    range === 'day'
      ? anchor.key === today.key
        ? t('places.todayLabel')
        : formatDay(anchor.key, { weekday: 'long', day: 'numeric', month: 'long' })
      : range === 'week'
        ? `${formatDay(span.from.key, { day: 'numeric', month: 'short' })} – ${formatDay(span.to.key, { day: 'numeric', month: 'short' })}`
        : formatDay(span.from.key, { month: 'long', year: 'numeric' });

  return (
    <div className="flex flex-col gap-4">
      <RecordsTabs />
      <div className="flex flex-wrap items-center gap-2">
        <h1 className="me-auto text-2xl font-extrabold">{t('places.title')}</h1>
        <ToggleGroup
          type="single"
          value={range}
          onValueChange={(value) => {
            if (value === 'day' || value === 'week' || value === 'month') moveTo(anchor, value);
          }}
          aria-label={t('places.range')}
        >
          <ToggleGroupItem value="day">{t('places.rangeDay')}</ToggleGroupItem>
          <ToggleGroupItem value="week">{t('places.rangeWeek')}</ToggleGroupItem>
          <ToggleGroupItem value="month">{t('places.rangeMonth')}</ToggleGroupItem>
        </ToggleGroup>
      </div>
      <div className="flex flex-wrap items-center gap-2">
        <Button variant="ghost" size="icon" aria-label={t('places.earlier')} onClick={() => moveTo(stepAnchor(range, anchor, -1))}>
          <ChevronLeftIcon className="rtl:rotate-180" />
        </Button>
        <h2 className="min-w-0 flex-1 truncate text-center text-sm font-extrabold" aria-live="polite">
          {spanLabel}
        </h2>
        <Button
          variant="ghost"
          size="icon"
          aria-label={t('places.later')}
          disabled={!canGoForward}
          onClick={() => {
            const next = stepAnchor(range, anchor, 1);
            moveTo(next.compareTo(today) > 0 ? today : next);
          }}
        >
          <ChevronRightIcon className="rtl:rotate-180" />
        </Button>
        <input
          type="date"
          value={key}
          max={today.key}
          onChange={(event) => {
            const next = HarvestDay.tryParse(event.target.value);
            if (next) moveTo(next);
          }}
          aria-label={t('places.pickDay')}
          className="rounded-md border bg-card px-2 py-1.5 text-sm font-bold outline-none focus-visible:ring-2 focus-visible:ring-ring"
        />
      </div>

      {places && (
        <>
          <div className="relative">
            <DayMap
              day={places}
              saved={saved ?? []}
              base={base}
              selected={selected}
              here={here}
              spanKey={spanKey}
              onSelect={onSelect}
              onPlace={onPlace}
              onSave={onSave}
              onLocate={onLocate}
              onBaseChange={setBase}
              draft={draft && !draft.edit ? draft : null}
            />
            {card && (
              <PlaceCard
                place={card}
                onClose={() => setCard(null)}
                onEdit={() => {
                  setDraft({ latitude: card.latitude, longitude: card.longitude, edit: card });
                  setCard(null);
                }}
                onForget={() => {
                  const uuid = card.uuid;
                  setCard(null);
                  repo.delete(uuid).then(
                    () =>
                      toast(t('places.placeForgotten'), {
                        action: { label: t('common.undo'), onClick: () => void repo.restore(uuid) },
                      }),
                    () => toast.error(t('common.saveFailed')),
                  );
                }}
              />
            )}
          </div>
          {draft && (
            <PlaceForm
              key={draft.edit?.uuid ?? `${draft.latitude},${draft.longitude}`}
              initial={draft.edit ?? null}
              onCancel={() => setDraft(null)}
              onSave={(name, notes, radiusM) => {
                const saving = draft.edit
                  ? repo.update(draft.edit.uuid, { name, notes, radiusM }).then(() => t('places.placeUpdated'))
                  : repo
                      .add({ name, latitude: draft.latitude, longitude: draft.longitude, notes, radiusM })
                      .then(() => t('places.placeSaved'));
                saving.then(
                  (message) => toast(message),
                  () => toast.error(t('common.saveFailed')),
                );
                setDraft(null);
              }}
            />
          )}
          {noTrail ? (
            <EmptyState icon={<MapPinIcon />} title={t('places.emptyTitle')} body={t('places.emptyBody')} />
          ) : (
            <>
              <p className="flex flex-wrap gap-x-4 px-1 text-xs text-muted-foreground tabular">
                {places.places.length > 0 && (
                  <span>
                    <MapPinIcon className="me-1 inline size-3 align-[-1px]" style={{ color: savedColor }} aria-hidden />
                    {t('places.savedCount', { count: places.places.length })}
                  </span>
                )}
                <span>{t('places.walked', { distance: distance(places.metres) })}</span>
                <span>{t('places.points', { count: places.points.length })}</span>
                {places.unavailable > 0 && <span>{t('places.unavailable', { count: places.unavailable })}</span>}
              </p>
              <Timeline day={places} showDays={range !== 'day'} selected={selected} onSelect={onSelect} onStay={onStay} />
              {mapped && mapped.length > 0 && (
                <p className="px-1 text-xs text-muted-foreground">{t('places.mappedDays', { count: mapped.length })}</p>
              )}
              <p className="px-1 text-xs text-muted-foreground">
                {t('places.rightClickHint')}
              </p>
            </>
          )}

          {saved && saved.length > 0 && (
            <section aria-labelledby="places-saved" className="flex flex-col gap-2">
              <h2 id="places-saved" className="px-1 text-sm font-extrabold text-muted-foreground">
                {t('places.savedPlaces')}
              </h2>
              <ul className="flex flex-col divide-y rounded-xl border bg-card">
                {saved.map((place) => (
                  <li key={place.uuid}>
                    <button
                      type="button"
                      onClick={() => onPlace(place)}
                      className="flex w-full items-center gap-3 px-4 py-2.5 text-start outline-none hover:bg-accent focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-ring"
                    >
                      <MapPinIcon className="size-4 shrink-0" style={{ color: savedColor }} aria-hidden />
                      <span className="flex min-w-0 flex-1 flex-col">
                        <span className="truncate font-bold">{place.name}</span>
                        {place.notes && <span className="truncate text-xs text-muted-foreground">{place.notes}</span>}
                      </span>
                    </button>
                  </li>
                ))}
              </ul>
            </section>
          )}

          {!noTrail && (
            <section aria-labelledby="places-history" className="flex flex-col gap-2 rounded-xl border p-4">
              <h2 id="places-history" className="text-sm font-extrabold">
                {t('places.history')}
              </h2>
              <p className="text-xs text-muted-foreground">{t('places.historyHint')}</p>
              <div className="flex flex-wrap gap-2">
                {range === 'day' && places.points.length > 0 && (
                  <Button variant="outline" size="sm" onClick={() => void deleteDay()}>
                    <Trash2Icon />
                    {t('places.deleteDay')}
                  </Button>
                )}
                <Button variant="outline" size="sm" className="text-destructive" onClick={() => setConfirmAll(true)}>
                  <Trash2Icon />
                  {t('places.deleteAll')}
                </Button>
              </div>
            </section>
          )}
        </>
      )}

      <AlertDialog open={confirmAll} onOpenChange={setConfirmAll}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>{t('places.deleteAll')}</AlertDialogTitle>
            <AlertDialogDescription>{t('places.deleteAllBody')}</AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>{t('common.cancel')}</AlertDialogCancel>
            <AlertDialogAction
              destructive
              onClick={() => {
                setCard(null);
                setDraft(null);
                history.deleteAll().then(
                  () => toast(t('places.allDeleted')),
                  () => toast.error(t('common.somethingWrong')),
                );
              }}
            >
              {t('places.deleteAllConfirm')}
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </div>
  );
}
