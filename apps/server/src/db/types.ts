import type { ClientKind, EncEnvelope, KeyCheck, SyncedTable } from '@harvest/contracts';
import type { Binary, ObjectId } from 'mongodb';

/**
 * The documents the server keeps. Every one but the user carries
 * `userId`, and every query on them filters by it (ADR-011 rule 2): the
 * repositories are the only code that touches a collection, so a
 * handler cannot forget.
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
}

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

/**
 * Failed sign-ins for one email, from any address, in the current
 * window. `_id` is the SHA-256 of the normalised email: an address
 * nobody registered is never written down as itself.
 */
export interface LoginFailureDoc {
  _id: string;
  count: number;
  resetAt: Date;
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
  blob: Binary;
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
  data?: Record<string, unknown>;
  enc?: EncEnvelope;
  purged?: true;
  /** The user's sequence value at the last stored write. */
  seq: number;
  /** Which device wrote it last; kept for debugging, never returned. */
  deviceId: string;
  receivedAt: Date;
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
