import type { Collection } from 'mongodb';
import type { WindowedCountDoc } from './types.js';

/** One window of a limit: at most [max] in [ms]. */
export interface CountWindow {
  max: number;
  ms: number;
}

/**
 * Counts kept in Mongo, in one or more fixed windows per key, so a
 * limit survives a restart: wrong PIN proofs per account, mails per
 * recipient. Each window starts at the first count after the last one
 * ended. A document goes on its own once its longest window is over.
 */
export class WindowedCountsRepository {
  constructor(private readonly counts: Collection<WindowedCountDoc>) {}

  /** Starts any window of [key] that has ended, and makes the document if it is new. */
  private async roll(key: string, windows: readonly CountWindow[], now: Date): Promise<void> {
    const longest = Math.max(...windows.map((w) => w.ms));
    const fresh = windows.map((w) => ({ count: 0, resetAt: new Date(now.getTime() + w.ms) }));
    await this.counts.updateOne(
      { _id: key },
      { $setOnInsert: { windows: fresh, expiresAt: new Date(now.getTime() + longest) } },
      { upsert: true },
    );
    for (const [index, window] of windows.entries()) {
      await this.counts.updateOne(
        { _id: key, [`windows.${index}.resetAt`]: { $lte: now } },
        {
          $set: { [`windows.${index}`]: { count: 0, resetAt: new Date(now.getTime() + window.ms) } },
          $max: { expiresAt: new Date(now.getTime() + window.ms) },
        },
      );
    }
  }

  /**
   * Takes one count in every window, atomically, if none is full.
   * Answers the counts left (the smallest over the windows) after this
   * one, or, when a window is full, the seconds until it opens again.
   */
  async take(
    key: string,
    windows: readonly CountWindow[],
    now: Date,
  ): Promise<{ ok: true; left: number } | { ok: false; retryAfter: number }> {
    await this.roll(key, windows, now);
    const room = Object.fromEntries(windows.map((w, index) => [`windows.${index}.count`, { $lt: w.max }]));
    const inc = Object.fromEntries(windows.map((_w, index) => [`windows.${index}.count`, 1]));
    const taken = await this.counts.findOneAndUpdate({ _id: key, ...room }, { $inc: inc }, { returnDocument: 'after' });
    if (taken) {
      const left = Math.min(...windows.map((w, index) => w.max - (taken.windows[index]?.count ?? 0)));
      return { ok: true, left };
    }
    const doc = await this.counts.findOne({ _id: key });
    const waits = windows
      .map((w, index) => {
        const held = doc?.windows[index];
        return held && held.count >= w.max ? held.resetAt.getTime() - now.getTime() : 0;
      })
      .filter((ms) => ms > 0);
    return { ok: false, retryAfter: Math.max(1, Math.ceil(Math.max(...waits, 1000) / 1000)) };
  }

  /**
   * Gives a count back: the one just taken turned out not to count (a
   * right PIN). [clear] windows go back to zero as well.
   */
  async giveBack(key: string, windows: readonly CountWindow[], clear: readonly number[] = []): Promise<void> {
    const set = Object.fromEntries(clear.map((index) => [`windows.${index}.count`, 0]));
    const inc = Object.fromEntries(
      windows.map((_w, index) => index).filter((index) => !clear.includes(index)).map((index) => [`windows.${index}.count`, -1]),
    );
    await this.counts.updateOne({ _id: key }, { ...(clear.length > 0 ? { $set: set } : {}), ...(Object.keys(inc).length > 0 ? { $inc: inc } : {}) });
  }

  async clear(key: string): Promise<void> {
    await this.counts.deleteOne({ _id: key });
  }
}
