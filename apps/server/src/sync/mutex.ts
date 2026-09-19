/**
 * One queue per key. Pushes for one account run one at a time, which is
 * what keeps a pull from ever skipping a row: a sequence number is taken
 * and its row written before the next one is taken, so whatever a pull
 * sees is always a prefix of the sequence, never a prefix with a hole
 * that fills in later behind its cursor.
 *
 * It is a lock in this process only. One server process is the
 * deployment ([[ADR-011-Backend]]); running several would need the lock
 * in Mongo instead.
 */
export class KeyedMutex {
  private readonly tails = new Map<string, Promise<void>>();

  async run<T>(key: string, task: () => Promise<T>): Promise<T> {
    const previous = this.tails.get(key) ?? Promise.resolve();
    let release!: () => void;
    const current = new Promise<void>((resolve) => (release = resolve));
    const tail = previous.then(() => current);
    this.tails.set(key, tail);
    try {
      await previous;
      return await task();
    } finally {
      release();
      if (this.tails.get(key) === tail) this.tails.delete(key);
    }
  }
}
