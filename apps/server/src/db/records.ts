import type { SyncedTable } from '@harvest/contracts';
import type { Collection, ObjectId } from 'mongodb';
import type { CounterDoc, RecordDoc } from './types.js';

export class RecordsRepository {
  constructor(
    private readonly records: Collection<RecordDoc>,
    private readonly counters: Collection<CounterDoc>,
  ) {}

  /** The stored copy's clock, if there is one. */
  async findStamp(userId: ObjectId, table: SyncedTable, uuid: string): Promise<{ _id: ObjectId; stamp: number } | null> {
    return this.records.findOne(
      { userId, table, uuid },
      { projection: { _id: 1, stamp: 1 } },
    );
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

  /** A page of the user's rows after [after], in sequence order. */
  page(userId: ObjectId, after: number, limit: number): Promise<RecordDoc[]> {
    return this.records
      .find({ userId, seq: { $gt: after } })
      .sort({ seq: 1 })
      .limit(limit)
      .toArray();
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
