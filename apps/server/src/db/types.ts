import type { ClientKind, EncEnvelope, KeyCheck, SyncedTable } from '@harvest/contracts';
import type { Binary, ObjectId } from 'mongodb';

/**
 * The documents the server keeps. Every one but the user carries
 * `userId`, and every query on them filters by it (ADR-011 rule 2): the
 * repositories are the only code that touches a collection, so a
 * handler cannot forget.
 */

/**
 * An account as the code sees it, with its address and name in the
 * clear. The database never holds those as themselves ([[StoredUserDoc]]);
 * the users repository seals and opens them.
 */
export interface UserDoc {
  _id: ObjectId;
  /** Normalised: trimmed and lowercase. */
  email: string;
  /** argon2id, encoded with its own parameters and salt. */
  passwordHash: string;
  displayName: string | null;
  verifiedAt: Date | null;
  /** Base64, 16 random bytes; the public half of the private tier's key. */
  syncSalt: string;
  createdAt: Date;
  lastSeenAt: Date;
  /**
   * The account's key share, sealed with KEY_SHARE_KEY (AES-256-GCM,
   * additional data `key-share/<user id>`), base64. Made the first time
   * it is asked for.
   */
  keyShare?: SealedBytes;
  /** The first device's key check; absent until a PIN is chosen. */
  keyCheck?: KeyCheck | null;
  /**
   * SHA-256 of the PIN proof (hex), sealed like the share (additional
   * data `pin-verifier/<user id>`): a copy of the database alone cannot
   * even be searched for the PIN. Absent until a PIN is chosen.
   */
  pinVerifier?: SealedBytes;
  /** Which key the private tier is under; 1 until the first start over. */
  keyEpoch?: number;
  /**
   * The last heartbeat ([[Admin]]): only the latest of each, never a
   * history. Absent until the first.
   */
  lastActiveAt?: Date;
  lastPlatform?: string;
  lastAppVersion?: string;
  /** The streak the last heartbeat shared, or null when it shared none. */
  streak?: { current: number; best: number } | null;
}

/**
 * An account as the database holds it (Phase 7, M7.7): the address
 * found by its keyed hash and kept sealed, the name sealed, both under
 * keys drawn from the environment (`people-keys.ts`), so a copy of the
 * database holds no readable address or name.
 */
export type StoredUserDoc = Omit<UserDoc, 'email' | 'displayName'> & {
  /** HMAC-SHA256 of the normalised address under the lookup key, hex. */
  emailLookup: string;
  /** The address, sealed (additional data `email/<user id>`). */
  emailSealed: SealedBytes;
  /** The display name, sealed (additional data `name/<user id>`), or null for none. */
  nameSealed: SealedBytes | null;
  /** Only on an account stored before Phase 7, until the server's start seals it. */
  email?: string;
  displayName?: string | null;
};

/** Bytes sealed by the server with a key of its own, base64. */
export interface SealedBytes {
  iv: string;
  ct: string;
}

/**
 * A signed-in device, and the refresh-token family that keeps it signed
 * in. Revoking the session is revoking the family.
 */
export interface SessionDoc {
  _id: ObjectId;
  userId: ObjectId;
  client: ClientKind;
  deviceName: string | null;
  createdAt: Date;
  lastSeenAt: Date;
  /** Moves forward on every refresh; a month of silence ends the session. */
  expiresAt: Date;
  revokedAt: Date | null;
}

export interface RefreshTokenDoc {
  _id: ObjectId;
  userId: ObjectId;
  sessionId: ObjectId;
  /** SHA-256 of the token, hex. The token itself is never stored. */
  tokenHash: string;
  createdAt: Date;
  expiresAt: Date;
  /**
   * Set when the token is exchanged. A used token is kept until it
   * expires, because seeing it a second time is how theft is noticed.
   */
  usedAt: Date | null;
  /**
   * The token this one was exchanged for, sealed under a key only the
   * holder of this token can derive, so a retry of a refresh whose
   * answer was lost gets the same successor back (Q5-13).
   */
  successor?: SealedBytes;
}

export type OneTimePurpose = 'verify' | 'reset';

/** An emailed link's token: verification (24 h) or password reset (1 h). */
export interface OneTimeTokenDoc {
  _id: ObjectId;
  userId: ObjectId;
  purpose: OneTimePurpose;
  tokenHash: string;
  createdAt: Date;
  expiresAt: Date;
  usedAt: Date | null;
}

