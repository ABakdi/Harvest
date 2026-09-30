import { describe, expect, it } from 'vitest';
import {
  announcementBodySchema,
  heartbeatBodySchema,
  meSchema,
  pushSubscriptionBodySchema,
  streakBandOf,
} from '../src/index.js';

describe('the heartbeat ([[Admin]])', () => {
  it('takes a platform, a version and a streak or none, and nothing else', () => {
    expect(heartbeatBodySchema.safeParse({ platform: 'android', appVersion: '3.3.0', streak: { current: 4, best: 9 } }).success).toBe(true);
    expect(heartbeatBodySchema.safeParse({ platform: 'web', appVersion: '3.3.0', streak: null }).success).toBe(true);
    expect(heartbeatBodySchema.safeParse({ platform: 'ios', appVersion: '3.3.0', streak: null }).success).toBe(false);
    expect(heartbeatBodySchema.safeParse({ platform: 'web', appVersion: '3.3.0', streak: null, email: 'x' }).success).toBe(false);
    expect(heartbeatBodySchema.safeParse({ platform: 'web', appVersion: '3.3.0', streak: { current: -1, best: 0 } }).success).toBe(false);
  });
});

describe('a piece of news', () => {
  const news = { title: 'Harvest 3.3', body: 'Update when you can.', push: true, popup: false };

  it('fills in its defaults', () => {
    expect(announcementBodySchema.parse(news)).toMatchObject({ link: null, audience: 'everyone', startsAt: null, endsAt: null });
  });

  it('must go somewhere, end after it starts, and link only over https', () => {
    expect(announcementBodySchema.safeParse({ ...news, push: false }).success).toBe(false);
    expect(
      announcementBodySchema.safeParse({ ...news, startsAt: '2026-10-02T00:00:00Z', endsAt: '2026-10-01T00:00:00Z' }).success,
    ).toBe(false);
    expect(announcementBodySchema.safeParse({ ...news, link: 'http://example.com' }).success).toBe(false);
    expect(announcementBodySchema.safeParse({ ...news, link: 'javascript:alert(1)' }).success).toBe(false);
    expect(announcementBodySchema.safeParse({ ...news, link: 'https://harvest.abakdi.com/download' }).success).toBe(true);
    expect(announcementBodySchema.safeParse({ ...news, title: 'x'.repeat(81) }).success).toBe(false);
  });
});

describe('web push and the admin flag', () => {
  it('takes an https endpoint and its two keys', () => {
    const keys = { p256dh: 'BNc', auth: 'tBH' };
    expect(pushSubscriptionBodySchema.safeParse({ endpoint: 'https://fcm.googleapis.com/fcm/send/abc', keys }).success).toBe(true);
    expect(pushSubscriptionBodySchema.safeParse({ endpoint: 'http://push.example/abc', keys }).success).toBe(false);
  });

  it('reads a me without the flag as not an admin', () => {
    const me = { id: 'u', email: 'a@b.c', displayName: null, verifiedAt: null, syncSalt: 's', createdAt: '2026-09-29T00:00:00Z' };
    expect(meSchema.parse(me).admin).toBeUndefined();
    expect(meSchema.parse({ ...me, admin: true }).admin).toBe(true);
  });

  it('bands a streak', () => {
    expect([0, 1, 2, 3, 6, 7, 13, 14, 29, 30, 99, 100, 400].map(streakBandOf)).toEqual([
      '0', '1–2', '1–2', '3–6', '3–6', '7–13', '7–13', '14–29', '14–29', '30–99', '30–99', '100+', '100+',
    ]);
  });
});
