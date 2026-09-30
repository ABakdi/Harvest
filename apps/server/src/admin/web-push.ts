import type { Logger } from 'pino';
import webpush from 'web-push';
import { open, seal } from '../auth/seal.js';
import type { PushSubscriptionsRepository, ServerSettingsRepository } from '../db/announcements.js';
import type { AnnouncementDoc, PushSubscriptionDoc } from '../db/types.js';

/** What a browser's service worker gets: enough to show the notification and open it. */
export interface PushPayload {
  id: string;
  title: string;
  body: string;
  link: string | null;
}

/** One delivery to one browser; answers the push service's status. */
export type PushSend = (
  subscription: Pick<PushSubscriptionDoc, 'endpoint' | 'keys'>,
  payload: string,
  vapid: { subject: string; publicKey: string; privateKey: string },
) => Promise<{ statusCode: number }>;

const realSend: PushSend = (subscription, payload, vapid) =>
  webpush.sendNotification(subscription, payload, { vapidDetails: vapid, TTL: 24 * 60 * 60, timeout: 15_000 });

/**
 * Web Push ([[Admin]]): the server's VAPID key pair, made on the first
 * start that needs it and kept with its private half sealed under
 * KEY_SHARE_KEY, and the sending of a piece of news to every subscribed
 * browser through its own push service, encrypted to that browser.
 */
export class WebPush {
  private keys: Promise<{ publicKey: string; privateKey: string }> | null = null;

  constructor(
    private readonly settings: ServerSettingsRepository,
    private readonly subscriptions: PushSubscriptionsRepository,
    private readonly secret: Buffer,
    private readonly subject: string,
    private readonly send: PushSend = realSend,
    private readonly logger?: Logger,
  ) {}

  private loadKeys(): Promise<{ publicKey: string; privateKey: string }> {
    this.keys ??= (async () => {
      let doc = await this.settings.get('vapid');
      if (!doc?.publicKey || !doc.privateKey) {
        const fresh = webpush.generateVAPIDKeys();
        doc = await this.settings.putOnce({
          _id: 'vapid',
          publicKey: fresh.publicKey,
          privateKey: seal(this.secret, Buffer.from(fresh.privateKey, 'utf8'), 'vapid'),
        });
      }
      const privateKey = open(this.secret, doc.privateKey!, 'vapid');
      if (!privateKey) throw new Error('The Web Push key does not open with this KEY_SHARE_KEY');
      return { publicKey: doc.publicKey!, privateKey: privateKey.toString('utf8') };
    })().catch((error: unknown) => {
      this.keys = null;
      throw error;
    });
    return this.keys;
  }

  async publicKey(): Promise<string> {
    return (await this.loadKeys()).publicKey;
  }

  /**
   * Sends [announcement] to every subscribed browser, ten at a time; a
   * subscription its push service calls gone (404, 410) is dropped.
   * Answers how many went through.
   */
  async broadcast(announcement: AnnouncementDoc): Promise<number> {
    const keys = await this.loadKeys();
    const vapid = { subject: this.subject, ...keys };
    const payload = JSON.stringify({
      id: announcement._id.toHexString(),
      title: announcement.title,
      body: announcement.body,
      link: announcement.link,
    } satisfies PushPayload);
    let delivered = 0;
    let batch: Promise<void>[] = [];
    const one = async (subscription: PushSubscriptionDoc) => {
      try {
        const { statusCode } = await this.send(subscription, payload, vapid);
        if (statusCode >= 200 && statusCode < 300) delivered += 1;
      } catch (error) {
        const statusCode = (error as { statusCode?: number }).statusCode;
        if (statusCode === 404 || statusCode === 410) await this.subscriptions.drop(subscription._id);
        else this.logger?.warn({ statusCode }, 'a push did not go');
      }
    };
    for await (const subscription of this.subscriptions.all()) {
      batch.push(one(subscription));
      if (batch.length === 10) {
        await Promise.all(batch);
        batch = [];
      }
    }
    await Promise.all(batch);
    return delivered;
  }
}
