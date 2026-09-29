import { createHash, randomBytes, timingSafeEqual } from 'node:crypto';
import {
  keyShareBytes,
  unlockLimits,
  type KeyCheck,
  type SyncKeyState,
  type UnlockResult,
} from '@harvest/contracts';
import type { ObjectId } from 'mongodb';
import type { UserDoc } from '../db/types.js';
import type { UsersRepository } from '../db/users.js';
import type { CountWindow, WindowedCountsRepository } from '../db/windowed-counts.js';
import { HttpError, unauthorized } from '../http/errors.js';
import { open, seal } from './seal.js';

const shareAad = (userId: ObjectId) => `key-share/${userId.toHexString()}`;
const verifierAad = (userId: ObjectId) => `pin-verifier/${userId.toHexString()}`;

/** Wrong proofs: five in a quarter of an hour, twenty in a day. */
const unlockWindows: readonly CountWindow[] = [
  { max: unlockLimits.shortWindowTries, ms: unlockLimits.shortWindowMs },
  { max: unlockLimits.dayTries, ms: unlockLimits.dayMs },
];
const triesKey = (userId: ObjectId) => `unlock/${userId.toHexString()}`;

/**
 * The server's half of the private tier's key, and the online check of
 * the PIN that guards it ([[Sync-API]], sync key; audit S5-04, S6-04).
 *
 * Each account has 32 random bytes the clients mix into their key,
 * stored sealed under KEY_SHARE_KEY, which lives in the environment and
 * never in the database. Once a PIN is set, the share leaves the server
 * only for a device that proves the PIN: it sends HKDF of the PIN's
 * PBKDF2 base (the proof), and the server compares its SHA-256 with the
 * verifier the first device stored, sealed like the share. Wrong proofs
 * are counted in Mongo, 5 per 15 minutes and 20 per day per account, so
 * a stolen session can try a handful of PINs, not a million. Nothing
 * handed out before a right proof lets anyone try PINs offline.
 *
 * The epoch names the key: 1, and one more with every start over.
 */
export class KeyShares {
  constructor(
    private readonly users: UsersRepository,
    private readonly tries: WindowedCountsRepository,
    private readonly key: Buffer,
    private readonly now: () => Date = () => new Date(),
  ) {}

  private async userWithShare(userId: ObjectId): Promise<UserDoc & { keyShare: NonNullable<UserDoc['keyShare']> }> {
    let user = await this.users.findById(userId);
    if (!user) throw unauthorized();
    if (!user.keyShare) {
      user = await this.users.setKeyShareOnce(userId, seal(this.key, randomBytes(keyShareBytes), shareAad(userId)));
      if (!user?.keyShare) throw unauthorized();
    }
    return user as UserDoc & { keyShare: NonNullable<UserDoc['keyShare']> };
  }

  private shareOf(user: UserDoc & { keyShare: NonNullable<UserDoc['keyShare']> }): string {
    const share = open(this.key, user.keyShare, shareAad(user._id));
    // Never replaced with a new one: every sealed row of the account
    // depends on this one. A key that does not open it is a server set
    // up with the wrong KEY_SHARE_KEY, and that is for me to fix.
    if (!share) throw new Error('KEY_SHARE_KEY does not open this account\'s key share; is it the key this database was made with?');
    return share.toString('base64');
  }

  /** What any verified session may know: whether a PIN is set, and the share only while none is. */
  async state(userId: ObjectId): Promise<SyncKeyState> {
    const user = await this.userWithShare(userId);
    const epoch = user.keyEpoch ?? 1;
    if (user.pinVerifier) return { state: 'set', salt: user.syncSalt, epoch };
    return { state: 'none', salt: user.syncSalt, epoch, keyShare: this.shareOf(user) };
  }

  /**
   * The share, the check and the epoch, for a proof of the account's
   * PIN. A try is taken before the comparison, atomically, so requests
   * sent at once cannot get past the limit; a right proof gives it back
   * and starts the short window again.
   */
  async unlock(userId: ObjectId, proof: string): Promise<UnlockResult> {
    const user = await this.userWithShare(userId);
    if (!user.pinVerifier || !user.keyCheck) {
      throw new HttpError('conflict', 'No PIN is set on this account yet; choose one');
    }
    const stored = open(this.key, user.pinVerifier, verifierAad(userId));
    if (!stored) throw new Error('KEY_SHARE_KEY does not open this account\'s PIN verifier');

    const taken = await this.tries.take(triesKey(userId), unlockWindows, this.now());
    if (!taken.ok) {
      throw new HttpError('rate_limited', 'Too many wrong PINs; try again later', undefined, {
        'Retry-After': String(taken.retryAfter),
      });
    }
    const given = createHash('sha256').update(Buffer.from(proof, 'base64')).digest();
    if (!timingSafeEqual(given, stored)) {
      throw new HttpError('wrong_pin', 'That is not the PIN of this account', undefined, {}, { triesLeft: taken.left });
    }
    await this.tries.giveBack(triesKey(userId), unlockWindows, [0]);
    return { keyShare: this.shareOf(user), check: user.keyCheck, epoch: user.keyEpoch ?? 1 };
  }

  /**
   * Sets the PIN: the verifier (hex) and the key check, while none is
   * set. The same pair again (a retry whose answer was lost) is a success
   * too; anything else is a conflict: another device chose first.
   */
  async setPin(userId: ObjectId, verifierHex: string, check: KeyCheck): Promise<{ epoch: number }> {
    const user = await this.userWithShare(userId);
    const verifier = Buffer.from(verifierHex, 'hex');
    if (await this.users.setPinOnce(userId, seal(this.key, verifier, verifierAad(userId)), check)) {
      return { epoch: user.keyEpoch ?? 1 };
    }
    const now = await this.users.findById(userId);
    if (!now) throw unauthorized();
    const stored = now.pinVerifier ? open(this.key, now.pinVerifier, verifierAad(userId)) : null;
    if (stored?.equals(verifier) && now.keyCheck?.iv === check.iv && now.keyCheck.ct === check.ct) {
      return { epoch: now.keyEpoch ?? 1 };
    }
    throw new HttpError('conflict', 'Another device chose this account\'s PIN first; enter that one');
  }

  /** Forgets the wrong tries, for a start over. */
  async forgetTries(userId: ObjectId): Promise<void> {
    await this.tries.clear(triesKey(userId));
  }
}
