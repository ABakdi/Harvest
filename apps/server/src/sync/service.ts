import {
  checkRecord,
  recordStamp,
  type Issue,
  type PulledRecord,
  type PullResult,
  type PushResult,
  type PushResultItem,
} from '@harvest/contracts';
import type { ObjectId } from 'mongodb';
import type { RecordDoc, Repositories } from '../db/index.js';
import { KeyedMutex } from './mutex.js';

/**
 * The sync API's two verbs ([[Sync-API]]). The server keeps rows and
 * hands them out in order; it computes nothing from them.
 */
export class SyncService {
  private readonly pushes = new KeyedMutex();

  constructor(
    private readonly repos: Repositories,
    private readonly now: () => Date = () => new Date(),
  ) {}

  /**
   * Applies a batch, record by record. For each one, keyed by
   * (user, table, uuid):
   * - no stored copy: store it;
   * - a stored copy with an older `updatedAt`: replace it;
   * - a stored copy the same age or newer: keep it and answer `stale`
   *   (equal stamps are the same write coming back).
   * A record that fails the contract is `invalid` on its own, with its
   * issues; the rest of the batch still lands.
   */
  async push(userId: ObjectId, deviceId: string, records: readonly unknown[]): Promise<PushResult> {
    return this.pushes.run(userId.toHexString(), async () => {
      const results: PushResultItem[] = [];
      for (const raw of records) results.push(await this.pushOne(userId, deviceId, raw));
      return { results, cursor: await this.repos.records.currentSeq(userId) };
    });
  }

  private async pushOne(userId: ObjectId, deviceId: string, raw: unknown): Promise<PushResultItem> {
    const identity = identify(raw);
    const checked = checkRecord(raw);
    if (!checked.ok) return invalid(identity, checked.issues);
    const record = checked.record;

    const stamp = recordStamp(record);
    const stored = await this.repos.records.findStamp(userId, record.table, record.uuid);
    if (stored && stamp <= stored.stamp) return { ...identity, status: 'stale' };

    const doc: Omit<RecordDoc, '_id'> = {
      userId,
      table: record.table,
      uuid: record.uuid,
      updatedAt: record.updatedAt,
      deletedAt: record.deletedAt,
      stamp,
      // A purged row keeps only its tombstone; whatever it held is dropped.
      ...(record.purged
        ? { purged: true as const }
        : record.enc
          ? { enc: record.enc }
          : { data: record.data ?? {} }),
      seq: await this.repos.records.nextSeq(userId),
      deviceId,
      receivedAt: this.now(),
    };
    const landed = await this.repos.records.put(doc, stored);
    return { ...identity, status: landed ? 'applied' : 'stale' };
  }

  /** A page of the user's rows after [after], oldest write first. */
  async pull(userId: ObjectId, after: number, limit: number): Promise<PullResult> {
    const page = await this.repos.records.page(userId, after, limit + 1);
    const more = page.length > limit;
    const records = page.slice(0, limit).map(toWire);
    return { records, cursor: records.at(-1)?.seq ?? after, more };
  }
}

function toWire(doc: RecordDoc): PulledRecord {
  return {
    table: doc.table,
    uuid: doc.uuid,
    updatedAt: doc.updatedAt,
    deletedAt: doc.deletedAt,
    ...(doc.purged ? { purged: true as const } : {}),
    ...(doc.enc ? { enc: doc.enc } : {}),
    ...(doc.data ? { data: doc.data } : {}),
    seq: doc.seq,
  };
}

/** Which row a record claims to be, for the answer, even when nothing else about it parses. */
function identify(raw: unknown): { table: string; uuid: string } {
  const value = (typeof raw === 'object' && raw !== null ? raw : {}) as Record<string, unknown>;
  return {
    table: typeof value.table === 'string' ? value.table : '',
    uuid: typeof value.uuid === 'string' ? value.uuid : '',
  };
}

function invalid(identity: { table: string; uuid: string }, issues: Issue[]): PushResultItem {
  return { ...identity, status: 'invalid', issues };
}
