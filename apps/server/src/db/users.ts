import { ObjectId, type Collection } from 'mongodb';
import type { UserDoc } from './types.js';

export class UsersRepository {
  constructor(private readonly users: Collection<UserDoc>) {}

  /** Inserts a new account; throws the driver's duplicate-key error when the email is taken. */
  async create(user: Omit<UserDoc, '_id'>): Promise<UserDoc> {
    const doc: UserDoc = { _id: new ObjectId(), ...user };
    await this.users.insertOne(doc);
    return doc;
  }

  findById(userId: ObjectId): Promise<UserDoc | null> {
    return this.users.findOne({ _id: userId });
  }

  /** The one lookup not by id: sign-in and the emailed flows start from an address. */
  findByEmail(email: string): Promise<UserDoc | null> {
    return this.users.findOne({ email });
  }

  async markVerified(userId: ObjectId, at: Date): Promise<void> {
    await this.users.updateOne({ _id: userId, verifiedAt: null }, { $set: { verifiedAt: at } });
  }

  async setPassword(userId: ObjectId, passwordHash: string): Promise<void> {
    await this.users.updateOne({ _id: userId }, { $set: { passwordHash } });
  }

  async setDisplayName(userId: ObjectId, displayName: string | null): Promise<UserDoc | null> {
    return this.users.findOneAndUpdate(
      { _id: userId },
      { $set: { displayName } },
      { returnDocument: 'after' },
    );
  }

  async touch(userId: ObjectId, at: Date): Promise<void> {
    await this.users.updateOne({ _id: userId }, { $set: { lastSeenAt: at } });
  }

  async delete(userId: ObjectId): Promise<void> {
    await this.users.deleteOne({ _id: userId });
  }
}
