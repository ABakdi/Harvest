import { useLiveQuery } from 'dexie-react-hooks';
import { Navigate, useLocation } from 'react-router';
import { useHarvest, useSyncStatus } from '../context';
import type { HarvestDB } from '../data/db';
import { settingKeys } from '../data/settings';

/*
 * The part of the welcome the shell needs on every visit, kept apart
 * from the welcome itself so the Field does not carry its code.
 */

/**
 * Whether this account has never been set up: no `onboarding.done` on
 * record and not one seed, live or retired. Either is proof enough that
 * somebody already chose — on the phone or here.
 */
export async function needsOnboarding(db: HarvestDB): Promise<boolean> {
  const [done, seeds] = await Promise.all([db.rows('kv_settings').get(settingKeys.onboardingDone), db.rows('commitments').count()]);
  return done === undefined && seeds === 0;
}

/**
 * Whether to ask now. Never before the first sync has finished — an
 * empty browser is not an empty account, and the phone's seeds may be
 * on their way — unless the account cannot sync yet at all, which is
 * the one case where the server holds nothing either.
 */
export function useOnboardingDue(): boolean | undefined {
  const { db } = useHarvest();
  const status = useSyncStatus();
  const settled = status.lastSyncedAt !== null || status.phase === 'unverified';
  const empty = useLiveQuery(() => needsOnboarding(db), [db]);
  if (empty === undefined) return undefined;
  return settled && empty;
}

/**
 * The stores that have just answered the welcome. The answer is written
 * before the field opens, but the gate's own live query hears of it a
 * moment later; without this it would send the field straight back to
 * the welcome for a frame.
 */
export const answered = new WeakSet<object>();

/** Sends a first-time account to the welcome, once. */
export function OnboardingGate() {
  const { db } = useHarvest();
  const due = useOnboardingDue();
  const location = useLocation();
  if (!due || answered.has(db) || location.pathname === '/app/welcome') return null;
  return <Navigate to="/app/welcome" replace />;
}
