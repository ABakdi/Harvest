import { HarvestDay, type Stay } from '@harvest/core';
import { useLiveQuery } from 'dexie-react-hooks';
import { ChevronLeftIcon, ChevronRightIcon, MapPinIcon, Trash2Icon } from 'lucide-react';
import { lazy, Suspense, useCallback, useMemo, useState } from 'react';
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
import { ToggleGroup, ToggleGroupItem } from '@/components/ui/toggle-group';
import { formatDay } from '@/lib/format';
import { EmptyState } from '../components/bits';
import { useHarvest, useHarvestDay } from '../context';
import {
  type PlacesSpan,
  type SavedPlaceRow,
  LocationHistoryRepository,
  readMappedDays,
  readSavedPlaces,
  readSpan,
  SavedPlaceRepository,
} from '../data/places';
import { readSetting } from '../data/settings';
import { savedColor, useDistance, type MapBase } from './places/bits';
import { PlaceCard, PlaceForm } from './places/save-card';
import { Timeline } from './places/timeline';
import { RecordsTabs } from './records';
import { runAction } from '@/lib/actions';

// MapLibre is most of a megabyte and its first frame costs the main
// thread half a second: the day's list comes first, the map after it
// (P6-15). Its chunk is kept out of the install ([[Audit-v3]] P6-09).
const DayMap = lazy(async () => ({ default: (await import('./places/map')).DayMap }));

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
      runAction(() => settings.setString('places.mapBase', next));
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
      action: { label: t('common.undo'), onClick: () => runAction(() => history.restoreDay(day, at)) },
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
        <h1 className="me-auto text-2xl font-extrabold max-md:sr-only">{t('places.title')}</h1>
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
          className="rounded-md border bg-card px-2 py-1.5 text-sm font-bold outline-none focus-visible:ring-2 focus-visible:ring-ring max-md:min-h-11"
        />
      </div>

      {places && (
        <>
          <div className="relative">
            <Suspense fallback={<div className="h-80 w-full rounded-2xl border bg-muted/40" aria-busy />}>
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
            </Suspense>
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
                        action: { label: t('common.undo'), onClick: () => runAction(() => repo.restore(uuid)) },
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
                  <Button variant="outline" size="sm" onClick={() => runAction(() => deleteDay())}>
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
