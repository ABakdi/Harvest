import { defaultBarGrams, dailySchedule, nextPosition, scheduleToJson } from '@harvest/core';
import type { DayRow, DayTree, ProgramRow, SlotRow, TargetSetRow } from './gym';
import type { Tx, Writer } from './writer';

export type PhotoPrompt = ProgramRow['photoPrompt'];

export interface TargetSetInput {
  reps: number | null;
  weightGrams: number | null;
  percentTenths: number | null;
  openEnded: boolean;
}

/**
 * Programs, their days, their slots and their target sets, mirroring
 * the phone's ProgramsRepository. A program is soft-deleted, because
 * its sessions name it; its structure — days, slots, sets — is mine to
 * edit and goes for good ([[Business-Rules]] #8).
 */
export class ProgramsRepository {
  constructor(private readonly writer: Writer) {}

  createProgram(name: string): Promise<ProgramRow> {
    return this.writer.run(async (tx) => {
      const now = tx.now();
      const row: ProgramRow = {
        uuid: crypto.randomUUID(),
        name: name.trim(),
        note: null,
        weeks: null,
        commitmentUuid: null,
        albumUuid: null,
        photoPrompt: 'after',
        createdAt: now,
        updatedAt: now,
        deletedAt: null,
      };
      await tx.put('programs', row);
      return row;
    });
  }

  /** Changes only what is given: a rename does not touch the seed link. */
  updateProgram(
    uuid: string,
    changes: Partial<Pick<ProgramRow, 'name' | 'note' | 'commitmentUuid' | 'albumUuid' | 'photoPrompt'>>,
  ): Promise<void> {
    return this.writer.run(async (tx) => {
      const next = { ...changes };
      if (next.name !== undefined) next.name = next.name.trim();
      await tx.patch('programs', uuid, { ...next, updatedAt: tx.now() });
    });
  }

  /** Soft: the sessions it made keep their titles and their history. */
  deleteProgram(uuid: string): Promise<void> {
    return this.writer.run(async (tx) => {
      const now = tx.now();
      await tx.patch('programs', uuid, { deletedAt: now, updatedAt: now });
    });
  }

  /**
   * Plants the program on the field (Y12): a habit, times a week or
   * daily, bound to it — and, if asked, an album that rides on the
   * habit rather than being scheduled beside it.
   */
  plant(uuid: string, input: { title: string; timesPerWeek: number; album: boolean }): Promise<void> {
    return this.writer.run(async (tx) => {
      const now = tx.now();
      const schedule = input.timesPerWeek >= 7 ? dailySchedule : { type: 'timesPerWeek' as const, times: input.timesPerWeek };
      const commitmentUuid = crypto.randomUUID();
      await tx.put('commitments', {
        uuid: commitmentUuid,
        type: 'habit',
        title: input.title.trim(),
        scheduleJson: JSON.stringify(scheduleToJson(schedule)),
        totalTarget: null,
        dailyCommitment: null,
        dueDay: null,
        note: null,
        remindAt: null,
        deadline: null,
        goalUuid: null,
        pausedAt: null,
        archivedAt: null,
        archiveNote: null,
        deletedAt: null,
        createdAt: now,
        updatedAt: now,
      });
      let albumUuid: string | null = null;
      if (input.album) {
        albumUuid = crypto.randomUUID();
        await tx.put('albums', {
          uuid: albumUuid,
          name: input.title.trim(),
          scheduleJson: null,
          remindAt: null,
          note: null,
          createdAt: now,
          updatedAt: now,
          deletedAt: null,
        });
      }
      await tx.patch('programs', uuid, { commitmentUuid, albumUuid, updatedAt: now });
    });
  }

  /** Unbinding leaves the seed and the album standing. */
  unplant(uuid: string): Promise<void> {
    return this.updateProgram(uuid, { commitmentUuid: null, albumUuid: null });
  }

  // ------------------------------------------------------------------ days

  /** After the last day, not at the count: a removed day leaves a gap, not a twin. */
  private async nextDayPosition(tx: Tx, programUuid: string): Promise<number> {
    return nextPosition(await tx.rows('program_days').where('programUuid').equals(programUuid).toArray());
  }

  private async insertDay(tx: Tx, programUuid: string, name: string, week: number | null, accessories: string | null): Promise<DayRow> {
    const row: DayRow = {
      uuid: crypto.randomUUID(),
      programUuid,
      name: name.trim(),
      position: await this.nextDayPosition(tx, programUuid),
      week,
      accessories,
    };
    await tx.put('program_days', row);
    return row;
  }

  addDay(programUuid: string, name: string): Promise<DayRow> {
    return this.writer.run((tx) => this.insertDay(tx, programUuid, name, null, null));
  }

