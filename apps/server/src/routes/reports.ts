import { adminReportsQuerySchema, reportAttachmentParamsSchema, reportBodySchema, reportPatchSchema, type AdminReport } from '@harvest/contracts';
import { Router } from 'express';
import { z } from 'zod';
import { looksLike } from '../admin/sniff.js';
import type { Repositories } from '../db/index.js';
import type { ReportDoc } from '../db/types.js';
import { HttpError } from '../http/errors.js';
import { validated } from '../http/validate.js';

function toReport(doc: ReportDoc): AdminReport {
  return {
    id: doc._id.toHexString(),
    text: doc.text,
    platform: doc.platform,
    appVersion: doc.appVersion,
    status: doc.status,
    createdAt: doc.createdAt.toISOString(),
    attachments: doc.attachments.map((file) => ({
      id: file._id.toHexString(),
      kind: file.kind,
      type: file.type,
      bytes: file.bytes,
    })),
  };
}

/**
 * `POST /v1/reports` ([[Admin]] F12-5): anonymous by construction. No
 * session is read, even one sent, and nothing of the caller is kept;
 * the limit in front of it counts by network in memory only.
 */
export function reportRoutes(repos: Repositories, now: () => Date = () => new Date()): Router {
  const router = Router();
  router.post(
    '/',
    ...validated({ body: reportBodySchema }, async ({ body }, _req, res) => {
      const files = body.attachments.map((attachment, index) => {
        const bytes = Buffer.from(attachment.data, 'base64');
        if (!looksLike(attachment.type, bytes)) {
          throw new HttpError('validation_failed', `Attachment ${index} is not a ${attachment.type}`);
        }
        return { kind: attachment.kind, type: attachment.type, bytes };
      });
      const id = await repos.reports.create(
        { text: body.text, platform: body.platform, appVersion: body.appVersion, createdAt: now() },
        files,
      );
      res.status(201).json({ id: id.toHexString() });
    }),
  );
  return router;
}

/** The admin's side of the reports. Mounted inside the admin router. */
export function adminReportRoutes(repos: Repositories): Router {
  const router = Router();
  const idParams = z.object({ id: z.string().regex(/^[0-9a-f]{24}$/) });

  router.get(
    '/',
    ...validated({ query: adminReportsQuerySchema }, async ({ query }, _req, res) => {
      const [page, unread] = await Promise.all([repos.reports.page(query.status, query.cursor, query.limit), repos.reports.unread()]);
      res.json({ reports: page.reports.map(toReport), next: page.next, unread });
    }),
  );

  router.patch(
    '/:id',
    ...validated({ params: idParams, body: reportPatchSchema }, async ({ params, body }, _req, res) => {
      const doc = await repos.reports.setStatus(params.id, body.status);
      if (!doc) throw new HttpError('not_found', 'No such report');
      res.json(toReport(doc));
    }),
  );

  router.delete(
    '/:id',
    ...validated({ params: idParams }, async ({ params }, _req, res) => {
      if (!(await repos.reports.delete(params.id))) throw new HttpError('not_found', 'No such report');
      res.status(204).end();
    }),
  );

  router.get(
    '/:id/attachments/:attachment',
    ...validated({ params: reportAttachmentParamsSchema }, async ({ params }, _req, res) => {
      const file = await repos.reports.attachment(params.id, params.attachment);
      if (!file) throw new HttpError('not_found', 'No such attachment');
      // Only ever shown as what it was checked to be, never as a page.
      res.set({
        'Content-Type': file.type,
        'Content-Length': String(file.bytes),
        'Content-Disposition': 'inline',
        'X-Content-Type-Options': 'nosniff',
        'Content-Security-Policy': "default-src 'none'; sandbox",
      });
      file.stream.pipe(res);
    }),
  );

  return router;
}
