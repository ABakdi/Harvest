import {
  checkRecord,
  clockIssues,
  maxPullBytes,
  maxRecordStoreBytes,
  recordStamp,
  type Issue,
  type PulledRecord,
  type PullResult,
  type PushResult,
  type PushResultItem,
} from '@harvest/contracts';
import type { ObjectId } from 'mongodb';
import type { RecordDoc, Repositories } from '../db/index.js';
import { payloadBytes } from '../db/records.js';
import { KeyedMutex } from './mutex.js';

/**
 * The sync API's two verbs ([[Sync-API]]). The server keeps rows and
 * hands them out in order; it computes nothing from them.
 */
export class SyncService {
  constructor(
    private readonly repos: Repositories,
    private readonly now: () => Date = () => new Date(),
    /**
     * One queue per account, shared with uploads and with deleting the
     * account, so none of them interleaves with a push.
     */
    readonly accountLock: KeyedMutex = new KeyedMutex(),
  ) {}

  /**
   * Applies a batch, record by record. For each one, keyed by
   * (user, table, uuid):
   * - no stored copy: store it;
   * - a stored copy with an older `updatedAt`: replace it;
   * - a stored copy the same age or newer: keep it and answer `stale`
   *   (equal stamps are the same write coming back).
   * A record that fails the contract is `invalid` on its own, with its
   * issues; the rest of the batch still lands. So is one whose clock is
   * more than a day ahead of the server's, and one that would take the
   * account past its row quota (issue code `quota_exceeded`).
   */
  async push(userId: ObjectId, deviceId: string, records: readonly unknown[]): Promise<PushResult> {
    return this.accountLock.run(userId.toHexString(), async () => {
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
    const now = this.now();

    // A clock from the far future would win every conflict until then.
    const clocks = clockIssues(record, now);
    if (clocks.length > 0) return invalid(identity, clocks);

    const stamp = recordStamp(record);
    const stored = await this.repos.records.findStamp(userId, record.table, record.uuid);
    if (stored && stamp <= stored.stamp) return { ...identity, status: 'stale' };

    // A purged row keeps only its tombstone; whatever it held is dropped.
    const payload: Pick<RecordDoc, 'data' | 'enc' | 'purged'> = record.purged
      ? { purged: true as const }
      : record.enc
        ? { enc: record.enc }
        : { data: record.data ?? {} };
    const bytes = payloadBytes(payload);
    const delta = bytes - (stored?.bytes ?? 0);
    const room = await this.repos.totals.reserve(userId, 'recordBytes', delta, maxRecordStoreBytes, () =>
      this.repos.records.storedBytes(userId),
    );
    if (!room) {
      return invalid(identity, [
        { path: [], message: 'This account has no room left for rows', code: 'quota_exceeded' },
      ]);
    }

    const doc: Omit<RecordDoc, '_id'> = {
      userId,
      table: record.table,
      uuid: record.uuid,
      updatedAt: record.updatedAt,
      deletedAt: record.deletedAt,
      stamp,
      ...payload,
      seq: await this.repos.records.nextSeq(userId),
      deviceId,
      receivedAt: now,
      bytes,
    };
    const landed = await this.repos.records.put(doc, stored);
    if (!landed) await this.repos.totals.release(userId, 'recordBytes', delta);
    return { ...identity, status: landed ? 'applied' : 'stale' };
  }

  /**
   * A page of the user's rows after [after], oldest write first: up to
   * [limit] of them, and no more than [maxPullBytes] past the first.
   */
  async pull(userId: ObjectId, after: number, limit: number, maxBytes = maxPullBytes): Promise<PullResult> {
    const page = await this.repos.records.page(userId, after, limit, maxBytes);
    const records = page.docs.map(toWire);
    return { records, cursor: records.at(-1)?.seq ?? after, more: page.more };
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
