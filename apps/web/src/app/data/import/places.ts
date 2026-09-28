import type { SyncedTable } from '@harvest/contracts';
import { dayOf, realOf } from '../archive';
import { spec, uuidOf, text, at, updated, type Spec } from './sheet-spec';

/** Places: the places I kept, the trail, and where things happened. */
export const placeSheets: Spec<SyncedTable>[] = [
  // Places. A blank coordinate reads as 0 rather than failing the
  // table; the archive I wrote never has one.
  spec({
    sheet: 'savedPlaces',
    table: 'saved_places',
    keyOf: uuidOf,
    stamp: updated,
    build: (row, { now }) => ({
      uuid: row.Uuid,
      name: row.Name ?? '',
      latitude: realOf(row.Latitude) ?? 0,
      longitude: realOf(row.Longitude) ?? 0,
      radiusM: realOf(row.RadiusM) ?? 100,
      notes: text(row.Notes),
      createdAt: at(row.CreatedAt) ?? now,
      updatedAt: at(row.UpdatedAt) ?? now,
      deletedAt: at(row.DeletedAt),
    }),
  }),
  spec({
    sheet: 'locationPoints',
    table: 'location_points',
    keyOf: uuidOf,
    stamp: updated,
    build: (row, { now }) => ({
      uuid: row.Uuid,
      harvestDay: dayOf(row.HarvestDay) ?? '',
      recordedAt: at(row.RecordedAt) ?? now,
      latitude: realOf(row.Latitude) ?? 0,
      longitude: realOf(row.Longitude) ?? 0,
      accuracyM: realOf(row.AccuracyM),
      speedMps: realOf(row.SpeedMps),
      altitudeM: realOf(row.AltitudeM),
      updatedAt: at(row.UpdatedAt) ?? at(row.RecordedAt) ?? now,
      deletedAt: at(row.DeletedAt),
    }),
  }),
  spec({
    sheet: 'geotags',
    table: 'geotags',
    keyOf: uuidOf,
    stamp: updated,
    build: (row, { now }) => ({
      uuid: row.Uuid,
      targetTable: row.TargetTable ?? '',
      targetUuid: row.TargetUuid ?? '',
      harvestDay: dayOf(row.HarvestDay) ?? '',
      at: at(row.At) ?? now,
      latitude: realOf(row.Latitude),
      longitude: realOf(row.Longitude),
      accuracyM: realOf(row.AccuracyM),
      state: row.State ?? 'pending',
      updatedAt: at(row.UpdatedAt) ?? now,
      deletedAt: at(row.DeletedAt),
    }),
  }),
];
