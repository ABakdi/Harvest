import {
  adminHistorySchema,
  adminOverviewSchema,
  adminUsersSchema,
  announcementsResultSchema,
  type Announcement,
} from '@harvest/contracts';
import { ObjectId } from 'mongodb';
import request from 'supertest';
import { afterEach, describe, expect, it } from 'vitest';
import type { PushSend } from '../src/admin/web-push.js';
import { bearer, expectError, harness, password, signUp, type Account, type Harness } from './harness.js';

const admin = 'boss@example.com';
let h: Harness;
afterEach(async () => {
  // The downloads test needs no server.
  await h?.close();
  h = undefined as unknown as Harness;
});

async function withAdmin(options: Parameters<typeof harness>[0] = {}) {
  h = await harness({ ...options, env: { ADMIN_EMAILS: ` ${admin.toUpperCase()} , other@example.com`, ...options.env } });
  const boss = await signUp(h, { email: admin });
  return boss;
}

const beat = (account: Account, body: object) =>
  request(h.app).post('/v1/me/heartbeat').set(bearer(account)).send(body);
const get = (account: Account, path: string) => request(h.app).get(`/v1/admin${path}`).set(bearer(account));
const news = (account: Account, body: object) =>
  request(h.app).post('/v1/admin/announcements').set(bearer(account)).send(body);

describe('who is an admin (Admin AD6)', () => {
  it('says so on me, for the emails the environment names, whatever their case', async () => {
    const boss = await withAdmin();
    const someone = await signUp(h);
    expect((await request(h.app).get('/v1/me').set(bearer(boss)).expect(200)).body).toMatchObject({ admin: true });
    expect((await request(h.app).get('/v1/me').set(bearer(someone)).expect(200)).body).toMatchObject({ admin: false });
  });

  it('answers anyone else as if the admin routes did not exist', async () => {
    await withAdmin();
    const someone = await signUp(h);
    for (const path of ['/overview', '/history', '/users', '/announcements']) {
      expectError(await get(someone, path), 404, 'not_found');
      expectError(await request(h.app).get(`/v1/admin${path}`), 401, 'unauthorized');
    }
    expectError(await news(someone, { title: 'x', body: 'y', push: true, popup: false }), 404, 'not_found');
  });
});

