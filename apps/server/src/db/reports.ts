import { Readable } from 'node:stream';
import { GridFSBucket, ObjectId, type Collection, type Db } from 'mongodb';
import type { ReportDoc } from './types.js';

/** The bucket a report's pictures and recording live in. */
export const reportBucket = 'report_files';

/** Reports of problems ([[Admin]] F12-5). */
export class ReportsRepository {
  private readonly bucket: GridFSBucket;

  constructor(
    private readonly reports: Collection<ReportDoc>,
    db: Db,
  ) {
    this.bucket = new GridFSBucket(db, { bucketName: reportBucket });
  }

  /**
   * Stores a report and its files: the files first, so a report is
   * never there without them; any that went in are taken out again if
   * the report does not land.
   */
  async create(
    report: Omit<ReportDoc, '_id' | 'attachments' | 'status'>,
    files: { kind: 'image' | 'audio'; type: string; bytes: Buffer }[],
  ): Promise<ObjectId> {
    const stored: ReportDoc['attachments'] = [];
    try {
      for (const file of files) {
        const gridId = new ObjectId();
        await new Promise<void>((resolve, reject) => {
          const upload = this.bucket.openUploadStreamWithId(gridId, 'report', { metadata: { type: file.type } });
          Readable.from([file.bytes]).pipe(upload).on('finish', () => resolve()).on('error', reject);
        });
        stored.push({ _id: new ObjectId(), kind: file.kind, type: file.type, bytes: file.bytes.length, gridId });
      }
      const doc: ReportDoc = { _id: new ObjectId(), ...report, status: 'new', attachments: stored };
      await this.reports.insertOne(doc);
      return doc._id;
    } catch (error) {
      await Promise.all(stored.map((file) => this.bucket.delete(file.gridId).catch(() => undefined)));
      throw error;
    }
  }

  /** A page of reports, newest first, after [cursor]; with [status], only those. */
  async page(status: ReportDoc['status'] | undefined, cursor: string | undefined, limit: number) {
    const filter = {
      ...(status ? { status } : {}),
      ...(cursor ? { _id: { $lt: new ObjectId(cursor) } } : {}),
    };
    const docs = await this.reports.find(filter).sort({ _id: -1 }).limit(limit + 1).toArray();
    const more = docs.length > limit;
    const page = docs.slice(0, limit);
    return { reports: page, next: more ? page.at(-1)!._id.toHexString() : null };
  }

  unread(): Promise<number> {
    return this.reports.countDocuments({ status: 'new' });
  }

  async setStatus(id: string, status: ReportDoc['status']): Promise<ReportDoc | null> {
    return this.reports.findOneAndUpdate({ _id: new ObjectId(id) }, { $set: { status } }, { returnDocument: 'after' });
  }

  /** Deletes a report and every file of it. */
  async delete(id: string): Promise<boolean> {
    const doc = await this.reports.findOneAndDelete({ _id: new ObjectId(id) });
    if (!doc) return false;
    await Promise.all(doc.attachments.map((file) => this.bucket.delete(file.gridId).catch(() => undefined)));
    return true;
  }

  /** One attachment's type and bytes, as a stream; null when there is none such. */
  async attachment(id: string, attachmentId: string): Promise<{ type: string; bytes: number; stream: Readable } | null> {
    const doc = await this.reports.findOne({ _id: new ObjectId(id) }, { projection: { attachments: 1 } });
    const file = doc?.attachments.find((a) => a._id.equals(new ObjectId(attachmentId)));
    if (!file) return null;
    return { type: file.type, bytes: file.bytes, stream: this.bucket.openDownloadStream(file.gridId) };
  }
}
