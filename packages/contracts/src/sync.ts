import { z } from 'zod';
import { type Issue, issueSchema, toIssues } from './errors.js';
import { isPortableSetting } from './settings.js';
import { hasColumn, syncedTableSchema, tables, type SyncedTable } from './tables.js';
import { instantMicros, isoInstantSchema, sameInstant } from './time.js';

// -------------------------------------------------------------- envelope

const base64 = z.base64({ message: 'Not base64' });

/**
 * How many bytes a base64 string decodes to, from its length alone, so
 * the check works the same in a browser (no `Buffer`) and on the server.
 */
function decodedLength(value: string): number {
  const padding = value.endsWith('==') ? 2 : value.endsWith('=') ? 1 : 0;
  return (value.length / 4) * 3 - padding;
}

/**
 * A private-tier row, sealed: AES-256-GCM over the JSON of its `data`,
 * keyed by the sync passphrase ([[Sync-API]]). The server checks that
 * it is well-formed and nothing more; it has no key to do anything else.
 */
export const encEnvelopeSchema = z.strictObject({
  v: z.literal(1),
  /** The 12-byte GCM nonce, base64. */
  iv: base64.refine((value) => decodedLength(value) === 12, {
    message: 'The nonce must be 12 bytes',
  }),
  /** Ciphertext followed by the 16-byte tag, base64. */
  ct: base64.min(1).max(4_000_000),
});
export type EncEnvelope = z.infer<typeof encEnvelopeSchema>;

// ---------------------------------------------------------------- record

export const recordUuidSchema = z.string().min(1).max(200);

/**
 * One synced row on the wire.
 *
 * Exactly one of `data` (plain tier) or `enc` (private tier) is present,
 * unless the row was purged, a hard delete, in which case neither is:
 * the record is a tombstone that tells the other devices to purge too.
 *
 * `updatedAt` is the clock the conflict rule compares. For tables with
 * an `updatedAt` column it is that column. For the append-only tables
 * without one it is the row's own creation time (`loggedAt` on the
 * ledger), and for the few child tables with no timestamp at all
 * (program days, slots, target sets, session exercises, note links) it
 * is the moment the change was queued.
 */
export const syncRecordSchema = z
  .strictObject({
    table: syncedTableSchema,
    uuid: recordUuidSchema,
    updatedAt: isoInstantSchema,
    deletedAt: isoInstantSchema.nullable(),
    data: z.record(z.string(), z.unknown()).optional(),
    enc: encEnvelopeSchema.optional(),
    purged: z.literal(true).optional(),
  })
  .superRefine((record, ctx) => {
    if (record.purged) {
      if (record.data !== undefined || record.enc !== undefined) {
        ctx.addIssue({
          code: 'custom',
          path: ['purged'],
          message: 'A purged record carries neither data nor enc',
        });
      }
      return;
    }
    const tier = tables[record.table].tier;
    if (tier === 'plain') {
      if (record.enc !== undefined) {
        ctx.addIssue({ code: 'custom', path: ['enc'], message: `${record.table} travels as data, not enc` });
      }
      if (record.data === undefined) {
        ctx.addIssue({ code: 'custom', path: ['data'], message: 'Missing data' });
      }
    } else {
      if (record.data !== undefined) {
        ctx.addIssue({
          code: 'custom',
          path: ['data'],
          message: `${record.table} is private-tier and travels only as enc`,
        });
      }
      if (record.enc === undefined) {
        ctx.addIssue({ code: 'custom', path: ['enc'], message: 'Missing enc' });
      }
    }
  });

export interface SyncRecord {
  table: SyncedTable;
  uuid: string;
  updatedAt: string;
  deletedAt: string | null;
  data?: Record<string, unknown>;
  enc?: EncEnvelope;
  purged?: true;
}

export type CheckedRecord =
  | { ok: true; record: SyncRecord }
  | { ok: false; issues: Issue[] };

function prefixed(issues: Issue[], prefix: string): Issue[] {
  return issues.map((issue) => ({ ...issue, path: [prefix, ...issue.path] }));
}

/**
 * Everything the server checks about one record, in one place, so a
 * client can run the same checks before it sends and never meet an
 * `invalid` it could have predicted:
 * - the envelope, and the tier's `data`/`enc` rule;
 * - a plain row's `data` against its table's schema;
 * - that the record's `uuid` is the row's key;
 * - that the record's clocks are the row's own `updatedAt`/`deletedAt`,
 *   where the row has those columns, so the conflict rule and the row
 *   cannot tell two different stories;
 * - that a setting is one that may leave the device at all.
 */
