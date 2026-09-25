import { HarvestDay, scheduleToJson, type Schedule } from '@harvest/core';
import type { Row } from './db';
import type { Tx, Writer } from './writer';

export type SeedRow = Row<'commitments'>;
export type SeedType = SeedRow['type'];

export interface SeedInput {
  type: SeedType;
  title: string;
  /** Habits only. */
  schedule?: Schedule | null;
  /** Projects only. */
  totalTarget?: number | null;
  dailyCommitment?: number | null;
  /** To-dos only. */
  dueDay?: string | null;
  note?: string | null;
  remindAt?: string | null;
  deadline?: string | null;
  goalUuid?: string | null;
}

/** The columns a seed's own fields decide, as `_toRow` writes them. */
function columns(input: SeedInput) {
  return {
    type: input.type,
    title: input.title.trim(),
    scheduleJson: input.type === 'habit' && input.schedule ? JSON.stringify(scheduleToJson(input.schedule)) : null,
    totalTarget: input.type === 'project' ? (input.totalTarget ?? null) : null,
    dailyCommitment: input.type === 'project' ? (input.dailyCommitment ?? null) : null,
    dueDay: input.type === 'todo' ? (input.dueDay ?? null) : null,
    note: input.note?.trim() ? input.note.trim() : null,
    remindAt: input.remindAt ?? null,
    // A deadline is for projects and to-dos; a habit never ends.
    deadline: input.type === 'habit' ? null : (input.deadline ?? null),
    goalUuid: input.goalUuid ?? null,
  };
}

/**
 * Plants a seed inside a write already open, so a caller can plant
 * several with other writes as one (onboarding's finish).
 */
export async function plantSeed(tx: Tx, input: SeedInput, linkItem?: string): Promise<SeedRow> {
  const now = tx.now();
  const row: SeedRow = {
    uuid: crypto.randomUUID(),
    ...columns(input),
    pausedAt: null,
    archivedAt: null,
    archiveNote: null,
    deletedAt: null,
    createdAt: now,
    updatedAt: now,
  };
  await tx.put('commitments', row);
  if (linkItem) await tx.patch('goal_items', linkItem, { commitmentUuid: row.uuid, updatedAt: now });
  return row;
}

/**
 * Seeds (`commitments`), mirroring CommitmentsRepository on the phone:
 * the same columns, and the same "history stays" rule, so archiving is
 * the way a seed retires.
 */
export class SeedsRepository {
  constructor(private readonly writer: Writer) {}

  /**
   * Plants a seed. [linkItem] is the goal item it was planted from; the
   * item and the seed are linked in the same transaction ([[Goals]]).
   */
  plant(input: SeedInput, linkItem?: string): Promise<SeedRow> {
    return this.writer.run((tx) => plantSeed(tx, input, linkItem));
  }

  /** An edit rewrites the seed's own fields and keeps its state (pause, archive). */
  edit(uuid: string, input: SeedInput): Promise<void> {
    return this.writer.run(async (tx) => {
      await tx.patch('commitments', uuid, { ...columns(input), updatedAt: tx.now() });
    });
  }

  /**
   * Vacation mode. The pause takes effect now: days that ended before it
   * are still judged, so pausing after a miss cannot rewrite the miss.
   */
  setPaused(uuid: string, paused: boolean): Promise<void> {
    return this.writer.run(async (tx) => {
      const now = tx.now();
      await tx.patch('commitments', uuid, { pausedAt: paused ? now : null, updatedAt: now });
    });
  }

  /** Puts a seed away, with the note that says why. History stays. */
  archive(uuid: string, note: string | null): Promise<void> {
    return this.writer.run(async (tx) => {
      const now = tx.now();
      await tx.patch('commitments', uuid, { archivedAt: now, archiveNote: note?.trim() || null, updatedAt: now });
    });
  }

  /** Back onto the field, note and all cleared. */
  restore(uuid: string): Promise<void> {
    return this.writer.run(async (tx) => {
      await tx.patch('commitments', uuid, { archivedAt: null, archiveNote: null, updatedAt: tx.now() });
    });
  }
}

/** Today's Harvest Day for a clock. */
export function dayOf(clock: () => Date): HarvestDay {
  return HarvestDay.of(clock());
}
