import { randomBytes } from 'node:crypto';
import type { ClientKind, Me, Session } from '@harvest/contracts';
import type { CryptoKey } from 'jose';
import type { ObjectId } from 'mongodb';
import type { Logger } from 'pino';
import { isDuplicateKey, type Repositories, type SessionDoc, type UserDoc } from '../db/index.js';
import { HttpError, unauthorized } from '../http/errors.js';
import type { Mailer, MailMessage } from '../mail/mailer.js';
import { resetMail, verificationMail } from '../mail/templates.js';
import { hashPassword, verifyPassword } from './passwords.js';
import {
  accessTokenSeconds,
  createOpaqueToken,
  readOpaqueToken,
  signAccessToken,
  verifyAccessToken,
  type AccessClaims,
} from './tokens.js';

export const refreshTokenMs = 30 * 24 * 60 * 60_000;
export const verifyLinkMs = 24 * 60 * 60_000;
export const resetLinkMs = 60 * 60_000;

/** One message for every failed sign-in, so it never says which half was wrong (AC3). */
export const wrongCredentials = 'Wrong email or password';

export interface SignedIn {
  accessToken: string;
  expiresIn: number;
  refreshToken: string;
  client: ClientKind;
  user: Me;
}

export interface AuthDeps {
  repos: Repositories;
  mailer: Mailer;
  logger: Logger;
  keys: { privateKey: CryptoKey; publicKey: CryptoKey };
  appUrl: string;
  now?: () => Date;
}

export function toMe(user: UserDoc): Me {
  return {
    id: user._id.toHexString(),
    email: user.email,
    displayName: user.displayName,
    verifiedAt: user.verifiedAt?.toISOString() ?? null,
    syncSalt: user.syncSalt,
    createdAt: user.createdAt.toISOString(),
  };
}

export function toSession(session: SessionDoc, currentId: ObjectId): Session {
  return {
    id: session._id.toHexString(),
    deviceName: session.deviceName,
    client: session.client,
    createdAt: session.createdAt.toISOString(),
    lastSeenAt: session.lastSeenAt.toISOString(),
    current: session._id.equals(currentId),
  };
}

/**
 * Accounts ([[Accounts]]): sign-up, sign-in, the refresh-token families,
 * the two emailed flows, and deleting it all. Routes parse and answer;
 * the decisions are here.
 */
export class AuthService {
  private readonly repos: Repositories;
  private readonly now: () => Date;

  constructor(private readonly deps: AuthDeps) {
    this.repos = deps.repos;
    this.now = deps.now ?? (() => new Date());
  }

  // ---------------------------------------------------------- sign-up

  async register(input: {
    email: string;
    password: string;
    displayName?: string | undefined;
    client: ClientKind;
    deviceName?: string | undefined;
  }): Promise<SignedIn> {
    // Checked before hashing, so a taken address costs no argon2 run.
    if (await this.repos.users.findByEmail(input.email)) {
      throw new HttpError('conflict', 'An account with this email already exists');
    }
    const now = this.now();
    let user: UserDoc;
    try {
      user = await this.repos.users.create({
        email: input.email,
        passwordHash: await hashPassword(input.password),
        displayName: input.displayName ?? null,
        verifiedAt: null,
        syncSalt: randomBytes(16).toString('base64'),
        createdAt: now,
        lastSeenAt: now,
      });
    } catch (error) {
      // Two sign-ups with one address at once: the index decides.
      if (isDuplicateKey(error)) throw new HttpError('conflict', 'An account with this email already exists');
      throw error;
    }
    await this.sendVerification(user);
    return this.startSession(user, input.client, input.deviceName ?? null);
  }

  async resendVerification(email: string): Promise<void> {
    const user = await this.repos.users.findByEmail(email);
    if (!user || user.verifiedAt !== null) return;
    await this.repos.oneTimeTokens.invalidate(user._id, 'verify', this.now());
    await this.sendVerification(user);
  }

