import { assistDoneMarker, assistRequestSchema } from '@harvest/contracts';
import { Router } from 'express';
import type { GeminiUpstream } from '../assist/gemini.js';
import { authOf } from '../http/authenticate.js';
import { HttpError } from '../http/errors.js';
import { validated } from '../http/validate.js';
import { AssistUsageRepository } from '../db/assist-usage.js';

export interface AssistDeps {
  upstream: GeminiUpstream | null;
  usage: AssistUsageRepository;
  dailyLimit: number;
  now?: () => Date;
}

/**
 * The server's own assist ([[ADR-013-Assist-Providers]]).
 *
 * A signed-in account may borrow the server's key, so an assist works
 * without pasting one — and a key of my own still wins on the phone,
 * where it is set. The words are relayed to the model and the model's
 * words back; nothing of either is stored, only the count that keeps
 * one account from spending the whole month's quota in an afternoon.
 *
 * Mounted behind requireAuth and requireVerified, like sync.
 */
export function assistRoutes({ upstream, usage, dailyLimit, now = () => new Date() }: AssistDeps): Router {
  const router = Router();

  router.get('/status', async (_req, res) => {
    const { userId } = authOf(res);
    const day = AssistUsageRepository.dayOf(now());
    res.json({
      available: upstream !== null,
      model: upstream?.model ?? null,
      usedToday: await usage.usedOn(userId, day),
      dailyLimit,
    });
  });

  router.post(
    '/',
    ...validated({ body: assistRequestSchema }, async ({ body }, _req, res) => {
      if (!upstream) throw new HttpError('unavailable', 'This server has no assist');
      const { userId } = authOf(res);
      const at = now();
      const day = AssistUsageRepository.dayOf(at);

      // Counted before the call, so a failure costs a request: a free
      // retry is a free loop.
      const spent = await usage.spend(userId, day, at);
      if (spent > dailyLimit) {
        throw new HttpError('rate_limited', 'That is all the assist this account has today');
      }

      // Server-sent events: the first words go out while the rest are
      // still being written.
      res.status(200).set({
        'content-type': 'text/event-stream; charset=utf-8',
        'cache-control': 'no-cache, no-transform',
        connection: 'keep-alive',
      });
      res.flushHeaders();

      try {
        for await (const text of upstream.stream(body)) {
          if (res.writableEnded) return;
          res.write(`data: ${JSON.stringify({ text })}\n\n`);
        }
        res.write(`data: ${assistDoneMarker}\n\n`);
      } catch (error) {
        // The status is long gone, so the failure travels as a line.
        const code = error instanceof HttpError ? error.code : 'internal';
        res.write(`data: ${JSON.stringify({ error: code })}\n\n`);
      } finally {
        res.end();
      }
    }),
  );

  return router;
}