  updateDay(uuid: string, changes: Partial<Pick<DayRow, 'name' | 'accessories'>>): Promise<void> {
    return this.writer.run(async (tx) => {
      const next = { ...changes };
      if (next.name !== undefined) next.name = next.name.trim();
      if (next.accessories !== undefined) next.accessories = next.accessories?.trim() || null;
      await tx.patch('program_days', uuid, next);
    });
  }

  /** A day goes with its slots and their sets. */
  removeDay(uuid: string): Promise<void> {
    return this.writer.run(async (tx) => {
      const slots = await tx.rows('program_slots').where('dayUuid').equals(uuid).toArray();
      for (const slot of slots) await this.purgeSlot(tx, slot.uuid);
      await tx.purge('program_days', uuid);
    });
  }

  /**
   * Copies a day, sets and all — most days are the last day with two
   * numbers changed. Every copied row gets a uuid of its own, or two
   * days would share one row and editing either would edit both.
   */
  duplicateDay(day: DayTree, name: string): Promise<DayRow> {
    return this.writer.run(async (tx) => {
      const copy = await this.insertDay(tx, day.row.programUuid, name, day.row.week, day.row.accessories);
      for (const slot of day.slots) {
        const slotUuid = crypto.randomUUID();
        await tx.put('program_slots', { ...slot.row, uuid: slotUuid, dayUuid: copy.uuid });
        for (const set of slot.sets) await tx.put('target_sets', { ...set, uuid: crypto.randomUUID(), slotUuid });
      }
      return copy;
    });
  }

  /** The days of a program, in the order given. */
  reorderDays(uuids: string[]): Promise<void> {
    return this.writer.run(async (tx) => {
      for (const [position, uuid] of uuids.entries()) await tx.patch('program_days', uuid, { position });
    });
  }

  // ----------------------------------------------------------------- slots

  addSlot(dayUuid: string, exerciseId: string): Promise<SlotRow> {
    return this.writer.run(async (tx) => {
      const row: SlotRow = {
        uuid: crypto.randomUUID(),
        dayUuid,
        exerciseId,
        position: nextPosition(await tx.rows('program_slots').where('dayUuid').equals(dayUuid).toArray()),
        restSeconds: null,
        barGrams: defaultBarGrams,
        note: null,
      };
      await tx.put('program_slots', row);
      return row;
    });
  }

  /** Only what is given changes: a new bar does not clear the rest. */
  updateSlot(uuid: string, changes: Partial<Pick<SlotRow, 'exerciseId' | 'restSeconds' | 'barGrams' | 'note'>>): Promise<void> {
    return this.writer.run(async (tx) => {
      await tx.patch('program_slots', uuid, changes);
    });
  }

  private async purgeSlot(tx: Tx, uuid: string): Promise<void> {
    const sets = await tx.rows('target_sets').where('slotUuid').equals(uuid).toArray();
    for (const set of sets) await tx.purge('target_sets', set.uuid);
    await tx.purge('program_slots', uuid);
  }

  removeSlot(uuid: string): Promise<void> {
    return this.writer.run((tx) => this.purgeSlot(tx, uuid));
  }

  /** The slots of a day, in the order given. */
  reorderSlots(uuids: string[]): Promise<void> {
    return this.writer.run(async (tx) => {
      for (const [position, uuid] of uuids.entries()) await tx.patch('program_slots', uuid, { position });
    });
  }

  // ------------------------------------------------------------ target sets

  addTargetSet(slotUuid: string, input: TargetSetInput): Promise<TargetSetRow> {
    return this.writer.run(async (tx) => {
      const row: TargetSetRow = {
        uuid: crypto.randomUUID(),
        slotUuid,
        position: nextPosition(await tx.rows('target_sets').where('slotUuid').equals(slotUuid).toArray()),
        ...input,
      };
      await tx.put('target_sets', row);
      return row;
    });
  }

  /**
   * A set is a weight or a percentage, never both and never neither
   * (`TargetSet`): whichever is given clears the other.
   */
  updateTargetSet(uuid: string, input: TargetSetInput): Promise<void> {
    return this.writer.run(async (tx) => {
      await tx.patch('target_sets', uuid, input);
    });
  }

  removeTargetSet(uuid: string): Promise<void> {
    return this.writer.run((tx) => tx.purge('target_sets', uuid));
  }

  /** Set by hand and bumped by hand: the app does not do the programming. */
  setTrainingMax(programUuid: string, exerciseId: string, grams: number): Promise<void> {
    return this.writer.run(async (tx) => {
      await tx.put('training_maxes', { programUuid, exerciseId, grams, updatedAt: tx.now() });
    });
  }
}
