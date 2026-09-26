import type { FixLike, HarvestDay, SavedPlaceLike, Stay } from '@harvest/core';
import { staysIn, trailMetres } from '@harvest/core';
import type { HarvestDB, Row } from './db';
import type { Writer } from './writer';

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
    case 'commitments': {
      const row = await db.rows('commitments').get(uuid);
      return row?.title ?? null;
    }
    case 'seed_notes': {
      const row = await db.rows('seed_notes').get(uuid);
      if (!row) return null;
      const seed = await db.rows('commitments').get(row.commitmentUuid);
      return seed?.title ?? null;
    }
    case 'goal_items': {
      const row = await db.rows('goal_items').get(uuid);
      return row?.body ?? null;
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

/** A span of days on the map: one day, a week, or a month ([[Places]]). */
export interface PlacesSpan {
  from: HarvestDay;
  to: HarvestDay;
}

/**
 * The span on the map: the trail, the stays it makes, and every action
 * that happened somewhere. A week or a month is one trail, drawn
 * together — the travel view — as the phone draws it.
 *
 * Stays are derived, never stored (PL5), and the same `staysIn` the
 * phone uses decides them — ten minutes inside a hundred metres, and a
 * named place claims whatever falls in its radius.
 */
export async function readSpan(db: HarvestDB, span: PlacesSpan): Promise<DayPlaces> {
  // Day keys sort as dates, so a span is one range over the index.
  const [points, geotags, places] = await Promise.all([
    db.rows('location_points').where('harvestDay').between(span.from.key, span.to.key, true, true).toArray(),
    db.rows('geotags').where('harvestDay').between(span.from.key, span.to.key, true, true).toArray(),
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
    notes: row.notes,
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

/** One day on the map. */
export function readDay(db: HarvestDB, day: HarvestDay): Promise<DayPlaces> {
  return readSpan(db, { from: day, to: day });
}

/** Which days have anything on the map at all, newest first. */
export async function readMappedDays(db: HarvestDB): Promise<string[]> {
  const [points, geotags] = await Promise.all([db.rows('location_points').toArray(), db.rows('geotags').toArray()]);
  const days = new Set<string>();
  for (const row of points) if (row.deletedAt === null) days.add(row.harvestDay);
  for (const row of geotags) if (row.deletedAt === null && row.state === 'fixed') days.add(row.harvestDay);
  return [...days].sort((a, b) => b.localeCompare(a));
}

/** Every saved place, as the map and the saved-places sheet list them. */
export async function readSavedPlaces(db: HarvestDB): Promise<SavedPlaceRow[]> {
  const rows = await db.rows('saved_places').toArray();
  return rows.filter((row) => row.deletedAt === null).sort((a, b) => a.name.localeCompare(b.name));
}

/**
 * The places I keep on the map, mirroring the phone's
 * PlacesRepository ([[Places]]): a name, a coordinate and a note, and
 * never a stay — those are still derived from the trail.
 */
export class SavedPlaceRepository {
  constructor(private readonly writer: Writer) {}

  add(input: { name: string; latitude: number; longitude: number; notes?: string | null; radiusM?: number }): Promise<SavedPlaceRow> {
    return this.writer.run(async (tx) => {
      const now = tx.now();
      const row: SavedPlaceRow = {
        uuid: crypto.randomUUID(),
        name: input.name.trim(),
        latitude: input.latitude,
        longitude: input.longitude,
        radiusM: input.radiusM !== undefined && Number.isFinite(input.radiusM) && input.radiusM > 0 ? input.radiusM : 100,
        notes: input.notes?.trim() || null,
        createdAt: now,
        updatedAt: now,
        deletedAt: null,
      };
      await tx.put('saved_places', row);
      return row;
    });
  }

  /**
   * Edits a name, a note or how wide the place reaches; a coordinate is
   * how a place is found again, and moving it is a new place.
   */
  update(uuid: string, input: { name?: string; notes?: string | null; radiusM?: number }): Promise<void> {
    return this.writer.run(async (tx) => {
      const changes: Partial<SavedPlaceRow> = { updatedAt: tx.now() };
      if (input.name !== undefined && input.name.trim()) changes.name = input.name.trim();
      if (input.notes !== undefined) changes.notes = input.notes?.trim() || null;
      if (input.radiusM !== undefined && Number.isFinite(input.radiusM) && input.radiusM > 0) {
        changes.radiusM = input.radiusM;
      }
      await tx.patch('saved_places', uuid, changes);
    });
  }

  /**
   * Names a stay, as the phone does: a stay a place already claims
   * renames that place, and any other becomes a new place where it
   * stood (PL5 — the name is the only part of a stay that is kept).
   */
  async nameStay(stay: Stay, name: string): Promise<void> {
    if (!name.trim()) return;
    if (stay.place) {
      await this.update(stay.place.uuid, { name });
      return;
    }
    await this.add({ name, latitude: stay.latitude, longitude: stay.longitude });
  }

  /** Soft delete; the map forgets the pin, the row survives for sync. */
  delete(uuid: string): Promise<void> {
    return this.writer.run(async (tx) => {
      await tx.patch('saved_places', uuid, { deletedAt: tx.now(), updatedAt: tx.now() });
    });
  }

  /** The undo of a forget: the same place, back where it was. */
  restore(uuid: string): Promise<void> {
    return this.writer.run(async (tx) => {
      await tx.patch('saved_places', uuid, { deletedAt: null, updatedAt: tx.now() });
    });
  }
}

/**
 * Deleting what Places keeps, as the phone's PlacesRepository offers
 * it ([[Places]] PL4, Privacy).
 */
export class LocationHistoryRepository {
  constructor(private readonly writer: Writer) {}

  /**
   * One day's trail, softly: every point gets the same `deletedAt`,
   * which is what [restoreDay] looks for to bring exactly those back.
   * Points are never edited otherwise (PL4).
   */
  deleteDay(day: HarvestDay): Promise<string> {
    return this.writer.run(async (tx) => {
      const at = tx.now();
      const rows = await tx.rows('location_points').where('harvestDay').equals(day.key).toArray();
      for (const row of rows) {
        if (row.deletedAt !== null) continue;
        await tx.put('location_points', { ...row, deletedAt: at, updatedAt: at });
      }
      return at;
    });
  }

  restoreDay(day: HarvestDay, deletedAt: string): Promise<void> {
    return this.writer.run(async (tx) => {
      const rows = await tx.rows('location_points').where('harvestDay').equals(day.key).toArray();
      for (const row of rows) {
        if (row.deletedAt !== deletedAt) continue;
        await tx.put('location_points', { ...row, deletedAt: null, updatedAt: tx.now() });
      }
    });
  }

  /**
   * Every point, geotag and saved place, gone for good: confirmed in
   * the screen, no undo, and sync hears of each purge.
   */
  deleteAll(): Promise<void> {
    return this.writer.run(async (tx) => {
      for (const table of ['location_points', 'geotags', 'saved_places'] as const) {
        const keys = (await tx.rows(table).toCollection().primaryKeys()) as string[];
        for (const key of keys) await tx.purge(table, key);
      }
    });
  }
}
