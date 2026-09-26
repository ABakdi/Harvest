import { HarvestDay, Xp, parseScheduleJson, scheduleIsDueOn, scheduleToJson, type Schedule } from '@harvest/core';
import type { HarvestDB, Row } from './db';
import type { FileStore } from './files';
import { onCheckIn, onUndo } from './streaks';
import type { Tx, Writer } from './writer';

export type AlbumRow = Row<'albums'>;
export type MemoryRow = Row<'memories'>;
export type MemoryKind = MemoryRow['kind'];

export interface AlbumInput {
  name: string;
  /** Null for a shoebox; a schedule makes the album a seed (G3). */
  schedule: Schedule | null;
  remindAt: string | null;
  note: string | null;
}

/** An album's schedule, or null for one I add to when I feel like it. */
export function albumSchedule(album: Pick<AlbumRow, 'scheduleJson'>): Schedule | null {
  if (!album.scheduleJson) return null;
  try {
    return parseScheduleJson(album.scheduleJson);
  } catch {
    return null;
  }
}

/**
 * A new memory's path, the phone's `GalleryStorage.pathFor`: one folder
 * per album, named by the day, so the phone files a picture made here
 * exactly where it would have put its own.
 */
export function memoryPath(albumUuid: string, dayKey: string, uuid: string, extension: string): string {
  return `${albumUuid}/${dayKey}-${uuid.slice(0, 8)}${extension}`;
}

/** Whether a gym program owns this album, and so its rhythm ([[Gym]]). */
export async function albumIsGymBound(db: HarvestDB, uuid: string): Promise<boolean> {
  return (await db.rows('programs').toArray()).some((program) => program.albumUuid === uuid && program.deletedAt === null);
}

/** A scheduled album on the field: a seed whose check-in is a picture (G3). */
export interface AlbumDue {
  album: AlbumRow;
  schedule: Schedule;
  /** Today already has its picture. */
  done: boolean;
  /** Distinct days with a picture in the day's week. */
  doneDaysThisWeek: number;
  streak: number;
}

/**
 * The scheduled albums due on [day], with whether each has been fed
 * (`albumsDueToday`): due by the same rule as a habit, nothing due
 * before the album was made, and one fed today stays, as a checked
 * crop does. A gym program's album rides on the gym seed and never
 * stands on the field by itself ([[Gym]] Y12).
 */
export async function readAlbumsDue(db: HarvestDB, day: HarvestDay): Promise<AlbumDue[]> {
  const [albums, memories, programs, streaks] = await Promise.all([
    db.rows('albums').toArray(),
    db.rows('memories').where('harvestDay').anyOf(day.weekDays.map((d) => d.key)).toArray(),
    db.rows('programs').toArray(),
    db.rows('streaks').toArray(),
  ]);
  const bound = new Set(programs.filter((row) => row.deletedAt === null).map((row) => row.albumUuid));
  const fed = new Map<string, Set<string>>();
  for (const memory of memories) {
    if (memory.deletedAt !== null) continue;
    const days = fed.get(memory.albumUuid) ?? new Set<string>();
    days.add(memory.harvestDay);
    fed.set(memory.albumUuid, days);
  }
  const streakBy = new Map(streaks.map((row) => [row.scope, row.current]));

  const due: AlbumDue[] = [];
  for (const album of albums.sort((a, b) => a.createdAt.localeCompare(b.createdAt))) {
    if (album.deletedAt !== null || bound.has(album.uuid)) continue;
    const schedule = albumSchedule(album);
    if (!schedule) continue;
    const days = fed.get(album.uuid);
    const done = days?.has(day.key) ?? false;
    const doneDaysThisWeek = days?.size ?? 0;
    if (!done && !albumIsDueOn(album, schedule, day, doneDaysThisWeek)) continue;
    due.push({ album, schedule, done, doneDaysThisWeek, streak: streakBy.get(album.uuid) ?? 0 });
  }
  return due;
}

/** `Album.isDueOn`: never before the day it was made (Business Rules #12). */
function albumIsDueOn(album: AlbumRow, schedule: Schedule, day: HarvestDay, doneDaysThisWeek: number): boolean {
  const made = new Date(album.createdAt);
  if (!Number.isNaN(made.getTime()) && day.compareTo(HarvestDay.of(made)) < 0) return false;
  try {
    return scheduleIsDueOn(schedule, day, doneDaysThisWeek);
  } catch {
    return false; // an interval of zero days is never due, not a broken field
  }
}

/** Live memories of one album on one day: the album's "did I check in". */
async function countOn(tx: Tx, albumUuid: string, dayKey: string): Promise<number> {
  const rows = await tx.rows('memories').where('harvestDay').equals(dayKey).toArray();
  return rows.filter((row) => row.albumUuid === albumUuid && row.deletedAt === null).length;
}

