/**
 * Where the phone was, and where it stayed. A port of
 * `apps/mobile/lib/features/places/domain/place.dart`: the haversine,
 * the length of a trail, and the stays a day's points add up to
 * ([[Places]] PL5). Held to `fixtures/places.json`.
 *
 * A stay is derived, never stored: the sampler records nothing while
 * the phone sits still, so a stay is usually two points far apart in
 * time and close in space — which is why the rule is about the span and
 * not the count.
 */

/** One point of the trail, as `location_points` stores it. */
export interface FixLike {
  readonly latitude: number;
  readonly longitude: number;
  /** When it was recorded (`recordedAt`). */
  readonly at: string | Date;
}

/** A stay I gave a name (`saved_places`). */
export interface SavedPlaceLike {
  readonly uuid: string;
  readonly name: string;
  readonly latitude: number;
  readonly longitude: number;
  readonly radiusM: number;
}

export interface Stay {
  readonly latitude: number;
  readonly longitude: number;
  readonly from: Date;
  readonly to: Date;
  /** The saved place it falls inside, if any. */
  readonly place: SavedPlaceLike | null;
  /** How long it lasted, in milliseconds. */
  readonly lengthMs: number;
}

/** How long and how close a run of points must be to count as a stay. */
export const stayMinimumMs = 10 * 60_000;
export const stayRadiusM = 100;

export function haversineMetres(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const earth = 6_371_000;
  const rad = (degrees: number) => (degrees * Math.PI) / 180;
  const dLat = rad(lat2 - lat1);
  const dLon = rad(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) ** 2 + Math.cos(rad(lat1)) * Math.cos(rad(lat2)) * Math.sin(dLon / 2) ** 2;
  return 2 * earth * Math.asin(Math.sqrt(a));
}

function at(fix: FixLike): Date {
  return typeof fix.at === 'string' ? new Date(fix.at) : fix.at;
}

/** Whether a saved place covers a point. */
export function placeContains(place: SavedPlaceLike, latitude: number, longitude: number): boolean {
  return haversineMetres(place.latitude, place.longitude, latitude, longitude) <= place.radiusM;
}

/**
 * The stays in a trail, oldest first: a run of consecutive points that
 * all fall within [stayRadiusM] of the run's first point and span at
 * least [stayMinimumMs].
 */
export function staysIn(trail: readonly FixLike[], places: readonly SavedPlaceLike[] = []): Stay[] {
  const sorted = [...trail].sort((a, b) => at(a).getTime() - at(b).getTime());
  const stays: Stay[] = [];
  let i = 0;
  while (i < sorted.length) {
    const anchor = sorted[i]!;
    let j = i;
    while (
      j + 1 < sorted.length &&
      haversineMetres(anchor.latitude, anchor.longitude, sorted[j + 1]!.latitude, sorted[j + 1]!.longitude) <=
        stayRadiusM
    ) {
      j++;
    }
    const run = sorted.slice(i, j + 1);
    const from = at(run[0]!);
    const to = at(run[run.length - 1]!);
    const span = to.getTime() - from.getTime();
    if (span >= stayMinimumMs) {
      const latitude = run.reduce((sum, fix) => sum + fix.latitude, 0) / run.length;
      const longitude = run.reduce((sum, fix) => sum + fix.longitude, 0) / run.length;
      stays.push({
        latitude,
        longitude,
        from,
        to,
        place: places.find((place) => placeContains(place, latitude, longitude)) ?? null,
        lengthMs: span,
      });
      i = j + 1;
    } else {
      i++;
    }
  }
  return stays;
}

/** The total length of a trail, in metres. */
export function trailMetres(trail: readonly FixLike[]): number {
  let total = 0;
  for (let i = 1; i < trail.length; i++) {
    total += haversineMetres(
      trail[i - 1]!.latitude,
      trail[i - 1]!.longitude,
      trail[i]!.latitude,
      trail[i]!.longitude,
    );
  }
  return total;
}
