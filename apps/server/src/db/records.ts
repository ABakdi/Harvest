import { hasColumn, privateTables, syncedTables, type SyncedTable } from '@harvest/contracts';
import { BSON, type Collection, type ObjectId } from 'mongodb';
import type { CounterDoc, RecordDoc } from './types.js';

/**
 * What a row costs beyond its payload: its table, key, clocks and
 * indexes. Counted so a million empty rows are not free.
 */
export const recordOverheadBytes = 256;

/**
 * A row's size as the quota counts it: the BSON size of what it carries
 * (its `enc` or its `data`), plus the fixed overhead. The same number
 * `$bsonSize` gives inside Mongo, so a total filled in from stored rows
 * agrees with one kept write by write.
 */
export function payloadBytes(doc: Pick<RecordDoc, 'data' | 'enc'>): number {
  const payload = doc.enc ?? doc.data;
  return (payload ? BSON.calculateObjectSize(payload) : 0) + recordOverheadBytes;
}

/** A stored row's identity, clock and size. */
export interface StoredStamp {
  _id: ObjectId;
  stamp: number;
  bytes: number;
}

/**
 * The tables whose rows name a file by its hash, in `data.fileHash`:
 * every table the contract gives that column, so a new one cannot be
 * missed and its files swept (SV-12). Each must be plain tier, or the
 * server could not read the name; a test holds that.
 */
export const fileTables: readonly SyncedTable[] = syncedTables.filter((table) => hasColumn(table, 'fileHash'));

export class RecordsRepository {
  constructor(
    private readonly records: Collection<RecordDoc>,
    private readonly counters: Collection<CounterDoc>,
  ) {}

  /**
   * The stored clocks of many rows at once, keyed `<table>/<uuid>`: one
   * read per table in the batch instead of one per row.
   */
  async findStamps(
    userId: ObjectId,
    keys: readonly { table: SyncedTable; uuid: string }[],
  ): Promise<Map<string, StoredStamp>> {
    const byTable = new Map<SyncedTable, string[]>();
    for (const { table, uuid } of keys) byTable.set(table, [...(byTable.get(table) ?? []), uuid]);
    const found = new Map<string, StoredStamp>();
    if (byTable.size === 0) return found;
    const docs = await this.records
      .find(
        { userId, $or: [...byTable].map(([table, uuids]) => ({ table, uuid: { $in: uuids } })) },
        { projection: { _id: 1, table: 1, uuid: 1, stamp: 1, bytes: 1 } },
      )
      .toArray();
    const unmeasured: ObjectId[] = [];
    for (const doc of docs) {
      found.set(`${doc.table}/${doc.uuid}`, { _id: doc._id, stamp: doc.stamp, bytes: doc.bytes ?? -1 });
      if (typeof doc.bytes !== 'number') unmeasured.push(doc._id);
    }
    // Rows stored before sizes were kept: measured once, here.
    if (unmeasured.length > 0) {
      const whole = await this.records
        .find({ userId, _id: { $in: unmeasured } }, { projection: { table: 1, uuid: 1, data: 1, enc: 1 } })
        .toArray();
      for (const doc of whole) {
        const entry = found.get(`${doc.table}/${doc.uuid}`);
        if (entry) entry.bytes = payloadBytes(doc);
      }
    }
    return found;
  }

  /**
   * Writes many records, in order, in one bulk write: an insert for a
   * row not stored yet, a replacement for one that is, conditional on
   * the stored clock not having moved. Answers the positions that did
   * not land (a race the conflict check could not see).
   */
  async putMany(writes: readonly { doc: Omit<RecordDoc, '_id'>; previous: { _id: ObjectId; stamp: number } | null }[]): Promise<number[]> {
    if (writes.length === 0) return [];
    const ops = writes.map(({ doc, previous }) =>
      previous === null
        ? { insertOne: { document: doc as RecordDoc } }
        : { replaceOne: { filter: { _id: previous._id, userId: doc.userId, stamp: previous.stamp }, replacement: doc } },
    );
    try {
      // Ordered: the rows land in their sequence order, so a pull running
      // meanwhile only ever sees a prefix of the sequence.
      const result = await this.records.bulkWrite(ops, { ordered: true });
      if (result.insertedCount + result.modifiedCount === writes.length) return [];
    } catch (error) {
      if (!isBulkDuplicate(error)) throw error;
    }
    // Something did not land: which, is read back by its clock and seq.
    const landed = await this.records
      .find(
        { userId: writes[0]!.doc.userId, seq: { $in: writes.map((w) => w.doc.seq) } },
        { projection: { seq: 1 } },
      )
      .toArray();
    const seqs = new Set(landed.map((doc) => doc.seq));
    return writes.flatMap((w, i) => (seqs.has(w.doc.seq) ? [] : [i]));
  }