export function checkRecord(raw: unknown): CheckedRecord {
  const envelope = syncRecordSchema.safeParse(raw);
  if (!envelope.success) return { ok: false, issues: toIssues(envelope.error) };
  const record = envelope.data as SyncRecord;

  if (record.table === 'kv_settings' && !isPortableSetting(record.uuid)) {
    return {
      ok: false,
      issues: [
        {
          path: ['uuid'],
          message: `The setting ${record.uuid} belongs to its device and does not sync`,
          code: 'custom',
        },
      ],
    };
  }

  if (record.purged || tables[record.table].tier === 'private') {
    return { ok: true, record };
  }

  const spec = tables[record.table];
  const parsed = spec.data.safeParse(record.data);
  if (!parsed.success) return { ok: false, issues: prefixed(toIssues(parsed.error), 'data') };

  const row = parsed.data as Record<string, unknown>;
  const issues: Issue[] = [];
  const key = (spec.keyOf as (row: Record<string, unknown>) => string)(row);
  if (key !== record.uuid) {
    issues.push({
      path: ['uuid'],
      message: `The record uuid must be the row's key (${key})`,
      code: 'custom',
    });
  }
  if (hasColumn(record.table, 'updatedAt') && !sameInstant(row.updatedAt as string, record.updatedAt)) {
    issues.push({
      path: ['updatedAt'],
      message: "The record's updatedAt must be the row's updatedAt",
      code: 'custom',
    });
  }
  if (
    hasColumn(record.table, 'deletedAt') &&
    !sameInstant((row.deletedAt as string | null) ?? null, record.deletedAt)
  ) {
    issues.push({
      path: ['deletedAt'],
      message: "The record's deletedAt must be the row's deletedAt",
      code: 'custom',
    });
  }
  if (issues.length > 0) return { ok: false, issues };
  return { ok: true, record: { ...record, data: row } };
}

/** The conflict clock of a record, exact to the microsecond. */
export function recordStamp(record: Pick<SyncRecord, 'updatedAt'>): number {
  return instantMicros(record.updatedAt);
}

// ------------------------------------------------------------------ push

export const maxPushRecords = 500;

/**
 * The push body as the server parses it. Each record is only required
 * to say which row it is; the rest is checked record by record with
 * [checkRecord], so one bad row comes back `invalid` on its own and the
 * rest of the batch still lands.
 */
export const pushBodySchema = z.object({
  deviceId: z.string().min(1).max(200),
  records: z
    .array(
      z.looseObject({
        table: z.string().max(100),
        uuid: z.string().max(200),
      }),
    )
    .max(maxPushRecords, { message: `At most ${maxPushRecords} records per push` }),
});

/** The push body as a client builds it. */
export interface PushBody {
  deviceId: string;
  records: SyncRecord[];
}

export const pushStatusSchema = z.enum(['applied', 'stale', 'invalid']);
export type PushStatus = z.infer<typeof pushStatusSchema>;

export const pushResultItemSchema = z.object({
  table: z.string(),
  uuid: z.string(),
  status: pushStatusSchema,
  issues: z.array(issueSchema).optional(),
});
export type PushResultItem = z.infer<typeof pushResultItemSchema>;

export const pushResultSchema = z.object({
  results: z.array(pushResultItemSchema),
  /** The account's sequence after this push: the newest stored write. */
  cursor: z.int().nonnegative(),
});
export type PushResult = z.infer<typeof pushResultSchema>;

// ------------------------------------------------------------------ pull

export const maxPullLimit = 1000;
export const defaultPullLimit = 500;

export const pullQuerySchema = z.object({
  after: z.coerce.number().int().nonnegative().default(0),
  limit: z.coerce.number().int().min(1).max(maxPullLimit).default(defaultPullLimit),
});
export type PullQuery = z.input<typeof pullQuerySchema>;

export type PulledRecord = SyncRecord & { seq: number };

export const pulledRecordSchema = z.object({
  table: syncedTableSchema,
  uuid: recordUuidSchema,
  updatedAt: isoInstantSchema,
  deletedAt: isoInstantSchema.nullable(),
  data: z.record(z.string(), z.unknown()).optional(),
  enc: encEnvelopeSchema.optional(),
  purged: z.literal(true).optional(),
  seq: z.int().positive(),
});

export const pullResultSchema = z.object({
  records: z.array(pulledRecordSchema),
  /** Where the next pull starts: the last record's `seq`, or `after` when there were none. */
  cursor: z.int().nonnegative(),
  more: z.boolean(),
});
export interface PullResult {
  records: PulledRecord[];
  cursor: number;
  more: boolean;
}
