import {
  checkRecord,
  tierOf,
  pinVerifierOf,
  type KeyCheck,
  type SyncKeySet,
  type SyncKeyState,
  type UnlockResult,
  recordStamp,
  type PulledRecord,
  type PullResult,
  type PushBody,
  type PushResult,
  type PushResultItem,
  type SyncRecord,
} from '@harvest/contracts';
import type { SyncTransport } from '@/app/sync/engine';

/**
 * The server's sync rules in memory (apps/server/src/sync/service.ts):
 * the contract's checks, last writer wins on the record's stamp, a tie
 * is stale, a purge keeps only its tombstone, and every stored write
 * takes the next sequence number.
 */
/** The key share every fresh fake account starts with. */
export const testKeyShare = Buffer.from(Array.from({ length: 32 }, (_, i) => i)).toString('base64');

export class FakeServer implements SyncTransport {
  readonly stored = new Map<string, PulledRecord>();
  private seq = 0;
  pushes = 0;
  pulls = 0;

  // The sync key routes (routes/sync-key.ts): the account's salt, its
  // key share, the PIN verifier and key check a device sets, the epoch,
  // and the limit on wrong tries.
  salt = 'c2FsdHNhbHRzYWx0c2FsdA==';
  keyShare = testKeyShare;
  verifier: string | null = null;
  check: KeyCheck | null = null;
  epoch = 1;
  password = 'the password';
  tries = 5;
  wrong = 0;
  keyAsks = 0;
  /** When set, a push of more records than this answers 413. */
  tooLargeOver: number | null = null;
  /** Every push body's record count, and every pull's deviceId. */
  readonly batches: number[] = [];
  readonly pulledAs: (string | undefined)[] = [];
  private readonly writtenBy = new Map<string, string>();

  syncKey(): Promise<SyncKeyState> {
    this.keyAsks++;
    return Promise.resolve(
      this.verifier === null
        ? { state: 'none', salt: this.salt, epoch: this.epoch, keyShare: this.keyShare }
        : { state: 'set', salt: this.salt, epoch: this.epoch },
    );
  }

  async unlockSyncKey(proof: string): Promise<UnlockResult> {
    if (this.verifier === null) throw Object.assign(new Error('No PIN set'), { status: 409, code: 'conflict' });
    if (this.wrong >= this.tries) {
      throw Object.assign(new Error('Too many'), { status: 429, code: 'rate_limited', retryAfter: 900 });
    }
    if ((await pinVerifierOf(Buffer.from(proof, 'base64'))) !== this.verifier) {
      this.wrong++;
      throw Object.assign(new Error('Wrong PIN'), { status: 403, code: 'wrong_pin', triesLeft: this.tries - this.wrong });
    }
    this.wrong = 0;
    return { keyShare: this.keyShare, check: this.check!, epoch: this.epoch };
  }

  setSyncKey(verifier: string, check: KeyCheck): Promise<SyncKeySet | null> {
    if (this.verifier !== null) return Promise.resolve(null);
    this.verifier = verifier;
    this.check = check;
    return Promise.resolve({ epoch: this.epoch });
  }

  startOverSyncKey(password: string): Promise<void> {
    if (password !== this.password) {
      return Promise.reject(Object.assign(new Error('Wrong password'), { status: 403, code: 'forbidden' }));
    }
    this.verifier = null;
    this.check = null;
    this.epoch++;
    this.keyShare = Buffer.from(Array.from({ length: 32 }, (_, i) => (i * 7 + this.epoch) % 256)).toString('base64');
    for (const [id, record] of this.stored) if (tierOf(record.table) === 'private') this.stored.delete(id);
    return Promise.resolve();
  }

  push(body: PushBody): Promise<PushResult> {
    if (this.tooLargeOver !== null && body.records.length > this.tooLargeOver) {
      return Promise.reject(Object.assign(new Error('Too large'), { status: 413, code: 'payload_too_large' }));
    }
    this.pushes++;
    this.batches.push(body.records.length);
    const results: PushResultItem[] = [];
    for (const raw of body.records) {
      const identity = { table: raw.table, uuid: raw.uuid };
      if (raw.enc !== undefined && body.keyEpoch !== this.epoch) {
        results.push({ ...identity, status: 'invalid', issues: [{ path: [], message: 'stale key', code: 'key_changed' }] });
        continue;
      }
      const checked = checkRecord(JSON.parse(JSON.stringify(raw)));
      if (!checked.ok) {
        results.push({ ...identity, status: 'invalid', issues: checked.issues });
        continue;
      }
      const record: SyncRecord = checked.record;
      const id = `${record.table}/${record.uuid}`;
      const existing = this.stored.get(id);
      if (existing && recordStamp(record) <= recordStamp(existing)) {
        results.push({ ...identity, status: 'stale' });
        continue;
      }
      const { data, enc, purged, ...rest } = record;
      this.writtenBy.set(id, body.deviceId);
      this.stored.set(id, {
        ...rest,
        ...(purged ? { purged } : enc ? { enc } : { data: data ?? {} }),
        seq: ++this.seq,
      });
      results.push({ ...identity, status: 'applied' });
    }
    return Promise.resolve({ results, cursor: this.seq });
  }

  pull(after: number, limit: number, deviceId?: string): Promise<PullResult> {
    this.pulls++;
    this.pulledAs.push(deviceId);
    const page = [...this.stored.values()]
      .filter((record) => record.seq > after)
      .sort((a, b) => a.seq - b.seq)
      .slice(0, limit + 1);
    const more = page.length > limit;
    const taken = page.slice(0, limit);
    // The device's own writes are left out; the cursor still moves past them.
    const records = taken
      .filter((record) => deviceId === undefined || this.writtenBy.get(`${record.table}/${record.uuid}`) !== deviceId)
      .map((record) => structuredClone(record));
    return Promise.resolve({ records, cursor: taken.at(-1)?.seq ?? after, more });
  }

  get(table: string, uuid: string): PulledRecord | undefined {
    return this.stored.get(`${table}/${uuid}`);
  }
}
