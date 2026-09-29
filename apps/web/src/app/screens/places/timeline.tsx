import { HarvestDay, type Stay } from '@harvest/core';
import { CameraIcon, CoinsIcon, DumbbellIcon, FileTextIcon, MapPinIcon, SproutIcon } from 'lucide-react';
import { useTranslation } from 'react-i18next';
import { formatDate, formatDay } from '@/lib/format';
import { cn } from '@/lib/utils';
import type { DayPlaces } from '../../data/places';
import { pinColor, stayColor } from './bits';

const icons: Record<string, typeof MapPinIcon> = {
  expenses: CoinsIcon,
  money_txns: CoinsIcon,
  memories: CameraIcon,
  notes: FileTextIcon,
  check_ins: SproutIcon,
  commitments: SproutIcon,
  workout_sessions: DumbbellIcon,
};

function time(at: string | Date): string {
  return formatDate(at, { hour: '2-digit', minute: '2-digit' });
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
export function Timeline({
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
