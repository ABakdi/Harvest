import type { Me } from '@harvest/contracts';
import { HarvestDay } from '@harvest/core';
import { createContext, useContext, useEffect, useState, useSyncExternalStore } from 'react';
import { api } from '@/lib/api';
import { CheckInsRepository } from './data/check-ins';
import { FileStore } from './data/files';
import type { HarvestDB } from './data/db';
import { GoalsRepository } from './data/goals';
import { MoneyRepository } from './data/money';
import { NotesRepository } from './data/notes';
import { SeedsRepository } from './data/seeds';
import { SettingsRepository } from './data/settings';
import { Writer, type Clock } from './data/writer';
import { SyncEngine, type SyncStatus, type SyncTransport } from './sync/engine';
import { Keyring } from './sync/keyring';

/** Everything a screen needs, built once per signed-in session. */
export interface Harvest {
  db: HarvestDB;
  writer: Writer;
  keyring: Keyring;
  files: FileStore;
  engine: SyncEngine;
  seeds: SeedsRepository;
  checkIns: CheckInsRepository;
  goals: GoalsRepository;
  notes: NotesRepository;
  money: MoneyRepository;
  settings: SettingsRepository;
  user: Me;
  clock: Clock;
}

export function createHarvest(
  db: HarvestDB,
  user: Me,
  transport: SyncTransport = api,
  clock: Clock = () => new Date(),
): Harvest {
  const writer = new Writer(db, clock);
  const keyring = new Keyring(db);
  const harvest: Harvest = {
    db,
    writer,
    keyring,
    files: new FileStore(db, keyring, () => harvest.user.syncSalt),
    engine: new SyncEngine({ db, transport, keyring, salt: () => harvest.user.syncSalt, now: clock }),
    seeds: new SeedsRepository(writer),
    checkIns: new CheckInsRepository(writer),
    goals: new GoalsRepository(writer),
    notes: new NotesRepository(writer),
    money: new MoneyRepository(writer),
    settings: new SettingsRepository(writer),
    user,
    clock,
  };
  return harvest;
}

export const HarvestContext = createContext<Harvest | null>(null);

export function useHarvest(): Harvest {
  const harvest = useContext(HarvestContext);
  if (!harvest) throw new Error('useHarvest outside the app');
  return harvest;
}

export function useSyncStatus(): SyncStatus {
  const { engine } = useHarvest();
  return useSyncExternalStore(
    (listener) => engine.subscribe(listener),
    () => engine.status,
    () => engine.status,
  );
}

/**
 * Today's Harvest Day, which turns over at 3 AM rather than midnight:
 * the field re-renders on its own when the day changes under it.
 */
export function useHarvestDay(): HarvestDay {
  const { clock } = useHarvest();
  const [day, setDay] = useState(() => HarvestDay.of(clock()));
  useEffect(() => {
    const next = day.next.startsAt.getTime() - clock().getTime();
    const timer = setTimeout(() => setDay(HarvestDay.of(clock())), Math.max(next, 1_000));
    return () => clearTimeout(timer);
  }, [day, clock]);
  return day;
}
