import argon2 from 'argon2';
import { HttpError } from '../http/errors.js';

/**
 * argon2id at the OWASP Password Storage Cheat Sheet's first
 * recommendation: 19 MiB of memory, two passes, one lane. The
 * parameters are encoded in each hash, so raising them later only
 * affects new hashes.
 */
const options = {
  type: argon2.argon2id,
  memoryCost: 19_456,
  timeCost: 2,
  parallelism: 1,
} as const;

/**
 * At most this many hashes at once, whoever asks: sign-up, sign-in, a
 * reset and deleting the account all share it. Tens of requests at once
 * would otherwise be tens of 19 MiB buffers on a small server (audit
 * S5-03). The rest wait their turn, up to a queue this long; past it
 * the answer is "try again shortly".
 */
export const maxConcurrentHashes = 4;
export const maxWaitingHashes = 64;

class Semaphore {
  private running = 0;
  private readonly waiting: (() => void)[] = [];

  constructor(
    private readonly limit: number,
    private readonly queue: number,
  ) {}

  async run<T>(task: () => Promise<T>): Promise<T> {
    if (this.running >= this.limit) {
      if (this.waiting.length >= this.queue) {
        throw new HttpError('rate_limited', 'The server is busy; try again shortly', undefined, { 'Retry-After': '5' });
      }
      await new Promise<void>((resolve) => this.waiting.push(resolve));
    } else {
      this.running += 1;
    }
    try {
      return await task();
    } finally {
      // The slot passes straight to the next in line, or is given back.
      const next = this.waiting.shift();
      if (next) next();
      else this.running -= 1;
    }
  }

  /** For tests: how many run and how many wait. */
  get load(): { running: number; waiting: number } {
    return { running: this.running, waiting: this.waiting.length };
  }
}

export const hashing = new Semaphore(maxConcurrentHashes, maxWaitingHashes);

export function hashPassword(password: string): Promise<string> {
  return hashing.run(() => argon2.hash(password, options));
}

/**
 * A hash of nothing in particular, verified against when the email is
 * unknown, so "no such account" takes as long as "wrong password" and
 * the timing cannot tell them apart (AC3).
 */
let decoy: Promise<string> | undefined;

export async function verifyPassword(hash: string | null, password: string): Promise<boolean> {
  if (hash === null) {
    decoy ??= argon2.hash('harvest-decoy-password', options);
    const stand = await decoy;
    await hashing.run(() => argon2.verify(stand, password));
    return false;
  }
  return hashing.run(async () => {
    try {
      return await argon2.verify(hash, password);
    } catch {
      return false;
    }
  });
}
