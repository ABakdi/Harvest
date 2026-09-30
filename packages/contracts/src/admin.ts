import { z } from 'zod';

/**
 * The admin panel and the news ([[Admin]], Checkpoint 12): what a
 * signed-in device tells the server once a day, the news it fetches,
 * and what the admin routes answer. No route here reads a user's rows.
 */

const isoInstant = z.iso.datetime();
const day = z.string().regex(/^\d{4}-\d{2}-\d{2}$/, { message: 'Not a day (yyyy-MM-dd)' });

// ------------------------------------------------------------- heartbeat

export const platforms = ['android', 'web'] as const;
export const platformSchema = z.enum(platforms);
export type Platform = z.infer<typeof platformSchema>;

/**
 * `POST /v1/me/heartbeat`: a signed-in device, at most once a day. The
 * streak only while the device's *Share my streak* is on; null otherwise.
 * 204.
 */
export const heartbeatBodySchema = z.strictObject({
  platform: platformSchema,
  appVersion: z.string().trim().min(1).max(40),
  streak: z
    .strictObject({
      current: z.int().min(0).max(100_000),
      best: z.int().min(0).max(100_000),
    })
    .nullable(),
});
export type HeartbeatBody = z.infer<typeof heartbeatBodySchema>;

// ------------------------------------------------------------------ news

export const announcementAudiences = ['everyone', 'accounts'] as const;

export const announcementTitleMax = 80;
export const announcementBodyMax = 1000;

const httpsLink = z
  .string()
  .trim()
  .max(500)
  .refine((value) => {
    try {
      return new URL(value).protocol === 'https:';
    } catch {
      return false;
    }
  }, { message: 'An https:// address' });

/** A piece of news, as every client reads it. */
export const announcementSchema = z.object({
  id: z.string(),
  title: z.string(),
  body: z.string(),
  link: z.string().nullable(),
  /** Sent as a notification. */
  push: z.boolean(),
  /** Shown once in a dialog when the app opens. */
  popup: z.boolean(),
  audience: z.enum(announcementAudiences),
  startsAt: isoInstant,
  endsAt: isoInstant.nullable(),
  createdAt: isoInstant,
});
export type Announcement = z.infer<typeof announcementSchema>;

/**
 * `GET /v1/announcements`: the news live now. Without a session, the
 * news for everyone; with one, the news for account holders too.
 */
export const announcementsResultSchema = z.object({
  announcements: z.array(announcementSchema),
});
export type AnnouncementsResult = z.infer<typeof announcementsResultSchema>;

/** `POST /v1/admin/announcements`. */
export const announcementBodySchema = z
  .strictObject({
    title: z.string().trim().min(1).max(announcementTitleMax),
    body: z.string().trim().min(1).max(announcementBodyMax),
    link: httpsLink.nullable().default(null),
    push: z.boolean(),
    popup: z.boolean(),
    audience: z.enum(announcementAudiences).default('everyone'),
    startsAt: isoInstant.nullable().default(null),
    endsAt: isoInstant.nullable().default(null),
  })
  .refine((body) => body.push || body.popup, { message: 'Push, pop-up or both', path: ['push'] })
  .refine((body) => !body.startsAt || !body.endsAt || body.startsAt < body.endsAt, {
    message: 'It ends before it starts',
    path: ['endsAt'],
  });
export type AnnouncementBody = z.input<typeof announcementBodySchema>;

/** `PATCH /v1/admin/announcements/:id`: end it now, or move its end. */
export const announcementPatchSchema = z.strictObject({
  endsAt: isoInstant.nullable(),
});

export const announcementParamsSchema = z.object({
  id: z.string().regex(/^[0-9a-f]{24}$/, { message: 'Not an id' }),
});

/** `GET /v1/admin/announcements`: every piece of news, live or not, newest first. */
export const adminAnnouncementsResultSchema = z.object({
  announcements: z.array(
    announcementSchema.extend({
      /** Web Push deliveries made when it was created. */
      pushed: z.int().nonnegative(),
    }),
  ),
});

// --------------------------------------------------------------- web push

/** `GET /v1/push/key`: the server's VAPID public key, base64url. */
export const pushKeyResultSchema = z.object({ publicKey: z.string() });

