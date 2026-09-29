import { Unzip, UnzipInflate } from 'fflate';

/** A zip whose entries, inflated, would be more than they may be. */
export class ZipTooLargeError extends Error {
  override readonly name = 'ZipTooLargeError';
}

export interface ZipLimits {
  /** What one entry may weigh, inflated. */
  limitOf: (name: string) => number;
  /** What every kept entry may weigh, together. */
  total: number;
  /** How many entries the zip may have. */
  maxEntries: number;
  /** Which entries are wanted; the rest are never inflated. */
  keep?: (name: string) => boolean;
}

/**
 * Unzips [bytes] weighing what comes out as it comes out (S6-09): an
 * entry that inflates past its limit, or all of them past the total,
 * stops the reading at once with [ZipTooLargeError], whatever the zip's
 * own directory claimed, so a bomb never reaches memory whole.
 */
export function boundedUnzip(bytes: Uint8Array, limits: ZipLimits): Record<string, Uint8Array> {
  const out: Record<string, Uint8Array> = {};
  let total = 0;
  let count = 0;
  const stop: { failure: Error | null } = { failure: null };
  const unzip = new Unzip((file) => {
    if (stop.failure !== null) return;
    count++;
    if (count > limits.maxEntries) {
      stop.failure = new ZipTooLargeError('Too many entries');
      return;
    }
    if (file.name.endsWith('/') || (limits.keep && !limits.keep(file.name))) return;
    const limit = limits.limitOf(file.name);
    const chunks: Uint8Array[] = [];
    let size = 0;
    file.ondata = (error, chunk, final) => {
      if (stop.failure !== null) return;
      if (error) {
        stop.failure = error instanceof Error ? error : new Error(String(error));
        return;
      }
      size += chunk.length;
      total += chunk.length;
      if (size > limit || total > limits.total) {
        stop.failure = new ZipTooLargeError(`${file.name} is too large`);
        file.terminate();
        return;
      }
      chunks.push(chunk);
      if (final) out[file.name] = concat(chunks, size);
    };
    file.start();
  });
  unzip.register(UnzipInflate);
  unzip.push(bytes, true);
  if (stop.failure !== null) throw stop.failure;
  return out;
}

function concat(chunks: Uint8Array[], size: number): Uint8Array {
  if (chunks.length === 1) return chunks[0]!;
  const joined = new Uint8Array(size);
  let at = 0;
  for (const chunk of chunks) {
    joined.set(chunk, at);
    at += chunk.length;
  }
  return joined;
}
