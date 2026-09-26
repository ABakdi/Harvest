import { HarvestDay } from '@harvest/core';
import type { HarvestDB, Row } from './db';
import type { SeedRow } from './seeds';
import type { Writer } from './writer';

export type SeedNoteRow = Row<'seed_notes'>;

/** The longest a note may be — the same cap the seed's own note has. */
export const seedNoteMaxLength = 500;

/**
 * The day-keyed notes on a seed, as the phone's SeedNotesRepository
 * keeps them: one row per seed per Harvest Day, so writing today's
 * note twice edits it rather than stacking duplicates, and a new day
 * always opens on a blank one.
 */
export class SeedNotesRepository {
  constructor(private readonly writer: Writer) {}

  /** Writes [body] as the note for [day]; an empty body removes it. */
  write(seedUuid: string, day: HarvestDay, body: string): Promise<void> {
    const capped = body.trim().slice(0, seedNoteMaxLength);
    return this.writer.run(async (tx) => {
      const existing = (await tx.rows('seed_notes').where('commitmentUuid').equals(seedUuid).toArray()).find(
        (row) => row.harvestDay === day.key && row.deletedAt === null,
      );
      if (capped === '') {
        // The phone removes an emptied note outright; so does this.
        if (existing) await tx.purge('seed_notes', existing.uuid);
        return;
      }
      const now = tx.now();
      if (existing) {
        await tx.put('seed_notes', { ...existing, body: capped, updatedAt: now });
        return;
      }
      await tx.put('seed_notes', {
        uuid: crypto.randomUUID(),
        commitmentUuid: seedUuid,
        harvestDay: day.key,
        body: capped,
        loggedAt: now,
        deletedAt: null,
        updatedAt: now,
      });
    });
  }
}

/** Every live note on a seed, newest day first. */
export async function notesFor(db: HarvestDB, seedUuid: string): Promise<SeedNoteRow[]> {
  const rows = await db.rows('seed_notes').where('commitmentUuid').equals(seedUuid).toArray();
  return rows
    .filter((row) => row.deletedAt === null && HarvestDay.tryParse(row.harvestDay) !== null)
    .sort((a, b) => b.harvestDay.localeCompare(a.harvestDay));
}

/** Every note written on [day], by seed — what the field's cards show. */
export async function notesOn(db: HarvestDB, day: HarvestDay): Promise<Map<string, string>> {
  const rows = await db.rows('seed_notes').where('harvestDay').equals(day.key).toArray();
  return new Map(rows.filter((row) => row.deletedAt === null).map((row) => [row.commitmentUuid, row.body]));
}

/** One day in a seed's life: what was logged, and what was written about it. */
export interface SeedDay {
  day: HarvestDay;
  quantity: number;
  note: string | null;
}

export interface SeedStory {
  seed: SeedRow | null;
  /** Newest day first: every day watered and every day written about. */
  timeline: SeedDay[];
  notes: SeedNoteRow[];
  current: number;
  best: number;
  /** Units (a project) or check-ins, over the seed's whole life. */
  total: number;
  daysLogged: number;
}

/**
 * Consecutive days checked in, counted back from the most recent one —
 * the honest history behind the stored streak, and what the detail
 * screen shows even for a seed the streak engine never judged
 * (`completedDaysRun`).
 */
export function completedDaysRun(days: readonly HarvestDay[]): number {
  if (days.length === 0) return 0;
  const sorted = [...days].sort((a, b) => b.compareTo(a));
  let run = 1;
  for (let index = 1; index < sorted.length; index += 1) {
    const newer = sorted[index - 1]!;
    const older = sorted[index]!;
    if (newer.previous.equals(older)) run += 1;
    else if (!newer.equals(older)) break;
  }
  return run;
}

/**
 * Everything one seed has done, as the phone's detail screen reads it:
 * check-ins summed by day, notes by day, merged into one timeline. The
 * stored streak is the engine's verdict; without one, the run of
 * consecutive days is what the history itself says.
 */
export async function readSeedStory(db: HarvestDB, seedUuid: string): Promise<SeedStory> {
  const [seed, checkIns, notes, streak] = await Promise.all([
    db.rows('commitments').get(seedUuid),
    db.rows('check_ins').where('commitmentUuid').equals(seedUuid).toArray(),
    notesFor(db, seedUuid),
    db.rows('streaks').get(seedUuid),
  ]);
  const quantities = new Map<string, number>();
  for (const row of checkIns) {
    if (row.deletedAt !== null) continue;
    quantities.set(row.harvestDay, (quantities.get(row.harvestDay) ?? 0) + row.quantity);
  }
  const bodies = new Map(notes.map((note) => [note.harvestDay, note.body]));
  const keys = [...new Set([...quantities.keys(), ...bodies.keys()])].sort((a, b) => b.localeCompare(a));
  const timeline: SeedDay[] = [];
  for (const key of keys) {
    const day = HarvestDay.tryParse(key);
    if (day === null) continue;
    timeline.push({ day, quantity: quantities.get(key) ?? 0, note: bodies.get(key) ?? null });
  }
  const done = timeline.filter((entry) => entry.quantity > 0);
  const current = streak?.current ?? completedDaysRun(done.map((entry) => entry.day));
  return {
    seed: seed && seed.deletedAt === null ? seed : null,
    timeline,
    notes,
    current,
    best: streak?.best ?? current,
    total: done.reduce((sum, entry) => sum + entry.quantity, 0),
    daysLogged: done.length,
  };
}
