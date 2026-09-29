import { HttpError } from '../http/errors.js';

/** How long a request waits for its account's lock before it is told to come back (Q6-17). */
export const lockWaitMs = 30_000;

/**
 * One queue per key. Pushes for one account run one at a time, which is
 * what keeps a pull from ever skipping a row: a sequence number is taken
 * and its row written before the next one is taken, so whatever a pull
 * sees is always a prefix of the sequence, never a prefix with a hole
 * that fills in later behind its cursor.
 *
 * A waiter waits at most [waitMs]; past that it answers `rate_limited`
 * with `Retry-After`, which both clients wait out, rather than hang
 * behind a task that is stuck. It keeps its place in the queue all the
 * same, so whoever came after it still waits for the stuck task.
 *
 * It is a lock in this process only. One server process is the
 * deployment ([[ADR-011-Backend]]); running several would need the lock
 * in Mongo instead.
 */
export class KeyedMutex {
  private readonly tails = new Map<string, Promise<void>>();

  constructor(private readonly waitMs = lockWaitMs) {}

  async run<T>(key: string, task: () => Promise<T>): Promise<T> {
    const previous = this.tails.get(key) ?? Promise.resolve();
    let release!: () => void;
    const current = new Promise<void>((resolve) => (release = resolve));
    const tail = previous.then(() => current);
    this.tails.set(key, tail);
    const done = () => {
      release();
      if (this.tails.get(key) === tail) this.tails.delete(key);
    };
    let timer: NodeJS.Timeout | undefined;
    const waited = await Promise.race([
      previous.then(() => true),
      new Promise<false>((resolve) => (timer = setTimeout(() => resolve(false), this.waitMs))),
    ]);
    clearTimeout(timer);
    if (!waited) {
      // Out of the queue only once the one ahead is: nothing behind
      // this waiter may slip past a task that is still running.
      void previous.then(done);
      throw new HttpError('rate_limited', 'This account is busy; try again in a moment', undefined, {
        'Retry-After': '5',
      });
    }
    try {
      return await task();
    } finally {
      done();
    }
  }
}
