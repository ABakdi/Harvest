import {
  checkRecord,
  clockIssues,
  isLegacySetting,
  maxPullBytes,
  maxRecordStoreBytes,
  recordStamp,
  type Issue,
  type PulledRecord,
  type PullResult,
  type PushResult,
  type PushResultItem,
  type SealedResult,
  type SyncRecord,
} from '@harvest/contracts';
import type { ObjectId } from 'mongodb';
import type { RecordDoc, Repositories } from '../db/index.js';
import { payloadBytes, type StoredStamp } from '../db/records.js';
import { HttpError, unauthorized } from '../http/errors.js';
import { KeyedMutex } from './mutex.js';

/** A record that passed every check and is newer than what is stored. */
interface Write {
  index: number;
  doc: Omit<RecordDoc, '_id' | 'seq'>;
  previous: StoredStamp | null;
  delta: number;
}

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
   * Applies a batch. For each record, keyed by (user, table, uuid), in
   * the batch's order:
   * - no stored copy: store it;
   * - a stored copy with an older `updatedAt`: replace it;
   * - a stored copy the same age or newer: keep it and answer `stale`
   *   (equal stamps are the same write coming back).
   * A record that fails the contract is `invalid` on its own, with its
   * issues; the rest of the batch still lands. So is one whose clock is
   * more than a day ahead of the server's, one that would take the
   * account past its row quota (issue code `quota_exceeded`), and a
   * sealed one made under a key the account no longer has (`key_changed`).
   *
   * Every row arrives sealed ([[Phase-7-Privacy-and-Currencies]]); one
   * in the clear is `invalid` with `sealed_required`. A sealed row
   * replaces its own copy stored in the clear before Phase 7 even at the
   * same clock, since it is that row, sealed.
   *
   * The whole batch costs a handful of round trips, not a handful per
   * row (P6-02): one read of the stored clocks, one of the running total,
   * one sequence range, one ordered bulk write, all under the account's
   * lock, taken after the body has arrived. An account deleted while the
   * body was on its way is not written back (Q6-02).
   */
  async push(
    userId: ObjectId,
    deviceId: string,
    records: readonly unknown[],
    keyEpoch?: number,
  ): Promise<PushResult> {
    return this.accountLock.run(userId.toHexString(), async () => {
      const user = await this.repos.users.findById(userId);
      if (!user) throw unauthorized();
      const epoch = user.keyEpoch ?? 1;
      const now = this.now();

      const results: PushResultItem[] = records.map((raw) => ({ ...identify(raw), status: 'stale' }));
      const checked: { index: number; record: SyncRecord }[] = [];
      for (const [index, raw] of records.entries()) {
        const outcome = checkRecord(raw);
        if (!outcome.ok) {
          results[index] = invalid(identify(raw), outcome.issues);
          continue;
        }
        const record = outcome.record;
        // A clock from the far future would win every conflict until then.
        const clocks = clockIssues(record, now);
        if (clocks.length > 0) {
          results[index] = invalid(identify(raw), clocks);
          continue;
        }
        // Sealed under a key the account no longer has (a start over on
        // another device): nothing is stored under it (S6-07).
        if (record.enc && keyEpoch !== epoch) {
          results[index] = invalid(identify(raw), [
            { path: ['enc'], message: 'Sealed under a key this account no longer has', code: 'key_changed' },
          ]);
          continue;
        }
        // An endpoint setting only a 3.0.0 phone still sends: taken, so
        // that phone stops sending it, and not kept (S6-16).
        if (record.table === 'kv_settings' && isLegacySetting(record.uuid)) {
          results[index] = { ...identify(raw), status: 'applied' };
          continue;
        }
        checked.push({ index, record });
      }

      const stored = await this.repos.records.findStamps(userId, checked.map(({ record }) => record));
      let room = await this.repos.totals.current(userId, 'recordBytes', () => this.repos.records.storedBytes(userId));
      const writes: Write[] = [];
      // The latest write of each row in this batch, so a row sent twice
      // is judged against its own earlier copy, as one by one would.
      const latest = new Map<string, Write>();

      for (const { index, record } of checked) {
        const id = `${record.table}/${record.uuid}`;
        const stamp = recordStamp(record);
        const earlier = latest.get(id);
        const current = earlier ? { stamp: earlier.doc.stamp, bytes: earlier.doc.bytes ?? 0 } : stored.get(id);
        // A row stored in the clear before Phase 7 gives way to its own
        // sealed copy at the same clock: that is the device sealing it.
        const sealing = current !== undefined && 'plain' in current && current.plain === true && record.enc !== undefined;
        if (current && (stamp < current.stamp || (stamp === current.stamp && !sealing))) {
          results[index] = { ...identify(record), status: 'stale' };
          continue;
        }
        // A purged row keeps only its tombstone; whatever it held is dropped.
        const payload: Pick<RecordDoc, 'enc' | 'file' | 'purged'> = record.purged
          ? { purged: true as const }
          : { enc: record.enc!, ...(record.file === undefined ? {} : { file: record.file }) };
        const bytes = payloadBytes(payload);
        const delta = bytes - (current?.bytes ?? 0);
        if (delta > 0 && room + delta > maxRecordStoreBytes) {
          results[index] = invalid(identify(record), [
            { path: [], message: 'This account has no room left for rows', code: 'quota_exceeded' },
          ]);
          continue;
        }
        room += delta;
        const write: Write = {
          index,
          doc: {
            userId,
            table: record.table,
            uuid: record.uuid,
            updatedAt: record.updatedAt,
            deletedAt: record.deletedAt,
            stamp,
            ...payload,
            deviceId,
            bytes,
          },
          previous: earlier ? earlier.previous : (stored.get(id) ?? null),
          delta,
        };
        // The earlier copy in this batch is overtaken before it is ever
        // written: it was applied, and this one is what lands.
        if (earlier) {
          writes.splice(writes.indexOf(earlier), 1);
          write.delta += earlier.delta;
        }
        latest.set(id, write);
        writes.push(write);
        results[index] = { ...identify(record), status: 'applied' };
      }

      if (writes.length > 0) {
        const charged = writes.reduce((sum, w) => sum + w.delta, 0);
        try {
          await this.repos.totals.add(userId, 'recordBytes', charged);
          const last = await this.repos.records.takeSeqs(userId, writes.length);
          const first = last - writes.length + 1;
          const failed = await this.repos.records.putMany(
            writes.map((w, i) => ({ doc: { ...w.doc, seq: first + i }, previous: w.previous })),
          );
          for (const i of failed) {
            const w = writes[i]!;
            results[w.index] = { ...identify(w.doc), status: 'stale' };
            await this.repos.totals.add(userId, 'recordBytes', -w.delta);
          }
        } catch (error) {
          // The charge may have landed and some of the batch or none of
          // it: the total is counted again from what is stored, the next
          // time it is needed (SV-07, Q6-15).
          await this.repos.totals.forget(userId, 'recordBytes');
          throw error;
        }
      }
      return { results, cursor: await this.repos.records.currentSeq(userId) };
    });
  }

  /**
   * A device has sent every row it holds sealed, under [keyEpoch]: what
   * is still stored in the clear goes (`POST /v1/sync/sealed`). Refused
   * with no sync secret set, or under a key the account no longer has.
   */
  async sealed(userId: ObjectId, keyEpoch: number): Promise<SealedResult> {
    return this.accountLock.run(userId.toHexString(), async () => {
      const user = await this.repos.users.findById(userId);
      if (!user) throw unauthorized();
      if (!user.pinVerifier || !user.keyCheck) {
        throw new HttpError('conflict', 'No sync secret is set, so nothing can have been sealed');
      }
      if (keyEpoch !== (user.keyEpoch ?? 1)) {
        throw new HttpError('key_changed', 'Sealed under a key this account no longer has; ask for the PIN again');
      }
      const dropped = await this.repos.records.deletePlain(userId);
      // Counted again from what is left, the next time it is needed.
      if (dropped > 0) await this.repos.totals.forget(userId, 'recordBytes');
      return { dropped };
    });
  }

  /**
   * A page of the user's rows after [after], oldest write first: up to
   * [limit] of them, and no more than [maxPullBytes] past the first.
   * With [deviceId], the rows that device wrote itself are left out and
   * the cursor still moves past them (P6-08).
   */
  async pull(
    userId: ObjectId,
    after: number,
    limit: number,
    maxBytes = maxPullBytes,
    deviceId?: string,
  ): Promise<PullResult> {
    const page = await this.repos.records.page(userId, after, limit, maxBytes, deviceId);
    return { records: page.docs.map(toWire), cursor: page.cursor, more: page.more };
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
