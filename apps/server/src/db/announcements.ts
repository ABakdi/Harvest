import type { Announcement } from '@harvest/contracts';
import { ObjectId, type Collection } from 'mongodb';
import type { AnnouncementDoc, PushSubscriptionDoc, ServerSettingDoc } from './types.js';

export function toAnnouncement(doc: AnnouncementDoc): Announcement {
  return {
    id: doc._id.toHexString(),
    title: doc.title,
    body: doc.body,
    link: doc.link,
    push: doc.push,
    popup: doc.popup,
    audience: doc.audience,
    startsAt: doc.startsAt.toISOString(),
    endsAt: doc.endsAt?.toISOString() ?? null,
    createdAt: doc.createdAt.toISOString(),
  };
}

/** The news ([[Admin]]). */
export class AnnouncementsRepository {
  constructor(private readonly announcements: Collection<AnnouncementDoc>) {}

  async create(doc: Omit<AnnouncementDoc, '_id' | 'pushed'>): Promise<AnnouncementDoc> {
    const created: AnnouncementDoc = { _id: new ObjectId(), ...doc, pushed: 0 };
    await this.announcements.insertOne(created);
    return created;
  }

  /** Every piece, live or not, newest first; a few hundred at most in practice. */
  all(): Promise<AnnouncementDoc[]> {
    return this.announcements.find().sort({ _id: -1 }).limit(500).toArray();
  }

  /** What is live at [now]: for everyone, and for account holders too when [accounts]. */
  live(now: Date, accounts: boolean): Promise<AnnouncementDoc[]> {
    return this.announcements
      .find({
        startsAt: { $lte: now },
        $or: [{ endsAt: null }, { endsAt: { $gt: now } }],
        ...(accounts ? {} : { audience: 'everyone' }),
      })
      .sort({ startsAt: -1 })
      .limit(20)
      .toArray();
  }

  get(id: string): Promise<AnnouncementDoc | null> {
    return this.announcements.findOne({ _id: new ObjectId(id) });
  }

  async setEnd(id: string, endsAt: Date | null): Promise<AnnouncementDoc | null> {
    return this.announcements.findOneAndUpdate({ _id: new ObjectId(id) }, { $set: { endsAt } }, { returnDocument: 'after' });
  }

  async delete(id: string): Promise<boolean> {
    return (await this.announcements.deleteOne({ _id: new ObjectId(id) })).deletedCount === 1;
  }

  async countPushed(id: ObjectId, delivered: number): Promise<void> {
    await this.announcements.updateOne({ _id: id }, { $inc: { pushed: delivered } });
  }
}

/** Browsers' Web Push subscriptions, one per endpoint, each an account's. */
export class PushSubscriptionsRepository {
  constructor(private readonly subscriptions: Collection<PushSubscriptionDoc>) {}

  /** Keeps [endpoint] for [userId]; a browser that subscribed under another account moves to this one. */
  async save(userId: ObjectId, endpoint: string, keys: PushSubscriptionDoc['keys'], at: Date): Promise<void> {
    await this.subscriptions.updateOne(
      { endpoint },
      { $set: { userId, keys }, $setOnInsert: { _id: new ObjectId(), endpoint, createdAt: at } },
      { upsert: true },
    );
  }

  async remove(userId: ObjectId, endpoint: string): Promise<void> {
    await this.subscriptions.deleteOne({ userId, endpoint });
  }

  /** One the push service said is gone. */
  async drop(id: ObjectId): Promise<void> {
    await this.subscriptions.deleteOne({ _id: id });
  }

  async deleteAllFor(userId: ObjectId): Promise<void> {
    await this.subscriptions.deleteMany({ userId });
  }

  /** Every subscription, a batch at a time. */
  all(): AsyncIterable<PushSubscriptionDoc> {
    return this.subscriptions.find().batchSize(200);
  }
}

/** The server's own named settings: the Web Push key pair. */
export class ServerSettingsRepository {
  constructor(private readonly settings: Collection<ServerSettingDoc>) {}

  get(name: string): Promise<ServerSettingDoc | null> {
    return this.settings.findOne({ _id: name });
  }

  /** Stores [doc] unless one is there; answers the one kept, the first when two starts race. */
  async putOnce(doc: ServerSettingDoc): Promise<ServerSettingDoc> {
    await this.settings.updateOne({ _id: doc._id }, { $setOnInsert: doc }, { upsert: true });
    return (await this.get(doc._id))!;
  }
}