  async verifyEmail(token: string): Promise<void> {
    const read = readOpaqueToken(token);
    const now = this.now();
    if (!read || !(await this.repos.oneTimeTokens.consume(read.userId, 'verify', read.hash, now))) {
      throw invalidLink();
    }
    await this.repos.users.markVerified(read.userId, now);
  }

  // ---------------------------------------------------------- sign-in

  async login(input: {
    email: string;
    password: string;
    client: ClientKind;
    deviceName?: string | undefined;
  }): Promise<SignedIn> {
    const user = await this.repos.users.findByEmail(input.email);
    const ok = await verifyPassword(user?.passwordHash ?? null, input.password);
    if (!user || !ok) throw unauthorized(wrongCredentials);
    return this.startSession(user, input.client, input.deviceName ?? null);
  }

  /**
   * Exchanges a refresh token for a new pair. The token is single use:
   * presenting one that was already exchanged means two parties hold it,
   * so the whole family (the session) is revoked and every device on it
   * must sign in again (AC4).
   */
  async refresh(token: string): Promise<SignedIn> {
    const read = readOpaqueToken(token);
    if (!read) throw unauthorized();
    const now = this.now();

    const consumed = await this.repos.sessions.consumeToken(read.userId, read.hash, now);
    if (!consumed) {
      const known = await this.repos.sessions.findToken(read.userId, read.hash);
      if (known) {
        await this.repos.sessions.revoke(read.userId, known.sessionId, now);
        this.deps.logger.warn(
          { userId: read.userId.toHexString(), sessionId: known.sessionId.toHexString() },
          'refresh token reused; session revoked',
        );
      }
      throw unauthorized();
    }
    if (consumed.expiresAt <= now) throw unauthorized();

    const session = await this.repos.sessions.findLive(read.userId, consumed.sessionId, now);
    const user = session ? await this.repos.users.findById(read.userId) : null;
    if (!session || !user) throw unauthorized();

    const next = createOpaqueToken(user._id);
    const expiresAt = new Date(now.getTime() + refreshTokenMs);
    await this.repos.sessions.addToken({ userId: user._id, sessionId: session._id, tokenHash: next.hash, expiresAt }, now);
    await this.repos.sessions.extend(user._id, session._id, expiresAt, now);
    await this.repos.users.touch(user._id, now);

    return {
      accessToken: await signAccessToken(this.deps.keys.privateKey, { userId: user._id, sessionId: session._id }),
      expiresIn: accessTokenSeconds,
      refreshToken: next.token,
      client: session.client,
      user: toMe(user),
    };
  }

  /** Signs out the device the refresh token belongs to. Quietly does nothing for a token it does not know. */
  async logout(token: string): Promise<void> {
    const read = readOpaqueToken(token);
    if (!read) return;
    const known = await this.repos.sessions.findToken(read.userId, read.hash);
    if (known) await this.repos.sessions.revoke(read.userId, known.sessionId, this.now());
  }

  /**
   * The access token's claims, if the token is valid and its session is
   * still signed in. Checking the session costs one indexed read per
   * request, and buys a sign-out (or a reset, or a deleted account) that
   * takes effect now rather than fifteen minutes from now.
   */
  async authenticate(accessToken: string): Promise<AccessClaims | null> {
    const claims = await verifyAccessToken(this.deps.keys.publicKey, accessToken);
    if (!claims) return null;
    const now = this.now();
    const session = await this.repos.sessions.findLive(claims.userId, claims.sessionId, now);
    if (!session) return null;
    await this.repos.sessions.touch(claims.userId, claims.sessionId, now);
    return claims;
  }

  // ----------------------------------------------------------- resets

