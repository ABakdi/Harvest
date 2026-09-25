import type { Me } from '@harvest/contracts';
import { HarvestDay } from '@harvest/core';
import { createContext, useContext, useEffect, useState, useSyncExternalStore } from 'react';
import { api } from '@/lib/api';
import { CategoriesRepository } from './data/categories';
import { CheckInsRepository } from './data/check-ins';
import { ExercisesRepository } from './data/exercises';
import { AttachmentsRepository } from './data/attachments';
import { FileStore } from './data/files';
import { GalleryRepository } from './data/gallery';
import type { HarvestDB } from './data/db';
import { Geotagger } from './data/geotags';
import { GoalsRepository } from './data/goals';
import { HealthRepository } from './data/health';
import { MoneyRepository } from './data/money';
import { NotesRepository } from './data/notes';
import { PomodoroRepository } from './data/pomodoro';
import { ProgramsRepository } from './data/programs';
import { SeedNotesRepository } from './data/seed-notes';
import { SeedsRepository } from './data/seeds';
import { SessionsRepository } from './data/sessions';
import { SettingsRepository } from './data/settings';
import { VaultRepository } from './data/vault';
import { WishlistRepository } from './data/wishlist';
import { Writer, type Clock } from './data/writer';
import { SyncEngine, type SyncStatus, type SyncTransport } from './sync/engine';
import { Keyring } from './sync/keyring';

/** Everything a screen needs, built once per signed-in session. */
export interface Harvest {
  db: HarvestDB;
  writer: Writer;
  keyring: Keyring;
  files: FileStore;
  gallery: GalleryRepository;
  attachments: AttachmentsRepository;
  engine: SyncEngine;
  seeds: SeedsRepository;
  checkIns: CheckInsRepository;
  seedNotes: SeedNotesRepository;
  pomodoro: PomodoroRepository;
  goals: GoalsRepository;
  health: HealthRepository;
  programs: ProgramsRepository;
  sessions: SessionsRepository;
  exercises: ExercisesRepository;
  notes: NotesRepository;
  money: MoneyRepository;
  vault: VaultRepository;
  categories: CategoriesRepository;
  settings: SettingsRepository;
  wishlist: WishlistRepository;
  geotags: Geotagger;
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
  // Files stamp their rows through the writer once the server has them.
  const files = new FileStore(db, keyring, () => harvest.user.syncSalt, writer);
  const harvest: Harvest = {
    db,
    writer,
    keyring,
    files,
    gallery: new GalleryRepository(writer, files),
    attachments: new AttachmentsRepository(writer, files),
    engine: new SyncEngine({ db, transport, keyring, salt: () => harvest.user.syncSalt, now: clock }),
    seeds: new SeedsRepository(writer),
    checkIns: new CheckInsRepository(writer),
    seedNotes: new SeedNotesRepository(writer),
    pomodoro: new PomodoroRepository(writer),
    goals: new GoalsRepository(writer),
    health: new HealthRepository(writer),
    programs: new ProgramsRepository(writer),
    // Stateless: its own door to the same check-ins.
    sessions: new SessionsRepository(writer, new CheckInsRepository(writer)),
    exercises: new ExercisesRepository(writer),
    notes: new NotesRepository(writer),
    money: new MoneyRepository(writer),
    vault: new VaultRepository(writer),
    categories: new CategoriesRepository(writer),
    settings: new SettingsRepository(writer),
    wishlist: new WishlistRepository(writer),
    geotags: new Geotagger(db, writer, clock),
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
