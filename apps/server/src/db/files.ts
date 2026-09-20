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

  async has(userId: ObjectId, sha256: string): Promise<boolean> {
    return (await this.files.countDocuments({ userId, sha256 }, { limit: 1 })) > 0;
  }

  /** Which of [hashes] the account does not have. */
  async missing(userId: ObjectId, hashes: readonly string[]): Promise<string[]> {
    if (hashes.length === 0) return [];
    const held = await this.files
      .find({ userId, sha256: { $in: [...hashes] } }, { projection: { sha256: 1 } })
      .toArray();
    const have = new Set(held.map((doc) => doc.sha256));
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

  /** Everything the account holds, for a delete-account sweep. */
  deleteAllFor(userId: ObjectId): Promise<unknown> {
    return this.files.deleteMany({ userId });
  }
}

export type { Binary };