  /** Takes [n] values of the user's sequence at once; answers the last. */
  async takeSeqs(userId: ObjectId, n: number): Promise<number> {
    const counter = await this.counters.findOneAndUpdate(
      { _id: userId },
      { $inc: { seq: n } },
      { upsert: true, returnDocument: 'after' },
    );
    return counter!.seq;
  }

  /**
   * A page of the user's rows after [after], in sequence order: at most
   * [limit] rows and, past the first, at most [maxBytes] of them. The
   * rows are read one batch at a time and the page stops where the
   * bytes run out, so a pull never holds more than that in memory
   * (audit S5-02).
   */
  async page(
    userId: ObjectId,
    after: number,
    limit: number,
    maxBytes: number,
    skipDevice?: string,
  ): Promise<{ docs: RecordDoc[]; more: boolean; cursor: number }> {
    const cursor = this.records
      .find({ userId, seq: { $gt: after } })
      .sort({ seq: 1 })
      .limit(limit + 1)
      .batchSize(100);
    const docs: RecordDoc[] = [];
    let bytes = 0;
    let scanned = 0;
    let last = after;
    let more = false;
    try {
      for await (const doc of cursor) {
        const own = skipDevice !== undefined && doc.deviceId === skipDevice;
        const size = own ? 0 : (doc.bytes ?? payloadBytes(doc));
        if (scanned === limit || (docs.length > 0 && bytes + size > maxBytes)) {
          more = true;
          break;
        }
        scanned += 1;
        last = doc.seq;
        // The device's own write: it has it, so only the cursor moves.
        if (own) continue;
        docs.push(doc);
        bytes += size;
      }
    } finally {
      await cursor.close();
    }
    return { docs, more, cursor: last };
  }

  /** What the account's rows add up to, as [payloadBytes] counts them. */
  async storedBytes(userId: ObjectId): Promise<number> {
    const [row] = await this.records
      .aggregate<{ total: number }>([
        { $match: { userId } },
        {
          $group: {
            _id: null,
            total: {
              $sum: {
                $add: [{ $ifNull: [{ $bsonSize: { $ifNull: ['$enc', '$data'] } }, 0] }, recordOverheadBytes],
              },
            },
          },
        },
      ])
      .toArray();
    return row?.total ?? 0;
  }

  /**
   * Every file hash a row still names: the rows of [fileTables] that
   * are not purged. A row in the trash still names its file, because it
   * can come back.
   */
  async namedFiles(userId: ObjectId): Promise<Set<string>> {
    // Read a hash at a time, not as one `distinct` answer, which stops
    // at 16 MB (SV-16).
    const cursor = this.records.aggregate<{ _id: unknown }>([
      { $match: { userId, table: { $in: [...fileTables] }, purged: { $ne: true } } },
      { $group: { _id: '$data.fileHash' } },
    ]);
    const named = new Set<string>();
    for await (const { _id: hash } of cursor) if (typeof hash === 'string') named.add(hash);
    return named;
  }

  /**
   * Hard-deletes every private-tier row of the account: sealed under a
   * key nobody has any more, they cannot be read by anyone. No
   * tombstone is left; a pull simply never hands them out again.
   * Answers how many went.
   */
  async deletePrivate(userId: ObjectId): Promise<number> {
    const result = await this.records.deleteMany({ userId, table: { $in: [...privateTables] } });
    return result.deletedCount;
  }

  /** Whether any row of [fileTables] still names [sha256] (in the trash counts). */
  async namesFile(userId: ObjectId, sha256: string): Promise<boolean> {
    const found = await this.records.countDocuments(
      { userId, table: { $in: [...fileTables] }, purged: { $ne: true }, 'data.fileHash': sha256 },
      { limit: 1 },
    );
    return found > 0;
  }

  async currentSeq(userId: ObjectId): Promise<number> {
    return (await this.counters.findOne({ _id: userId }))?.seq ?? 0;
  }

  async deleteAll(userId: ObjectId): Promise<void> {
    await this.records.deleteMany({ userId });
    await this.counters.deleteOne({ _id: userId });
  }
}

function isBulkDuplicate(error: unknown): boolean {
  const errors = (error as { writeErrors?: unknown } | null)?.writeErrors;
  const list = Array.isArray(errors) ? errors : errors ? [errors] : [];
  return list.length > 0 && list.every((e) => (e as { code?: unknown }).code === 11000);
}

export function isDuplicateKey(error: unknown): boolean {
  return typeof error === 'object' && error !== null && (error as { code?: unknown }).code === 11000;
}
