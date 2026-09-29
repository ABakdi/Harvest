import { ObjectId, type Collection } from 'mongodb';
import type { RefreshTokenDoc, SealedBytes, SessionDoc } from './types.js';

/** The accounts' collection, which a caller's session is joined to. */
export const usersCollection = 'users';

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

  /**
   * Whether the session is live and its account has confirmed its email,
   * in one round trip: what every request behind sign-in needs to know
   * before its handler (SV-11). Null when the session or the account is
   * gone.
   */
  async findLiveCaller(userId: ObjectId, sessionId: ObjectId, now: Date): Promise<{ verified: boolean } | null> {
    const [row] = await this.sessions
      .aggregate<{ user: { verifiedAt?: Date | null }[] }>([
        { $match: { _id: sessionId, userId, revokedAt: null, expiresAt: { $gt: now } } },
        { $limit: 1 },
        // The plain form of $lookup: a pipeline beside localField and
        // foreignField needs MongoDB 5, and a server without AVX runs 4.4.
        { $lookup: { from: usersCollection, localField: 'userId', foreignField: '_id', as: 'user' } },
        { $project: { _id: 0, 'user.verifiedAt': 1 } },
      ])
      .toArray();
    const user = row?.user[0];
    if (!user) return null;
    return { verified: user.verifiedAt !== null && user.verifiedAt !== undefined };
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
   * Marks the token used and keeps, on it, the token it was exchanged
   * for (sealed), in one atomic write, and returns it; null when there
   * is no unused token by that hash. Two requests racing with the same
   * token get one success and one null. A used token therefore always
   * names its successor: a retry never finds one half exchanged (Q6-16).
   */
  consumeToken(
    userId: ObjectId,
    tokenHash: string,
    now: Date,
    successor: SealedBytes,
  ): Promise<RefreshTokenDoc | null> {
    return this.tokens.findOneAndUpdate(
      { userId, tokenHash, usedAt: null },
      { $set: { usedAt: now, successor } },
      { returnDocument: 'after' },
    );
  }

  /** Lets go of an unused token nobody was given (a lost race). */
  async dropUnused(userId: ObjectId, tokenHash: string): Promise<void> {
    await this.tokens.deleteOne({ userId, tokenHash, usedAt: null });
  }

  findToken(userId: ObjectId, tokenHash: string): Promise<RefreshTokenDoc | null> {
    return this.tokens.findOne({ userId, tokenHash });
  }
}
