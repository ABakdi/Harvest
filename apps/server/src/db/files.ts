import type { Binary, Collection, ObjectId } from 'mongodb';
import type { FileDoc } from './types.js';

/**
 * The account's files, by the SHA-256 of their plaintext.
 *
 * The bytes stored are ciphertext and the server has no key, so the
 * name is a claim it cannot check — which is safe, because a wrong
 * name only ever misleads the account that wrote it. What the server
 * does enforce is the size of each file and the size of the lot.
 */
export class FilesRepository {
  constructor(private readonly files: Collection<FileDoc>) {}

  get(userId: ObjectId, sha256: string): Promise<FileDoc | null> {
    return this.files.findOne({ userId, sha256 });
  }

  /** When the file came and was last claimed, without its bytes. */
  times(userId: ObjectId, sha256: string): Promise<Pick<FileDoc, 'uploadedAt' | 'claimedAt'> | null> {
    return this.files.findOne({ userId, sha256 }, { projection: { _id: 0, uploadedAt: 1, claimedAt: 1 } });
  }

  /**
   * Whether the account has the file; when it does, the file is marked
   * claimed at [now], because the device asking is about to name it.
   */
  async claim(userId: ObjectId, sha256: string, now: Date): Promise<boolean> {
    const result = await this.files.updateOne({ userId, sha256 }, { $set: { claimedAt: now } });
    return result.matchedCount === 1;
  }

  /**
   * Which of [hashes] the account does not have. The ones it has are
   * marked claimed at [now]: the device asking will name them in rows
   * it may not have pushed yet.
   */
  async missing(userId: ObjectId, hashes: readonly string[], now: Date): Promise<string[]> {
    if (hashes.length === 0) return [];
    const held = await this.files
      .find({ userId, sha256: { $in: [...hashes] } }, { projection: { sha256: 1 } })
      .toArray();
    const have = new Set(held.map((doc) => doc.sha256));
    if (have.size > 0) {
      await this.files.updateMany({ userId, sha256: { $in: [...have] } }, { $set: { claimedAt: now } });
    }
    return hashes.filter((hash) => !have.has(hash));
  }

  /** What the account is using, in ciphertext bytes. */
  async usedBytes(userId: ObjectId): Promise<number> {
    const [row] = await this.files
      .aggregate<{ total: number }>([
        { $match: { userId } },
        { $group: { _id: null, total: { $sum: '$bytes' } } },
      ])
      .toArray();
    return row?.total ?? 0;
  }

  /**
   * Stores a file, or leaves the stored copy alone: the bytes are named
   * by their own contents, so a second upload of the same name is the
   * same file and re-writing it would only cost time.
   */
  async put(doc: Omit<FileDoc, '_id'>): Promise<boolean> {
    const result = await this.files.updateOne(
      { userId: doc.userId, sha256: doc.sha256 },
      { $setOnInsert: doc },
      { upsert: true },
    );
    return result.upsertedCount === 1;
  }

  /** Deletes one file; answers its size, or null when there was none. */
  async delete(userId: ObjectId, sha256: string): Promise<number | null> {
    const gone = await this.files.findOneAndDelete({ userId, sha256 }, { projection: { bytes: 1 } });
    return gone ? gone.bytes : null;
  }

  /**
   * The files no row names ([named]) that nobody has uploaded or
   * claimed since [before]: what the sweep may let go.
   */
  async unnamed(userId: ObjectId, named: readonly string[], before: Date): Promise<string[]> {
    const docs = await this.files
      .find(
        {
          userId,
          sha256: { $nin: [...named] },
          uploadedAt: { $lt: before },
          $or: [{ claimedAt: { $exists: false } }, { claimedAt: { $lt: before } }],
        },
        { projection: { sha256: 1 } },
      )
      .toArray();
    return docs.map((doc) => doc.sha256);
  }

  /** The accounts that hold any file at all, for the sweep. */
  async owners(): Promise<ObjectId[]> {
    return this.files.distinct('userId');
  }

  /** Everything the account holds, for a delete-account sweep. */
  deleteAllFor(userId: ObjectId): Promise<unknown> {
    return this.files.deleteMany({ userId });
  }
}

export type { Binary };
