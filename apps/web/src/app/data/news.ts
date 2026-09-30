import type { Announcement, HeartbeatBody, PushSubscriptionBody } from '@harvest/contracts';
import {
  getNewsPrefs,
  heartbeatDay,
  pushEndpoint,
  seenNews,
  setHeartbeatDay,
  setPushEndpoint,
} from '@/lib/news-prefs';
import type { HarvestDB } from './db';

/**
 * The web's side of [[Admin]]: the once-a-day heartbeat, the pop-ups
 * still to show, and Web Push. Nothing here reads a row but the global
 * streak, and that only while *Share my streak* is on.
 */

/** The version this build is, the phone's own number for the same release. */
export const appVersion: string = typeof __HARVEST_VERSION__ === 'string' ? __HARVEST_VERSION__ : '0.0.0';

/** The calendar day of [now] in this browser's own zone, `yyyy-MM-dd`. */
export function localDay(now: Date): string {
  const pad = (n: number) => String(n).padStart(2, '0');
  return `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())}`;
}

export interface HeartbeatApi {
  heartbeat(body: HeartbeatBody): Promise<void>;
}

/**
 * Says hello once a day from this browser: its platform, its version,
 * and the global streak while it is shared. A day already said is
 * skipped; a failure is silent, and the next opening tries again.
 * True when one went.
 */
export async function sendHeartbeat(db: HarvestDB, api: HeartbeatApi, now: Date = new Date()): Promise<boolean> {
  const today = localDay(now);
  if (heartbeatDay() === today) return false;
  let streak: HeartbeatBody['streak'] = null;
  if (getNewsPrefs().shareStreak) {
    const row = await db.rows('streaks').get('global');
    streak = { current: Math.max(0, row?.current ?? 0), best: Math.max(0, row?.best ?? 0) };
  }
  try {
    await api.heartbeat({ platform: 'web', appVersion, streak });
  } catch {
    return false;
  }
  setHeartbeatDay(today);
  return true;
}

/**
 * The pop-ups to show now, newest first: live, a pop-up, and not shown
 * on this browser before.
 */
export function popupsToShow(announcements: readonly Announcement[], seen: Set<string> = seenNews(), now: Date = new Date()): Announcement[] {
  const at = now.getTime();
  return announcements
    .filter(
      (news) =>
        news.popup &&
        !seen.has(news.id) &&
        Date.parse(news.startsAt) <= at &&
        (news.endsAt === null || Date.parse(news.endsAt) > at),
    )
    .sort((a, b) => Date.parse(b.startsAt) - Date.parse(a.startsAt));
}

// -------------------------------------------------------------- web push

export interface PushApi {
  pushKey(): Promise<string | null>;
  subscribePush(body: PushSubscriptionBody): Promise<void>;
  unsubscribePush(endpoint: string): Promise<void>;
}

export type PushStatus = 'on' | 'off' | 'denied' | 'unsupported';

/** Whether this browser can take a push at all: a service worker, the Push API, notifications. */
export function pushSupported(): boolean {
  return (
    typeof navigator !== 'undefined' &&
    'serviceWorker' in navigator &&
    typeof window !== 'undefined' &&
    'PushManager' in window &&
    'Notification' in window
  );
}

/** The app's service worker, when one is registered; never waits for one that is not. */
async function registration(): Promise<ServiceWorkerRegistration | null> {
  if (!pushSupported()) return null;
  return (await navigator.serviceWorker.getRegistration()) ?? null;
}

export async function pushStatus(): Promise<PushStatus> {
  const worker = await registration();
  if (!worker) return 'unsupported';
  if (Notification.permission === 'denied') return 'denied';
  return (await worker.pushManager.getSubscription()) ? 'on' : 'off';
}

/** A VAPID key, base64url, as the Push API takes it. */
export function keyBytes(base64url: string): Uint8Array<ArrayBuffer> {
  const base64 = base64url.replace(/-/g, '+').replace(/_/g, '/').padEnd(Math.ceil(base64url.length / 4) * 4, '=');
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes;
}

/**
 * Turns push on in this browser: the server's key, the browser's own
 * permission prompt (only ever from a tap), a subscription, and the
 * server told. What it came to, as a [PushStatus].
 */
export async function enablePush(api: PushApi): Promise<PushStatus> {
  const worker = await registration();
  if (!worker) return 'unsupported';
  const key = await api.pushKey();
  if (!key) return 'unsupported';
  const permission = await Notification.requestPermission();
  if (permission !== 'granted') return permission === 'denied' ? 'denied' : 'off';
  const subscription =
    (await worker.pushManager.getSubscription()) ??
    (await worker.pushManager.subscribe({ userVisibleOnly: true, applicationServerKey: keyBytes(key) }));
  const json = subscription.toJSON();
  const endpoint = json.endpoint ?? subscription.endpoint;
  const p256dh = json.keys?.p256dh;
  const auth = json.keys?.auth;
  if (!endpoint || !p256dh || !auth) {
    await subscription.unsubscribe();
    return 'unsupported';
  }
  await api.subscribePush({ endpoint, keys: { p256dh, auth } });
  setPushEndpoint(endpoint);
  return 'on';
}

/**
 * Turns push off in this browser: the subscription goes, and the server
 * is told, as far as it can be. Signing out and turning the news off
 * both come here; neither waits on the server.
 */
export async function disablePush(api: PushApi): Promise<void> {
  const worker = await registration().catch(() => null);
  const subscription = worker ? await worker.pushManager.getSubscription().catch(() => null) : null;
  const endpoint = subscription?.endpoint ?? pushEndpoint();
  if (subscription) await subscription.unsubscribe().catch(() => false);
  setPushEndpoint(null);
  if (endpoint) await api.unsubscribePush(endpoint).catch(() => undefined);
}
