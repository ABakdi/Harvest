import type { Collection } from 'mongodb';
import type { LoginFailureDoc } from './types.js';

/**
 * Failed sign-ins per email, from any address (audit S5-06). The
 * per-address limit stops one machine guessing; this one slows many
 * machines guessing at one account, softly: twenty wrong passwords an
 * hour is more than a person makes, and far fewer than a list does.
 *
 * Kept in Mongo, so a restart does not hand out a fresh allowance, and
 * keyed by a hash of the address, so an address nobody registered is
 * never written down as itself. Every address counts the same whether
 * or not it has an account, so the limit says nothing about which do.
 */
export class LoginFailuresRepository {
  constructor(private readonly failures: Collection<LoginFailureDoc>) {}

  /** Seconds until [key] may try again, or null when it may now. */
  async blockedFor(key: string, now: Date, limit: number): Promise<number | null> {
    const doc = await this.failures.findOne({ _id: key, resetAt: { $gt: now } });
    if (!doc || doc.count < limit) return null;
    return Math.max(1, Math.ceil((doc.resetAt.getTime() - now.getTime()) / 1000));
  }

  /** Counts one failure in the current window, or starts a window. */
  async fail(key: string, now: Date, windowMs: number): Promise<void> {
    const counted = await this.failures.updateOne({ _id: key, resetAt: { $gt: now } }, { $inc: { count: 1 } });
    if (counted.matchedCount === 1) return;
    await this.failures.updateOne(
      { _id: key },
      { $set: { count: 1, resetAt: new Date(now.getTime() + windowMs) } },
      { upsert: true },
    );
  }

  /** The right password ends the window. */
  async clear(key: string): Promise<void> {
    await this.failures.deleteOne({ _id: key });
  }
}
