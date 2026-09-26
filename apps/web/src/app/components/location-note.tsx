import { placeContains } from '@harvest/core';
import { useLiveQuery } from 'dexie-react-hooks';
import { MapPinIcon, MapPinOffIcon } from 'lucide-react';
import { useTranslation } from 'react-i18next';
import { useNavigate } from 'react-router';
import { cn } from '@/lib/utils';
import { useHarvest } from '../context';
import type { HarvestDB } from '../data/db';
import { readSavedPlaces } from '../data/places';

function coord(value: number): string {
  return value.toFixed(4);
}

function clock(at: string): string {
  return new Date(at).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
}

/**
 * The newest live geotag of one action, with the saved place that
 * claims it — read together, so the chip never shows the coordinates
 * for a moment before the name arrives.
 */
async function readChip(db: HarvestDB, table: string, uuid: string) {
  const tags = await db.rows('geotags').where('[targetTable+targetUuid]').equals([table, uuid]).toArray();
  const geotag = tags.filter((row) => row.deletedAt === null).sort((a, b) => b.at.localeCompare(a.at))[0] ?? null;
  if (!geotag || geotag.latitude === null || geotag.longitude === null) return { geotag, place: null };
  const saved = await readSavedPlaces(db);
  const place = saved.find((row) => placeContains(row, geotag.latitude!, geotag.longitude!)) ?? null;
  return { geotag, place };
}

/**
 * Where an action happened, in one small link: the place or the
 * coordinates, with the time, and a tap that lands on that day's map
 * with the pin in front ([[Places]] PL8).
 *
 * Nothing renders when the row has no geotag at all, a quiet
 * "locating…" while its place is still being looked for, and a muted
 * line when the geotag never got a fix — the action stands, the place
 * is unknown (PL3).
 */
export function LocationNote({ table, uuid, className }: { table: string; uuid: string; className?: string | undefined }) {
  const { t } = useTranslation();
  const { db } = useHarvest();
  const navigate = useNavigate();
  const chip = useLiveQuery(() => readChip(db, table, uuid), [db, table, uuid]);

  const geotag = chip?.geotag;
  if (!geotag) return null;
  if (geotag.state === 'pending') {
    return (
      <span className={cn('flex items-center gap-1 text-xs text-muted-foreground', className)}>
        <MapPinIcon className="size-3 shrink-0" aria-hidden />
        {t('places.geoPending')}
      </span>
    );
  }
  if (geotag.state !== 'fixed' || geotag.latitude === null || geotag.longitude === null) {
    return (
      <span className={cn('flex items-center gap-1 text-xs text-muted-foreground', className)}>
        <MapPinOffIcon className="size-3 shrink-0" aria-hidden />
        {t('places.geoUnavailable')}
      </span>
    );
  }

  const name = chip.place?.name ?? `${coord(geotag.latitude)}, ${coord(geotag.longitude)}`;

  return (
    <button
      type="button"
      onClick={() => {
        void navigate(
          `/app/records/places?day=${geotag.harvestDay}&table=${encodeURIComponent(table)}&uuid=${encodeURIComponent(uuid)}`,
        );
      }}
      title={t('places.openOnMap')}
      className={cn(
        'flex items-center gap-1 text-xs font-semibold text-primary hover:underline',
        className,
      )}
    >
      <MapPinIcon className="size-3 shrink-0" aria-hidden />
      <span className="truncate">
        {name} · {clock(geotag.at)}
      </span>
    </button>
  );
}

/**
 * The chip for a seed's check-in on one day, for lists that show the
 * seed rather than the check-in row itself (the calendar's day).
 */
export function CheckInLocationNote({
  seedUuid,
  day,
  className,
}: {
  seedUuid: string;
  day: string;
  className?: string | undefined;
}) {
  const { db } = useHarvest();
  const checkIn = useLiveQuery(
    async () =>
      (await db.rows('check_ins').where('[commitmentUuid+harvestDay]').equals([seedUuid, day]).toArray())
        .filter((row) => row.deletedAt === null)
        .sort((a, b) => a.loggedAt.localeCompare(b.loggedAt))[0] ?? null,
    [db, seedUuid, day],
  );
  if (!checkIn) return null;
  return <LocationNote table="check_ins" uuid={checkIn.uuid} className={className} />;
}