  async forgotPassword(email: string): Promise<void> {
    const user = await this.repos.users.findByEmail(email);
    if (!user) return;
    const now = this.now();
    await this.repos.oneTimeTokens.invalidate(user._id, 'reset', now);
    const link = createOpaqueToken(user._id);
    await this.repos.oneTimeTokens.create(user._id, 'reset', link.hash, now, resetLinkMs);
    this.deliver(resetMail(user.email, this.deps.appUrl, link.token));
  }

  /**
   * Sets a new password from an emailed link, and signs out every device
   * (AC5). Following the link also proves the address works, so an
   * unverified account becomes verified.
   */
  async resetPassword(token: string, password: string): Promise<void> {
    const read = readOpaqueToken(token);
    const now = this.now();
    if (!read || !(await this.repos.oneTimeTokens.consume(read.userId, 'reset', read.hash, now))) {
      throw invalidLink();
    }
    await this.repos.users.setPassword(read.userId, await hashPassword(password));
    await this.repos.users.markVerified(read.userId, now);
    await this.repos.oneTimeTokens.invalidate(read.userId, 'reset', now);
    await this.repos.sessions.revokeAll(read.userId, now);
  }

  // ----------------------------------------------------------- account

  async me(userId: ObjectId): Promise<UserDoc> {
    const user = await this.repos.users.findById(userId);
    if (!user) throw unauthorized();
    return user;
  }

  /**
   * Deletes the account and everything under it, now (AC6, ADR-011
   * rule 4). Tokens go first, so the account is signed out everywhere
   * even if a later step fails; the user goes last, so a retry can
   * still find it.
   */
  async deleteAccount(userId: ObjectId, password: string): Promise<void> {
    const user = await this.me(userId);
    if (!(await verifyPassword(user.passwordHash, password))) {
      // Not 401: the session is fine, and a 401 would send the client to refresh.
      throw new HttpError('forbidden', 'Wrong password');
    }
    await this.repos.sessions.deleteAll(userId);
    await this.repos.oneTimeTokens.deleteAll(userId);
    await this.repos.records.deleteAll(userId);
    await this.repos.files.deleteAllFor(userId);
    await this.repos.assistUsage.deleteAllFor(userId);
    await this.repos.users.delete(userId);
  }

  // ---------------------------------------------------------- helpers

  private async startSession(user: UserDoc, client: ClientKind, deviceName: string | null): Promise<SignedIn> {
    const now = this.now();
    const expiresAt = new Date(now.getTime() + refreshTokenMs);
    const session = await this.repos.sessions.create({
      userId: user._id,
      client,
      deviceName,
      createdAt: now,
      lastSeenAt: now,
      expiresAt,
    });
    const refresh = createOpaqueToken(user._id);
    await this.repos.sessions.addToken({ userId: user._id, sessionId: session._id, tokenHash: refresh.hash, expiresAt }, now);
    await this.repos.users.touch(user._id, now);
    return {
      accessToken: await signAccessToken(this.deps.keys.privateKey, { userId: user._id, sessionId: session._id }),
      expiresIn: accessTokenSeconds,
      refreshToken: refresh.token,
      client,
      user: toMe(user),
    };
  }

  private async sendVerification(user: UserDoc): Promise<void> {
    const link = createOpaqueToken(user._id);
    await this.repos.oneTimeTokens.create(user._id, 'verify', link.hash, this.now(), verifyLinkMs);
    this.deliver(verificationMail(user.email, this.deps.appUrl, link.token));
  }

  /**
   * Sends without waiting. The answer to "resend" and "forgot" must not
   * take longer for an address that exists than for one that does not,
   * and a slow mail server must not hold a request open.
   */
  private deliver(message: MailMessage): void {
    this.deps.mailer.send(message).catch((error: unknown) => {
      this.deps.logger.error({ err: error, purpose: message.purpose }, 'mail failed');
    });
  }
}

function invalidLink(): HttpError {
  return new HttpError('validation_failed', 'This link is invalid, used or expired', [
    { path: ['body', 'token'], message: 'Invalid, used or expired', code: 'custom' },
  ]);
}
