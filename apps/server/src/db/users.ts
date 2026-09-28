import { ObjectId, type Collection } from 'mongodb';
import type { KeyCheck } from '@harvest/contracts';
import { lookupOf, type PeopleKeys } from '../auth/people-keys.js';
import { open, seal } from '../auth/seal.js';
import type { SealedBytes, StoredUserDoc, UserDoc } from './types.js';

/**
 * The accounts. What the rest of the server sees is a [UserDoc], with
 * its address and name in the clear; what the database holds is a
 * [StoredUserDoc], with neither (Phase 7, M7.7): this is the one place
 * that turns one into the other.
 */
export class UsersRepository {
  constructor(
    private readonly users: Collection<StoredUserDoc>,
    private readonly keys: PeopleKeys,
  ) {}

  /** The keyed hash of [text]: how an address, or anything drawn from one, is kept. */
  lookup(text: string): string {
    return lookupOf(this.keys, text);
  }

  /** Inserts a new account; throws the driver's duplicate-key error when the email is taken. */
  async create(user: Omit<UserDoc, '_id'>): Promise<UserDoc> {
    const doc: UserDoc = { _id: new ObjectId(), ...user };
    await this.users.insertOne(this.stored(doc));
    return doc;
  }

  async findById(userId: ObjectId): Promise<UserDoc | null> {
    return this.opened(await this.users.findOne({ _id: userId }));
  }

  /** The one lookup not by id: sign-in and the emailed flows start from an address. */
  async findByEmail(email: string): Promise<UserDoc | null> {
    return this.opened(await this.users.findOne({ emailLookup: this.lookup(email) }));
  }

  /**
   * Seals every account stored before Phase 7: its address becomes a
   * keyed hash and a sealed copy, its name a sealed one, and neither is
   * left as itself. Run at every start; one that finds nothing does
   * nothing. Answers how many it sealed.
   */
  async sealLegacy(): Promise<number> {
    let sealed = 0;
    for await (const doc of this.users.find({ email: { $exists: true } })) {
      const { email, displayName, ...rest } = doc;
      const user = { ...rest, email: email!, displayName: displayName ?? null } as UserDoc;
      const { _id, ...fields } = this.stored(user);
      await this.users.updateOne({ _id }, { $set: fields, $unset: { email: '', displayName: '' } });
      sealed += 1;
    }
    return sealed;
  }

  private stored(user: UserDoc): StoredUserDoc {
    const { email, displayName, ...rest } = user;
    const id = user._id.toHexString();
    return {
      ...rest,
      emailLookup: this.lookup(email),
      emailSealed: seal(this.keys.seal, Buffer.from(email, 'utf8'), `email/${id}`),
      nameSealed: displayName === null ? null : seal(this.keys.seal, Buffer.from(displayName, 'utf8'), `name/${id}`),
    };
  }

  private opened(doc: StoredUserDoc | null): UserDoc | null {
    if (!doc) return null;
    const { emailLookup: _lookup, emailSealed, nameSealed, email: legacyEmail, displayName: legacyName, ...rest } = doc;
    const id = doc._id.toHexString();
    // Not sealed yet: a start that has not run the seal since the upgrade.
    if (legacyEmail !== undefined) return { ...rest, email: legacyEmail, displayName: legacyName ?? null };
    const email = open(this.keys.seal, emailSealed, `email/${id}`);
    // A KEY_SHARE_KEY other than the one the account was sealed with:
    // nothing can be read, and that is a deployment to fix, not a guess.
    if (!email) throw new Error(`The account ${id} does not open with this KEY_SHARE_KEY`);
    const name = nameSealed ? open(this.keys.seal, nameSealed, `name/${id}`) : null;
    return { ...rest, email: email.toString('utf8'), displayName: name ? name.toString('utf8') : null };
  }

  async markVerified(userId: ObjectId, at: Date): Promise<void> {
    await this.users.updateOne({ _id: userId, verifiedAt: null }, { $set: { verifiedAt: at } });
  }

  async setPassword(userId: ObjectId, passwordHash: string): Promise<void> {
    await this.users.updateOne({ _id: userId }, { $set: { passwordHash } });
  }

  async setDisplayName(userId: ObjectId, displayName: string | null): Promise<UserDoc | null> {
    const nameSealed =
      displayName === null
        ? null
        : seal(this.keys.seal, Buffer.from(displayName, 'utf8'), `name/${userId.toHexString()}`);
    return this.opened(
      await this.users.findOneAndUpdate({ _id: userId }, { $set: { nameSealed } }, { returnDocument: 'after' }),
    );
  }

  async touch(userId: ObjectId, at: Date): Promise<void> {
    await this.users.updateOne({ _id: userId }, { $set: { lastSeenAt: at } });
  }

  /**
   * Stores the account's sealed key share unless it has one; answers
   * the one it has afterwards, which is the first one written when two
   * requests race.
   */
  async setKeyShareOnce(userId: ObjectId, keyShare: SealedBytes): Promise<UserDoc | null> {
    await this.users.updateOne({ _id: userId, keyShare: { $exists: false } }, { $set: { keyShare } });
    return this.findById(userId);
  }

  /**
   * Sets the PIN (its sealed verifier and the key check) unless one is
   * set; answers whether this one is now the account's.
   */
  async setPinOnce(userId: ObjectId, pinVerifier: SealedBytes, keyCheck: KeyCheck): Promise<boolean> {
    const result = await this.users.updateOne(
      { _id: userId, pinVerifier: { $exists: false }, keyShare: { $exists: true } },
      { $set: { pinVerifier, keyCheck } },
    );
    return result.modifiedCount === 1;
  }

  /**
   * Drops the key share, the verifier and the key check, and moves the
   * epoch on: the private tier starts over under a key nobody has yet.
   * Run under the account's lock, so the read and the write agree.
   */
  async clearSyncKey(userId: ObjectId): Promise<number> {
    const user = await this.users.findOne({ _id: userId }, { projection: { keyEpoch: 1 } });
    const epoch = (user?.keyEpoch ?? 1) + 1;
    await this.users.updateOne(
      { _id: userId },
      { $unset: { keyShare: '', keyCheck: '', pinVerifier: '' }, $set: { keyEpoch: epoch } },
    );
    return epoch;
  }

  async delete(userId: ObjectId): Promise<void> {
    await this.users.deleteOne({ _id: userId });
  }
}
