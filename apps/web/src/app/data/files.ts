import { openFile } from '@harvest/contracts';
import { api } from '@/lib/api';
import type { HarvestDB } from './db';
import type { Keyring } from '../sync/keyring';

/**
 * Pictures and recordings, fetched by the name of their own bytes
 * ([[Sync-API]], files).
 *
 * What comes back is opened with the private tier's key and hashed
 * again: bytes that do not hash to the name they came under are not
 * the file the row means, and are thrown away rather than shown.
 */
export class FileStore {
  private readonly pending = new Map<string, Promise<Blob | null>>();

  constructor(
    private readonly db: HarvestDB,
    private readonly keyring: Keyring,
    private readonly salt: () => string,
  ) {}

  /** The file, from the cache or the server; null when it cannot be had. */
  async get(sha256: string): Promise<Blob | null> {
    const held = await this.db.files.get(sha256);
    if (held) return held.blob;
    const running = this.pending.get(sha256);
    if (running) return running;
    const fetching = this.fetch(sha256).finally(() => this.pending.delete(sha256));
    this.pending.set(sha256, fetching);
    return fetching;
  }

  private async fetch(sha256: string): Promise<Blob | null> {
    const key = await this.keyring.key(this.salt());
    if (!key) return null;
    try {
      const { sealed, iv } = await api.file(sha256);
      const plain = await openFile(key, sha256, { iv, ct: sealed });
      const bytes = plain.slice().buffer;
      if ((await sha256Of(bytes)) !== sha256) return null;
      const blob = new Blob([bytes]);
      await this.db.files.put({ sha256, blob, fetchedAt: new Date().toISOString() });
      return blob;
    } catch {
      // Not there yet, not ours to open, or no connection: the picture
      // is simply on another device for now.
      return null;
    }
  }
}

/** The name a file's bytes give themselves. */
export async function sha256Of(bytes: ArrayBuffer): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-256', bytes);
  return [...new Uint8Array(digest)].map((byte) => byte.toString(16).padStart(2, '0')).join('');
}
