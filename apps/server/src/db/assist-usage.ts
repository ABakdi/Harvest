import type { Collection, ObjectId } from 'mongodb';
import type { AssistUsageDoc } from './types.js';

/**
 * How much of the day's assist an account has spent.
 *
 * A count and a date, nothing else: what was asked and what was
 * answered are not the server's to keep ([[Notes]] N8). The day is the
 * UTC date, because a quota that follows a timezone is a quota that
 * can be reset by flying.
 */
export class AssistUsageRepository {
  constructor(private readonly usage: Collection<AssistUsageDoc>) {}

  static dayOf(at: Date): string {
    return at.toISOString().slice(0, 10);
  }

  async usedOn(userId: ObjectId, day: string): Promise<number> {
    return (await this.usage.findOne({ userId, day }))?.count ?? 0;
  }

  /**
   * Counts one request against the day, and answers with the new
   * total. Counted before the model is called, not after: a failure
   * that costs the server a call is a failure that costs the account
   * one too, or a retry loop is free.
   */
  async spend(userId: ObjectId, day: string, at: Date): Promise<number> {
    const doc = await this.usage.findOneAndUpdate(
      { userId, day },
      { $inc: { count: 1 }, $set: { lastAt: at } },
      { upsert: true, returnDocument: 'after' },
    );
    return doc?.count ?? 1;
  }

  deleteAllFor(userId: ObjectId): Promise<unknown> {
    return this.usage.deleteMany({ userId });
  }
}
