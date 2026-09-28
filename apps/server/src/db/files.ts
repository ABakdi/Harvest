import { Readable } from 'node:stream';
import { CursorTimeoutMode, GridFSBucket, ObjectId, type Collection, type Db } from 'mongodb';
import { operationTimeoutMs } from './mongo.js';
import type { FileDoc } from './types.js';

/** The GridFS bucket the bytes live in, beside the `files` documents. */
export const fileBlobBucket = 'file_blobs';

/** Everything of a file document but its bytes. */
const withoutBytes = { projection: { blob: 0 } } as const;

/**
 * The account's files, by the SHA-256 of their plaintext.
 *
 * The bytes stored are ciphertext and the server has no key, so the
 * name is a claim it cannot check — which is safe, because a wrong
 * name only ever misleads the account that wrote it. What the server
 * does enforce is the size of each file and the size of the lot.
 *
 * The bytes live in GridFS, in chunks, not in the `files` document: a
 * document stops at 16 MB and a file may be 25 (Q6-01), and a chunked
 * file goes out as a stream rather than whole in memory (P6-05). A file
 * stored before that keeps its bytes in `blob` and is read from there.
 */
export class FilesRepository {
  private readonly bucket: GridFSBucket;

  constructor(
    private readonly files: Collection<FileDoc>,
    private readonly db: Db,
  ) {
    this.bucket = new GridFSBucket(db, { bucketName: fileBlobBucket });
  }

  /** The file's document, without its bytes. */
  get(userId: ObjectId, sha256: string): Promise<FileDoc | null> {
    return this.files.findOne({ userId, sha256 }, withoutBytes);
  }

  /**
   * The file's bytes as a stream: from GridFS, a chunk at a time, or
   * from the document of a file stored before GridFS.
   */
  async bytesOf(doc: FileDoc): Promise<Readable | null> {
    if (doc.gridId) return Readable.from(this.chunks(doc.gridId));
    const old = await this.files.findOne({ _id: doc._id, userId: doc.userId }, { projection: { blob: 1 } });
    const u8 = old?.blob?.buffer;
    if (!u8) return null;
    // A view on the bytes the driver read, not a copy of them.
    return Readable.from([Buffer.from(u8.buffer, u8.byteOffset, u8.byteLength)]);
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
   * A GridFS file's chunks in order, a few at a time. The driver's own
   * download stream reads a whole batch of chunks ahead (up to 16 MB),
   * so thirty downloads at once held half a gigabyte; this holds four
   * chunks (about 1 MB) per download (P6-05).
   */
  private async *chunks(gridId: ObjectId): AsyncGenerator<Buffer> {
    const cursor = this.db
      .collection<{ files_id: ObjectId; n: number; data: { buffer: Uint8Array } }>(`${fileBlobBucket}.chunks`)
      // Each batch in its own time, not the whole download in one: a slow
      // phone may take minutes over a big file (Q6-17).
      .find(
        { files_id: gridId },
        { projection: { n: 1, data: 1 }, timeoutMS: operationTimeoutMs, timeoutMode: CursorTimeoutMode.ITERATION },
      )
      .sort({ n: 1 })
      .batchSize(4);
    let expected = 0;
    try {
      for await (const chunk of cursor) {
        if (chunk.n !== expected) throw new Error(`file ${gridId.toHexString()} is missing chunk ${expected}`);
        expected += 1;
        const u8 = chunk.data.buffer;
        yield Buffer.from(u8.buffer, u8.byteOffset, u8.byteLength);
      }
    } finally {
      await cursor.close();
    }
  }

  /**
   * Stores a file, or leaves the stored copy alone: the bytes are named
   * by their own contents, so a second upload of the same name is the
   * same file and re-writing it would only cost time. The bytes go to
   * GridFS first; if the document then turns out to exist already, they
   * are let go again. Answers whether this call stored it.
   */
  async put(doc: Omit<FileDoc, '_id' | 'blob' | 'gridId'>, bytes: Buffer): Promise<boolean> {
    const gridId = new ObjectId();
    await new Promise<void>((resolve, reject) => {
      const upload = this.bucket.openUploadStreamWithId(gridId, doc.sha256, {
        metadata: { userId: doc.userId },
      });
      upload.once('finish', () => resolve());
      upload.once('error', reject);
      upload.end(bytes);
    });
    let stored = false;
    try {
      const result = await this.files.updateOne(
        { userId: doc.userId, sha256: doc.sha256 },
        { $setOnInsert: { ...doc, gridId } },
        { upsert: true },
      );
      stored = result.upsertedCount === 1;
    } finally {
      if (!stored) await this.dropBytes([gridId]);
    }
    return stored;
  }

  /** Deletes one file; answers its size, or null when there was none. */
  async delete(userId: ObjectId, sha256: string): Promise<number | null> {
    const gone = await this.files.findOneAndDelete({ userId, sha256 }, { projection: { bytes: 1, gridId: 1 } });
    if (!gone) return null;
    if (gone.gridId) await this.dropBytes([gone.gridId]);
    return gone.bytes;
  }

  /** Lets GridFS files go, chunks and all; one that is already gone is no error. */
  private async dropBytes(ids: readonly ObjectId[]): Promise<void> {
    if (ids.length === 0) return;
    await this.db.collection(`${fileBlobBucket}.chunks`).deleteMany({ files_id: { $in: [...ids] } });
    await this.db.collection(`${fileBlobBucket}.files`).deleteMany({ _id: { $in: [...ids] } });
  }

  /**
   * The files no row names ([named]) that nobody has uploaded or
   * claimed since [before]: what the sweep may let go. The account's
   * old files are read a name at a time and checked here, rather than
   * sent every named hash in one `$nin`, which stops at 16 MB (SV-16).
   */
  async unnamed(userId: ObjectId, named: ReadonlySet<string>, before: Date): Promise<string[]> {
    const cursor = this.files.find(
      {
        userId,
        uploadedAt: { $lt: before },
        $or: [{ claimedAt: { $exists: false } }, { claimedAt: { $lt: before } }],
      },
      { projection: { _id: 0, sha256: 1 } },
    );
    const gone: string[] = [];
    for await (const doc of cursor) if (!named.has(doc.sha256)) gone.push(doc.sha256);
    return gone;
  }

  /** The accounts that hold any file at all, for the sweep. */
  async owners(): Promise<ObjectId[]> {
    return this.files.distinct('userId');
  }

  /** Everything the account holds, for deleting the account or starting over. */
  async deleteAllFor(userId: ObjectId): Promise<void> {
    const docs = await this.files.find({ userId }, { projection: { gridId: 1 } }).toArray();
    await this.files.deleteMany({ userId });
    const ids = docs.flatMap((doc) => (doc.gridId ? [doc.gridId] : []));
    for (let i = 0; i < ids.length; i += 1000) await this.dropBytes(ids.slice(i, i + 1000));
    // Bytes whose document never landed (a process stopped between the two).
    const strays = await this.db
      .collection(`${fileBlobBucket}.files`)
      .find({ 'metadata.userId': userId }, { projection: { _id: 1 } })
      .toArray();
    await this.dropBytes(strays.map((doc) => doc._id));
  }
}
