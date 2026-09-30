import type { Collection, Db } from 'mongodb';
import type {
  AnnouncementDoc,
  DailyStatsDoc,
  PushSubscriptionDoc,
  ServerSettingDoc,
  AssistDayDoc,
  AssistUsageDoc,
  CounterDoc,
  FileDoc,
  LoginFailureDoc,
  WindowedCountDoc,
  OneTimeTokenDoc,
  RecordDoc,
  RefreshTokenDoc,
  SessionDoc,
  StoredUserDoc,
} from './types.js';
import { usersCollection } from './sessions.js';

export interface Collections {
  users: Collection<StoredUserDoc>;
  sessions: Collection<SessionDoc>;
  refreshTokens: Collection<RefreshTokenDoc>;
  oneTimeTokens: Collection<OneTimeTokenDoc>;
  records: Collection<RecordDoc>;
  counters: Collection<CounterDoc>;
  files: Collection<FileDoc>;
  assistUsage: Collection<AssistUsageDoc>;
  assistDays: Collection<AssistDayDoc>;
  loginFailures: Collection<LoginFailureDoc>;
  windowedCounts: Collection<WindowedCountDoc>;
  announcements: Collection<AnnouncementDoc>;
  pushSubscriptions: Collection<PushSubscriptionDoc>;
  dailyStats: Collection<DailyStatsDoc>;
  serverSettings: Collection<ServerSettingDoc>;
  /** GridFS's own `files` collection of the file bytes' bucket. */
  fileBlobs: Collection;
}

export function collections(db: Db): Collections {
  return {
    users: db.collection<StoredUserDoc>(usersCollection),
    sessions: db.collection<SessionDoc>('sessions'),
    refreshTokens: db.collection<RefreshTokenDoc>('refresh_tokens'),
    oneTimeTokens: db.collection<OneTimeTokenDoc>('one_time_tokens'),
    records: db.collection<RecordDoc>('records'),
    counters: db.collection<CounterDoc>('counters'),
    files: db.collection<FileDoc>('files'),
    assistUsage: db.collection<AssistUsageDoc>('assist_usage'),
    assistDays: db.collection<AssistDayDoc>('assist_days'),
    loginFailures: db.collection<LoginFailureDoc>('login_failures'),
    windowedCounts: db.collection<WindowedCountDoc>('windowed_counts'),
    announcements: db.collection<AnnouncementDoc>('announcements'),
    pushSubscriptions: db.collection<PushSubscriptionDoc>('push_subscriptions'),
    dailyStats: db.collection<DailyStatsDoc>('daily_stats'),
    serverSettings: db.collection<ServerSettingDoc>('server_settings'),
    fileBlobs: db.collection('file_blobs.files'),
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
  // A new index on a big collection may take longer to build than any
  // one operation is allowed at run time: at boot it may take its time.
  const building = { timeoutMS: 0 } as const;
  // Before Phase 7 an address was unique as itself; sealed, every account
  // would be missing it at once, so that index goes first (M7.7).
  const legacyIndex = await c.users.indexExists('email_unique').catch(() => false);
  if (legacyIndex) await c.users.dropIndex('email_unique', building);
  await Promise.all([
    // An address is found by its keyed hash (Phase 7, M7.7); an account
    // from before is sealed at start, and has none until then.
    c.users.createIndex(
      { emailLookup: 1 },
      { unique: true, name: 'email_lookup_unique', partialFilterExpression: { emailLookup: { $exists: true } }, ...building },
    ),

    c.sessions.createIndex({ userId: 1, lastSeenAt: -1 }, { name: 'user_sessions', ...building }),
    c.sessions.createIndex({ expiresAt: 1 }, { expireAfterSeconds: 0, name: 'sessions_ttl', ...building }),

    c.refreshTokens.createIndex({ userId: 1, tokenHash: 1 }, { unique: true, name: 'user_token', ...building }),
    c.refreshTokens.createIndex({ userId: 1, sessionId: 1 }, { name: 'user_session_tokens', ...building }),
    c.refreshTokens.createIndex({ expiresAt: 1 }, { expireAfterSeconds: 0, name: 'refresh_ttl', ...building }),

    c.oneTimeTokens.createIndex({ userId: 1, purpose: 1, tokenHash: 1 }, { unique: true, name: 'user_purpose_token', ...building }),
    c.oneTimeTokens.createIndex({ expiresAt: 1 }, { expireAfterSeconds: 0, name: 'one_time_ttl', ...building }),

    // The row's identity: one stored copy per (user, table, key).
    c.records.createIndex({ userId: 1, table: 1, uuid: 1 }, { unique: true, name: 'user_row', ...building }),
    // The pull: a user's rows in sequence order.
    c.records.createIndex({ userId: 1, seq: 1 }, { unique: true, name: 'user_seq', ...building }),

    // A file is named by its own contents, once per account.
    c.files.createIndex({ userId: 1, sha256: 1 }, { unique: true, name: 'user_file', ...building }),

    // One row per account per day, and old days sweep themselves away.
    c.assistUsage.createIndex({ userId: 1, day: 1 }, { unique: true, name: 'user_day', ...building }),
    c.assistUsage.createIndex({ lastAt: 1 }, { expireAfterSeconds: 60 * 60 * 24 * 60, name: 'assist_ttl', ...building }),
    c.assistDays.createIndex({ lastAt: 1 }, { expireAfterSeconds: 60 * 60 * 24 * 60, name: 'assist_days_ttl', ...building }),

    // A window of failed sign-ins goes when it ends.
    c.loginFailures.createIndex({ resetAt: 1 }, { expireAfterSeconds: 0, name: 'login_failures_ttl', ...building }),
    c.loginFailures.createIndex({ emailKey: 1 }, { name: 'login_failures_email', ...building }),
    c.windowedCounts.createIndex({ expiresAt: 1 }, { expireAfterSeconds: 0, name: 'windowed_counts_ttl', ...building }),

    // The news live now, newest first ([[Admin]]).
    c.announcements.createIndex({ startsAt: 1, endsAt: 1 }, { name: 'announcements_live', ...building }),
    // A browser subscribes once; an account's go with it.
    c.pushSubscriptions.createIndex({ endpoint: 1 }, { unique: true, name: 'push_endpoint', ...building }),
    c.pushSubscriptions.createIndex({ userId: 1 }, { name: 'push_user', ...building }),
    // The admin's counts over the accounts.
    c.users.createIndex({ lastActiveAt: 1 }, { name: 'users_last_active', ...building }),
    c.users.createIndex({ createdAt: 1 }, { name: 'users_created', ...building }),

    // A file's bytes by their owner, to sweep up after a delete.
    c.fileBlobs.createIndex({ 'metadata.userId': 1 }, { name: 'file_blobs_owner', ...building }),
  ]);
  // Rows stored before Phase 7 kept when they arrived; nothing needs it
  // (M7.3), so it goes, once, and a later start finds nothing to do.
  await c.records.updateMany({ receivedAt: { $exists: true } }, { $unset: { receivedAt: '' } }, building);
}
