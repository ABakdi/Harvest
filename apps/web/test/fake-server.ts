import {
  checkRecord,
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
export class FakeServer implements SyncTransport {
  readonly stored = new Map<string, PulledRecord>();
  private seq = 0;
  pushes = 0;
  pulls = 0;

  push(body: PushBody): Promise<PushResult> {
    this.pushes++;
    const results: PushResultItem[] = [];
    for (const raw of body.records) {
      const identity = { table: raw.table, uuid: raw.uuid };
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
      this.stored.set(id, {
        ...rest,
        ...(purged ? { purged } : enc ? { enc } : { data: data ?? {} }),
        seq: ++this.seq,
      });
      results.push({ ...identity, status: 'applied' });
    }
    return Promise.resolve({ results, cursor: this.seq });
  }

  pull(after: number, limit: number): Promise<PullResult> {
    this.pulls++;
    const page = [...this.stored.values()]
      .filter((record) => record.seq > after)
      .sort((a, b) => a.seq - b.seq)
      .slice(0, limit + 1);
    const more = page.length > limit;
    const records = page.slice(0, limit).map((record) => structuredClone(record));
    return Promise.resolve({ records, cursor: records.at(-1)?.seq ?? after, more });
  }

  get(table: string, uuid: string): PulledRecord | undefined {
    return this.stored.get(`${table}/${uuid}`);
  }
}
