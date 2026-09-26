import { ObjectId, type Collection } from 'mongodb';
import type { RefreshTokenDoc, SessionDoc } from './types.js';

export class SessionsRepository {
  constructor(
    private readonly sessions: Collection<SessionDoc>,
    private readonly tokens: Collection<RefreshTokenDoc>,
  ) {}

  async create(session: Omit<SessionDoc, '_id' | 'revokedAt'>): Promise<SessionDoc> {
    const doc: SessionDoc = { _id: new ObjectId(), revokedAt: null, ...session };
    await this.sessions.insertOne(doc);
    return doc;
  }

  /** The session, if it is still signed in: not revoked, not expired. */
  findLive(userId: ObjectId, sessionId: ObjectId, now: Date): Promise<SessionDoc | null> {
    return this.sessions.findOne({
      _id: sessionId,
      userId,
      revokedAt: null,
      expiresAt: { $gt: now },
    });
  }

  listLive(userId: ObjectId, now: Date): Promise<SessionDoc[]> {
    return this.sessions
      .find({ userId, revokedAt: null, expiresAt: { $gt: now } })
      .sort({ lastSeenAt: -1 })
      .toArray();
  }

  /**
   * Records that the device was seen. Written at most once a minute per
   * session, so an active client does not turn every request into a write.
   */
  async touch(userId: ObjectId, sessionId: ObjectId, now: Date): Promise<void> {
    await this.sessions.updateOne(
      { _id: sessionId, userId, lastSeenAt: { $lt: new Date(now.getTime() - 60_000) } },
      { $set: { lastSeenAt: now } },
    );
  }

  async extend(userId: ObjectId, sessionId: ObjectId, expiresAt: Date, now: Date): Promise<void> {
    await this.sessions.updateOne({ _id: sessionId, userId }, { $set: { expiresAt, lastSeenAt: now } });
  }

  /**
   * Signs one device out: the session is marked revoked and its whole
   * refresh-token family goes with it. Returns whether a live session
   * was found.
   */
  async revoke(userId: ObjectId, sessionId: ObjectId, now: Date): Promise<boolean> {
    const result = await this.sessions.updateOne(
      { _id: sessionId, userId, revokedAt: null },
      { $set: { revokedAt: now } },
    );
    await this.tokens.deleteMany({ userId, sessionId });
    return result.modifiedCount === 1;
  }

  /** Signs every device out (a password reset, AC5). */
  async revokeAll(userId: ObjectId, now: Date): Promise<void> {
    await this.sessions.updateMany({ userId, revokedAt: null }, { $set: { revokedAt: now } });
    await this.tokens.deleteMany({ userId });
  }

  async deleteAll(userId: ObjectId): Promise<void> {
    await this.tokens.deleteMany({ userId });
    await this.sessions.deleteMany({ userId });
  }

  // ------------------------------------------------------ refresh tokens

  async addToken(token: Omit<RefreshTokenDoc, '_id' | 'usedAt' | 'createdAt'>, now: Date): Promise<void> {
    await this.tokens.insertOne({ _id: new ObjectId(), usedAt: null, createdAt: now, ...token });
  }

  /**
   * Marks the token used, atomically, and returns it, or null when there
   * is no unused token by that hash. Two requests racing with the same
   * token get one success and one null, and the null is then treated as
   * reuse.
   */
  consumeToken(userId: ObjectId, tokenHash: string, now: Date): Promise<RefreshTokenDoc | null> {
    return this.tokens.findOneAndUpdate(
      { userId, tokenHash, usedAt: null },
      { $set: { usedAt: now } },
      { returnDocument: 'after' },
    );
  }

  findToken(userId: ObjectId, tokenHash: string): Promise<RefreshTokenDoc | null> {
    return this.tokens.findOne({ userId, tokenHash });
  }
}
