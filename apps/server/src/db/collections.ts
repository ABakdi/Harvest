import type { Collection, Db } from 'mongodb';
import type { CounterDoc, FileDoc, OneTimeTokenDoc, RecordDoc, RefreshTokenDoc, SessionDoc, UserDoc } from './types.js';

export interface Collections {
  users: Collection<UserDoc>;
  sessions: Collection<SessionDoc>;
  refreshTokens: Collection<RefreshTokenDoc>;
  oneTimeTokens: Collection<OneTimeTokenDoc>;
  records: Collection<RecordDoc>;
  counters: Collection<CounterDoc>;
  files: Collection<FileDoc>;
}

export function collections(db: Db): Collections {
  return {
    users: db.collection<UserDoc>('users'),
    sessions: db.collection<SessionDoc>('sessions'),
    refreshTokens: db.collection<RefreshTokenDoc>('refresh_tokens'),
    oneTimeTokens: db.collection<OneTimeTokenDoc>('one_time_tokens'),
    records: db.collection<RecordDoc>('records'),
    counters: db.collection<CounterDoc>('counters'),
    files: db.collection<FileDoc>('files'),
  };
}

/**
 * The indexes every query relies on, created at boot. `createIndex` is
 * a no-op for an index that already exists, so this runs on every start.
 *
 * The TTL indexes are housekeeping, not security: an expired token is
 * refused by its `expiresAt` check whether or not Mongo has swept it yet.
 */
export async function ensureIndexes(c: Collections): Promise<void> {
  await Promise.all([
    c.users.createIndex({ email: 1 }, { unique: true, name: 'email_unique' }),

    c.sessions.createIndex({ userId: 1, lastSeenAt: -1 }, { name: 'user_sessions' }),
    c.sessions.createIndex({ expiresAt: 1 }, { expireAfterSeconds: 0, name: 'sessions_ttl' }),

    c.refreshTokens.createIndex({ userId: 1, tokenHash: 1 }, { unique: true, name: 'user_token' }),
    c.refreshTokens.createIndex({ userId: 1, sessionId: 1 }, { name: 'user_session_tokens' }),
    c.refreshTokens.createIndex({ expiresAt: 1 }, { expireAfterSeconds: 0, name: 'refresh_ttl' }),

    c.oneTimeTokens.createIndex({ userId: 1, purpose: 1, tokenHash: 1 }, { unique: true, name: 'user_purpose_token' }),
    c.oneTimeTokens.createIndex({ expiresAt: 1 }, { expireAfterSeconds: 0, name: 'one_time_ttl' }),

    // The row's identity: one stored copy per (user, table, key).
    c.records.createIndex({ userId: 1, table: 1, uuid: 1 }, { unique: true, name: 'user_row' }),
    // The pull: a user's rows in sequence order.
    c.records.createIndex({ userId: 1, seq: 1 }, { unique: true, name: 'user_seq' }),

    // A file is named by its own contents, once per account.
    c.files.createIndex({ userId: 1, sha256: 1 }, { unique: true, name: 'user_file' }),
  ]);
}
