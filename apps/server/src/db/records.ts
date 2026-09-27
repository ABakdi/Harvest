import { privateTables, type SyncedTable } from '@harvest/contracts';
import { BSON, type Collection, type ObjectId } from 'mongodb';
import type { CounterDoc, RecordDoc } from './types.js';

/**
 * What a row costs beyond its payload: its table, key, clocks and
 * indexes. Counted so a million empty rows are not free.
 */
export const recordOverheadBytes = 256;

/**
 * A row's size as the quota counts it: the BSON size of what it carries
 * (its `enc` or its `data`), plus the fixed overhead. The same number
 * `$bsonSize` gives inside Mongo, so a total filled in from stored rows
 * agrees with one kept write by write.
 */
export function payloadBytes(doc: Pick<RecordDoc, 'data' | 'enc'>): number {
  const payload = doc.enc ?? doc.data;
  return (payload ? BSON.calculateObjectSize(payload) : 0) + recordOverheadBytes;
}

/** The tables whose rows name a file by its hash, in `data.fileHash`. */
export const fileTables: readonly SyncedTable[] = ['memories', 'note_attachments'];

export class RecordsRepository {
  constructor(
    private readonly records: Collection<RecordDoc>,
    private readonly counters: Collection<CounterDoc>,
  ) {}

  /** The stored copy's clock and size, if there is one. */
  async findStamp(
    userId: ObjectId,
    table: SyncedTable,
    uuid: string,
  ): Promise<{ _id: ObjectId; stamp: number; bytes: number } | null> {
    const found = await this.records.findOne(
      { userId, table, uuid },
      { projection: { _id: 1, stamp: 1, bytes: 1 } },
    );
    if (!found) return null;
    if (typeof found.bytes === 'number') return { _id: found._id, stamp: found.stamp, bytes: found.bytes };
    // A row stored before sizes were kept: measured once, here.
    const whole = await this.records.findOne({ _id: found._id, userId }, { projection: { data: 1, enc: 1 } });
    return { _id: found._id, stamp: found.stamp, bytes: whole ? payloadBytes(whole) : 0 };
  }

  /**
   * Writes a record, replacing the stored copy if there is one. The
   * replacement is conditional on the stored clock not having moved, so
   * a write that raced past the conflict check cannot be overwritten by
   * an older one. Returns whether the write landed.
   */
  async put(doc: Omit<RecordDoc, '_id'>, previous: { _id: ObjectId; stamp: number } | null): Promise<boolean> {
    if (previous === null) {
      try {
        await this.records.insertOne(doc as RecordDoc);
        return true;
      } catch (error) {
        if (isDuplicateKey(error)) return false;
        throw error;
      }
    }
    const result = await this.records.replaceOne(
      { _id: previous._id, userId: doc.userId, stamp: previous.stamp },
      doc,
    );
    return result.modifiedCount === 1;
  }

  /**
   * A page of the user's rows after [after], in sequence order: at most
   * [limit] rows and, past the first, at most [maxBytes] of them. The
   * rows are read one batch at a time and the page stops where the
   * bytes run out, so a pull never holds more than that in memory
   * (audit S5-02).
   */
  async page(
    userId: ObjectId,
    after: number,
    limit: number,
    maxBytes: number,
  ): Promise<{ docs: RecordDoc[]; more: boolean }> {
    const cursor = this.records
      .find({ userId, seq: { $gt: after } })
      .sort({ seq: 1 })
      .limit(limit + 1)
      .batchSize(100);
    const docs: RecordDoc[] = [];
    let bytes = 0;
    let more = false;
    try {
      for await (const doc of cursor) {
        const size = doc.bytes ?? payloadBytes(doc);
        if (docs.length === limit || (docs.length > 0 && bytes + size > maxBytes)) {
          more = true;
          break;
        }
        docs.push(doc);
        bytes += size;
      }
    } finally {
      await cursor.close();
    }
    return { docs, more };
  }

  /** What the account's rows add up to, as [payloadBytes] counts them. */
  async storedBytes(userId: ObjectId): Promise<number> {
    const [row] = await this.records
      .aggregate<{ total: number }>([
        { $match: { userId } },
        {
          $group: {
            _id: null,
            total: {
              $sum: {
                $add: [{ $ifNull: [{ $bsonSize: { $ifNull: ['$enc', '$data'] } }, 0] }, recordOverheadBytes],
              },
            },
          },
        },
      ])
      .toArray();
    return row?.total ?? 0;
  }

  /**
   * Every file hash a row still names: the rows of [fileTables] that
   * are not purged. A row in the trash still names its file, because it
   * can come back.
   */
  async namedFiles(userId: ObjectId): Promise<string[]> {
    const hashes = await this.records.distinct('data.fileHash', {
      userId,
      table: { $in: [...fileTables] },
      purged: { $ne: true },
    });
    return hashes.filter((hash): hash is string => typeof hash === 'string');
  }

  /**
   * Hard-deletes every private-tier row of the account: sealed under a
   * key nobody has any more, they cannot be read by anyone. No
   * tombstone is left; a pull simply never hands them out again.
   * Answers how many went.
   */
  async deletePrivate(userId: ObjectId): Promise<number> {
    const result = await this.records.deleteMany({ userId, table: { $in: [...privateTables] } });
    return result.deletedCount;
  }

  /** Whether any row of [fileTables] still names [sha256] (in the trash counts). */
  async namesFile(userId: ObjectId, sha256: string): Promise<boolean> {
    const found = await this.records.countDocuments(
      { userId, table: { $in: [...fileTables] }, purged: { $ne: true }, 'data.fileHash': sha256 },
      { limit: 1 },
    );
    return found > 0;
  }

  /** The next value of the user's sequence, taken atomically. */
  async nextSeq(userId: ObjectId): Promise<number> {
    const counter = await this.counters.findOneAndUpdate(
      { _id: userId },
      { $inc: { seq: 1 } },
      { upsert: true, returnDocument: 'after' },
    );
    return counter!.seq;
  }

  async currentSeq(userId: ObjectId): Promise<number> {
    return (await this.counters.findOne({ _id: userId }))?.seq ?? 0;
  }

  async deleteAll(userId: ObjectId): Promise<void> {
    await this.records.deleteMany({ userId });
    await this.counters.deleteOne({ _id: userId });
  }
}

export function isDuplicateKey(error: unknown): boolean {
  return typeof error === 'object' && error !== null && (error as { code?: unknown }).code === 11000;
}