/** `POST /v1/me/push-subscription`, `DELETE /v1/me/push-subscription` (endpoint only). */
export const pushSubscriptionBodySchema = z.strictObject({
  endpoint: z.url().max(1000).refine((value) => value.startsWith('https://'), { message: 'An https:// endpoint' }),
  keys: z.strictObject({
    p256dh: z.string().min(1).max(200),
    auth: z.string().min(1).max(100),
  }),
});
export type PushSubscriptionBody = z.infer<typeof pushSubscriptionBodySchema>;
export const pushUnsubscribeBodySchema = z.strictObject({ endpoint: z.string().max(1000) });

// ---------------------------------------------------------------- admin

export const streakBands = ['0', '1–2', '3–6', '7–13', '14–29', '30–99', '100+'] as const;

/** `GET /v1/admin/overview`. */
export const adminOverviewSchema = z.object({
  accounts: z.object({
    total: z.int(),
    verified: z.int(),
    newToday: z.int(),
    newWeek: z.int(),
    newMonth: z.int(),
  }),
  active: z.object({ today: z.int(), week: z.int(), month: z.int() }),
  streaks: z.object({
    sharing: z.int(),
    median: z.number(),
    mean: z.number(),
    longest: z.int(),
    bands: z.array(z.object({ band: z.enum(streakBands), accounts: z.int() })),
  }),
  platforms: z.array(z.object({ platform: z.string(), accounts: z.int() })),
  versions: z.array(z.object({ version: z.string(), accounts: z.int() })),
  /** Null when GitHub could not be asked. */
  downloads: z
    .object({
      total: z.int(),
      releases: z.array(
        z.object({ tag: z.string(), name: z.string(), publishedAt: isoInstant, downloads: z.int() }),
      ),
    })
    .nullable(),
  generatedAt: isoInstant,
});
export type AdminOverview = z.infer<typeof adminOverviewSchema>;

/** `GET /v1/admin/history?days=30|90|365`. */
export const adminHistoryQuerySchema = z.object({
  days: z.coerce.number().int().min(1).max(730).default(90),
});
export const dailyStatsSchema = z.object({
  day,
  accounts: z.int(),
  verified: z.int(),
  signups: z.int(),
  active: z.int(),
  active7: z.int(),
  active30: z.int(),
  sharing: z.int(),
  streakMedian: z.number(),
  streakMean: z.number(),
});
export type DailyStats = z.infer<typeof dailyStatsSchema>;
export const adminHistorySchema = z.object({ days: z.array(dailyStatsSchema) });
export type AdminHistory = z.infer<typeof adminHistorySchema>;

/** `GET /v1/admin/users?q=&cursor=&limit=`. */
export const adminUsersQuerySchema = z.object({
  q: z.string().trim().max(200).optional(),
  /** The last id of the page before. */
  cursor: z.string().regex(/^[0-9a-f]{24}$/).optional(),
  limit: z.coerce.number().int().min(1).max(100).default(50),
});
export const adminUserSchema = z.object({
  id: z.string(),
  email: z.string(),
  displayName: z.string().nullable(),
  createdAt: isoInstant,
  verifiedAt: isoInstant.nullable(),
  lastActiveAt: isoInstant.nullable(),
  platform: z.string().nullable(),
  appVersion: z.string().nullable(),
  /** Null when it was never shared, or is not any more. */
  streak: z.object({ current: z.int(), best: z.int() }).nullable(),
});
export type AdminUser = z.infer<typeof adminUserSchema>;
export const adminUsersSchema = z.object({
  users: z.array(adminUserSchema),
  next: z.string().nullable(),
});
export type AdminUsers = z.infer<typeof adminUsersSchema>;

/** The band a current streak of [days] falls in. */
export function streakBandOf(days: number): (typeof streakBands)[number] {
  if (days <= 0) return '0';
  if (days <= 2) return '1–2';
  if (days <= 6) return '3–6';
  if (days <= 13) return '7–13';
  if (days <= 29) return '14–29';
  if (days <= 99) return '30–99';
  return '100+';
}

// --------------------------------------------------------------- reports

/**
 * *Report a problem* ([[Admin]], F12-5): anonymous, read by the admin.
 * The attachments travel as base64 in the one body; their bytes are
 * checked by the server against their type.
 */
