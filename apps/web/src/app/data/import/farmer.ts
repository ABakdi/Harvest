import type { StoredTable } from '../db';
import { dayOf, intOf } from '../archive';
import { spec, uuidOf, text, at, updated, type Spec } from './sheet-spec';

/** The Farmer: focus sessions, the ledger and the streaks. */
export const farmerSheets: Spec<StoredTable>[] = [
  spec({
    sheet: 'focus',
    table: 'pomodoro_sessions',
    keyOf: uuidOf,
    stamp: { sheet: 'StartedAt', local: 'startedAt' },
    build: (row, { now }) => ({
      uuid: row.Uuid,
      commitmentUuid: text(row.CommitmentUuid),
      harvestDay: dayOf(row.HarvestDay) ?? '',
      focusBlocks: intOf(row.FocusBlocks) ?? 0,
      startedAt: at(row.StartedAt) ?? now,
      endedAt: at(row.EndedAt),
    }),
  }),
  spec({
    sheet: 'ledger',
    table: 'ledger',
    keyOf: uuidOf,
    stamp: { sheet: 'LoggedAt', local: 'loggedAt' },
    build: (row, { now }) => ({
      uuid: row.Uuid,
      kind: row.Kind ?? 'xp',
      delta: intOf(row.Delta) ?? 0,
      reason: row.Reason ?? '',
      harvestDay: dayOf(row.HarvestDay) ?? '',
      loggedAt: at(row.LoggedAt) ?? now,
    }),
  }),
  // Derived state, but derived from history this device may not have,
  // so the newer copy wins like everywhere else (B-02).
  spec({
    sheet: 'streaks',
    table: 'streaks',
    keyOf: (row) => row.Scope,
    stamp: updated,
    build: (row, { now }) => ({
      scope: row.Scope,
      current: intOf(row.Current) ?? 0,
      best: intOf(row.Best) ?? 0,
      lastEarnedDay: dayOf(row.LastEarnedDay),
      freezesStored: intOf(row.FreezesStored) ?? 0,
      updatedAt: at(row.UpdatedAt) ?? now,
    }),
  }),
];
