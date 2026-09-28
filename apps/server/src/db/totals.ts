import type { Collection, ObjectId } from 'mongodb';
import { isDuplicateKey } from './records.js';
import type { CounterDoc } from './types.js';

/** A running total kept on the account's counter. */
export type Total = 'recordBytes' | 'fileBytes';

/**
 * What an account keeps, in bytes, kept beside its sequence so a quota
 * can be checked and charged in one atomic step (audit S5-02, S5-08).
 *
 * A total is filled in from what is stored the first time it is needed,
 * so an account from before it was kept starts at the right number.
 */
export class TotalsRepository {
  constructor(private readonly counters: Collection<CounterDoc>) {}

  /** The total, filled in with [compute] when the account has none yet. */
  async current(userId: ObjectId, total: Total, compute: () => Promise<number>): Promise<number> {
    const doc = await this.counters.findOne({ _id: userId }, { projection: { [total]: 1 } });
    const value = doc?.[total];
    if (typeof value === 'number') return value;
    const computed = await compute();
    try {
      // Only where it is still missing: two requests filling it in at
      // once agree, and the first one's number stands.
      await this.counters.updateOne(
        { _id: userId, [total]: { $exists: false } },
        { $set: { [total]: computed } },
        { upsert: true },
      );
    } catch (error) {
      // The counter exists and already has the total: nothing to fill in.
      if (!isDuplicateKey(error)) throw error;
    }
    const after = await this.counters.findOne({ _id: userId }, { projection: { [total]: 1 } });
    return after?.[total] ?? computed;
  }

  /**
   * Charges [delta] bytes if the total stays within [max], atomically:
   * two uploads at once cannot both fit into the last free megabyte.
   * A delta of zero or less always lands.
   */
  async reserve(
    userId: ObjectId,
    total: Total,
    delta: number,
    max: number,
    compute: () => Promise<number>,
  ): Promise<boolean> {
    await this.current(userId, total, compute);
    if (delta <= 0) {
      await this.counters.updateOne({ _id: userId }, { $inc: { [total]: delta } });
      return true;
    }
    const result = await this.counters.updateOne(
      { _id: userId, [total]: { $lte: max - delta } },
      { $inc: { [total]: delta } },
    );
    return result.modifiedCount === 1;
  }

  /**
   * Forgets the total, so it is filled in again from what is stored the
   * next time it is needed: after a sweep that dropped more than one
   * count can follow.
   */
  async forget(userId: ObjectId, total: Total): Promise<void> {
    await this.counters.updateOne({ _id: userId }, { $unset: { [total]: '' } });
  }

  /** Adds [delta] (either sign) to a total that is already filled in. */
  async add(userId: ObjectId, total: Total, delta: number): Promise<void> {
    if (delta === 0) return;
    await this.counters.updateOne({ _id: userId, [total]: { $exists: true } }, { $inc: { [total]: delta } });
  }

  /** Gives [bytes] back: a write that did not land, or a file let go. */
  async release(userId: ObjectId, total: Total, bytes: number): Promise<void> {
    if (bytes === 0) return;
    await this.counters.updateOne({ _id: userId, [total]: { $exists: true } }, { $inc: { [total]: -bytes } });
  }
}
