import type { Health } from '@harvest/contracts';
import { Readable } from 'node:stream';
import { pipeline } from 'node:stream/promises';
import { Router, type RequestHandler } from 'express';
import type { Db } from 'mongodb';
import { HttpError } from '../http/errors.js';
import type { ReleaseSource } from '../releases/github.js';

export function publicRoutes(db: Db, releases: ReleaseSource, downloadLimit: RequestHandler): Router {
  const router = Router();

  /** Liveness for the host: the process answers and the database does too. */
  router.get('/health', async (_req, res) => {
    try {
      await db.command({ ping: 1 });
    } catch {
      throw new HttpError('unavailable', 'The database is not answering');
    }
    const body: Health = { status: 'ok' };
    res.json(body);
  });

  router.get('/releases/latest', async (_req, res) => {
    const release = await releases.latest();
    res.setHeader('cache-control', 'public, max-age=300');
    res.json(release);
  });

  /**
   * The APK from the site's own address (B12-05). Linked straight to
   * GitHub, the installed web app opened the download in a custom tab,
   * where the browser's "download anyway?" question for an APK never
   * shows and the download sits finished at 100 %. Only the APKs the
   * download page offers are served.
   */
  router.get('/releases/download/:name', downloadLimit, async (req, res) => {
    const gone = new AbortController();
    res.on('close', () => gone.abort());
    const name = req.params['name'];
    const apk = typeof name === 'string' ? await releases.openApk(name, gone.signal) : null;
    if (!apk) throw new HttpError('not_found', 'No such APK in the current releases');
    res.set({
      'content-type': 'application/vnd.android.package-archive',
      'content-length': String(apk.size),
      'content-disposition': `attachment; filename="${apk.name}"`,
    });
    await pipeline(Readable.fromWeb(apk.body as import('node:stream/web').ReadableStream), res).catch(() => {
      // The phone left, or GitHub stopped halfway: the download fails on
      // the phone, which can start it again.
    });
  });

  return router;
}