/** One account's assist requests on one UTC day. */
export interface AssistUsageDoc {
  _id: ObjectId;
  userId: ObjectId;
  /** `2026-09-20`. */
  day: string;
  count: number;
  lastAt: Date;
}

/** The whole server's assist requests on one UTC day. `_id` is the day. */
export interface AssistDayDoc {
  _id: string;
  count: number;
  lastAt: Date;
}

/** Counts in fixed windows ([[WindowedCountsRepository]]). */
export interface WindowedCountDoc {
  _id: string;
  windows: { count: number; resetAt: Date }[];
  expiresAt: Date;
}

/**
 * Failed sign-ins for one email, from any address, in the current
 * window. `_id` is the SHA-256 of the normalised email: an address
 * nobody registered is never written down as itself.
 */
export interface LoginFailureDoc {
  _id: string;
  count: number;
  resetAt: Date;
  /** The hashed address the count belongs to, whatever network it came from. */
  emailKey?: string;
}

/** One file, content-addressed, its bytes sealed by the client. */
export interface FileDoc {
  _id: ObjectId;
  userId: ObjectId;
  /** SHA-256 of the plaintext, lowercase hex. */
  sha256: string;
  /** The ciphertext. */
  bytes: number;
  iv: string;
  /** The plaintext's length, so a reader can check what it decrypted. */
  plainBytes: number;
  /** The ciphertext in GridFS (`file_blobs`), for every file stored from 3.1.0 on. */
  gridId?: ObjectId;
  /** The ciphertext itself, for a file stored before GridFS (under 16 MB). */
  blob?: Binary;
  uploadedAt: Date;
  /**
   * The last time a device was told the server has it (an upload, or a
   * "missing?" that did not list it): a device may name it in a row it
   * has not pushed yet, so the sweep leaves it alone for a while.
   */
  claimedAt?: Date;
}

/** One synced row, as the server holds it. */
export interface RecordDoc {
  _id: ObjectId;
  userId: ObjectId;
  table: SyncedTable;
  uuid: string;
  /** Exactly as the client sent them, so a pull returns them unchanged. */
  updatedAt: string;
  deletedAt: string | null;
  /** `updatedAt` in epoch microseconds: what the conflict rule compares. */
  stamp: number;
  /** Only on a row stored in the clear before Phase 7, until a device seals it. */
  data?: Record<string, unknown>;
  enc?: EncEnvelope;
  /** The name of the file a sealed row names, in the clear, for the sweep. */
  file?: string;
  purged?: true;
  /** The user's sequence value at the last stored write. */
  seq: number;
  /**
   * Which device wrote it last, so a pull can leave out a device's own
   * writes; never returned. No arrival time is kept beside it (Phase 7,
   * M7.3): the sequence is all a pull needs.
   */
  deviceId: string;
  /** The stored payload's size (`payloadBytes`); absent on rows from before it was kept. */
  bytes?: number;
}

/**
 * The per-user sequence, and what the account keeps. `_id` is the
 * user's id. The two byte totals are filled in the first time they are
 * needed, from what is stored.
 */
export interface CounterDoc {
  _id: ObjectId;
  seq: number;
  recordBytes?: number;
  fileBytes?: number;
}

/** A piece of news ([[Admin]]). */
export interface AnnouncementDoc {
  _id: ObjectId;
  title: string;
  body: string;
  link: string | null;
  push: boolean;
  popup: boolean;
  audience: 'everyone' | 'accounts';
  startsAt: Date;
  endsAt: Date | null;
  createdAt: Date;
  /** Web Push deliveries that went through. */
  pushed: number;
}

/** A browser's Web Push subscription, for one account. */
export interface PushSubscriptionDoc {
  _id: ObjectId;
  userId: ObjectId;
  endpoint: string;
  keys: { p256dh: string; auth: string };
  createdAt: Date;
}

/**
 * One day's totals ([[Admin]]), `_id` the UTC day. Written every hour for
 * the day under way; `active` is counted by the heartbeats themselves.
 */
export interface DailyStatsDoc {
  _id: string;
  accounts: number;
  verified: number;
  signups: number;
  active: number;
  active7: number;
  active30: number;
  sharing: number;
  streakMedian: number;
  streakMean: number;
}

/** What the server keeps of its own, by name: the Web Push key pair. */
export interface ServerSettingDoc {
  _id: string;
  publicKey?: string;
  /** Sealed with KEY_SHARE_KEY (additional data `vapid`). */
  privateKey?: SealedBytes;
}
