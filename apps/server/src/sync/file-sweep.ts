import type { ObjectId } from 'mongodb';
import type { Logger } from 'pino';
import type { Repositories } from '../db/index.js';
import type { KeyedMutex } from './mutex.js';

/**
 * How long a file no row names is kept anyway: a device that uploaded
 * it, or was told the server has it, may name it in a row it has not
 * pushed yet (offline for a week, say).
 */
export const unnamedFileGraceMs = 30 * 24 * 60 * 60_000;

/**
 * Lets go of files no row names any more (Q5-23).
 *
 * The server can tell which files are named because the only rows that
 * name one, those of `fileTables` (every table with a `fileHash`, today
 * `memories` and `note_attachments`), are plain tier: their `fileHash`
 * is in the clear. A row in the trash still names its file; a purged
 * one does not.
 *
 * It runs under the account's lock, so a push naming a file and the
 * sweep deciding nobody does cannot interleave, and it leaves alone
 * anything uploaded or claimed within [unnamedFileGraceMs].
 */
export class FileSweeper {
  constructor(
    private readonly repos: Repositories,
    private readonly lock: KeyedMutex,
    private readonly now: () => Date = () => new Date(),
  ) {}

  /** Sweeps one account; answers how many files went. */
  async sweep(userId: ObjectId): Promise<number> {
    return this.lock.run(userId.toHexString(), async () => {
      const named = await this.repos.records.namedFiles(userId);
      const before = new Date(this.now().getTime() - unnamedFileGraceMs);
      const gone = await this.repos.files.unnamed(userId, named, before);
      for (const sha256 of gone) {
        const bytes = await this.repos.files.delete(userId, sha256);
        if (bytes !== null) await this.repos.totals.release(userId, 'fileBytes', bytes);
      }
      return gone.length;
    });
  }

  /** Sweeps every account that holds a file. */
  async sweepAll(logger?: Logger): Promise<number> {
    let total = 0;
    for (const userId of await this.repos.files.owners()) {
      try {
        total += await this.sweep(userId);
      } catch (error) {
        logger?.error({ err: error, userId: userId.toHexString() }, 'file sweep failed for an account');
      }
    }
    if (total > 0) logger?.info({ files: total }, 'swept files no row names');
    return total;
  }
}
