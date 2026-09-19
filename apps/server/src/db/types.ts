import type { ClientKind, EncEnvelope, SyncedTable } from '@harvest/contracts';
import type { ObjectId } from 'mongodb';

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
}

/** The per-user sequence. `_id` is the user's id. */
export interface CounterDoc {
  _id: ObjectId;
  seq: number;
}
