import { createHash, randomBytes } from 'node:crypto';
import type { ClientKind, Me, Session } from '@harvest/contracts';
import type { CryptoKey } from 'jose';
import type { ObjectId } from 'mongodb';
import type { Logger } from 'pino';
import { isDuplicateKey, type RefreshTokenDoc, type Repositories, type SessionDoc, type UserDoc } from '../db/index.js';
import { HttpError, unauthorized } from '../http/errors.js';
import { networkOf } from '../http/ip.js';
import { KeyedMutex } from '../sync/mutex.js';
import type { Mailer, MailMessage } from '../mail/mailer.js';
import { resetMail, verificationMail } from '../mail/templates.js';
import { hashPassword, verifyPassword } from './passwords.js';
import { open, seal } from './seal.js';
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

/**
 * How long after a refresh token is exchanged the same token may be
 * exchanged again for the same successor: a phone whose answer was lost
 * to a timeout retries, and a retry is not a theft (Q5-13).
 */
export const refreshGraceMs = 30_000;

/** How often a session's "last seen" is written. */
const touchEveryMs = 60_000;

/** Who is asking, as a request behind sign-in knows it. */
export interface Caller extends AccessClaims {
  /** Whether the account has confirmed its email. */
  verified: boolean;
}

/** Mails to one address: three an hour, ten a day (S6-14). */
const mailWindows = [
  { max: 3, ms: 60 * 60_000 },
  { max: 10, ms: 24 * 60 * 60_000 },
] as const;

/** One message for every failed sign-in, so it never says which half was wrong (AC3). */
export const wrongCredentials = 'Wrong email or password';

