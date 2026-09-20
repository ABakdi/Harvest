import { HarvestDay } from '@harvest/core';
import { useLiveQuery } from 'dexie-react-hooks';
import maplibregl, { type Map as MapLibreMap } from 'maplibre-gl';
import { CameraIcon, CoinsIcon, DumbbellIcon, FileTextIcon, MapPinIcon, SproutIcon } from 'lucide-react';
import { useEffect, useRef, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { EmptyState } from '../components/bits';
import { useHarvest, useHarvestDay } from '../context';
import { type DayPlaces, readDay, readMappedDays } from '../data/places';
import { formatDate, formatDay, formatNumber } from '@/lib/format';
import { RecordsTabs } from './records';
import 'maplibre-gl/dist/maplibre-gl.css';

/** Free and open, and it never learns the trail ([[ADR-010-Maps]]). */
const styleUrl = 'https://tiles.openfreemap.org/styles/liberty';

const icons: Record<string, typeof MapPinIcon> = {
  expenses: CoinsIcon,
  memories: CameraIcon,
  notes: FileTextIcon,
  check_ins: SproutIcon,
  workout_sessions: DumbbellIcon,
};

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

/**
 * The day, drawn: the trail as one line, each action as a pin.
 *
 * The map is the only thing on this screen that needs a connection.
 * Without one the tiles stay blank and the timeline below still lists
 * everything, because all of it is local ([[Places]]).
 */
function DayMap({ day }: { day: DayPlaces }) {
  const holder = useRef<HTMLDivElement>(null);
  const map = useRef<MapLibreMap | null>(null);

  useEffect(() => {
    if (!holder.current || map.current) return;
    const instance = new maplibregl.Map({
      container: holder.current,
      style: styleUrl,
      center: [3.06, 36.75],
      zoom: 10,
      attributionControl: { compact: true },
    });
    instance.addControl(new maplibregl.NavigationControl({ showCompass: false }), 'top-right');
    map.current = instance;
    return () => {
      instance.remove();
      map.current = null;
    };
  }, []);

  useEffect(() => {
    const instance = map.current;
    if (!instance) return;
    const line = day.points.map((point) => [point.longitude, point.latitude] as [number, number]);
    const markers: maplibregl.Marker[] = [];

    const draw = () => {
      const source = instance.getSource<maplibregl.GeoJSONSource>('trail');
      const data = {
        type: 'Feature' as const,
        properties: {},
        geometry: { type: 'LineString' as const, coordinates: line },
      };
      if (source) {
        source.setData(data);
      } else {
        instance.addSource('trail', { type: 'geojson', data });
        instance.addLayer({
          id: 'trail',
          type: 'line',
          source: 'trail',
          layout: { 'line-cap': 'round', 'line-join': 'round' },
          paint: { 'line-color': '#1F8A46', 'line-width': 4, 'line-opacity': 0.85 },
        });
      }
      for (const pin of day.pins) {
        const element = document.createElement('span');
        element.className = 'block size-3 rounded-full border-2 border-white bg-[#C2410C] shadow';
        element.title = pin.label;
        markers.push(new maplibregl.Marker({ element }).setLngLat([pin.longitude, pin.latitude]).addTo(instance));
      }
      const coordinates = [...line, ...day.pins.map((pin) => [pin.longitude, pin.latitude] as [number, number])];
      if (coordinates.length > 0) {
        const bounds = coordinates.reduce(
          (box, point) => box.extend(point),
          new maplibregl.LngLatBounds(coordinates[0], coordinates[0]),
        );
        instance.fitBounds(bounds, { padding: 48, maxZoom: 16, animate: false });
      }
    };

    if (instance.isStyleLoaded()) draw();
    // The style is fetched; until it lands there is nothing to draw on.
    else void instance.once('load', draw);
    return () => {
      for (const marker of markers) marker.remove();
    };
  }, [day]);

  return <div ref={holder} className="h-80 w-full overflow-hidden rounded-2xl border" />;
}

/** The day's own timeline: stays, and the actions between them. */
function Timeline({ day }: { day: DayPlaces }) {
  const { t } = useTranslation();
  if (day.stays.length === 0 && day.pins.length === 0) {
    return <p className="px-1 text-sm text-muted-foreground">{t('places.nothingHere')}</p>;
  }
  return (
    <ul className="flex flex-col divide-y rounded-xl border bg-card">
      {day.stays.map((stay) => (
        <li key={`${stay.from.toISOString()}-${stay.latitude}`} className="flex items-center gap-3 px-4 py-2.5">
          <MapPinIcon className="size-4 text-primary" aria-hidden />
          <span className="flex min-w-0 flex-1 flex-col">
            <span className="font-bold">{stay.place?.name ?? t('places.stay')}</span>
            <span className="text-xs text-muted-foreground tabular" dir="ltr">
              {time(stay.from)}–{time(stay.to)} ·{' '}
              {t('places.minutes', { count: Math.round(stay.lengthMs / 60_000) })}
            </span>
          </span>
        </li>
      ))}
      {day.pins.map((pin) => {
        const Icon = icons[pin.table] ?? MapPinIcon;
        return (
          <li key={pin.geotag.uuid} className="flex items-center gap-3 px-4 py-2.5">
            <Icon className="size-4 text-muted-foreground" aria-hidden />
            <span className="flex min-w-0 flex-1 flex-col">
              <span className="truncate font-bold">{pin.label || t(`places.tables.${pin.table}`, { defaultValue: pin.table })}</span>
              <span className="text-xs text-muted-foreground tabular">{time(pin.geotag.at)}</span>
            </span>
          </li>
        );
      })}
    </ul>
  );
}

/**
 * Places: where I went, and what I did there, a day at a time.
 *
 * The trail is recorded on the phone and nowhere else — a browser has
 * no business following anyone around ([[Places]]).
 */
export function PlacesScreen() {
  const { t } = useTranslation();
  const { db } = useHarvest();
  const distance = useDistance();
  const today = useHarvestDay();
  const [key, setKey] = useState(today.key);
  const day = HarvestDay.tryParse(key) ?? today;
  const mapped = useLiveQuery(() => readMappedDays(db), [db]);
  const places = useLiveQuery(() => readDay(db, day), [db, day.key]);

  return (
    <div className="flex flex-col gap-4">
      <RecordsTabs />
      <div className="flex flex-wrap items-center gap-2">
        <h1 className="me-auto text-2xl font-extrabold">{t('places.title')}</h1>
        <input
          type="date"
          value={key}
          max={today.key}
          onChange={(event) => setKey(event.target.value)}
          aria-label={t('places.pickDay')}
          className="rounded-md border bg-card px-2 py-1.5 text-sm font-bold outline-none focus-visible:ring-2 focus-visible:ring-ring"
        />
      </div>

      {mapped && mapped.length === 0 ? (
        <EmptyState icon={<MapPinIcon />} title={t('places.emptyTitle')} body={t('places.emptyBody')} />
      ) : (
        places && (
          <>
            <DayMap day={places} />
            <p className="flex flex-wrap gap-x-4 px-1 text-xs text-muted-foreground tabular">
              <span>{t('places.walked', { distance: distance(places.metres) })}</span>
              <span>{t('places.points', { count: places.points.length })}</span>
              {places.unavailable > 0 && <span>{t('places.unavailable', { count: places.unavailable })}</span>}
            </p>
            <h2 className="px-1 text-sm font-extrabold text-muted-foreground">
              {day.key === today.key ? t('places.todayLabel') : formatDay(day.key, { weekday: 'long', day: 'numeric', month: 'long' })}
            </h2>
            <Timeline day={places} />
            {mapped && mapped.length > 0 && (
              <p className="px-1 text-xs text-muted-foreground">{t('places.mappedDays', { count: mapped.length })}</p>
            )}
          </>
        )
      )}
    </div>
  );
}