describe('the heartbeat and the numbers (Admin)', () => {
  it('keeps the latest of each, counts the first of a day once, and shows it all', async () => {
    const boss = await withAdmin();
    const phone = await signUp(h);
    const quiet = await signUp(h, { verify: false });
    await beat(phone, { platform: 'android', appVersion: '3.3.0', streak: { current: 12, best: 30 } }).expect(204);
    await beat(phone, { platform: 'android', appVersion: '3.3.0', streak: { current: 12, best: 30 } }).expect(204);
    await beat(boss, { platform: 'web', appVersion: '3.3.0', streak: null }).expect(204);
    expectError(await beat(phone, { platform: 'android', appVersion: '3.3.0', streak: null, where: 'x' }), 400, 'validation_failed');

    const overview = adminOverviewSchema.parse((await get(boss, '/overview').expect(200)).body);
    expect(overview.accounts).toMatchObject({ total: 3, verified: 2, newToday: 3 });
    expect(overview.active).toEqual({ today: 2, week: 2, month: 2 });
    expect(overview.streaks).toMatchObject({ sharing: 1, median: 12, mean: 12, longest: 12 });
    expect(overview.streaks.bands.find((b) => b.band === '7–13')?.accounts).toBe(1);
    expect(overview.platforms).toEqual(
      expect.arrayContaining([
        { platform: 'android', accounts: 1 },
        { platform: 'web', accounts: 1 },
      ]),
    );
    expect(overview.versions).toEqual([{ version: '3.3.0', accounts: 2 }]);
    // No GitHub in tests: downloads say so rather than lie.
    expect(overview.downloads).toBeNull();

    // The day's totals: counted once per account, whatever the beats.
    const day = await h.db.collection('daily_stats').findOne({});
    expect(day).toMatchObject({ active: 2 });

    const users = adminUsersSchema.parse((await get(boss, '/users').expect(200)).body);
    expect(users.users.map((u) => u.email)).toEqual([quiet.email, phone.email, admin]);
    expect(users.users[1]).toMatchObject({ platform: 'android', appVersion: '3.3.0', streak: { current: 12, best: 30 } });
    expect(users.users[0]).toMatchObject({ lastActiveAt: null, streak: null, verifiedAt: null });
    // A streak no longer shared is gone, not kept.
    await beat(phone, { platform: 'android', appVersion: '3.3.1', streak: null }).expect(204);
    const again = adminUsersSchema.parse((await get(boss, `/users?q=${encodeURIComponent(phone.email.slice(0, 8))}`).expect(200)).body);
    expect(again.users).toHaveLength(1);
    expect(again.users[0]).toMatchObject({ appVersion: '3.3.1', streak: null });
  });

  it('pages the users by a cursor', async () => {
    const boss = await withAdmin();
    for (let i = 0; i < 4; i += 1) await signUp(h);
    const first = adminUsersSchema.parse((await get(boss, '/users?limit=2').expect(200)).body);
    expect(first.users).toHaveLength(2);
    expect(first.next).not.toBeNull();
    const second = adminUsersSchema.parse((await get(boss, `/users?limit=2&cursor=${first.next}`).expect(200)).body);
    const third = adminUsersSchema.parse((await get(boss, `/users?limit=2&cursor=${second.next}`).expect(200)).body);
    const all = [...first.users, ...second.users, ...third.users].map((u) => u.id);
    expect(new Set(all).size).toBe(5);
    expect(third.next).toBeNull();
  });

  it('writes a day of totals, and hands the days back without inventing the missing ones', async () => {
    let clock = new Date('2026-09-29T10:00:00Z').getTime();
    const boss = await withAdmin({ now: () => new Date(clock) });
    await h.repos.adminStats.snapshot(new Date(clock));
    clock += 3 * 24 * 60 * 60_000;
    await h.repos.adminStats.snapshot(new Date(clock));
    const history = adminHistorySchema.parse((await get(boss, '/history?days=30').expect(200)).body);
    expect(history.days.map((d) => d.day)).toEqual(['2026-09-29', '2026-10-02']);
    expect(history.days[0]).toMatchObject({ accounts: 1, verified: 1, signups: 1 });
    expectError(await get(boss, '/history?days=0'), 400, 'validation_failed');
  });

  it('forgets an account whole, its push subscriptions too', async () => {
    await withAdmin();
    const someone = await signUp(h);
    await request(h.app)
      .post('/v1/me/push-subscription')
      .set(bearer(someone))
      .send({ endpoint: 'https://push.example/a', keys: { p256dh: 'p', auth: 'a' } })
      .expect(204);
    await request(h.app).delete('/v1/me').set(bearer(someone)).send({ password }).expect(204);
    expect(await h.db.collection('push_subscriptions').countDocuments({ userId: new ObjectId(someone.userId) })).toBe(0);
  });
});