/** The soft per-email sign-in limits (S5-06, S6-03). */
export interface EmailLimit {
  /** Per email and network (/24, /48). */
  failures: number;
  /** Per email, from anywhere. */
  globalFailures: number;
  windowMs: number;
}

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
  /**
   * The per-account lock pushes run under, so deleting an account cannot
   * interleave with a push that would write rows back for it (Q5-56).
   */
  accountLock?: KeyedMutex;
  /** The soft per-email sign-in limit (audit S5-06). */
  emailLimit?: EmailLimit;
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
  private readonly lock: KeyedMutex;
  private readonly emailLimit: EmailLimit;
  private readonly pending = new Set<Promise<void>>();
  /** When this process last wrote each session's "last seen". */
  private readonly touched = new Map<string, number>();

  constructor(private readonly deps: AuthDeps) {
    this.repos = deps.repos;
    this.now = deps.now ?? (() => new Date());
    this.lock = deps.accountLock ?? new KeyedMutex();
    this.emailLimit = deps.emailLimit ?? { failures: 20, globalFailures: 200, windowMs: 60 * 60_000 };
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
    // This is the one answer that says an address has an account: a
    // deliberate exception to AC3, for a session straight after sign-up,
    // and the reason sign-up has the tightest limit ([[Accounts]]).
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
    if (!(await this.mayMail(user.email))) return;
    await this.repos.oneTimeTokens.invalidate(user._id, 'verify', this.now());
    await this.sendVerification(user, false);
  }

  /**
   * Runs [task] after the answer has gone: "resend" and "forgot" answer
   * 202 before looking anything up, so an address with an account does
   * not take longer to answer than one without (S6-10). A failure is
   * logged, never answered.
   */
  later(task: () => Promise<void>): void {
    const run = new Promise<void>((resolve) => setImmediate(resolve))
      .then(task)
      .catch((error: unknown) => this.deps.logger.error({ err: error }, 'background work failed'))
      .finally(() => this.pending.delete(run));
    this.pending.add(run);
  }

  /** Waits for everything [later] started, for tests and a clean stop. */
  async settled(): Promise<void> {
    while (this.pending.size > 0) await Promise.all([...this.pending]);
  }

  /**
   * Whether another mail may go to [email]: three an hour and ten a
   * day, whoever asks (S6-14). Past that nothing is sent, and nobody is
   * told: the answer is 202 either way.
   */
  private async mayMail(email: string): Promise<boolean> {
    const key = `mail/${this.repos.users.lookup(`mail/${email}`)}`;
    const taken = await this.repos.windowedCounts.take(key, mailWindows, this.now());
    return taken.ok;
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
    /** The client's address, for the per-network count. */
    ip?: string | undefined;
  }): Promise<SignedIn> {
    const now = this.now();
    const everywhere = this.emailKey(input.email);
    const here = this.repos.users.lookup(`${everywhere}/${networkOf(input.ip)}`);
    // Counted per email *and network*: one machine can only lock the
    // email out for itself. The ceiling from anywhere is ten times
    // higher, far past what one network may send (S6-03).
    const wait =
      (await this.repos.loginFailures.blockedFor(here, now, this.emailLimit.failures)) ??
      (await this.repos.loginFailures.blockedFor(everywhere, now, this.emailLimit.globalFailures));
    if (wait !== null) {
      // Before the hash: an account under a guessing run costs nothing
      // more. Every address is counted alike, so this says nothing about
      // whether it has an account.
      throw new HttpError('rate_limited', 'Too many attempts for this account; try again later', undefined, {
        'Retry-After': String(wait),
      });
    }
    const user = await this.repos.users.findByEmail(input.email);
    const ok = await verifyPassword(user?.passwordHash ?? null, input.password);
    if (!user || !ok) {
      await this.repos.loginFailures.fail(here, everywhere, now, this.emailLimit.windowMs);
      await this.repos.loginFailures.fail(everywhere, everywhere, now, this.emailLimit.windowMs);
      throw unauthorized(wrongCredentials);
    }
    await this.repos.loginFailures.clearEmail(everywhere);
    return this.startSession(user, input.client, input.deviceName ?? null);
  }

  /**
   * Exchanges a refresh token for a new pair. The token is single use:
   * presenting one that was already exchanged means two parties hold it,
   * so the whole family (the session) is revoked and every device on it
   * must sign in again (AC4).
   *
   * The one exception is a retry: the same token again within
   * [refreshGraceMs] of its exchange, while its successor is still
   * unused, gets that same successor back. The answer to the first
   * exchange was lost, not stolen (Q5-13).
   */
  async refresh(token: string): Promise<SignedIn> {
    const read = readOpaqueToken(token);
    if (!read) throw unauthorized();
    const now = this.now();

    let known = await this.repos.sessions.findToken(read.userId, read.hash);
    if (!known) throw unauthorized();
    if (known.usedAt === null) {
      if (known.expiresAt <= now) throw unauthorized();
      const session = await this.repos.sessions.findLive(read.userId, known.sessionId, now);
      const user = session ? await this.repos.users.findById(read.userId) : null;
      if (!session || !user) throw unauthorized();

      // The successor is written first, and the old token is marked used
      // together with it: whatever fails in between, a retry finds either
      // an unused token or a used one that names its successor, never a
      // used one with none, which would read as theft (Q6-16).
      const next = createOpaqueToken(user._id);
      const expiresAt = new Date(now.getTime() + refreshTokenMs);
      await this.repos.sessions.addToken({ userId: user._id, sessionId: session._id, tokenHash: next.hash, expiresAt }, now);
      const sealed = seal(successorKey(token), Buffer.from(next.token), 'refresh-successor');
      const consumed = await this.repos.sessions.consumeToken(read.userId, read.hash, now, sealed);
      if (consumed) {
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
      // Another request exchanged it a moment ago: this successor was
      // never handed out, and the other one's is.
      await this.repos.sessions.dropUnused(user._id, next.hash);
      known = await this.repos.sessions.findToken(read.userId, read.hash);
      if (!known) throw unauthorized();
    }

    const retried = await this.retry(token, read.userId, known, now);
    if (retried) return retried;
    await this.repos.sessions.revoke(read.userId, known.sessionId, now);
    this.deps.logger.warn(
      { userId: read.userId.toHexString(), sessionId: known.sessionId.toHexString() },
      'refresh token reused; session revoked',
    );
    throw unauthorized();
  }

  /**
   * The successor of a token presented again, if this is a retry inside
   * the grace: the token was exchanged moments ago, its successor has
   * not been used, and the session is live. Null means reuse.
   */
  private async retry(
    token: string,
    userId: ObjectId,
    known: RefreshTokenDoc,
    now: Date,
  ): Promise<SignedIn | null> {
    if (!known.usedAt || now.getTime() - known.usedAt.getTime() > refreshGraceMs) return null;
    // Marked used and given its successor in one write, so there is no
    // half-exchanged token to wait for.
    if (!known.successor) return null;
    const successor = open(successorKey(token), known.successor, 'refresh-successor')?.toString();
    const next = successor ? readOpaqueToken(successor) : null;
    if (!successor || !next || !next.userId.equals(userId)) return null;
    const unused = await this.repos.sessions.findToken(userId, next.hash);
    if (!unused || unused.usedAt !== null || unused.expiresAt <= now) return null;

    const session = await this.repos.sessions.findLive(userId, known.sessionId, now);
    const user = session ? await this.repos.users.findById(userId) : null;
    if (!session || !user) return null;
    return {
      accessToken: await signAccessToken(this.deps.keys.privateKey, { userId: user._id, sessionId: session._id }),
      expiresIn: accessTokenSeconds,
      refreshToken: successor,
      client: session.client,
      user: toMe(user),
    };
  }

  /** Signs out the device the refresh token belongs to. Quietly does nothing for a token it does not know. */
  async logout(token: string): Promise<void> {
    const read = readOpaqueToken(token);
    if (!read) return;
    const known = await this.repos.sessions.findToken(read.userId, read.hash);
    if (!known) return;
    const now = this.now();
    // Only the device's current token signs it out, or one exchanged
    // moments ago (the grace): an old one from a log or a backup is not
    // enough to end a session (S6-15).
    if (known.usedAt && now.getTime() - known.usedAt.getTime() > refreshGraceMs) return;
    await this.repos.sessions.revoke(read.userId, known.sessionId, now);
  }

  /**
   * The access token's claims, if the token is valid and its session is
   * still signed in. Checking the session costs one indexed read per
   * request, and buys a sign-out (or a reset, or a deleted account) that
   * takes effect now rather than fifteen minutes from now.
   */
  async authenticate(accessToken: string): Promise<Caller | null> {
    const claims = await verifyAccessToken(this.deps.keys.publicKey, accessToken);
    if (!claims) return null;
    const now = this.now();
    // The session and the account in one read, not two (SV-11).
    const live = await this.repos.sessions.findLiveCaller(claims.userId, claims.sessionId, now);
    if (!live) return null;
    await this.touch(claims, now);
    return { ...claims, verified: live.verified };
  }

  /**
   * "Last seen" is written at most once a minute per session; this
   * process remembers when it last wrote, so the other requests of that
   * minute send nothing at all (SV-11).
   */
  private async touch(claims: AccessClaims, now: Date): Promise<void> {
    const key = claims.sessionId.toHexString();
    const last = this.touched.get(key);
    if (last !== undefined && now.getTime() - last < touchEveryMs && now.getTime() >= last) return;
    if (this.touched.size >= 10_000) {
      for (const [id, at] of this.touched) if (now.getTime() - at >= touchEveryMs) this.touched.delete(id);
      if (this.touched.size >= 10_000) this.touched.clear();
    }
    this.touched.set(key, now.getTime());
    await this.repos.sessions.touch(claims.userId, claims.sessionId, now);
  }

  // ----------------------------------------------------------- resets

  async forgotPassword(email: string): Promise<void> {
    const user = await this.repos.users.findByEmail(email);
    if (!user) return;
    // Past the limit the links already sent stay good: nothing changes.
    if (!(await this.mayMail(user.email))) return;
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
    // A new password is a fresh start for sign-in too (S6-03).
    const owner = await this.repos.users.findById(read.userId);
    if (owner) await this.repos.loginFailures.clearEmail(this.emailKey(owner.email));
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
  /** Whether [password] is the account's, for a device about to write my data out; 403 when not. */
  async reauth(userId: ObjectId, password: string): Promise<void> {
    const user = await this.me(userId);
    if (!(await verifyPassword(user.passwordHash, password))) {
      throw new HttpError('forbidden', 'Wrong password');
    }
  }

  async deleteAccount(userId: ObjectId, password: string): Promise<void> {
    const user = await this.me(userId);
    if (!(await verifyPassword(user.passwordHash, password))) {
      // Not 401: the session is fine, and a 401 would send the client to refresh.
      throw new HttpError('forbidden', 'Wrong password');
    }
    // Under the account's lock: a push or an upload already running
    // finishes first, and none starts until everything is gone.
    await this.lock.run(userId.toHexString(), async () => {
      await this.repos.sessions.deleteAll(userId);
      await this.repos.oneTimeTokens.deleteAll(userId);
      await this.repos.records.deleteAll(userId);
      await this.repos.files.deleteAllFor(userId);
      await this.repos.assistUsage.deleteAllFor(userId);
      await this.repos.users.delete(userId);
    });
  }

  /**
   * Starts the private tier over ([[Accounts]], a forgotten PIN, or a new
   * one): with the password, drops the key check, the key share (a new
   * one is made on the next read, so nothing sealed before can be opened
   * again, even with the old PIN), every sealed row and every file. Only
   * rows still in the clear from before Phase 7 stay. Under the
   * account's lock, like a push.
   */
  async resetSyncKey(userId: ObjectId, password: string): Promise<void> {
    const user = await this.me(userId);
    if (!(await verifyPassword(user.passwordHash, password))) {
      throw new HttpError('forbidden', 'Wrong password');
    }
    await this.lock.run(userId.toHexString(), async () => {
      await this.repos.users.clearSyncKey(userId);
      await this.repos.records.deleteSealed(userId);
      await this.repos.files.deleteAllFor(userId);
      // Filled in again from what is left, the next time they are needed.
      await this.repos.totals.forget(userId, 'recordBytes');
      await this.repos.totals.forget(userId, 'fileBytes');
    });
  }

  // ---------------------------------------------------------- helpers

  /**
   * A sign-in's per-email key: the address under the server's lookup
   * key, so none is kept as itself and none can be found by hashing a
   * guess without the environment (Phase 7, M7.7).
   */
  private emailKey(email: string): string {
    return this.repos.users.lookup(`login/${email}`);
  }

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

  private async sendVerification(user: UserDoc, count = true): Promise<void> {
    if (count && !(await this.mayMail(user.email))) return;
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
      // Only the codes: a mail error carries the rejected address, and
      // logs never carry one.
      const { code, responseCode, command } = (error ?? {}) as { code?: unknown; responseCode?: unknown; command?: unknown };
      this.deps.logger.error(
        {
          purpose: message.purpose,
          code: typeof code === 'string' ? code : undefined,
          responseCode: typeof responseCode === 'number' ? responseCode : undefined,
          command: typeof command === 'string' ? command : undefined,
        },
        'mail failed',
      );
    });
  }
}


/**
 * The key a token's successor is sealed under: derived from the token
 * itself, which the server never keeps (only a different hash of it), so
 * only whoever presents the token can open it.
 */
function successorKey(token: string): Buffer {
  return createHash('sha256').update(`harvest/refresh-successor/${token}`).digest();
}

function invalidLink(): HttpError {
  return new HttpError('validation_failed', 'This link is invalid, used or expired', [
    { path: ['body', 'token'], message: 'Invalid, used or expired', code: 'custom' },
  ]);
}
