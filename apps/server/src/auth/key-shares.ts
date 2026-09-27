import { randomBytes } from 'node:crypto';
import { keyShareBytes, type KeyCheck, type SyncKeyResult } from '@harvest/contracts';
import type { ObjectId } from 'mongodb';
import type { UsersRepository } from '../db/users.js';
import { HttpError, unauthorized } from '../http/errors.js';
import { open, seal } from './seal.js';

const aadOf = (userId: ObjectId) => `key-share/${userId.toHexString()}`;

/**
 * The server's half of the private tier's key ([[Sync-API]], sync key;
 * audit S5-04, S5-09).
 *
 * Each account has 32 random bytes the clients mix into their key. They
 * are stored sealed under KEY_SHARE_KEY, which lives in the environment
 * and never in the database: a copy of the database, or a backup of its
 * volume, holds the salt and the ciphertexts but not the share, and so
 * cannot be used to try PINs. A signed-in, verified session gets the
 * share in the clear, which is what makes it a share and not a secret
 * from the account.
 *
 * Beside it, the account's key check: the first device to choose a PIN
 * stores it, and every other device's PIN is accepted only if it opens
 * it. The server keeps it and cannot open it.
 */
export class KeyShares {
  constructor(
    private readonly users: UsersRepository,
    private readonly key: Buffer,
  ) {}

  async read(userId: ObjectId): Promise<SyncKeyResult> {
    let user = await this.users.findById(userId);
    if (!user) throw unauthorized();
    if (!user.keyShare) {
      user = await this.users.setKeyShareOnce(userId, seal(this.key, randomBytes(keyShareBytes), aadOf(userId)));
      if (!user?.keyShare) throw unauthorized();
    }
    const share = open(this.key, user.keyShare, aadOf(userId));
    // Never replaced with a new one: every sealed row of the account
    // depends on this one. A key that does not open it is a server set
    // up with the wrong KEY_SHARE_KEY, and that is for me to fix.
    if (!share) throw new Error('KEY_SHARE_KEY does not open this account\'s key share; is it the key this database was made with?');
    return { salt: user.syncSalt, keyShare: share.toString('base64'), check: user.keyCheck ?? null };
  }

  /**
   * Stores [check] as the account's, if it has none. The same check sent
   * again (a retry whose answer was lost) is a success too; any other
   * is a conflict, answered with the stored one.
   */
  async storeCheck(userId: ObjectId, check: KeyCheck): Promise<KeyCheck> {
    if (await this.users.setKeyCheckOnce(userId, check)) return check;
    const user = await this.users.findById(userId);
    if (!user) throw unauthorized();
    const stored = user.keyCheck;
    if (!stored) throw new HttpError('conflict', 'The key check could not be stored; try again');
    if (stored.iv === check.iv && stored.ct === check.ct && stored.v === check.v) return stored;
    throw new HttpError(
      'conflict',
      'Another device chose this account\'s PIN first; enter that one',
      undefined,
      {},
      { check: stored },
    );
  }
}