export const reportTextMax = 5000;
export const reportImagesMax = 4;
/** One picture, already re-encoded on the device (no metadata). */
export const reportImageMaxBytes = 5 * 1024 * 1024;
/** The one recording: a few minutes of speech. */
export const reportAudioMaxBytes = 10 * 1024 * 1024;
/** Everything a report may carry, decoded. */
export const reportMaxBytes = 21 * 1024 * 1024;

export const reportImageTypes = ['image/jpeg', 'image/png', 'image/webp'] as const;
export const reportAudioTypes = ['audio/mp4', 'audio/aac', 'audio/webm', 'audio/ogg', 'audio/mpeg', 'audio/wav'] as const;

const base64Data = z.base64({ message: 'Not base64' });

export const reportAttachmentSchema = z.discriminatedUnion('kind', [
  z.strictObject({ kind: z.literal('image'), type: z.enum(reportImageTypes), data: base64Data }),
  z.strictObject({ kind: z.literal('audio'), type: z.enum(reportAudioTypes), data: base64Data }),
]);
export type ReportAttachment = z.infer<typeof reportAttachmentSchema>;

/** How many bytes a base64 string decodes to. */
export function base64Bytes(value: string): number {
  const padding = value.endsWith('==') ? 2 : value.endsWith('=') ? 1 : 0;
  return Math.floor((value.length * 3) / 4) - padding;
}

/** `POST /v1/reports`: no session read, no address kept. 201 `{id}`. */
export const reportBodySchema = z
  .strictObject({
    text: z.string().trim().min(1).max(reportTextMax),
    platform: platformSchema,
    appVersion: z.string().trim().min(1).max(40),
    attachments: z.array(reportAttachmentSchema).max(reportImagesMax + 1).default([]),
  })
  .superRefine((body, ctx) => {
    const images = body.attachments.filter((a) => a.kind === 'image');
    const audio = body.attachments.filter((a) => a.kind === 'audio');
    if (images.length > reportImagesMax) {
      ctx.addIssue({ code: 'custom', path: ['attachments'], message: `At most ${reportImagesMax} pictures` });
    }
    if (audio.length > 1) ctx.addIssue({ code: 'custom', path: ['attachments'], message: 'At most one recording' });
    let total = 0;
    for (const [index, attachment] of body.attachments.entries()) {
      const bytes = base64Bytes(attachment.data);
      total += bytes;
      const max = attachment.kind === 'image' ? reportImageMaxBytes : reportAudioMaxBytes;
      if (bytes === 0 || bytes > max) {
        ctx.addIssue({ code: 'custom', path: ['attachments', index, 'data'], message: 'Empty or too large' });
      }
    }
    if (total > reportMaxBytes) ctx.addIssue({ code: 'custom', path: ['attachments'], message: 'Too large all told' });
  });
export type ReportBody = z.input<typeof reportBodySchema>;

export const reportStatuses = ['new', 'read', 'done'] as const;

/** A report as the admin reads it. */
export const adminReportSchema = z.object({
  id: z.string(),
  text: z.string(),
  platform: z.string(),
  appVersion: z.string(),
  status: z.enum(reportStatuses),
  createdAt: isoInstant,
  attachments: z.array(
    z.object({ id: z.string(), kind: z.enum(['image', 'audio']), type: z.string(), bytes: z.int() }),
  ),
});
export type AdminReport = z.infer<typeof adminReportSchema>;

/** `GET /v1/admin/reports?status=&cursor=&limit=`. */
export const adminReportsQuerySchema = z.object({
  status: z.enum(reportStatuses).optional(),
  cursor: z.string().regex(/^[0-9a-f]{24}$/).optional(),
  limit: z.coerce.number().int().min(1).max(100).default(30),
});
export const adminReportsSchema = z.object({
  reports: z.array(adminReportSchema),
  next: z.string().nullable(),
  /** How many are still new, whatever the page. */
  unread: z.int(),
});
export type AdminReports = z.infer<typeof adminReportsSchema>;

/** `PATCH /v1/admin/reports/:id`. */
export const reportPatchSchema = z.strictObject({ status: z.enum(reportStatuses) });
/** `GET /v1/admin/reports/:id/attachments/:attachment` answers the bytes, with their type. */
export const reportAttachmentParamsSchema = z.object({
  id: z.string().regex(/^[0-9a-f]{24}$/),
  attachment: z.string().regex(/^[0-9a-f]{24}$/),
});
