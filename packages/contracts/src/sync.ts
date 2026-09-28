import { z } from 'zod';
import { type Issue, issueSchema, toIssues } from './errors.js';
import { isSafeRelativePath, storagePathColumns } from './paths.js';
import { isLegacySetting, isPortableSetting } from './settings.js';
import { fileHashSchema } from './files.js';
import { hasColumn, retiredTables, syncedTableSchema, tables, type SyncedTable } from './tables.js';
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
 * The longest `ct` a sealed row may carry, in base64 characters (about
 * 2.4 MB of ciphertext). Since every row is sealed the biggest is a
 * note: [maxTextLength] characters of Arabic are about a megabyte of
 * UTF-8, and four-byte characters at most two, padded; this is room for
 * that and no more, well short of what a push carries (audit S5-02).
 */
export const maxEnvelopeCtLength = 3_200_000;

/**
 * A private-tier row, sealed: AES-256-GCM over the JSON of its `data`,
 * keyed by the sync passphrase ([[Sync-API]]). The server checks that
 * it is well-formed and nothing more; it has no key to do anything else.
 *
 * `v: 2` is what clients write now (`crypto.ts`). `v: 1`, what 3.0.0
 * wrote, is still well-formed, so such a row can be stored and pulled;
 * a newer client counts it as locked.
 */
export const encEnvelopeSchema = z.strictObject({
  v: z.union([z.literal(1), z.literal(2)]),
  /** The 12-byte GCM nonce, base64. */
  iv: base64.refine((value) => decodedLength(value) === 12, {
    message: 'The nonce must be 12 bytes',
  }),
  /** Ciphertext followed by the 16-byte tag, base64. */
  ct: base64.min(1).max(maxEnvelopeCtLength),
});
export type EncEnvelope = z.infer<typeof encEnvelopeSchema>;

// ---------------------------------------------------------------- record

export const recordUuidSchema = z.string().min(1).max(200);

/**
 * One synced row on the wire.
 *
 * Every row travels sealed, as `enc` ([[Phase-7-Privacy-and-Currencies]],
 * M7.1), unless it was purged, a hard delete, in which case it carries
 * nothing: the record is a tombstone that tells the other devices to
 * purge too. A record with `data` is refused with the issue code
 * `sealed_required`; rows stored that way before Phase 7 are still
 * handed out by a pull, with their `data`, until a device seals them.
 *
 * `file`, on a row of a table that names a file (`fileHash`), is the
 * name the file is stored under on the server ([[fileNameOf]]), in the
 * clear, so the server can tell which files are still needed without
 * reading the row. It says nothing about the file's content.
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
    file: fileHashSchema.optional(),
    purged: z.literal(true).optional(),
  })
  .superRefine((record, ctx) => {
    if (record.purged) {
      if (record.data !== undefined || record.enc !== undefined || record.file !== undefined) {
        ctx.addIssue({
          code: 'custom',
          path: ['purged'],
          message: 'A purged record carries neither data, enc nor file',
        });
      }
      return;
    }
    if (record.data !== undefined) {
      ctx.addIssue({
        code: 'custom',
        path: ['data'],
        message: `${record.table} travels sealed, as enc, never as data`,
        params: { code: 'sealed_required' },
      });
    }
    if (record.enc === undefined) {
      ctx.addIssue({ code: 'custom', path: ['enc'], message: 'Missing enc' });
    }
    if (record.file !== undefined && !hasColumn(record.table, 'fileHash')) {
      ctx.addIssue({ code: 'custom', path: ['file'], message: `${record.table} names no file` });
    }
  });

export interface SyncRecord {
  table: SyncedTable;
  uuid: string;
  updatedAt: string;
  deletedAt: string | null;
  /** Only ever on a pulled row stored before Phase 7; never sent. */
  data?: Record<string, unknown>;
  enc?: EncEnvelope;
  file?: string;
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
 * - the envelope, and that the row travels sealed;
 * - that a setting is one that may leave the device at all.
 *
 * What is inside the envelope the server cannot check; a client checks
 * it after opening a row, with [checkRow].
 */