describe('the news (Admin)', () => {
  it('is made, listed, ended and deleted by the admin', async () => {
    const boss = await withAdmin();
    expectError(await news(boss, { title: 'x', body: 'y', push: false, popup: false }), 400, 'validation_failed');
    const made = (await news(boss, { title: 'Harvest 3.3', body: 'Update\nwhen you can.', link: 'https://harvest.abakdi.com/download', push: false, popup: true }).expect(201))
      .body as Announcement;
    expect(made).toMatchObject({ audience: 'everyone', popup: true, endsAt: null });

    const listed = (await get(boss, '/announcements').expect(200)).body as { announcements: (Announcement & { pushed: number })[] };
    expect(listed.announcements).toEqual([expect.objectContaining({ id: made.id, pushed: 0 })]);

    const ended = await request(h.app)
      .patch(`/v1/admin/announcements/${made.id}`)
      .set(bearer(boss))
      .send({ endsAt: new Date(Date.now() - 1000).toISOString() })
      .expect(200);
    expect((ended.body as Announcement).endsAt).not.toBeNull();
    expect(announcementsResultSchema.parse((await request(h.app).get('/v1/announcements').expect(200)).body).announcements).toEqual([]);

    await request(h.app).delete(`/v1/admin/announcements/${made.id}`).set(bearer(boss)).expect(204);
    expectError(await request(h.app).delete(`/v1/admin/announcements/${made.id}`).set(bearer(boss)), 404, 'not_found');
  });

  it('shows everyone the news for everyone, and account holders theirs too, when it is live', async () => {
    const boss = await withAdmin();
    const someone = await signUp(h);
    await news(boss, { title: 'For all', body: 'a', push: false, popup: true }).expect(201);
    await news(boss, { title: 'For accounts', body: 'b', push: false, popup: true, audience: 'accounts' }).expect(201);
    await news(boss, { title: 'Later', body: 'c', push: false, popup: true, startsAt: new Date(Date.now() + 86_400_000).toISOString() }).expect(201);

    const anonymous = announcementsResultSchema.parse((await request(h.app).get('/v1/announcements').expect(200)).body);
    expect(anonymous.announcements.map((a) => a.title)).toEqual(['For all']);
    const signedIn = announcementsResultSchema.parse((await request(h.app).get('/v1/announcements').set(bearer(someone)).expect(200)).body);
    expect(signedIn.announcements.map((a) => a.title).sort()).toEqual(['For accounts', 'For all']);
    // A stale token is no session, not an error: the news for everyone.
    const stale = await request(h.app).get('/v1/announcements').set({ Authorization: 'Bearer not-a-token' }).expect(200);
    expect(announcementsResultSchema.parse(stale.body).announcements.map((a) => a.title)).toEqual(['For all']);
  });

  it('pushes to every subscribed browser, drops the gone ones, and counts what went', async () => {
    const sent: string[] = [];
    const pushSend: PushSend = (subscription, payload) => {
      sent.push(`${subscription.endpoint} ${payload}`);
      if (subscription.endpoint.endsWith('/gone')) return Promise.reject(Object.assign(new Error('gone'), { statusCode: 410 }));
      return Promise.resolve({ statusCode: 201 });
    };
    const boss = await withAdmin({ pushSend });
    const key = (await request(h.app).get('/v1/push/key').expect(200)).body as { publicKey: string };
    expect(key.publicKey).toMatch(/^[A-Za-z0-9_-]{80,}$/);
    // Made once and kept: the same key on the next ask.
    expect(((await request(h.app).get('/v1/push/key').expect(200)).body as { publicKey: string }).publicKey).toBe(key.publicKey);
    const stored = await h.db.collection('server_settings').findOne({ _id: 'vapid' as never });
    expect(JSON.stringify(stored)).not.toContain('"privateKey":"');

    for (const endpoint of ['https://push.example/a', 'https://push.example/gone']) {
      await request(h.app)
        .post('/v1/me/push-subscription')
        .set(bearer(boss))
        .send({ endpoint, keys: { p256dh: 'p', auth: 'a' } })
        .expect(204);
    }
    const made = (await news(boss, { title: 'Now', body: 'Update', push: true, popup: false }).expect(201)).body as Announcement;
    await h.settled();
    expect(sent).toHaveLength(2);
    expect(JSON.parse(sent[0]!.split(' ').slice(1).join(' '))).toEqual({ id: made.id, title: 'Now', body: 'Update', link: null });
    expect(await h.db.collection('push_subscriptions').countDocuments({})).toBe(1);
    const listed = (await get(boss, '/announcements').expect(200)).body as { announcements: { pushed: number }[] };
    expect(listed.announcements[0]!.pushed).toBe(1);

    // Unsubscribed, a browser gets nothing more.
    await request(h.app).delete('/v1/me/push-subscription').set(bearer(boss)).send({ endpoint: 'https://push.example/a' }).expect(204);
    expect(await h.db.collection('push_subscriptions').countDocuments({})).toBe(0);
  });
});

describe('downloads (Admin AD2)', () => {
  it('counts every release’s APK downloads, from GitHub’s own figure, and keeps the last count when GitHub is away', async () => {
    const { ReleaseSource } = await import('../src/releases/github.js');
    let up = true;
    const asset = (name: string, count: number) => ({ name, browser_download_url: `https://x/${name}`, size: 1, download_count: count });
    const fetch = (() =>
      up
        ? Promise.resolve(
            Response.json([
              { tag_name: 'v3.2.0', name: 'Harvest 3.2.0', published_at: '2026-09-29T01:00:00Z', html_url: 'h', assets: [asset('harvest-3.2.0.apk', 40), asset('notes.txt', 999)] },
              { tag_name: 'v3.1.0-beta.4', name: null, published_at: '2026-09-28T01:00:00Z', html_url: 'h', prerelease: true, assets: [asset('harvest.apk', 2)] },
              { tag_name: 'draft', html_url: 'h', draft: true, assets: [asset('d.apk', 5)] },
            ]),
          )
        : Promise.reject(new Error('down'))) as typeof globalThis.fetch;
    let clock = 0;
    const source = new ReleaseSource({ repo: 'ABakdi/Harvest', fetch, now: () => clock });
    const counted = await source.downloads();
    expect(counted).toEqual({
      total: 42,
      releases: [
        { tag: 'v3.2.0', name: 'Harvest 3.2.0', publishedAt: '2026-09-29T01:00:00Z', downloads: 40 },
        { tag: 'v3.1.0-beta.4', name: 'v3.1.0-beta.4', publishedAt: '2026-09-28T01:00:00Z', downloads: 2 },
      ],
    });
    up = false;
    clock += 60 * 60_000;
    expect(await source.downloads()).toEqual(counted);
    expect(await new ReleaseSource({ repo: 'a/b', fetch }).downloads()).toBeNull();
  });
});
