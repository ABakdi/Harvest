import { ObjectId, type Collection } from 'mongodb';
import type { OneTimePurpose, OneTimeTokenDoc } from './types.js';

export class OneTimeTokensRepository {
  constructor(private readonly tokens: Collection<OneTimeTokenDoc>) {}

  async create(userId: ObjectId, purpose: OneTimePurpose, tokenHash: string, now: Date, ttlMs: number): Promise<void> {
    await this.tokens.insertOne({
      _id: new ObjectId(),
      userId,
      purpose,
      tokenHash,
      createdAt: now,
      expiresAt: new Date(now.getTime() + ttlMs),
      usedAt: null,
    });
  }

  /** Uses the token up, if it is live; returns whether it was. Single use by construction. */
  async consume(userId: ObjectId, purpose: OneTimePurpose, tokenHash: string, now: Date): Promise<boolean> {
    const used = await this.tokens.findOneAndUpdate(
      { userId, purpose, tokenHash, usedAt: null, expiresAt: { $gt: now } },
      { $set: { usedAt: now } },
    );
    return used !== null;
  }

  /** A new link makes the old ones worthless: only the newest email works. */
  async invalidate(userId: ObjectId, purpose: OneTimePurpose, now: Date): Promise<void> {
    await this.tokens.updateMany({ userId, purpose, usedAt: null }, { $set: { usedAt: now } });
  }

  async deleteAll(userId: ObjectId): Promise<void> {
    await this.tokens.deleteMany({ userId });
  }
}