/** The streak scope of an album is its uuid, earned like a habit's. */
const asSeed = (album: AlbumRow) => ({ uuid: album.uuid, type: 'habit' });

/**
 * Albums and the pictures in them, mirroring the phone's
 * GalleryRepository and GalleryService together.
 *
 * Adding a picture to a scheduled album is a check-in (G3): the first
 * one of a day pays what a habit pays and moves the album's streak and
 * the global one, in the same transaction as the row. Deleting the
 * day's last one takes it back with a mirror row, and restoring it
 * pays again, so history stays honest.
 */
export class GalleryRepository {
  constructor(
    private readonly writer: Writer,
    private readonly files: FileStore,
  ) {}

  createAlbum(input: AlbumInput): Promise<AlbumRow> {
    return this.writer.run(async (tx) => {
      const now = tx.now();
      const row: AlbumRow = {
        uuid: crypto.randomUUID(),
        name: input.name.trim(),
        scheduleJson: input.schedule ? JSON.stringify(scheduleToJson(input.schedule)) : null,
        remindAt: input.schedule ? input.remindAt : null,
        note: input.note?.trim() ? input.note.trim() : null,
        createdAt: now,
        updatedAt: now,
        deletedAt: null,
      };
      await tx.put('albums', row);
      return row;
    });
  }

  updateAlbum(uuid: string, input: AlbumInput): Promise<void> {
    return this.writer.run(async (tx) => {
      await tx.patch('albums', uuid, {
        name: input.name.trim(),
        scheduleJson: input.schedule ? JSON.stringify(scheduleToJson(input.schedule)) : null,
        remindAt: input.schedule ? input.remindAt : null,
        note: input.note?.trim() ? input.note.trim() : null,
        updatedAt: tx.now(),
      });
    });
  }

  /** Into the trash; its pictures go with it and come back with it. */
  deleteAlbum(uuid: string): Promise<void> {
    return this.writer.run(async (tx) => {
      const now = tx.now();
      await tx.patch('albums', uuid, { deletedAt: now, updatedAt: now });
    });
  }

  restoreAlbum(uuid: string): Promise<void> {
    return this.writer.run(async (tx) => {
      await tx.patch('albums', uuid, { deletedAt: null, updatedAt: tx.now() });
    });
  }

  /** The album and every picture in it, for good (G5). */
  async purgeAlbum(uuid: string): Promise<void> {
    const released = await this.writer.run(async (tx) => {
      const memories = (await tx.rows('memories').toArray()).filter((row) => row.albumUuid === uuid);
      for (const memory of memories) await tx.purge('memories', memory.uuid);
      await tx.purge('albums', uuid);
      return memories;
    });
    for (const memory of released) await this.files.release(memory.uuid, await this.hashOf(memory));
  }

  /**
   * Files a picture or a clip and pays the check-in it counts as
   * (`GalleryService.add`). The bytes are kept in this browser first and
   * sent once the passphrase allows; the row does not wait for them.
   */
  async addMemory(
    album: AlbumRow,
    input: { blob: Blob; kind: MemoryKind; extension: string; note?: string | null; day?: HarvestDay },
  ): Promise<MemoryRow> {
    const { sha256 } = await this.files.keep(input.blob);
    const day = input.day ?? HarvestDay.of(this.writer.clock());
    const uuid = crypto.randomUUID();
    await this.files.queue('memories', uuid, sha256);
    const memory = await this.writer.run(async (tx) => {
      const before = await countOn(tx, album.uuid, day.key);
      const now = tx.now();
      const row: MemoryRow = {
        uuid,
        albumUuid: album.uuid,
        harvestDay: day.key,
        path: memoryPath(album.uuid, day.key, uuid, input.extension),
        kind: input.kind,
        note: input.note?.trim() ? input.note.trim() : null,
        fileHash: null,
        capturedAt: now,
        updatedAt: now,
        deletedAt: null,
      };
      await tx.put('memories', row);
      if (album.scheduleJson !== null && before === 0) {
        await tx.ledger({ kind: 'xp', delta: Xp.memory, reason: `memory:${uuid}`, harvestDay: day.key });
        await onCheckIn(tx, asSeed(album), day);
      }
      return row;
    });
    void this.files.upload().catch(() => undefined);
    return memory;
  }

  setMemoryNote(uuid: string, note: string | null): Promise<void> {
    return this.writer.run(async (tx) => {
      await tx.patch('memories', uuid, { note: note?.trim() ? note.trim() : null, updatedAt: tx.now() });
    });
  }

