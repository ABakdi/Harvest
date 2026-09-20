import type { FixLike, HarvestDay, SavedPlaceLike, Stay } from '@harvest/core';
import { staysIn, trailMetres } from '@harvest/core';
import type { HarvestDB, Row } from './db';

export type PointRow = Row<'location_points'>;
export type GeotagRow = Row<'geotags'>;
export type SavedPlaceRow = Row<'saved_places'>;

/** A geotag with enough of its action to name it in a list. */
export interface PinnedAction {
  geotag: GeotagRow;
  latitude: number;
  longitude: number;
  /** The table the action is in: `expenses`, `memories`, `notes`… */
  table: string;
  label: string;
}

export interface DayPlaces {
  points: PointRow[];
  metres: number;
  stays: Stay[];
  pins: PinnedAction[];
  places: SavedPlaceRow[];
  /** Geotags that never got a fix; the action stands, the place is unknown (PL3). */
  unavailable: number;
}

/** What an action is called in a list, from the row it points at. */
async function labelOf(db: HarvestDB, table: string, uuid: string): Promise<string | null> {
  switch (table) {
    case 'expenses': {
      const row = await db.rows('expenses').get(uuid);
      return row ? (row.note ?? row.category) : null;
    }
    case 'notes': {
      const row = await db.rows('notes').get(uuid);
      return row ? row.title : null;
    }
    case 'memories': {
      const row = await db.rows('memories').get(uuid);
      return row ? row.note : null;
    }
    case 'check_ins': {
      const row = await db.rows('check_ins').get(uuid);
      if (!row) return null;
      const seed = await db.rows('commitments').get(row.commitmentUuid);
      return seed?.title ?? null;
    }
    case 'workout_sessions': {
      const row = await db.rows('workout_sessions').get(uuid);
      return row ? row.title : null;
    }
    case 'body_weights':
    case 'sleep_sessions':
    case 'goals': {
      const row = await db.rows(table).get(uuid);
      return row && 'title' in row ? ((row as { title: string | null }).title ?? null) : null;
    }
    default:
      return null;
  }
}

/**
 * One day on the map: the trail, the stays it makes, and every action
 * that happened somewhere.
 *
 * Stays are derived, never stored (PL5), and the same `staysIn` the
 * phone uses decides them — ten minutes inside a hundred metres, and a
 * named place claims whatever falls in its radius.
 */
export async function readDay(db: HarvestDB, day: HarvestDay): Promise<DayPlaces> {
  const [points, geotags, places] = await Promise.all([
    db.rows('location_points').where('harvestDay').equals(day.key).toArray(),
    db.rows('geotags').where('harvestDay').equals(day.key).toArray(),
    db.rows('saved_places').toArray(),
  ]);

  const trail = points
    .filter((row) => row.deletedAt === null)
    .sort((a, b) => a.recordedAt.localeCompare(b.recordedAt));
  const fixes: FixLike[] = trail.map((row) => ({ latitude: row.latitude, longitude: row.longitude, at: row.recordedAt }));
  const saved = places.filter((row) => row.deletedAt === null);
  const known: SavedPlaceLike[] = saved.map((row) => ({
    uuid: row.uuid,
    name: row.name,
    latitude: row.latitude,
    longitude: row.longitude,
    radiusM: row.radiusM,
  }));

  const live = geotags.filter((row) => row.deletedAt === null).sort((a, b) => a.at.localeCompare(b.at));
  const pins: PinnedAction[] = [];
  for (const geotag of live) {
    if (geotag.state !== 'fixed' || geotag.latitude === null || geotag.longitude === null) continue;
    pins.push({
      geotag,
      latitude: geotag.latitude,
      longitude: geotag.longitude,
      table: geotag.targetTable,
      label: (await labelOf(db, geotag.targetTable, geotag.targetUuid)) ?? '',
    });
  }

  return {
    points: trail,
    metres: trailMetres(fixes),
    stays: staysIn(fixes, known),
    pins,
    places: saved,
    unavailable: live.filter((row) => row.state === 'unavailable').length,
  };
}

/** Which days have anything on the map at all, newest first. */
export async function readMappedDays(db: HarvestDB): Promise<string[]> {
  const [points, geotags] = await Promise.all([db.rows('location_points').toArray(), db.rows('geotags').toArray()]);
  const days = new Set<string>();
  for (const row of points) if (row.deletedAt === null) days.add(row.harvestDay);
  for (const row of geotags) if (row.deletedAt === null && row.state === 'fixed') days.add(row.harvestDay);
  return [...days].sort((a, b) => b.localeCompare(a));
}

/** Several days at once: the travel view, one trail per day. */
export async function readRange(db: HarvestDB, days: readonly HarvestDay[]): Promise<{ day: HarvestDay; places: DayPlaces }[]> {
  const list = [];
  for (const day of days) list.push({ day, places: await readDay(db, day) });
  return list;
}