export function checkRecord(raw: unknown): CheckedRecord {
  const envelope = syncRecordSchema.safeParse(raw);
  if (!envelope.success) return { ok: false, issues: toIssues(envelope.error) };
  const record = envelope.data as SyncRecord;

  if ((retiredTables as readonly string[]).includes(record.table) && !record.purged) {
    return {
      ok: false,
      issues: [
        {
          path: ['table'],
          message: `${record.table} is not sent any more; its rows travel in another table`,
          code: 'retired_table',
        },
      ],
    };
  }

  // A legacy key from a 3.0.0 phone is stored so that phone is not
  // refused for ever; nothing current applies it.
  if (record.table === 'kv_settings' && !isPortableSetting(record.uuid) && !isLegacySetting(record.uuid)) {
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
  return { ok: true, record };
}

export type CheckedRow = { ok: true; data: Record<string, unknown> } | { ok: false; issues: Issue[] };

/**
 * What a client checks about a row once it has it in the clear, opened
 * from its envelope (or, from before Phase 7, taken from `data`):
 * - the row against its table's schema;
 * - that the record's `uuid` is the row's key;
 * - that the record's clocks are the row's own `updatedAt`/`deletedAt`,
 *   where the row has those columns, so the conflict rule and the row
 *   cannot tell two different stories;
 * - that a path into a device's storage cannot lead out of it (S6-08).
 */
export function checkRow(
  record: Pick<SyncRecord, 'table' | 'uuid' | 'updatedAt' | 'deletedAt'>,
  data: unknown,
): CheckedRow {
  const spec = tables[record.table];
  const parsed = spec.data.safeParse(data);
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
  const pathColumn = storagePathColumns[record.table];
  if (pathColumn !== undefined) {
    const value = row[pathColumn];
    if (typeof value === 'string' && !isSafeRelativePath(value)) {
      issues.push({ path: ['data', pathColumn], message: 'Not a safe relative path', code: 'custom' });
    }
  }
  if (issues.length > 0) return { ok: false, issues };
  return { ok: true, data: row };
}

/** The conflict clock of a record, exact to the microsecond. */
export function recordStamp(record: Pick<SyncRecord, 'updatedAt'>): number {
  return instantMicros(record.updatedAt);
}

/**
 * How far ahead of the server's clock a record's `updatedAt` may be. A
 * stamp from next year would win every conflict until next year, so a
 * row written by a device whose clock ran away is refused rather than
 * frozen (audit S5-11, Q5-10).
 */
export const maxClockLeadMs = 24 * 60 * 60_000;

/**
 * No clock past this: microseconds since the epoch stop being exact
 * doubles in 2255, and nothing Harvest keeps is dated after 2200.
 */
export const latestInstant = '2200-01-01T00:00:00Z';

/**
 * What is wrong with a record's clocks, judged at [now] (the server's
 * clock), or null when nothing is.
 */
export function clockIssues(record: Pick<SyncRecord, 'updatedAt' | 'deletedAt'>, now: Date): Issue[] {
  const latest = instantMicros(latestInstant);
  const issues: Issue[] = [];
  const stamp = instantMicros(record.updatedAt);
  if (stamp >= latest) {
    issues.push({ path: ['updatedAt'], message: 'The clock is past the year 2200', code: 'clock_too_far' });
  } else if (stamp > (now.getTime() + maxClockLeadMs) * 1000) {
    issues.push({
      path: ['updatedAt'],
      message: "The clock is more than a day ahead of the server's; check this device's date",
      code: 'clock_ahead',
    });
  }
  if (record.deletedAt !== null && instantMicros(record.deletedAt) >= latest) {
    issues.push({ path: ['deletedAt'], message: 'The clock is past the year 2200', code: 'clock_too_far' });
  }
  return issues;
}

/**
 * What one account may keep in rows, all told: the sealed and plain
 * payloads as stored. Years of a heavy day are a few tens of megabytes;
 * this is room for far more, and a ceiling on a volume that has none
 * otherwise (audit S5-02). Past it, a record that would grow the store
 * comes back `invalid` with the issue code `quota_exceeded`.
 */
export const maxRecordStoreBytes = 256 * 1024 * 1024;

/**
 * How much one pull carries at most, in stored bytes: the page ends at
 * the first record past it (with `more: true`), so a pull never holds
 * more than this and one record in memory.
 */
export const maxPullBytes = 8 * 1024 * 1024;

// ------------------------------------------------------------------ push

export const maxPushRecords = 500;

/**
 * The most a push body may be, in bytes of its JSON (UTF-8): a client
 * fills a batch until the next record would take it past this. It sits
 * under the server's body limit (5 MB) and nginx's (6 MB), so a batch
 * built to it is never refused whole; one that is anyway comes back 413
 * `payload_too_large`, and the client halves it.
 */
export const maxPushBytes = 4 * 1024 * 1024;

/**
 * The push body as the server parses it. Each record is only required
 * to say which row it is; the rest is checked record by record with
 * [checkRecord], so one bad row comes back `invalid` on its own and the
 * rest of the batch still lands.
 */
export const pushBodySchema = z.object({
  deviceId: z.string().min(1).max(200),
  /**
   * The key epoch the batch's sealed records were made under. Required
   * whenever the batch carries an `enc` record; when it is not the
   * account's, every sealed record comes back `invalid` with the issue
   * code `key_changed`, and the plain ones still land.
   */
  keyEpoch: z.int().min(1).optional(),
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
  keyEpoch?: number;
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
  /**
   * The pulling device's id, as it pushes with. When given, the server
   * leaves out what this device wrote itself (it has it already) and
   * still moves the cursor past it, so a push is not downloaded again
   * on the next pull. A device rebuilding its store from nothing leaves
   * it out, and gets its own writes back.
   */
  deviceId: z.string().min(1).max(200).optional(),
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
  /**
   * Where the next pull starts: the last `seq` the page covered, which
   * is past the last record when the device's own writes were left out,
   * or `after` when there was nothing.
   */
  cursor: z.int().nonnegative(),
  more: z.boolean(),
});
export interface PullResult {
  records: PulledRecord[];
  cursor: number;
  more: boolean;
}

// ---------------------------------------------------------------- sealed

/**
 * `POST /v1/sync/sealed`: a device says it has sent every row it holds
 * sealed, under the account's current key ([[Phase-7-Privacy-and-Currencies]],
 * M7.1). The server then deletes every row it still keeps in the clear,
 * stored before Phase 7, and every row of a [retiredTables] table, and
 * answers how many went. A key epoch that is
 * not the account's is refused (409 `key_changed`), and so is an account
 * with no sync secret set (409 `conflict`): nothing goes unless it
 * can have been sealed.
 */
export const sealedBodySchema = z.strictObject({
  deviceId: z.string().min(1).max(200),
  keyEpoch: z.int().min(1),
});
export type SealedBody = z.infer<typeof sealedBodySchema>;

export const sealedResultSchema = z.object({
  /** How many rows in the clear, and of retired tables, were deleted. */
  dropped: z.int().nonnegative(),
});
export type SealedResult = z.infer<typeof sealedResultSchema>;