  /**
   * Into the trash, taking back what the picture earned when it was
   * the day's only one (`GalleryService.remove`).
   */
  removeMemory(uuid: string): Promise<void> {
    return this.writer.run(async (tx) => {
      const memory = await tx.get('memories', uuid);
      if (!memory || memory.deletedAt !== null) return;
      const now = tx.now();
      await tx.put('memories', { ...memory, deletedAt: now, updatedAt: now });
      const album = await tx.get('albums', memory.albumUuid);
      if (!album || album.scheduleJson === null) return;
      if ((await countOn(tx, album.uuid, memory.harvestDay)) > 0) return;
      const granted = (await tx.ledgerFor(`memory:${uuid}`, `memory-undo:${uuid}`)).reduce(
        (sum, entry) => sum + entry.delta,
        0,
      );
      if (granted !== 0) {
        await tx.ledger({ kind: 'xp', delta: -granted, reason: `memory-undo:${uuid}`, harvestDay: memory.harvestDay });
      }
      await onUndo(tx, asSeed(album), HarvestDay.parse(memory.harvestDay));
    });
  }

  /** Back from the trash, paying its day again if it is now the only one. */
  async restoreMemory(uuid: string): Promise<void> {
    await this.writer.run(async (tx) => {
      const memory = await tx.get('memories', uuid);
      if (!memory || memory.deletedAt === null) return;
      await tx.put('memories', { ...memory, deletedAt: null, updatedAt: tx.now() });
      const album = await tx.get('albums', memory.albumUuid);
      if (!album || album.scheduleJson === null) return;
      if ((await countOn(tx, album.uuid, memory.harvestDay)) !== 1) return;
      await tx.ledger({ kind: 'xp', delta: Xp.memory, reason: `memory:${uuid}`, harvestDay: memory.harvestDay });
      await onCheckIn(tx, asSeed(album), HarvestDay.parse(memory.harvestDay));
    });
    // A picture brought back may still have a file to send.
    void this.files.upload().catch(() => undefined);
  }

  /** The step that actually deletes: the row, and this browser's copy. */
  async purgeMemory(uuid: string): Promise<void> {
    const memory = await this.writer.run(async (tx) => {
      const row = await tx.get('memories', uuid);
      if (row) await tx.purge('memories', uuid);
      return row;
    });
    if (memory) await this.files.release(uuid, await this.hashOf(memory));
  }

  /** Every trashed picture and every trashed album, for good. */
  async emptyTrash(): Promise<number> {
    const { memories, albums } = await this.writer.run(async (tx) => ({
      memories: (await tx.rows('memories').toArray()).filter((row) => row.deletedAt !== null),
      albums: (await tx.rows('albums').toArray()).filter((row) => row.deletedAt !== null),
    }));
    for (const memory of memories) await this.purgeMemory(memory.uuid);
    for (const album of albums) await this.purgeAlbum(album.uuid);
    return memories.length + albums.length;
  }

  private async hashOf(memory: MemoryRow): Promise<string | null> {
    return memory.fileHash ?? (await this.files.localHash(memory.uuid));
  }
}

// --------------------------------------------------------------- capture

/** Long edge after downscaling, and the JPEG quality it lands at (G4). */
export const maxImageEdge = 1600;
export const imageQuality = 0.82;

/** `.jpg` unless the source says otherwise; a video keeps its own. */
export function extensionOf(name: string, video: boolean): string {
  const dot = name.lastIndexOf('.');
  const extension = dot > 0 ? name.slice(dot).toLowerCase() : '';
  if (extension.length > 1 && extension.length <= 5) return extension;
  return video ? '.mp4' : '.jpg';
}

/**
 * A picture as the phone would keep it: at most 1600 on the long edge
 * and re-encoded as JPEG at 82, the original not kept (G4). A picture
 * this browser cannot decode is kept as it came, rather than lost.
 */
export async function downscaleImage(file: Blob): Promise<{ blob: Blob; converted: boolean }> {
  if (typeof createImageBitmap !== 'function') return { blob: file, converted: false };
  try {
    const bitmap = await createImageBitmap(file, { imageOrientation: 'from-image' });
    const scale = Math.min(1, maxImageEdge / Math.max(bitmap.width, bitmap.height));
    const width = Math.max(1, Math.round(bitmap.width * scale));
    const height = Math.max(1, Math.round(bitmap.height * scale));
    const canvas = document.createElement('canvas');
    canvas.width = width;
    canvas.height = height;
    const context = canvas.getContext('2d');
    if (!context) return { blob: file, converted: false };
    context.drawImage(bitmap, 0, 0, width, height);
    bitmap.close();
    const blob = await new Promise<Blob | null>((resolve) => canvas.toBlob(resolve, 'image/jpeg', imageQuality));
    return blob ? { blob, converted: true } : { blob: file, converted: false };
  } catch {
    return { blob: file, converted: false };
  }
}
